\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE
  tenant_id uuid := gen_random_uuid();
  owner_id uuid := gen_random_uuid();
  property_id uuid;
  offer jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM core.currencies WHERE code = 'CNY') THEN
    RAISE EXCEPTION 'CNY currency seed is missing';
  END IF;
  INSERT INTO core.organizations(id, legal_name, kind)
    VALUES (tenant_id, 'CNY currency fixture', 'supplier');
  INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role)
    VALUES(owner_id,tenant_id,owner_id::text||'@example.invalid','disabled','Owner','owner');
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
    VALUES(owner_id,tenant_id,'holiday_home','CNY currency fixture','approved','verified');
  INSERT INTO catalog.properties(
    tenant_id, title, description, locality, capacity, nightly_minor, currency, status, moderation_status, category_code,
    attributes, seo_title, seo_description, media
  ) VALUES (
    tenant_id, 'CNY Villa', 'CNY currency test listing', 'Shanghai', 2, 8800, 'CNY', 'published', 'approved', 'holiday_home',
    '{"property_type":"villa","bedroom_count":1,"bathroom_count":1,"guest_capacity":2}'::jsonb,
    'CNY Villa','CNY currency test listing','["https://example.invalid/cny-fixture.jpg"]'::jsonb
  ) RETURNING id INTO property_id;
  offer := pricing.calculate_offer(property_id::text, '', 'b2c', '2026-10-01', '2026-10-03');
  IF offer->>'currency' <> 'CNY' THEN
    RAISE EXCEPTION 'CNY offer currency mismatch: %', offer;
  END IF;
  RAISE NOTICE 'PASS: CNY is accepted by pricing and preserved in offer currency';
END $$;
ROLLBACK;
