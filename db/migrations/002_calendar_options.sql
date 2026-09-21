ALTER TABLE inventory.resources ADD CONSTRAINT one_resource_per_property UNIQUE(tenant_id,property_id);
ALTER TABLE inventory.days ADD COLUMN nightly_minor bigint CHECK(nightly_minor>0);
ALTER TABLE inventory.days ADD COLUMN currency char(3) REFERENCES core.currencies;
ALTER TABLE booking.holds ADD COLUMN resource_id uuid;
ALTER TABLE booking.holds ADD COLUMN check_in date;
ALTER TABLE booking.holds ADD COLUMN check_out date;
ALTER TABLE booking.holds ADD COLUMN request_key text;
ALTER TABLE booking.holds ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE booking.holds ADD CONSTRAINT hold_resource_fk FOREIGN KEY(tenant_id,resource_id) REFERENCES inventory.resources(tenant_id,id);
ALTER TABLE booking.holds ADD CONSTRAINT hold_dates CHECK(check_out>check_in);
ALTER TABLE booking.holds ADD CONSTRAINT hold_request_unique UNIQUE(tenant_id,request_key);
CREATE TABLE inventory.allocations (
 tenant_id uuid NOT NULL, hold_id uuid NOT NULL, resource_id uuid NOT NULL, service_date date NOT NULL,
 PRIMARY KEY(tenant_id,hold_id,service_date),
 FOREIGN KEY(tenant_id,hold_id) REFERENCES booking.holds(tenant_id,id),
 FOREIGN KEY(tenant_id,resource_id,service_date) REFERENCES inventory.days(tenant_id,resource_id,service_date)
);
ALTER TABLE inventory.allocations ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON inventory.allocations
 USING(tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid)
 WITH CHECK(tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid);

-- Every writer locks the same property first. No network call occurs under this lock.
CREATE FUNCTION inventory.require_editor() RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid;
BEGIN
 IF NOT EXISTS(SELECT FROM auth.users WHERE tenant_id=t AND id=nullif(current_setting('app.actor_id',true),'')::uuid AND role IN ('owner','editor')) THEN
  RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501';
 END IF;
 RETURN t;
END $$;

CREATE FUNCTION inventory.expire_locked(p_tenant uuid,p_resource uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE h record;
BEGIN
 FOR h IN SELECT * FROM booking.holds WHERE tenant_id=p_tenant AND resource_id=p_resource AND status='active' AND expires_at<=clock_timestamp() FOR UPDATE LOOP
  UPDATE inventory.days d SET held=held-1 FROM inventory.allocations a
  WHERE a.tenant_id=p_tenant AND a.hold_id=h.id AND d.tenant_id=a.tenant_id AND d.resource_id=a.resource_id AND d.service_date=a.service_date;
  UPDATE booking.holds SET status='expired' WHERE id=h.id;
  INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload) VALUES(p_tenant,'hold.expired',h.id,2,'{}');
  INSERT INTO events.audit(tenant_id,action,resource_id,payload) VALUES(p_tenant,'hold.expired',h.id,'{}');
 END LOOP;
END $$;

CREATE FUNCTION inventory.configure(p_property text,p_start text,p_end text,p_minor bigint,p_blocked boolean) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=inventory.require_editor(); p catalog.properties%ROWTYPE; r uuid; a date; b date;
BEGIN
 BEGIN a:=p_start::date; b:=p_end::date; EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN 'invalid_dates'; END;
 IF a IS NULL OR b IS NULL OR b<=a OR b-a>366 OR a<(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date OR p_minor IS NULL OR p_minor<=0 OR p_minor>1000000000 THEN RETURN 'invalid_range'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE tenant_id=t AND id::text=p_property FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 INSERT INTO inventory.resources(tenant_id,property_id,name) VALUES(t,p.id,p.title) ON CONFLICT(tenant_id,property_id) DO NOTHING;
 SELECT id INTO r FROM inventory.resources WHERE tenant_id=t AND property_id=p.id;
 PERFORM inventory.expire_locked(t,r);
 IF p_blocked AND EXISTS(SELECT FROM inventory.days WHERE tenant_id=t AND resource_id=r AND service_date>=a AND service_date<b AND held+sold>0) THEN RETURN 'occupied'; END IF;
 INSERT INTO inventory.days(tenant_id,resource_id,service_date,capacity,blocked,nightly_minor,currency)
 SELECT t,r,a+i,1,CASE WHEN p_blocked THEN 1 ELSE 0 END,p_minor,p.currency FROM generate_series(0,b-a-1) i
 ON CONFLICT(tenant_id,resource_id,service_date) DO UPDATE SET blocked=EXCLUDED.blocked,nightly_minor=EXCLUDED.nightly_minor,currency=EXCLUDED.currency;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,nullif(current_setting('app.actor_id',true),'')::uuid,'calendar.configured',p.id,jsonb_build_object('start',a,'end_exclusive',b,'nightly_minor',p_minor,'blocked',p_blocked));
 INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload) VALUES(t,'availability.changed',p.id,1,jsonb_build_object('start',a,'end_exclusive',b));
 RETURN 'ok';
