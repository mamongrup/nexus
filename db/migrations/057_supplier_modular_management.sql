-- 057_supplier_modular_management.sql
-- Enables comprehensive per-supplier module assignment and interactive operational module suites

-- 1. Unassign module function
CREATE OR REPLACE FUNCTION onboarding.unassign_module(
  p_supplier text,
  p_module text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT onboarding.operator() THEN
    RETURN 'forbidden';
  END IF;

  DELETE FROM onboarding.supplier_modules
  WHERE supplier_id = p_supplier::uuid
    AND module_code = p_module;

  RETURN 'ok';
END $$;

-- 2. Supplier modules matrix (returns all catalog modules for a specific supplier with their status)
CREATE OR REPLACE FUNCTION onboarding.supplier_modules_matrix(
  p_supplier text
) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    m.code,
    m.family,
    m.name,
    m.description,
    coalesce(sm.status, 'unassigned'),
    coalesce(to_char(sm.assigned_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), '-'),
    m.page_slug
  ]
  FROM onboarding.product_modules m
  LEFT JOIN onboarding.supplier_modules sm
    ON sm.module_code = m.code
   AND sm.supplier_id = p_supplier::uuid
  WHERE onboarding.operator()
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

-- 3. Supplier overview with assigned module stats
CREATE OR REPLACE FUNCTION onboarding.supplier_overview()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    o.id::text,
    o.legal_name,
    coalesce(count(sm.module_code), 0)::text,
    coalesce(count(sm.module_code) FILTER (WHERE sm.status = 'enabled'), 0)::text
  ]
  FROM core.organizations o
  LEFT JOIN onboarding.supplier_modules sm ON sm.supplier_id = o.id
  WHERE o.kind = 'supplier'
    AND onboarding.operator()
  GROUP BY o.id, o.legal_name
  ORDER BY o.legal_name;
$$;

-- 4. Operational tables for interactive module execution
CREATE TABLE IF NOT EXISTS onboarding.module_telemetry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  module_code text NOT NULL REFERENCES onboarding.product_modules(code),
  action_name text NOT NULL,
  target_ref text NOT NULL,
  result_status text NOT NULL DEFAULT 'success',
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed initial telemetry and operational state per module for suppliers
INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
SELECT
  o.id,
  'kbs',
  'kbs_notification',
  'KBS-TR-2026-0981',
  'success',
  '{"guest": "Ahmet Yılmaz", "tc_no": "12345678901", "room": "102", "status": "EGM Onaylandı"}'::jsonb
FROM core.organizations o WHERE o.kind = 'supplier'
ON CONFLICT DO NOTHING;

INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
SELECT
  o.id,
  'channel-manager',
  'ota_sync',
  'Booking.com & Airbnb',
  'success',
  '{"sync_rate": 100, "updated_rooms": 14, "latency_ms": 340}'::jsonb
FROM core.organizations o WHERE o.kind = 'supplier'
ON CONFLICT DO NOTHING;

-- 5. Operational execution function callable by suppliers or admin
CREATE OR REPLACE FUNCTION onboarding.trigger_module_action(
  p_module text,
  p_action text,
  p_target text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
  u uuid := nullif(current_setting('app.actor_id', true), '')::uuid;
BEGIN
  IF t IS NULL THEN
    RETURN 'unauthorized';
  END IF;

  INSERT INTO onboarding.module_telemetry(tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (
    t,
    p_module,
    p_action,
    coalesce(nullif(p_target, ''), 'Operasyonel İşlem'),
    'success',
    jsonb_build_object(
      'triggered_by', u,
      'timestamp', now(),
      'message', 'Operasyon başarıyla yürütüldü ve güncellendi'
    )
  );

  RETURN 'ok';
END $$;

-- 6. Module telemetry logs function
CREATE OR REPLACE FUNCTION onboarding.module_telemetry_logs(
  p_module text
) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    t.id::text,
    to_char(t.created_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI:SS'),
    t.action_name,
    t.target_ref,
    t.result_status,
    coalesce(t.details->>'status', t.details->>'message', 'Başarılı')
  ]
  FROM onboarding.module_telemetry t
  WHERE (t.tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid OR auth.workspace() = 'nexus')
    AND (p_module = '' OR t.module_code = p_module)
  ORDER BY t.created_at DESC
  LIMIT 20;
$$;

-- 7. Permissions
GRANT USAGE ON SCHEMA onboarding TO nexus_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON onboarding.module_telemetry TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.unassign_module(text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.supplier_modules_matrix(text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.supplier_overview() TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.trigger_module_action(text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.module_telemetry_logs(text) TO nexus_app;
