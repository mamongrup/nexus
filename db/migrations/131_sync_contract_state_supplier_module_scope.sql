-- Keep sync contract module counts limited to the shared supplier panel
-- contract modules, not every central-platform/admin module.

CREATE OR REPLACE FUNCTION onboarding.sync_contract_state()
RETURNS TABLE(data text[])
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  WITH contract_modules(code) AS (
    VALUES
      ('dashboard'),('company_profile'),('documents'),('catalog'),
      ('availability'),('pricing'),('reservations'),('offers'),
      ('customers'),('messages'),('tasks'),('staff'),('accounting'),
      ('payments'),('reports'),('integrations'),('settings')
  ),
  contract AS (
    SELECT
      coalesce(max(version) FILTER (WHERE contract_name = 'nexus.catalog.categories'), '') AS catalog_version,
      coalesce(max(version) FILTER (WHERE contract_name = 'nexus.supplier_listing'), '') AS supplier_listing_version
    FROM core.contract_versions
  ),
  category_stats AS (
    SELECT count(DISTINCT c.code)::text AS active_category_count
    FROM onboarding.categories c
    WHERE c.active
      AND c.code IN (
        'hotel','holiday_home','yacht','tour','activity','flight','car',
        'cruise','pilgrimage','visa','ferry','transfer','beach','cinema',
        'event','restaurant','bus'
      )
  ),
  filter_stats AS (
    SELECT count(DISTINCT i.item_key)::text AS active_filter_item_count
    FROM onboarding.category_filter_groups g
    JOIN onboarding.category_filter_items i ON i.group_id = g.id
    WHERE g.active
      AND i.active
      AND g.category_code IN (
        'hotel','holiday_home','yacht','tour','activity','flight','car',
        'cruise','pilgrimage','visa','ferry','transfer','beach','cinema',
        'event','restaurant','bus'
      )
  ),
  module_stats AS (
    SELECT count(DISTINCT m.code)::text AS active_supplier_module_count
    FROM onboarding.product_modules m
    JOIN contract_modules cm ON cm.code = m.code
    WHERE m.active
  )
  SELECT ARRAY['catalog_contract_version', catalog_version] FROM contract
  UNION ALL
  SELECT ARRAY['supplier_listing_contract_version', supplier_listing_version] FROM contract
  UNION ALL
  SELECT ARRAY['active_category_count', active_category_count] FROM category_stats
  UNION ALL
  SELECT ARRAY['active_filter_item_count', active_filter_item_count] FROM filter_stats
  UNION ALL
  SELECT ARRAY['active_supplier_module_count', active_supplier_module_count] FROM module_stats
  ORDER BY 1;
$$;

GRANT EXECUTE ON FUNCTION onboarding.sync_contract_state() TO nexus_app;
