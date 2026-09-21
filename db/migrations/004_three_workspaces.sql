ALTER TABLE core.organizations ADD COLUMN kind text NOT NULL DEFAULT 'supplier' CHECK(kind IN ('supplier','nexus','agency'));
UPDATE core.organizations SET kind='nexus' WHERE id='11111111-1111-4111-8111-111111111111';
CREATE SCHEMA partners;
CREATE TABLE partners.connections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), supplier_id uuid NOT NULL REFERENCES core.organizations,
 agency_id uuid NOT NULL REFERENCES core.organizations, status text NOT NULL CHECK(status IN ('active','paused')),
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(supplier_id,agency_id), CHECK(supplier_id<>agency_id)
);
CREATE TABLE booking.option_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), supplier_id uuid NOT NULL REFERENCES core.organizations,
 agency_id uuid NOT NULL REFERENCES core.organizations, property_id uuid NOT NULL,
 check_in date NOT NULL, check_out date NOT NULL CHECK(check_out>check_in), minutes int NOT NULL CHECK(minutes BETWEEN 1 AND 1440),
 request_key text NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 hold_id uuid, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(agency_id,request_key),
 FOREIGN KEY(supplier_id,property_id) REFERENCES catalog.properties(tenant_id,id),
 FOREIGN KEY(supplier_id,hold_id) REFERENCES booking.holds(tenant_id,id)
);
ALTER TABLE partners.connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking.option_requests ENABLE ROW LEVEL SECURITY;
-- No runtime direct table grants: every cross-company operation passes a checked function.
CREATE FUNCTION auth.workspace() RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT o.kind FROM core.organizations o JOIN auth.users u ON u.tenant_id=o.id
 WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid;
$$;
DROP FUNCTION auth.session(text);
CREATE FUNCTION auth.session(p_token text) RETURNS TABLE(tenant text,userid text,username text,userrole text,workspace text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.role,o.kind FROM auth.sessions s JOIN auth.users u ON u.id=s.user_id JOIN core.organizations o ON o.id=u.tenant_id
 WHERE s.token_hash=encode(public.digest(p_token,'sha256'),'hex') AND s.expires_at>now();
$$;
CREATE OR REPLACE FUNCTION inventory.require_editor() RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid;
BEGIN
 IF auth.workspace()<>'supplier' OR NOT EXISTS(SELECT FROM auth.users WHERE tenant_id=t AND id=nullif(current_setting('app.actor_id',true),'')::uuid AND role IN ('owner','editor')) THEN
  RAISE EXCEPTION 'Supplier editor required' USING ERRCODE='42501';
 END IF;
 RETURN t;
END $$;
CREATE FUNCTION partners.directory() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[s.id::text,s.legal_name,a.id::text,a.legal_name,coalesce(c.status,'not_connected')]
 FROM core.organizations s CROSS JOIN core.organizations a LEFT JOIN partners.connections c ON c.supplier_id=s.id AND c.agency_id=a.id
 WHERE auth.workspace()='nexus' AND s.kind='supplier' AND a.kind='agency' ORDER BY s.legal_name,a.legal_name LIMIT 100;
$$;
CREATE FUNCTION partners.connect(p_supplier text,p_agency text,p_status text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.workspace()<>'nexus' OR NOT EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND role='owner') THEN RETURN 'forbidden'; END IF;
 IF p_status NOT IN ('active','paused') OR NOT EXISTS(SELECT FROM core.organizations WHERE id::text=p_supplier AND kind='supplier') OR NOT EXISTS(SELECT FROM core.organizations WHERE id::text=p_agency AND kind='agency') THEN RETURN 'not_found'; END IF;
 INSERT INTO partners.connections(supplier_id,agency_id,status) VALUES(p_supplier::uuid,p_agency::uuid,p_status) ON CONFLICT(supplier_id,agency_id) DO UPDATE SET status=EXCLUDED.status,updated_at=now();
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,nullif(current_setting('app.actor_id',true),'')::uuid,'partner.connection_changed',p_supplier::uuid,jsonb_build_object('agency',p_agency,'status',p_status));
 RETURN 'ok';
END $$;
CREATE FUNCTION partners.agency_catalog() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[p.id::text,p.title,o.legal_name,p.locality,p.nightly_minor::text,p.currency::text]
 FROM catalog.properties p JOIN core.organizations o ON o.id=p.tenant_id JOIN partners.connections c ON c.supplier_id=p.tenant_id
 WHERE auth.workspace()='agency' AND c.agency_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND c.status='active' AND p.status='published' ORDER BY p.title LIMIT 100;
