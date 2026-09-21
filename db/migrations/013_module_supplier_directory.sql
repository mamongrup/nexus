CREATE FUNCTION onboarding.suppliers() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[id::text,legal_name] FROM core.organizations WHERE kind='supplier' AND onboarding.operator() ORDER BY legal_name
$$;
REVOKE ALL ON FUNCTION onboarding.suppliers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding.suppliers() TO nexus_app;
