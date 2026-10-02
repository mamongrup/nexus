CREATE TABLE IF NOT EXISTS operations.listing_content_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL,listing_id uuid NOT NULL,
 actor_id uuid NOT NULL REFERENCES auth.users(id),source_text text NOT NULL,
 review jsonb NOT NULL CHECK(jsonb_typeof(review)='object'),provider text NOT NULL,model text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,listing_id) REFERENCES catalog.properties(tenant_id,id) ON DELETE CASCADE
);
ALTER TABLE operations.listing_content_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY content_review_tenant ON operations.listing_content_reviews
 USING(tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid);
CREATE OR REPLACE FUNCTION operations.listing_review_source(p_listing uuid) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid;
BEGIN
 IF NOT inventory.calendar_admin(t,u) THEN RAISE EXCEPTION 'ai_access_denied'; END IF;
 RETURN (SELECT jsonb_build_object('title',title,'description',description,'category',category_code,'locality',locality,'contract_fields',attributes)::text
 FROM catalog.properties WHERE id=p_listing AND tenant_id=t);
END $$;
CREATE OR REPLACE FUNCTION operations.listing_review_config() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid; config_t uuid;
BEGIN
 IF NOT inventory.calendar_admin(t,u) THEN RAISE EXCEPTION 'ai_access_denied'; END IF;
 -- Supplier requests use centrally administered provider settings, never another supplier's settings.
 SELECT id INTO config_t FROM core.organizations WHERE kind='nexus' ORDER BY created_at,id LIMIT 1;
 RETURN jsonb_build_object('tenant',config_t,'settings',coalesce((SELECT jsonb_object_agg(key,value) FROM settings.values
 WHERE tenant_id=config_t AND key IN ('ai.provider','ai.model','ai.openai_key','ai.gemini_key','ai.deepseek_key','ai.glm_key')),'{}'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION operations.save_listing_review(p_listing uuid,p_source text,p_review jsonb,p_provider text,p_model text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid;
BEGIN
 IF NOT inventory.calendar_admin(t,u) THEN RAISE EXCEPTION 'ai_access_denied'; END IF;
 PERFORM 1 FROM catalog.properties WHERE id=p_listing AND tenant_id=t FOR UPDATE;
 IF NOT FOUND OR operations.listing_review_source(p_listing) IS DISTINCT FROM p_source THEN RETURN 'stale_source'; END IF;
 IF length(p_source)>12000 OR jsonb_typeof(p_review)<>'object' THEN RETURN 'invalid_review'; END IF;
 INSERT INTO operations.listing_content_reviews(tenant_id,listing_id,actor_id,source_text,review,provider,model)
 VALUES(t,p_listing,u,p_source,p_review,p_provider,p_model);
 RETURN 'saved';
END $$;
INSERT INTO settings.fields(key,section,label,kind,choices,description,position)
 VALUES('ai.deepseek_key','Yapay zekâ','DeepSeek API anahtarı','secret','','',34),('ai.glm_key','Yapay zekâ','GLM API anahtarı','secret','','',34)
 ON CONFLICT(key) DO NOTHING;
UPDATE settings.fields SET choices='disabled,openai,anthropic,gemini,google,deepseek,glm,compatible' WHERE key='ai.provider';
REVOKE ALL ON operations.listing_content_reviews FROM PUBLIC;
GRANT SELECT ON operations.listing_content_reviews TO nexus_app;
REVOKE ALL ON FUNCTION operations.listing_review_source(uuid),operations.listing_review_config(),operations.save_listing_review(uuid,text,jsonb,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION operations.listing_review_source(uuid),operations.listing_review_config(),operations.save_listing_review(uuid,text,jsonb,text,text) TO nexus_app;
