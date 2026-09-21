ALTER TABLE booking.reservations ADD COLUMN agency_id uuid REFERENCES core.organizations;
ALTER TABLE booking.reservations ADD COLUMN request_id uuid UNIQUE REFERENCES booking.option_requests;
ALTER TABLE booking.reservations ADD COLUMN total_minor bigint CHECK(total_minor>0);
ALTER TABLE booking.reservations ADD COLUMN currency char(3) REFERENCES core.currencies;
ALTER TABLE booking.reservations ADD COLUMN payment_status text NOT NULL DEFAULT 'unpaid' CHECK(payment_status IN ('unpaid','paid','refunded'));

CREATE FUNCTION booking.confirm_request(p_id text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; r booking.option_requests%ROWTYPE; h booking.holds%ROWTYPE; q booking.quotes%ROWTYPE; rid uuid;
BEGIN
 IF auth.workspace() IS DISTINCT FROM 'agency' OR NOT EXISTS(SELECT FROM auth.users WHERE tenant_id=t AND id=nullif(current_setting('app.actor_id',true),'')::uuid AND role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 SELECT * INTO r FROM booking.option_requests WHERE id::text=p_id AND agency_id=t FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF EXISTS(SELECT FROM booking.reservations WHERE request_id=r.id) THEN RETURN 'already_booked'; END IF;
 IF r.status<>'approved' OR r.hold_id IS NULL THEN RETURN 'not_approved'; END IF;
 PERFORM 1 FROM partners.connections WHERE supplier_id=r.supplier_id AND agency_id=t AND status='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'forbidden'; END IF;
 -- Same lock order as configure/release/expiry: property, then hold.
 PERFORM 1 FROM catalog.properties WHERE id=r.property_id AND tenant_id=r.supplier_id FOR UPDATE;
 SELECT * INTO h FROM booking.holds WHERE id=r.hold_id AND tenant_id=r.supplier_id;
 PERFORM inventory.expire_locked(r.supplier_id,h.resource_id);
 SELECT * INTO h FROM booking.holds WHERE id=r.hold_id AND tenant_id=r.supplier_id FOR UPDATE;
 IF h.status<>'active' OR h.expires_at<=clock_timestamp() THEN RETURN 'expired'; END IF;
 SELECT * INTO q FROM booking.quotes WHERE id=h.quote_id AND tenant_id=r.supplier_id;
 UPDATE inventory.days d SET held=held-1,sold=sold+1 FROM inventory.allocations a WHERE a.tenant_id=r.supplier_id AND a.hold_id=h.id AND d.tenant_id=a.tenant_id AND d.resource_id=a.resource_id AND d.service_date=a.service_date;
 UPDATE booking.holds SET status='consumed' WHERE id=h.id;
 INSERT INTO booking.reservations(tenant_id,hold_id,status,agency_id,request_id,total_minor,currency)
 VALUES(r.supplier_id,h.id,'confirmed',t,r.id,q.total_minor,q.currency) RETURNING id INTO rid;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(r.supplier_id,nullif(current_setting('app.actor_id',true),'')::uuid,'reservation.confirmed',rid,jsonb_build_object('agency_id',t,'payment_status','unpaid'));
 INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload) VALUES(r.supplier_id,'reservation.confirmed',rid,1,jsonb_build_object('request_id',r.id));
 RETURN 'ok';
END $$;

CREATE FUNCTION booking.cancel_reservation(p_id text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=inventory.require_editor(); b booking.reservations%ROWTYPE; p uuid;
BEGIN
 SELECT q.property_id INTO p FROM booking.reservations r JOIN booking.holds h ON h.id=r.hold_id JOIN booking.quotes q ON q.id=h.quote_id WHERE r.id::text=p_id AND r.tenant_id=t;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 PERFORM 1 FROM catalog.properties WHERE id=p AND tenant_id=t FOR UPDATE;
 SELECT * INTO b FROM booking.reservations WHERE id::text=p_id AND tenant_id=t FOR UPDATE;
 IF b.status='cancelled' THEN RETURN 'ok'; END IF;
 IF b.status<>'confirmed' OR b.payment_status<>'unpaid' THEN RETURN 'manual_review'; END IF;
 UPDATE inventory.days d SET sold=sold-1 FROM inventory.allocations a WHERE a.tenant_id=t AND a.hold_id=b.hold_id AND d.tenant_id=a.tenant_id AND d.resource_id=a.resource_id AND d.service_date=a.service_date;
 UPDATE booking.reservations SET status='cancelled' WHERE id=b.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,nullif(current_setting('app.actor_id',true),'')::uuid,'reservation.cancelled',b.id,'{}');
 INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload) VALUES(t,'reservation.cancelled',b.id,2,'{}');
 RETURN 'ok';
END $$;

CREATE FUNCTION booking.reservation_list() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[b.id::text,p.title,s.legal_name,a.legal_name,h.check_in::text,h.check_out::text,b.total_minor::text,b.currency::text,b.status,b.payment_status]
 FROM booking.reservations b JOIN booking.holds h ON h.id=b.hold_id JOIN booking.quotes q ON q.id=h.quote_id JOIN catalog.properties p ON p.id=q.property_id JOIN core.organizations s ON s.id=b.tenant_id JOIN core.organizations a ON a.id=b.agency_id
 WHERE auth.workspace()='nexus' OR (auth.workspace()='supplier' AND b.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid) OR (auth.workspace()='agency' AND b.agency_id=nullif(current_setting('app.tenant_id',true),'')::uuid)
 ORDER BY b.created_at DESC LIMIT 100;
$$;
REVOKE ALL ON FUNCTION booking.confirm_request(text),booking.cancel_reservation(text),booking.reservation_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION booking.confirm_request(text),booking.cancel_reservation(text),booking.reservation_list() TO nexus_app;

CREATE OR REPLACE FUNCTION booking.requests() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[r.id::text,p.title,s.legal_name,a.legal_name,r.check_in::text,r.check_out::text,r.status,coalesce(CASE WHEN h.status='active' AND h.expires_at<=clock_timestamp() THEN 'expired' ELSE h.status END,'-'),coalesce(q.total_minor::text,''),coalesce(q.currency::text,'')]
 FROM booking.option_requests r JOIN catalog.properties p ON p.id=r.property_id JOIN core.organizations s ON s.id=r.supplier_id JOIN core.organizations a ON a.id=r.agency_id LEFT JOIN booking.holds h ON h.id=r.hold_id LEFT JOIN booking.quotes q ON q.id=h.quote_id
 WHERE auth.workspace()='nexus' OR (auth.workspace()='supplier' AND r.supplier_id=nullif(current_setting('app.tenant_id',true),'')::uuid) OR (auth.workspace()='agency' AND r.agency_id=nullif(current_setting('app.tenant_id',true),'')::uuid)
 ORDER BY r.created_at DESC LIMIT 100;
$$;
