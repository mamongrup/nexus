CREATE FUNCTION ai.claim_listing_requests(p_limit int DEFAULT 10) RETURNS TABLE(id uuid,property_id uuid,capability text,prompt text,provider text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.workspace()<>'supplier' AND NOT onboarding.operator() THEN RETURN; END IF;
 RETURN QUERY WITH picked AS (SELECT r.id FROM ai.listing_requests r WHERE r.status='queued' ORDER BY r.created_at FOR UPDATE SKIP LOCKED LIMIT greatest(1,least(p_limit,50)))
 UPDATE ai.listing_requests r SET status='processing',updated_at=now() FROM picked WHERE r.id=picked.id RETURNING r.id,r.property_id,r.capability,r.prompt,r.provider;
END $$;
CREATE FUNCTION ai.complete_listing_request(p_id uuid,p_result jsonb,p_error text DEFAULT NULL) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT EXISTS(SELECT FROM ai.listing_requests r WHERE r.id=p_id AND (r.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid OR onboarding.operator())) THEN RETURN 'forbidden'; END IF;
 UPDATE ai.listing_requests SET status=CASE WHEN p_error IS NULL THEN 'completed' ELSE 'failed' END,result=coalesce(p_result,'{}'),error=p_error,updated_at=now() WHERE id=p_id AND status='processing';
 RETURN CASE WHEN FOUND THEN 'ok' ELSE 'not_found' END;
END $$;
GRANT EXECUTE ON FUNCTION ai.claim_listing_requests(int),ai.complete_listing_request(uuid,jsonb,text) TO nexus_app;