END $$;

CREATE FUNCTION inventory.create_hold(p_property text,p_start text,p_end text,p_minutes int,p_key text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=inventory.require_editor(); p catalog.properties%ROWTYPE; r uuid; a date; b date; total bigint; n int; q uuid; h uuid; expiry timestamptz; old booking.holds%ROWTYPE; snapshot jsonb;
BEGIN
 BEGIN a:=p_start::date; b:=p_end::date; EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN 'invalid_dates'; END;
 IF a IS NULL OR b IS NULL OR b<=a OR b-a>90 OR a<(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date OR p_minutes IS NULL OR p_minutes<1 OR p_minutes>1440 OR p_key IS NULL OR length(p_key) NOT BETWEEN 16 AND 128 THEN RETURN 'invalid_range'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE tenant_id=t AND id::text=p_property FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 SELECT id INTO r FROM inventory.resources WHERE tenant_id=t AND property_id=p.id;
 IF NOT FOUND THEN RETURN 'unavailable'; END IF;
 SELECT * INTO old FROM booking.holds WHERE tenant_id=t AND request_key=p_key;
 IF FOUND THEN
  IF old.resource_id<>r OR old.check_in<>a OR old.check_out<>b OR (SELECT (quotes.snapshot->>'minutes')::int FROM booking.quotes WHERE id=old.quote_id)<>p_minutes THEN RETURN 'key_conflict'; END IF;
  RETURN 'ok';
 END IF;
 PERFORM inventory.expire_locked(t,r);
 SELECT count(*),sum(nightly_minor),jsonb_agg(jsonb_build_object('date',service_date,'minor',nightly_minor) ORDER BY service_date)
 INTO n,total,snapshot FROM inventory.days WHERE tenant_id=t AND resource_id=r AND service_date>=a AND service_date<b
 AND capacity-blocked-held-sold>=1 AND nightly_minor IS NOT NULL AND currency=p.currency;
 IF n<>b-a THEN RETURN 'unavailable'; END IF;
 expiry:=clock_timestamp()+make_interval(mins=>p_minutes);
 INSERT INTO booking.quotes(tenant_id,property_id,total_minor,currency,snapshot,expires_at)
 VALUES(t,p.id,total,p.currency,jsonb_build_object('nights',snapshot,'check_in',a,'check_out',b,'minutes',p_minutes,'pricing_model','nightly_no_extras','currency',p.currency),expiry) RETURNING id INTO q;
 INSERT INTO booking.holds(tenant_id,quote_id,status,expires_at,resource_id,check_in,check_out,request_key)
 VALUES(t,q,'active',expiry,r,a,b,p_key) RETURNING id INTO h;
 INSERT INTO inventory.allocations SELECT t,h,r,a+i FROM generate_series(0,b-a-1) i;
 UPDATE inventory.days SET held=held+1 WHERE tenant_id=t AND resource_id=r AND service_date>=a AND service_date<b;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,nullif(current_setting('app.actor_id',true),'')::uuid,'hold.created',h,jsonb_build_object('total_minor',total,'expires_at',expiry));
 INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload) VALUES(t,'hold.created',h,1,jsonb_build_object('quote_id',q,'expires_at',expiry));
 RETURN 'ok';
END $$;

CREATE FUNCTION inventory.release_hold(p_id text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=inventory.require_editor(); r uuid; p uuid; h booking.holds%ROWTYPE;
BEGIN
 SELECT resources.id,resources.property_id INTO r,p FROM inventory.resources resources JOIN booking.holds holds ON holds.resource_id=resources.id AND holds.tenant_id=resources.tenant_id WHERE holds.tenant_id=t AND holds.id::text=p_id;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 PERFORM 1 FROM catalog.properties WHERE tenant_id=t AND id=p FOR UPDATE;
 PERFORM inventory.expire_locked(t,r);
 SELECT * INTO h FROM booking.holds WHERE tenant_id=t AND id::text=p_id FOR UPDATE;
 IF h.status<>'active' THEN RETURN 'ok'; END IF;
 UPDATE inventory.days d SET held=held-1 FROM inventory.allocations a WHERE a.tenant_id=t AND a.hold_id=h.id AND d.tenant_id=a.tenant_id AND d.resource_id=a.resource_id AND d.service_date=a.service_date;
 UPDATE booking.holds SET status='released' WHERE id=h.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,nullif(current_setting('app.actor_id',true),'')::uuid,'hold.released',h.id,'{}');
 INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload) VALUES(t,'hold.released',h.id,2,'{}');
 RETURN 'ok';
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA inventory FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory.configure(text,text,text,bigint,boolean),inventory.create_hold(text,text,text,int,text),inventory.release_hold(text) TO nexus_app;
