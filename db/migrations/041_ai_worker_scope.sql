CREATE OR REPLACE FUNCTION ai.claim_listing_requests(p_limit int DEFAULT 10) RETURNS TABLE(id uuid,property_id uuid,capability text,prompt text,provider text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT coalesce(onboarding.operator() OR (auth.workspace()='supplier' AND EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND role IN ('owner','editor'))),false) THEN RETURN; END IF;
 RETURN QUERY WITH picked AS (
 SELECT r.id FROM ai.listing_requests r WHERE r.status='queued'
 AND (onboarding.operator() OR r.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid)
 ORDER BY r.created_at FOR UPDATE SKIP LOCKED LIMIT greatest(1,least(p_limit,50)))
 UPDATE ai.listing_requests r SET status='processing',updated_at=now() FROM picked WHERE r.id=picked.id RETURNING r.id,r.property_id,r.capability,r.prompt,r.provider;
END $$;
REVOKE ALL ON FUNCTION ai.claim_listing_requests(int),ai.complete_listing_request(uuid,jsonb,text),ai.admin_queue() FROM PUBLIC;
