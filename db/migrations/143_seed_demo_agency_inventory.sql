-- Demo marketplace listings need inventory rows so agency-side availability
-- sync and reservation date guards can be exercised end to end.
DO $$
DECLARE
  demo_listing_ids uuid[] := ARRAY[
    '22222222-bbbb-4222-8222-222222222222'::uuid,
    '44444444-dddd-4444-8444-444444444444'::uuid
  ];
  prop catalog.properties%ROWTYPE;
  v_resource_id uuid;
BEGIN
  FOR prop IN
    SELECT *
    FROM catalog.properties
    WHERE id = ANY(demo_listing_ids)
      AND status = 'published'
  LOOP
    INSERT INTO inventory.resources(tenant_id, property_id, name)
    VALUES(prop.tenant_id, prop.id, prop.title)
    ON CONFLICT(tenant_id, property_id) DO UPDATE
      SET name = excluded.name
    RETURNING id INTO v_resource_id;

    INSERT INTO inventory.days(
      tenant_id,
      resource_id,
      service_date,
      capacity,
      blocked,
      held,
      sold,
      nightly_minor,
      currency
    )
    SELECT
      prop.tenant_id,
      v_resource_id,
      current_date + step.day_offset,
      greatest(prop.capacity, 1),
      CASE WHEN step.day_offset IN (14, 31, 47, 63) THEN greatest(prop.capacity, 1) ELSE 0 END,
      0,
      0,
      greatest(prop.nightly_minor, 1),
      prop.currency
    FROM generate_series(0, 89) AS step(day_offset)
    ON CONFLICT(tenant_id, resource_id, service_date) DO UPDATE SET
      capacity = excluded.capacity,
      blocked = excluded.blocked,
      nightly_minor = excluded.nightly_minor,
      currency = excluded.currency;
  END LOOP;
END $$;

-- Fresh-install safety: agency-side availability sync and the reservation
-- flow need an ACTIVE demo supplier-agency connection with a permissive
-- policy; nothing in the chain seeds one (the live DB got them historically).
-- Idempotent: re-running or richer live data keeps their own state.
DO $$
DECLARE
  v_supplier uuid := '33333333-3333-4333-8333-333333333333';
  v_agency uuid := '55555555-5555-4555-8555-555555555555';
BEGIN
  INSERT INTO core.organizations(id, legal_name, kind)
  VALUES (v_agency, 'NEXUS Demo Agency', 'agency')
  ON CONFLICT (id) DO UPDATE SET legal_name = EXCLUDED.legal_name;
  -- Demo platform operator (kind='nexus') with an owner account: control
  -- center and settings surfaces require one; nothing in the chain seeds it
  -- (live DBs got theirs historically). Idempotent upsert by email keeps
  -- existing live accounts on their own tenant.
  INSERT INTO core.organizations(id, legal_name, kind)
  VALUES ('66666666-6666-4666-8666-666666666666', 'NEXUS Platform', 'nexus')
  ON CONFLICT (id) DO UPDATE SET legal_name = EXCLUDED.legal_name;
  INSERT INTO auth.users(tenant_id, email, display_name, role, password_hash)
  VALUES ('66666666-6666-4666-8666-666666666666', 'admin@nexus.local', 'NEXUS Platform Admin', 'owner',
          crypt('admin123456', gen_salt('bf')))
  ON CONFLICT (email) DO UPDATE SET display_name = EXCLUDED.display_name;
  INSERT INTO partners.connections(supplier_id, agency_id, status, updated_at)
  VALUES (v_supplier, v_agency, 'active', now())
  ON CONFLICT (supplier_id, agency_id) DO UPDATE
    SET status = 'active', updated_at = now();
  INSERT INTO partners.connection_policies(agency_id, allowed_categories, listing_limit, active, updated_at)
  VALUES (v_agency, '[]'::jsonb, 100, true, now())
  ON CONFLICT (agency_id) DO UPDATE
    SET allowed_categories = '[]'::jsonb, listing_limit = 100, active = true, updated_at = now();
END $$;
