-- 060_admin_listings_and_management.sql
-- Allow platform superadmin (workspace: nexus) to view and administer all properties

CREATE OR REPLACE FUNCTION catalog.all_properties_for_admin()
RETURNS TABLE(
  id text,
  title text,
  locality text,
  description text,
  capacity int,
  nightly_minor int,
  currency text,
  status text,
  version int
) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    p.id::text,
    p.title,
    p.locality,
    coalesce(p.description, ''),
    p.capacity,
    p.nightly_minor::int,
    p.currency::text,
    p.status,
    p.version::int
  FROM catalog.properties p
  ORDER BY p.created_at DESC LIMIT 100;
$$;

CREATE OR REPLACE FUNCTION catalog.admin_publish(
  p_id text,
  p_version int,
  p_status text
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE catalog.properties
  SET status = p_status, version = version + 1, updated_at = now()
  WHERE id::text = p_id AND version = p_version;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count = 1;
END $$;

GRANT EXECUTE ON FUNCTION catalog.all_properties_for_admin() TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.admin_publish(text, int, text) TO nexus_app;
