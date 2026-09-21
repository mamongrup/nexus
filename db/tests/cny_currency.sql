\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE
  tenant_id uuid := gen_random_uuid();
  property_id uuid;
  offer jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM core.currencies WHERE code = 'CNY') THEN
    RAISE EXCEPTION 'CNY currency seed is missing';
  END IF;
  INSERT INTO core.organizations(id, legal_name, kind)
    VALUES (tenant_id, 'CNY currency fixture', 'supplier');
  INSERT INTO catalog.properties(
    tenant_id, title, locality, capacity, nightly_minor, currency, status, category_code
  ) VALUES (
    tenant_id, 'CNY Villa', 'Shanghai', 2, 8800, 'CNY', 'published', 'villa'
  ) RETURNING id INTO property_id;
  offer := pricing.calculate_offer(property_id::text, '', 'b2c', '2026-10-01', '2026-10-03');
  IF offer->>'currency' <> 'CNY' THEN
    RAISE EXCEPTION 'CNY offer currency mismatch: %', offer;
  END IF;
  RAISE NOTICE 'PASS: CNY is accepted by pricing and preserved in offer currency';
END $$;
ROLLBACK;
