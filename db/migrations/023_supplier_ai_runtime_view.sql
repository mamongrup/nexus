CREATE FUNCTION settings.supplier_ai_current() RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[provider,visual_provider,writing_provider,content_provider,seo_provider,base_url,model,monthly_budget_minor::text,version::text]
 FROM settings.supplier_ai_credentials c
 WHERE c.supplier_id=nullif(current_setting('app.tenant_id',true),'')::uuid
   AND auth.workspace()='supplier'
$$;
REVOKE ALL ON FUNCTION settings.supplier_ai_current() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION settings.supplier_ai_current() TO nexus_app;