$$;
CREATE FUNCTION booking.request_option(p_property text,p_start text,p_end text,p_minutes int,p_key text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; p catalog.properties%ROWTYPE; a date; b date; old booking.option_requests%ROWTYPE;
BEGIN
 IF auth.workspace()<>'agency' OR NOT EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 BEGIN a:=p_start::date; b:=p_end::date; EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN 'invalid_dates'; END;
 IF a IS NULL OR b IS NULL OR b<=a OR b-a>90 OR a<(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date OR p_minutes IS NULL OR p_minutes NOT BETWEEN 1 AND 1440 OR length(p_key) NOT BETWEEN 16 AND 128 THEN RETURN 'invalid_range'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_property AND status='published';
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 PERFORM 1 FROM partners.connections WHERE supplier_id=p.tenant_id AND agency_id=t AND status='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'forbidden'; END IF;
 SELECT * INTO old FROM booking.option_requests WHERE agency_id=t AND request_key=p_key;
 IF FOUND THEN
  IF old.property_id<>p.id OR old.check_in<>a OR old.check_out<>b OR old.minutes<>p_minutes THEN RETURN 'key_conflict'; END IF;
  RETURN 'ok';
 END IF;
 INSERT INTO booking.option_requests(supplier_id,agency_id,property_id,check_in,check_out,minutes,request_key) VALUES(p.tenant_id,t,p.id,a,b,p_minutes,p_key);
 RETURN 'ok';
END $$;
CREATE FUNCTION booking.requests() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[r.id::text,p.title,s.legal_name,a.legal_name,r.check_in::text,r.check_out::text,r.status,coalesce(CASE WHEN h.status='active' AND h.expires_at<=clock_timestamp() THEN 'expired' ELSE h.status END,'-')]
 FROM booking.option_requests r JOIN catalog.properties p ON p.id=r.property_id JOIN core.organizations s ON s.id=r.supplier_id JOIN core.organizations a ON a.id=r.agency_id LEFT JOIN booking.holds h ON h.id=r.hold_id
 WHERE auth.workspace()='nexus' OR (auth.workspace()='supplier' AND r.supplier_id=nullif(current_setting('app.tenant_id',true),'')::uuid) OR (auth.workspace()='agency' AND r.agency_id=nullif(current_setting('app.tenant_id',true),'')::uuid)
 ORDER BY r.created_at DESC LIMIT 100;
$$;
CREATE FUNCTION booking.decide_request(p_request text,p_decision text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=inventory.require_editor(); r booking.option_requests%ROWTYPE; answer text; h uuid;
BEGIN
 SELECT * INTO r FROM booking.option_requests WHERE id::text=p_request AND supplier_id=t FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF r.status<>'pending' THEN RETURN 'already_decided'; END IF;
 IF p_decision='rejected' THEN UPDATE booking.option_requests SET status='rejected' WHERE id=r.id; RETURN 'ok'; END IF;
 IF p_decision<>'approved' THEN RETURN 'invalid_range'; END IF;
 PERFORM 1 FROM partners.connections WHERE supplier_id=t AND agency_id=r.agency_id AND status='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'forbidden'; END IF;
 answer:=inventory.create_hold(r.property_id::text,r.check_in::text,r.check_out::text,r.minutes,'request-'||r.id::text);
 IF answer<>'ok' THEN RETURN answer; END IF;
 SELECT id INTO h FROM booking.holds WHERE tenant_id=t AND request_key='request-'||r.id::text;
 UPDATE booking.option_requests SET status='approved',hold_id=h WHERE id=r.id;
 RETURN 'ok';
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA partners FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.workspace(),auth.session(text),booking.request_option(text,text,text,int,text),booking.requests(),booking.decide_request(text,text) FROM PUBLIC;
GRANT USAGE ON SCHEMA partners TO nexus_app;
GRANT EXECUTE ON FUNCTION auth.session(text),partners.directory(),partners.connect(text,text,text),partners.agency_catalog(),booking.request_option(text,text,text,int,text),booking.requests(),booking.decide_request(text,text) TO nexus_app;
-- Recheck role at the DB boundary for every listing write.
CREATE FUNCTION catalog.supplier_write_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF session_user='nexus_app' THEN PERFORM inventory.require_editor(); END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION catalog.supplier_write_guard() FROM PUBLIC;
CREATE TRIGGER supplier_write_guard BEFORE INSERT OR UPDATE ON catalog.properties FOR EACH ROW EXECUTE FUNCTION catalog.supplier_write_guard();
