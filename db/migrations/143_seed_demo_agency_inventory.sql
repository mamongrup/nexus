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
