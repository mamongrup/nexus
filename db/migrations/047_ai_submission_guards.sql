CREATE OR REPLACE FUNCTION ai.queue_listing_request(p_property text,p_capability text,p_prompt text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p uuid; t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid; job uuid;
BEGIN
 IF p_capability IS NULL OR p_capability NOT IN ('visual','writing','content','seo') THEN RETURN 'invalid'; END IF;
 IF NOT coalesce(auth.workspace()='supplier' AND EXISTS(SELECT FROM auth.users WHERE id=u AND tenant_id=t AND role IN ('owner','editor')),false) THEN RETURN 'forbidden'; END IF;
 SELECT id INTO p FROM catalog.properties WHERE id::text=p_property AND tenant_id=t;
 IF p IS NULL THEN RETURN 'forbidden'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p::text||p_capability,47));
 IF EXISTS(SELECT FROM ai.listing_requests WHERE property_id=p AND tenant_id=t AND capability=p_capability AND status IN ('queued','processing')) THEN RETURN 'already_queued'; END IF;
 INSERT INTO ai.listing_requests(tenant_id,property_id,capability,prompt) VALUES(t,p,p_capability,left(coalesce(p_prompt,''),5000)) RETURNING id INTO job;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,u,'ai.action.requested',job,jsonb_build_object('property_id',p,'capability',p_capability));
 RETURN 'queued';
END $$;
