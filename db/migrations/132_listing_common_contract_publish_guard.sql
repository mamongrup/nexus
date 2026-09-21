-- Enforce shared listing common requirements before a central supplier listing
-- can be published. Mirrors the agency-side common publish guard.

CREATE OR REPLACE FUNCTION catalog.validate_listing_common_contract(
  p_listing catalog.properties
)
RETURNS TABLE(field_key text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT field_key
  FROM (
    VALUES
      ('category_code', nullif(trim(coalesce(p_listing.category_code, '')), '') IS NULL),
      ('title', nullif(trim(coalesce(p_listing.title, '')), '') IS NULL),
      ('description', nullif(trim(coalesce(p_listing.description, '')), '') IS NULL),
      ('locality', nullif(trim(coalesce(p_listing.locality, '')), '') IS NULL),
      ('capacity', coalesce(p_listing.capacity, 0) <= 0),
      ('currency', nullif(trim(coalesce(p_listing.currency::text, '')), '') IS NULL),
      ('nightly_minor', coalesce(p_listing.nightly_minor, 0) <= 0),
      ('seo_title', nullif(trim(coalesce(p_listing.seo_title, '')), '') IS NULL),
      ('seo_description', nullif(trim(coalesce(p_listing.seo_description, '')), '') IS NULL),
      ('media', coalesce(jsonb_array_length(coalesce(p_listing.media, '[]'::jsonb)), 0) = 0)
  ) AS required(field_key, missing)
  WHERE missing;
$$;

CREATE OR REPLACE FUNCTION catalog.enforce_listing_contract_before_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  missing text;
  missing_common text;
BEGIN
  IF NEW.status = 'published' THEN
    SELECT string_agg(field_key, ', ' ORDER BY field_key)
    INTO missing_common
    FROM catalog.validate_listing_common_contract(NEW);

    SELECT string_agg(field_key, ', ' ORDER BY field_key)
    INTO missing
    FROM onboarding.validate_listing_contract(NEW.category_code, NEW.attributes);

    IF coalesce(missing_common, '') <> '' THEN
      RAISE EXCEPTION 'Listing common contract required fields missing: %', missing_common
        USING ERRCODE = '23514';
    END IF;

    IF coalesce(missing, '') <> '' THEN
      RAISE EXCEPTION 'Listing category contract required fields missing: %', missing
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS nexus_listing_contract_publish_guard ON catalog.properties;

CREATE TRIGGER nexus_listing_contract_publish_guard
BEFORE INSERT OR UPDATE OF status, category_code, attributes, title, locality, description, capacity, nightly_minor, seo_title, seo_description, media
ON catalog.properties
FOR EACH ROW
EXECUTE FUNCTION catalog.enforce_listing_contract_before_publish();

GRANT EXECUTE ON FUNCTION catalog.validate_listing_common_contract(catalog.properties),catalog.enforce_listing_contract_before_publish() TO nexus_app;
