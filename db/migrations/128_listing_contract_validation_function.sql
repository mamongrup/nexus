-- Listing contract validation helper.
-- Returns missing required category field keys for a listing metadata payload.

CREATE OR REPLACE FUNCTION onboarding.validate_listing_contract(
  p_category text,
  p_metadata jsonb
)
RETURNS TABLE(field_key text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT f.field_code
  FROM onboarding.category_fields f
  WHERE f.category_code = p_category
    AND f.active
    AND f.required
    AND nullif(trim(coalesce(p_metadata->'contract_fields'->>f.field_code, p_metadata->>f.field_code, '')), '') IS NULL
  ORDER BY f.position, f.field_code
$$;

GRANT EXECUTE ON FUNCTION onboarding.validate_listing_contract(text,jsonb) TO nexus_app;
