CREATE SCHEMA IF NOT EXISTS ai;
CREATE TABLE ai.listing_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES core.organizations,
 property_id uuid NOT NULL REFERENCES catalog.properties ON DELETE CASCADE,
 capability text NOT NULL CHECK(capability IN ('visual','writing','content','seo')),
 prompt text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','completed','failed')),
 provider text NOT NULL DEFAULT 'assigned', result jsonb NOT NULL DEFAULT '{}', error text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE ai.listing_requests ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION ai.queue_listing_request(p_property text,p_capability text,p_prompt text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p uuid;
BEGIN
 IF p_capability NOT IN ('visual','writing','content','seo') THEN RETURN 'invalid'; END IF;
 SELECT id INTO p FROM catalog.properties WHERE id::text=p_property AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid;
 IF p IS NULL OR auth.workspace()<>'supplier' THEN RETURN 'forbidden'; END IF;
 INSERT INTO ai.listing_requests(tenant_id,property_id,capability,prompt) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,p,p_capability,left(coalesce(p_prompt,''),5000));
 RETURN 'queued';
END $$;
CREATE FUNCTION ai.listing_requests_for(p_property text) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[id::text,capability,status,provider,created_at::text] FROM ai.listing_requests WHERE property_id::text=p_property AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid ORDER BY created_at DESC LIMIT 50;
$$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ai FROM PUBLIC;
GRANT USAGE ON SCHEMA ai TO nexus_app;
GRANT EXECUTE ON FUNCTION ai.queue_listing_request(text,text,text),ai.listing_requests_for(text) TO nexus_app;
