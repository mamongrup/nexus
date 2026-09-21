-- 086_dynamic_modules_and_operations.sql
-- Enables 1-click dynamic module bundle activation, instant toggle, and centralized operations cockpit support

-- Make assigned_by nullable or default to system admin to allow autonomous module activation
ALTER TABLE onboarding.supplier_modules ALTER COLUMN assigned_by DROP NOT NULL;

-- 1. Function to activate pre-packaged module bundles for a supplier or current tenant
CREATE OR REPLACE FUNCTION onboarding.activate_module_bundle(
  p_bundle text,
  p_supplier text DEFAULT NULL
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant uuid;
  v_actor uuid := coalesce(
    nullif(current_setting('app.actor_id', true), '')::uuid,
    (SELECT id FROM auth.users WHERE role = 'owner' LIMIT 1),
    (SELECT id FROM auth.users LIMIT 1)
  );
  v_codes text[];
  v_code text;
BEGIN
  IF p_supplier IS NOT NULL AND nullif(p_supplier, '') IS NOT NULL AND auth.workspace() = 'nexus' THEN
    v_tenant := p_supplier::uuid;
  ELSE
    v_tenant := nullif(current_setting('app.tenant_id', true), '')::uuid;
  END IF;

  IF v_tenant IS NULL THEN
    RETURN 'unauthorized';
  END IF;

  CASE p_bundle
    WHEN 'hotel' THEN
      v_codes := ARRAY['pms', 'channel-manager', 'kbs', 'dynamic-pricing', 'housekeeping', 'restaurant-pos', 'einvoice', 'table-reservation'];
    WHEN 'villa' THEN
      v_codes := ARRAY['villa-management', 'pms', 'channel-manager', 'whatsapp', 'dynamic-pricing', 'kbs'];
    WHEN 'yacht' THEN
      v_codes := ARRAY['marine', 'pms', 'channel-manager', 'dynamic-pricing', 'einvoice'];
    WHEN 'transfer' THEN
      v_codes := ARRAY['kbs', 'mobile-checkin', 'whatsapp', 'crm', 'einvoice'];
    WHEN 'tour' THEN
      v_codes := ARRAY['tour-operator', 'package-tour', 'flight', 'booking-engine', 'einvoice'];
    WHEN 'all' THEN
      SELECT array_agg(code) INTO v_codes FROM onboarding.product_modules WHERE active;
    ELSE
      RETURN 'invalid_bundle';
  END CASE;

  FOREACH v_code IN ARRAY v_codes LOOP
    INSERT INTO onboarding.supplier_modules(supplier_id, module_code, status, assigned_by)
    VALUES (v_tenant, v_code, 'enabled', v_actor)
    ON CONFLICT (supplier_id, module_code)
    DO UPDATE SET status = 'enabled', assigned_at = now(), assigned_by = coalesce(EXCLUDED.assigned_by, onboarding.supplier_modules.assigned_by);
  END LOOP;

  -- Log telemetry
  INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (
    v_tenant,
    'pms',
    'bundle_activation',
    p_bundle,
    'success',
    jsonb_build_object(
      'bundle', p_bundle,
      'activated_count', array_length(v_codes, 1),
      'timestamp', now()
    )
  );

  RETURN 'ok';
END $$;

-- 2. Function for suppliers to toggle any module in their workspace
CREATE OR REPLACE FUNCTION onboarding.toggle_supplier_module(
  p_module text,
  p_status text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
  v_actor uuid := coalesce(
    nullif(current_setting('app.actor_id', true), '')::uuid,
    (SELECT id FROM auth.users WHERE role = 'owner' LIMIT 1),
    (SELECT id FROM auth.users LIMIT 1)
  );
BEGIN
  IF v_tenant IS NULL THEN
    RETURN 'unauthorized';
  END IF;

  IF p_status NOT IN ('enabled', 'assigned', 'paused', 'unassigned') THEN
    RETURN 'invalid_status';
  END IF;

  IF NOT EXISTS (SELECT FROM onboarding.product_modules WHERE code = p_module AND active) THEN
    RETURN 'not_found';
  END IF;

  IF p_status = 'unassigned' THEN
    DELETE FROM onboarding.supplier_modules
    WHERE supplier_id = v_tenant AND module_code = p_module;
  ELSE
    INSERT INTO onboarding.supplier_modules (supplier_id, module_code, status, assigned_by)
    VALUES (v_tenant, p_module, p_status, v_actor)
    ON CONFLICT (supplier_id, module_code)
    DO UPDATE SET status = EXCLUDED.status, assigned_at = now();
  END IF;

  RETURN 'ok';
END $$;

-- 3. Function to get all modules with their current status for the current session
CREATE OR REPLACE FUNCTION onboarding.all_modules_catalog_for_session()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    m.code,
    m.family,
    m.name,
    m.description,
    coalesce(sm.status, 'unassigned'),
    m.page_slug,
    CASE m.code
      WHEN 'pms' THEN 'Otel & Villa & Yat'
      WHEN 'channel-manager' THEN 'Otel & Villa'
      WHEN 'dynamic-pricing' THEN 'Otel & Villa & Yat'
      WHEN 'kbs' THEN 'Otel & Villa & Transfer'
      WHEN 'housekeeping' THEN 'Otel & Resort'
      WHEN 'restaurant-pos' THEN 'Otel & Restoran'
      WHEN 'villa-management' THEN 'Özel Villa'
      WHEN 'marine' THEN 'Yat & Marina'
      WHEN 'tour-operator' THEN 'Tur Operatörü'
      ELSE 'Genel'
    END
  ]
  FROM onboarding.product_modules m
  LEFT JOIN onboarding.supplier_modules sm
    ON sm.module_code = m.code
   AND sm.supplier_id = nullif(current_setting('app.tenant_id', true), '')::uuid
  ORDER BY
    CASE coalesce(sm.status, 'unassigned')
      WHEN 'enabled' THEN 1
      WHEN 'assigned' THEN 2
      WHEN 'paused' THEN 3
      ELSE 4
    END,
    m.family,
    m.name;
$$;

-- 4. Function to resolve or create a primary property for the centralized operations cockpit
CREATE OR REPLACE FUNCTION catalog.get_or_create_primary_property()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
  v_actor uuid := coalesce(
    nullif(current_setting('app.actor_id', true), '')::uuid,
    (SELECT id FROM auth.users WHERE role = 'owner' LIMIT 1),
    (SELECT id FROM auth.users LIMIT 1)
  );
  v_prop_id uuid;
BEGIN
  IF v_tenant IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Try to find an existing property owned by this tenant
  SELECT id INTO v_prop_id
  FROM catalog.properties
  WHERE tenant_id = v_tenant
  ORDER BY status = 'published' DESC, updated_at DESC
  LIMIT 1;

  -- 2. If no property exists, create a high-end demo operational property for this supplier
  IF v_prop_id IS NULL THEN
    INSERT INTO catalog.properties (
      tenant_id,
      title,
      locality,
      description,
      capacity,
      nightly_minor,
      currency,
      status,
      category_code,
      attributes,
      created_by
    ) VALUES (
      v_tenant,
      'NEXUS Demo Resort & Suites',
      'Antalya, Kalkan',
      'NEXUS operasyon kokpiti için tahsis edilmiş birincil tesis ve PMS çalışma alanı.',
      10,
      1250000,
      'TRY',
      'published',
      'hotel',
      '{"room_count": 24, "pool": true, "sea_view": true}'::jsonb,
      v_actor
    )
    RETURNING id INTO v_prop_id;

    -- Also activate hotel bundle automatically so the cockpit is alive immediately
    PERFORM onboarding.activate_module_bundle('hotel');
  END IF;

  RETURN v_prop_id::text;
END $$;

-- 5. Seed active modules for suppliers so they are dynamic immediately
INSERT INTO onboarding.supplier_modules (supplier_id, module_code, status, assigned_by)
SELECT o.id, m.code, 'enabled', (SELECT id FROM auth.users LIMIT 1)
FROM core.organizations o
CROSS JOIN onboarding.product_modules m
WHERE o.kind = 'supplier'
  AND m.code IN ('pms', 'channel-manager', 'kbs', 'dynamic-pricing', 'housekeeping', 'restaurant-pos', 'whatsapp', 'einvoice')
ON CONFLICT (supplier_id, module_code) DO NOTHING;

-- 6. Permissions
GRANT EXECUTE ON FUNCTION onboarding.activate_module_bundle(text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.toggle_supplier_module(text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.all_modules_catalog_for_session() TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.get_or_create_primary_property() TO nexus_app;
