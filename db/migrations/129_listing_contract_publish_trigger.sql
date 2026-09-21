-- Enforce listing contract validation directly on catalog.properties.
-- Function-level guards already exist, but this trigger protects direct writes,
-- sync jobs and future endpoints from publishing incomplete listings.

CREATE OR REPLACE FUNCTION catalog.enforce_listing_contract_before_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  missing text;
BEGIN
  IF NEW.status = 'published' THEN
    SELECT string_agg(field_key, ', ' ORDER BY field_key)
    INTO missing
    FROM onboarding.validate_listing_contract(NEW.category_code, NEW.attributes);

    IF coalesce(missing, '') <> '' THEN
      RAISE EXCEPTION 'Listing contract required fields missing: %', missing
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS nexus_listing_contract_publish_guard ON catalog.properties;

CREATE TRIGGER nexus_listing_contract_publish_guard
BEFORE INSERT OR UPDATE OF status, category_code, attributes
ON catalog.properties
FOR EACH ROW
EXECUTE FUNCTION catalog.enforce_listing_contract_before_publish();

GRANT EXECUTE ON FUNCTION catalog.enforce_listing_contract_before_publish() TO nexus_app;
