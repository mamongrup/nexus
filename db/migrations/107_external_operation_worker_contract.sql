-- Worker-safe claiming and operator visibility for external operations.
CREATE OR REPLACE FUNCTION events.claim_next_external_operation()
RETURNS TABLE(id uuid,property_id uuid,provider text,operation_type text,payload jsonb,attempts int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 RETURN QUERY
 WITH candidate AS (
   SELECT e.id FROM events.external_operations e
   WHERE e.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
     AND e.status IN ('pending','failed') AND e.next_attempt_at<=now() AND e.attempts<10
   ORDER BY e.next_attempt_at,e.created_at
   FOR UPDATE SKIP LOCKED LIMIT 1
 )
 UPDATE events.external_operations e
 SET status='running',attempts=e.attempts+1,updated_at=now()
 FROM candidate c WHERE e.id=c.id
 RETURNING e.id,e.property_id,e.provider,e.operation_type,e.payload,e.attempts;
END $$;

CREATE OR REPLACE FUNCTION events.external_operation_status()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[e.id::text,coalesce(e.property_id::text,''),e.provider,e.operation_type,e.status,
   e.attempts::text,to_char(e.next_attempt_at,'YYYY-MM-DD HH24:MI:SS'),e.last_error,e.provider_reference,
   to_char(e.created_at,'YYYY-MM-DD HH24:MI:SS')]
 FROM events.external_operations e
 WHERE e.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
 ORDER BY e.created_at DESC LIMIT 500
$$;
GRANT EXECUTE ON FUNCTION events.claim_next_external_operation(),events.external_operation_status() TO nexus_app;
