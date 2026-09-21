-- Explicit retry policy: only failed operations may be retried, with bounded
-- exponential backoff. Succeeded/cancelled operations are immutable.
CREATE OR REPLACE FUNCTION events.retry_external_operation(p_id text,p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE op events.external_operations%ROWTYPE; delay_seconds int;
BEGIN
 SELECT * INTO op FROM events.external_operations
 WHERE id::text=p_id AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF op.status<>'failed' THEN RETURN 'not_retryable'; END IF;
 IF op.attempts>=10 THEN RETURN 'attempt_limit'; END IF;
 delay_seconds:=least(3600,greatest(30,30*(2^least(op.attempts,7))));
 UPDATE events.external_operations SET status='pending',next_attempt_at=now()+(delay_seconds||' seconds')::interval,
   last_error=left(coalesce(p_reason,'manual retry'),2000),updated_at=now() WHERE id=op.id;
 RETURN 'ok';
END $$;
GRANT EXECUTE ON FUNCTION events.retry_external_operation(text,text) TO nexus_app;
