CREATE FUNCTION catalog.review_listing_api(p_id text,p_version text,p_decision text,p_note text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 RETURN catalog.review_listing(p_id,p_version::int,p_decision,p_note);
EXCEPTION WHEN OTHERS THEN
 RETURN 'review_error_'||SQLSTATE;
END $$;
REVOKE ALL ON FUNCTION catalog.review_listing_api(text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.review_listing_api(text,text,text,text) TO nexus_app;
