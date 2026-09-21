-- Surface supplier panel module contract details in the supplier workspace catalog.

CREATE OR REPLACE FUNCTION onboarding.supplier_module_catalog()
RETURNS TABLE(data text[])
LANGUAGE sql
SECURITY DEFINER
SET search_path=pg_catalog
AS $$
  SELECT ARRAY[
    m.code,
    coalesce(d.family, m.family),
    m.name,
    m.description,
    sm.status,
    m.page_slug,
    coalesce(array_to_string(d.scope, ','), '')
  ]
  FROM onboarding.supplier_modules sm
  JOIN onboarding.product_modules m
    ON m.code = sm.module_code
  LEFT JOIN onboarding.supplier_panel_module_contract_details() d
    ON d.code = m.code
  WHERE sm.supplier_id = nullif(current_setting('app.tenant_id', true), '')::uuid
  ORDER BY coalesce(d.family, m.family), m.name;
$$;

GRANT EXECUTE ON FUNCTION onboarding.supplier_module_catalog() TO nexus_app;

