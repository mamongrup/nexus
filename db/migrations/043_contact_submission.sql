CREATE OR REPLACE FUNCTION cms.contact_submit(p_name text,p_email text,p_message text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_name IS NULL OR p_email IS NULL OR p_message IS NULL OR length(trim(p_name)) NOT BETWEEN 2 AND 160 OR length(p_email)>254 OR p_email ~ '[\r\n]' OR p_email !~ '^[^ @]+@[^ @]+[.][^ @]+$' OR length(trim(p_message)) NOT BETWEEN 5 AND 5000 THEN RETURN 'invalid'; END IF;
 INSERT INTO cms.contact_messages(name,email,message) VALUES(trim(p_name),lower(trim(p_email)),trim(p_message)); RETURN 'queued';
END $$;
REVOKE ALL ON FUNCTION cms.contact_submit(text,text,text) FROM PUBLIC;
