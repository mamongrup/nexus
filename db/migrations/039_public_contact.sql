CREATE FUNCTION cms.public_contact() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[v.key,v.value] FROM settings.values v
 WHERE v.tenant_id=(SELECT id FROM core.organizations WHERE kind='nexus' ORDER BY created_at,id LIMIT 1)
 AND v.key IN ('contact.phone','contact.whatsapp','contact.email','contact.address','contact.linkedin','contact.instagram','contact.map_url')
$$;
REVOKE ALL ON FUNCTION cms.public_contact() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cms.public_contact() TO nexus_app;
