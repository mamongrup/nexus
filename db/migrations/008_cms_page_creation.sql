CREATE FUNCTION cms.create_page(p_slug text,p_title text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cms.can_edit() THEN RETURN 'forbidden'; END IF;
 IF p_slug IS NULL OR p_slug !~ '^[a-z][a-z0-9-]{0,59}$' OR p_slug IN ('admin','login','logout','static','v1') OR p_title IS NULL OR length(trim(p_title)) NOT BETWEEN 3 AND 150 THEN RETURN 'invalid_setting'; END IF;
 INSERT INTO cms.pages(slug,title,summary,body) VALUES(p_slug,p_title,'','') ON CONFLICT DO NOTHING;
 IF NOT FOUND THEN RETURN 'cms_exists'; END IF;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,nullif(current_setting('app.actor_id',true),'')::uuid,'cms.page_created',gen_random_uuid(),jsonb_build_object('slug',p_slug));
 RETURN 'ok';
END $$;
REVOKE ALL ON FUNCTION cms.create_page(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cms.create_page(text,text) TO nexus_app;
