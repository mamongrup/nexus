CREATE OR REPLACE FUNCTION catalog.supplier_write_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF session_user='nexus_app' AND NOT onboarding.operator() THEN PERFORM inventory.require_editor(); END IF;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION catalog.review_listing_api(p_id text,p_version text,p_decision text,p_note text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 RETURN catalog.review_listing(p_id,p_version::int,p_decision,p_note);
EXCEPTION WHEN OTHERS THEN
 RETURN 'review_error_'||SQLSTATE;
END $$;
