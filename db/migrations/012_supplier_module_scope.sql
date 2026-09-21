CREATE OR REPLACE FUNCTION onboarding.supplier_module_catalog() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[m.code,m.name,sm.status,m.page_slug] FROM onboarding.supplier_modules sm JOIN onboarding.product_modules m ON m.code=sm.module_code WHERE sm.supplier_id=nullif(current_setting('app.tenant_id',true),'')::uuid ORDER BY m.name $$;
REVOKE ALL ON FUNCTION onboarding.supplier_module_catalog(text) FROM nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.supplier_module_catalog() TO nexus_app;
