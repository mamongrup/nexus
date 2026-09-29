-- db/tests/elite_hospitality_suite.sql
-- Integration test for NEXUS Elite Hospitality Suite (Migration 084)
-- Tests:
-- 1. Live Room Rack (Quick Check-in, Check-out, Clean)
-- 2. Multi-Department Room Folios & POS Billing
-- 3. Folio Settlement & Cash Desk Integration
-- 4. Automated Night Audit & Manager Flash
-- 5. Yield Autopilot Rules & Promo Codes Engine
-- 6. Automated Multi-Channel Guest Messaging

BEGIN;

DO $$
DECLARE
  v_supplier uuid := gen_random_uuid();
  v_user uuid := gen_random_uuid();
  v_property uuid;
  v_unit_101 uuid;
  v_unit_102 uuid;
  v_unit_103 uuid;
  v_occ text;
  v_hk text;
  v_guest text;
  v_folio_cnt int;
  v_folio_sum bigint;
  v_cash_cnt int;
  v_audit_cnt int;
  v_rule_cnt int;
  v_promo_cnt int;
  v_msg_cnt int;
  v_eval text;
  v_msg_body text;
  v_rule_id uuid;
  v_rule_active boolean;
BEGIN
  -- 1. Setup Tenant & Property
  INSERT INTO core.organizations(id, legal_name, kind) VALUES (v_supplier, 'Elite Palace Resort A.Ş.', 'supplier');
  INSERT INTO auth.users(id, tenant_id, email, password_hash, display_name, role)
  VALUES (v_user, v_supplier, 'manager@elitepalace.local', 'disabled', 'General Manager', 'owner');
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
  VALUES(v_user,v_supplier,'hotel','Elite Palace Resort','approved','verified');

  PERFORM set_config('app.tenant_id', v_supplier::text, true);
  PERFORM set_config('app.actor_id', v_user::text, true);
  PERFORM set_config('app.role', 'owner', true);

  INSERT INTO catalog.properties(tenant_id, title, description, capacity, nightly_minor, currency, locality, category_code,
                                 attributes, seo_title, seo_description, media, status, moderation_status)
  VALUES (v_supplier, 'Elite Palace Grand Hotel & Spa', '5 Yıldızlı Elit Tesis', 30, 2000000, 'TRY',
          'Antalya / Lara', 'hotel',
          '{"room_type":"deluxe","property_type":"hotel","room_types":"deluxe","board_type":"room_only","check_in_time":"14:00","check_out_time":"11:00"}'::jsonb,
          'Elite Palace Grand Hotel', 'Elite hospitality operations test listing',
          '["https://example.invalid/elite-hotel.jpg"]'::jsonb, 'published', 'approved')
  RETURNING id INTO v_property;

  -- Create Units
  INSERT INTO catalog.property_units(property_id, unit_code, unit_name, unit_type, occupancy_status, housekeeping_status)
  VALUES (v_property, '101', 'Deluxe Sea View 101', 'deluxe', 'available', 'clean')
  RETURNING id INTO v_unit_101;

  INSERT INTO catalog.property_units(property_id, unit_code, unit_name, unit_type, occupancy_status, housekeeping_status)
  VALUES (v_property, '102', 'Deluxe Sea View 102', 'deluxe', 'available', 'clean')
  RETURNING id INTO v_unit_102;

  INSERT INTO catalog.property_units(property_id, unit_code, unit_name, unit_type, occupancy_status, housekeeping_status)
  VALUES (v_property, '201', 'Presidential Suite 201', 'suite', 'available', 'clean')
  RETURNING id INTO v_unit_103;

  -- 2. Test Live Room Rack: Quick Check-In
  PERFORM catalog.quick_check_in(v_property, '101', 'Can Yılmaz', 3, 2000000);

  SELECT occupancy_status, housekeeping_status, current_guest INTO v_occ, v_hk, v_guest
  FROM catalog.property_units WHERE id = v_unit_101;

  IF v_occ <> 'occupied' OR v_hk <> 'clean' OR v_guest <> 'Can Yılmaz' THEN
    RAISE EXCEPTION 'Quick check-in unit status mismatch: occ=%, hk=%, guest=%', v_occ, v_hk, v_guest;
  END IF;

  -- Folio should have accommodation charge (3 * 2000000 = 6000000)
  SELECT count(*), coalesce(sum(amount_minor), 0) INTO v_folio_cnt, v_folio_sum
  FROM catalog.property_room_folios WHERE property_id = v_property AND room_code = '101';

  IF v_folio_cnt <> 1 OR v_folio_sum <> 6000000 THEN
    RAISE EXCEPTION 'Accommodation folio charge failed: count=%, sum=%', v_folio_cnt, v_folio_sum;
  END IF;

  -- Police KBS record should be automatically created
  IF NOT EXISTS (SELECT 1 FROM catalog.property_kbs_records WHERE property_id = v_property AND room_code = '101' AND guest_name = 'Can Yılmaz') THEN
    RAISE EXCEPTION 'Auto police KBS record not created';
  END IF;

  RAISE NOTICE 'Step 1 PASSED: Live Room Rack Quick Check-In, Folio creation, and Police KBS verified';

  -- 3. Test Room Folio: Post Departmental Charges (Restaurant POS & SPA)
  PERFORM catalog.post_room_folio_charge(v_property, '101', 'restaurant_pos', 'Akşam Yemeği #402', 85000);
  PERFORM catalog.post_room_folio_charge(v_property, '101', 'spa_wellness', 'Aromaterapi Masajı', 120000);

  SELECT count(*), coalesce(sum(amount_minor), 0) INTO v_folio_cnt, v_folio_sum
  FROM catalog.property_room_folios WHERE property_id = v_property AND room_code = '101';

  IF v_folio_cnt <> 3 OR v_folio_sum <> 6205000 THEN
    RAISE EXCEPTION 'Departmental folio charges mismatch: count=%, sum=%', v_folio_cnt, v_folio_sum;
  END IF;

  RAISE NOTICE 'Step 2 PASSED: Multi-department folio charges posted successfully (Total: 6,205.00 TRY)';

  -- 4. Test Folio Settlement & Front Cash Desk Integration
  PERFORM catalog.settle_room_folio(v_property, '101', 'credit_card');

  -- All folios should be settled
  IF EXISTS (SELECT 1 FROM catalog.property_room_folios WHERE property_id = v_property AND room_code = '101' AND is_settled = false) THEN
    RAISE EXCEPTION 'Unsettled folios remain after settlement';
  END IF;

  -- Cash desk should have collection record of 6205000
  SELECT count(*) INTO v_cash_cnt
  FROM catalog.property_cash_desk_transactions
  WHERE property_id = v_property AND room_code = '101' AND amount_minor = 6205000 AND trans_type = 'collection';

  IF v_cash_cnt <> 1 THEN
    RAISE EXCEPTION 'Cash desk collection transaction not recorded from folio settlement';
  END IF;

  RAISE NOTICE 'Step 3 PASSED: Folio settlement and automatic Cash Desk ledger integration verified';

  -- 5. Test Quick Check-Out & Housekeeping Clean
  PERFORM catalog.quick_check_out(v_property, '101');

  SELECT occupancy_status, housekeeping_status INTO v_occ, v_hk
  FROM catalog.property_units WHERE id = v_unit_101;

  IF v_occ <> 'available' OR v_hk <> 'dirty' THEN
    RAISE EXCEPTION 'Check-out unit status mismatch (should be available & dirty): occ=%, hk=%', v_occ, v_hk;
  END IF;

  PERFORM catalog.mark_room_clean(v_property, '101');

  SELECT housekeeping_status INTO v_hk
  FROM catalog.property_units WHERE id = v_unit_101;

  IF v_hk <> 'clean' THEN
    RAISE EXCEPTION 'Mark room clean failed, got: %', v_hk;
  END IF;

  RAISE NOTICE 'Step 4 PASSED: Quick Check-Out and Housekeeping cleaning workflow verified';

  -- 6. Test Night Audit Engine
  PERFORM catalog.run_night_audit(v_property);

  SELECT count(*) INTO v_audit_cnt
  FROM catalog.property_night_audits WHERE property_id = v_property;

  IF v_audit_cnt <> 1 THEN
    RAISE EXCEPTION 'Night audit not recorded';
  END IF;

  RAISE NOTICE 'Step 5 PASSED: Automated Night Audit & Manager Flash calculation verified';

  -- 7. Test Yield Autopilot Rules & Evaluation
  PERFORM catalog.add_yield_rule(v_property, 'high_occupancy_surge', 75.00, 15.00);

  SELECT id, is_active INTO v_rule_id, v_rule_active
  FROM catalog.property_yield_rules WHERE property_id = v_property;

  IF v_rule_id IS NULL OR v_rule_active <> true THEN
    RAISE EXCEPTION 'Yield rule creation failed';
  END IF;

  PERFORM catalog.toggle_yield_rule(v_rule_id);
  SELECT is_active INTO v_rule_active FROM catalog.property_yield_rules WHERE id = v_rule_id;
  IF v_rule_active <> false THEN RAISE EXCEPTION 'Toggle yield rule failed'; END IF;

  -- Test evaluation function
  v_eval := catalog.evaluate_yield_autopilot(v_property);
  IF length(v_eval) < 10 THEN
    RAISE EXCEPTION 'Yield autopilot evaluation returned empty string';
  END IF;

  RAISE NOTICE 'Step 6 PASSED: Yield Autopilot rule management and evaluation verified: %', v_eval;

  -- 8. Test Promo Codes
  PERFORM catalog.add_promo_code(v_property, 'YAZ2026', 'percentage', 15, 50);

  SELECT count(*) INTO v_promo_cnt
  FROM catalog.property_promo_codes WHERE property_id = v_property AND promo_code = 'YAZ2026';

  IF v_promo_cnt <> 1 THEN
    RAISE EXCEPTION 'Promo code creation failed';
  END IF;

  RAISE NOTICE 'Step 7 PASSED: Promo code engine verified (YAZ2026, 15%% discount)';

  -- 9. Test Automated Guest Messaging Workflows
  IF catalog.dispatch_guest_automated_message(v_property, '101', 'Can Yılmaz', '+905551234567', 'pre_arrival_24h') <> 'pending' THEN
    RAISE EXCEPTION 'Automated message should be queued pending provider delivery';
  END IF;

  SELECT message_body INTO v_msg_body
  FROM catalog.property_automated_messages
  WHERE property_id = v_property AND room_code = '101' AND trigger_type = 'pre_arrival_24h';

  IF v_msg_body NOT LIKE '%yarın sizi ağırlamaktan mutluluk duyacağız%' OR v_msg_body NOT LIKE '%101%' THEN
    RAISE EXCEPTION 'Automated message template generation failed: %', v_msg_body;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM catalog.property_automated_messages
    WHERE property_id = v_property AND room_code = '101'
      AND trigger_type = 'pre_arrival_24h' AND dispatch_status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Automated message was not kept pending until provider verification';
  END IF;

  RAISE NOTICE 'Step 8 PASSED: Automated guest messaging workflow verified: %', v_msg_body;

  RAISE NOTICE 'ALL ELITE HOSPITALITY SUITE TESTS PASSED SUCCESSFULLY!';
END $$;

ROLLBACK;
