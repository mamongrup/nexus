-- Expose canonical listing lifecycle statuses from the shared supplier-listing contract.
-- NEXUS keeps internal moderation_status values for review workflow, but this function
-- is the contract boundary shared with the agency project.

CREATE OR REPLACE FUNCTION onboarding.supplier_listing_lifecycle_statuses()
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[status_code, position::text]
  FROM (
    VALUES
      ('draft',10),
      ('pending_review',20),
      ('published',30),
      ('paused',40),
      ('archived',50)
  ) v(status_code, position)
  ORDER BY position;
$$;

GRANT EXECUTE ON FUNCTION onboarding.supplier_listing_lifecycle_statuses() TO nexus_app;
