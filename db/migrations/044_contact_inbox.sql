CREATE FUNCTION cms.contact_inbox() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[id::text,name,email,message,recipient,status,created_at::text] FROM cms.contact_messages
 WHERE cms.can_edit() ORDER BY created_at DESC LIMIT 200
$$;
REVOKE ALL ON FUNCTION cms.contact_inbox() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cms.contact_inbox() TO nexus_app;
