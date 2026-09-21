-- Surface supplier panel module contract details in module directory views.

CREATE OR REPLACE FUNCTION onboarding.module_directory()
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
    coalesce(count(sm.supplier_id), 0)::text,
    coalesce(array_to_string(d.scope, ','), ''),
    coalesce(array_to_string(d.permissions, ','), '')
  ]
  FROM onboarding.product_modules m
  LEFT JOIN onboarding.supplier_modules sm
    ON sm.module_code = m.code
   AND sm.status <> 'paused'
  LEFT JOIN onboarding.supplier_panel_module_contract_details() d
    ON d.code = m.code
  WHERE onboarding.operator()
  GROUP BY m.code, m.family, m.name, m.description, d.family, d.scope, d.permissions
  ORDER BY coalesce(d.family, m.family), m.name;
$$;

CREATE OR REPLACE FUNCTION onboarding.supplier_modules_matrix(
  p_supplier text
) RETURNS TABLE(data text[])
LANGUAGE sql
SECURITY DEFINER
SET search_path=pg_catalog
AS $$
  SELECT ARRAY[
    m.code,
    coalesce(d.family, m.family),
    m.name,
    m.description,
    coalesce(sm.status, 'unassigned'),
    coalesce(to_char(sm.assigned_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), '-'),
    m.page_slug,
    coalesce(array_to_string(d.scope, ','), ''),
    coalesce(array_to_string(d.permissions, ','), '')
  ]
  FROM onboarding.product_modules m
  LEFT JOIN onboarding.supplier_modules sm
    ON sm.module_code = m.code
   AND sm.supplier_id = p_supplier::uuid
  LEFT JOIN onboarding.supplier_panel_module_contract_details() d
    ON d.code = m.code
  WHERE onboarding.operator()
  ORDER BY
    CASE coalesce(sm.status, 'unassigned')
      WHEN 'enabled' THEN 1
      WHEN 'assigned' THEN 2
      WHEN 'paused' THEN 3
      ELSE 4
    END,
    coalesce(d.family, m.family),
    m.name;
$$;

GRANT EXECUTE ON FUNCTION onboarding.module_directory() TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.supplier_modules_matrix(text) TO nexus_app;

