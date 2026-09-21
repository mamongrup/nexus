-- Durable, idempotent queue for provider operations. A pending row is an honest
-- statement that work remains; workers may claim it and record provider evidence.
CREATE TABLE IF NOT EXISTS events.external_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  property_id uuid REFERENCES catalog.properties(id) ON DELETE CASCADE,
  operation_key text NOT NULL,
  provider text NOT NULL,
  operation_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','running','succeeded','failed','cancelled')),
  attempts int NOT NULL DEFAULT 0 CHECK(attempts>=0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error text NOT NULL DEFAULT '',
  provider_reference text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,operation_key)
);
CREATE INDEX IF NOT EXISTS external_operations_claim_idx
 ON events.external_operations(status,next_attempt_at,created_at);
ALTER TABLE events.external_operations ENABLE ROW LEVEL SECURITY;
CREATE POLICY external_operations_tenant_isolation ON events.external_operations
 USING (tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid)
 WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid);

CREATE OR REPLACE FUNCTION events.enqueue_external_operation(
 p_tenant text,p_property text,p_operation_key text,p_provider text,p_operation_type text,p_payload jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(p_tenant,'')::uuid; p uuid:=nullif(p_property,'')::uuid; result_id uuid;
BEGIN
 IF t IS NULL OR p_operation_key IS NULL OR trim(p_operation_key)='' THEN RAISE EXCEPTION 'Invalid external operation'; END IF;
 INSERT INTO events.external_operations(tenant_id,property_id,operation_key,provider,operation_type,payload)
 VALUES(t,p,p_operation_key,trim(p_provider),trim(p_operation_type),coalesce(p_payload,'{}'::jsonb))
 ON CONFLICT(tenant_id,operation_key) DO UPDATE SET updated_at=now()
 RETURNING id INTO result_id;
 RETURN result_id;
END $$;

CREATE OR REPLACE FUNCTION events.claim_external_operation(p_id text)
RETURNS TABLE(id uuid,provider text,operation_type text,payload jsonb,attempts int)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 UPDATE events.external_operations SET status='running',attempts=attempts+1,updated_at=now()
 WHERE id::text=p_id AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
   AND status IN ('pending','failed') AND next_attempt_at<=now() AND attempts<10
 RETURNING id,provider,operation_type,payload,attempts
$$;

CREATE OR REPLACE FUNCTION events.finish_external_operation(p_id text,p_status text,p_error text,p_reference text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_status NOT IN ('succeeded','failed','cancelled') THEN RETURN 'invalid_status'; END IF;
 UPDATE events.external_operations SET status=p_status,last_error=left(coalesce(p_error,''),2000),
   provider_reference=left(coalesce(p_reference,''),500),next_attempt_at=case when p_status='failed' then now()+interval '5 minutes' else next_attempt_at end,updated_at=now()
 WHERE id::text=p_id AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND status='running';
 RETURN case when found then 'ok' else 'not_found' end;
END $$;
GRANT SELECT,INSERT,UPDATE ON events.external_operations TO nexus_app;
GRANT EXECUTE ON FUNCTION events.enqueue_external_operation(text,text,text,text,text,jsonb),events.claim_external_operation(text),events.finish_external_operation(text,text,text,text) TO nexus_app;
