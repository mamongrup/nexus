CREATE FUNCTION onboarding.module_assignments() RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[o.id::text,o.legal_name,m.code,m.name,s.status]
 FROM onboarding.supplier_modules s
 JOIN core.organizations o ON o.id=s.supplier_id
 JOIN onboarding.product_modules m ON m.code=s.module_code
 WHERE onboarding.operator() ORDER BY o.legal_name,m.name
$$;
REVOKE ALL ON FUNCTION onboarding.module_assignments() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding.module_assignments() TO nexus_app;
