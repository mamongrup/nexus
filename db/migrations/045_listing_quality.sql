CREATE FUNCTION catalog.quality_report(p_id text) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[f.label,CASE WHEN coalesce(trim(p.attributes->>f.field_code),'')='' THEN 'Eksik' ELSE 'Dolu' END]
 FROM catalog.properties p JOIN onboarding.category_fields f ON f.category_code=p.category_code AND f.active AND f.required WHERE p.id::text=p_id AND p.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND auth.workspace()='supplier'
$$;
REVOKE ALL ON FUNCTION catalog.quality_report(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.quality_report(text) TO nexus_app;
