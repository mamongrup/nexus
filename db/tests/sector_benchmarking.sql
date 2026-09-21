-- db/tests/sector_benchmarking.sql
-- Integration test for Sector Benchmarking Expansion (Migration 083)

BEGIN;

DO $$
DECLARE
  v_supplier uuid := gen_random_uuid();
  v_user uuid := gen_random_uuid();
  v_property uuid;
  v_unit uuid;
  v_agency_cnt int;
  v_ticket_res text;
  v_cash_res text;
  v_trans_res text;
  v_concierge_res text;
  v_parity_cnt int;
  v_unit_status text;
  v_hotel_fields int;
  v_villa_fields int;
  v_car_fields int;
BEGIN
  -- 1. Verify Category Fields
  SELECT count(*) INTO v_hotel_fields FROM onboarding.category_fields WHERE category_code = 'hotel' AND active;
  IF v_hotel_fields < 10 THEN RAISE EXCEPTION 'Hotel Booking.com category fields missing, count: %', v_hotel_fields; END IF;

  SELECT count(*) INTO v_villa_fields FROM onboarding.category_fields WHERE category_code = 'villa' AND active;
  IF v_villa_fields < 10 THEN RAISE EXCEPTION 'Villa Airbnb category fields missing, count: %', v_villa_fields; END IF;

  SELECT count(*) INTO v_car_fields FROM onboarding.category_fields WHERE category_code = 'car' AND active;
  IF v_car_fields < 10 THEN RAISE EXCEPTION 'Car rental category fields missing, count: %', v_car_fields; END IF;

  RAISE NOTICE 'Step 1 PASSED: Rich category fields verified (Hotel: %, Villa: %, Car: %)', v_hotel_fields, v_villa_fields, v_car_fields;

  -- 2. Setup Test Tenant & Property
  INSERT INTO core.organizations(id, legal_name, kind) VALUES (v_supplier, 'Benchmark Test Resort A.Ş.', 'supplier');
  INSERT INTO auth.users(id, tenant_id, email, password_hash, display_name, role)
  VALUES (v_user, v_supplier, 'benchmark@test.local', 'disabled', 'Resort Manager', 'owner');

  PERFORM set_config('app.tenant_id', v_supplier::text, true);
  PERFORM set_config('app.actor_id', v_user::text, true);
  PERFORM set_config('app.role', 'owner', true);

  INSERT INTO catalog.properties(tenant_id, title, description, capacity, nightly_minor, currency, locality, category_code, status)
  VALUES (v_supplier, 'Benchmark Luxury Hotel & Suites', '5 yıldızlı lüks konaklama ve tatil tesisi', 30, 1500000, 'TRY', 'Antalya / Belek', 'hotel', 'published')
  RETURNING id INTO v_property;

  -- Create a PMS room
  INSERT INTO catalog.property_units(property_id, unit_code, unit_name, unit_type, occupancy_status, housekeeping_status)
  VALUES (v_property, '101', 'Deluxe Deniz Manzaralı 101', 'deluxe', 'available', 'clean')
  RETURNING id INTO v_unit;

  -- 3. Test B2B Agencies (HotelRunner B2B Network)
  PERFORM catalog.add_b2b_agency(v_property, 'TatilSepeti Turizm', 'TATILSEPETI', 15.00, 5, 1200000);
  SELECT count(*) INTO v_agency_cnt FROM catalog.property_b2b_agencies WHERE property_id = v_property;
  IF v_agency_cnt <> 1 THEN RAISE EXCEPTION 'B2B agency creation failed'; END IF;

  -- Toggle stop-sale
  DECLARE
    v_aid uuid;
    v_stop boolean;
  BEGIN
    SELECT id, stop_sale INTO v_aid, v_stop FROM catalog.property_b2b_agencies WHERE property_id = v_property;
    IF v_stop <> false THEN RAISE EXCEPTION 'Initial stop sale should be false'; END IF;
    PERFORM catalog.toggle_agency_stop_sale(v_aid);
    SELECT stop_sale INTO v_stop FROM catalog.property_b2b_agencies WHERE id = v_aid;
    IF v_stop <> true THEN RAISE EXCEPTION 'Stop sale should be true after toggle'; END IF;
  END;

  RAISE NOTICE 'Step 2 PASSED: B2B agency allotment and stop-sale verified';

  -- 4. Test Rate Parity Monitor (HotelRunner Parity Intelligence)
  PERFORM catalog.run_rate_parity_check(v_property);
  SELECT count(*) INTO v_parity_cnt FROM catalog.property_rate_parity_alerts WHERE property_id = v_property;
  IF v_parity_cnt < 3 THEN RAISE EXCEPTION 'Rate parity check failed to generate channel alerts'; END IF;

  RAISE NOTICE 'Step 3 PASSED: Rate parity monitor checked (% channels audited)', v_parity_cnt;

  -- 5. Test Maintenance Tickets (ElektraWeb / Akınsoft Maintenance)
  PERFORM catalog.create_maintenance_ticket(v_property, '101', 'Klima arızası', 'urgent', 'Ahmet Usta');
  
  -- Room 101 should now be in maintenance
  SELECT occupancy_status INTO v_unit_status FROM catalog.property_units WHERE id = v_unit;
  IF v_unit_status <> 'maintenance' THEN RAISE EXCEPTION 'Unit status should be maintenance, got: %', v_unit_status; END IF;

  -- Resolve ticket
  DECLARE
    v_tid uuid;
    v_tstat text;
  BEGIN
    SELECT id, status INTO v_tid, v_tstat FROM catalog.property_maintenance_tickets WHERE property_id = v_property;
    IF v_tstat <> 'open' THEN RAISE EXCEPTION 'Ticket should be open'; END IF;
    PERFORM catalog.resolve_maintenance_ticket(v_tid);
    SELECT status INTO v_tstat FROM catalog.property_maintenance_tickets WHERE id = v_tid;
    IF v_tstat <> 'resolved' THEN RAISE EXCEPTION 'Ticket should be resolved'; END IF;
  END;

  -- Room 101 should be restored to available
  SELECT occupancy_status INTO v_unit_status FROM catalog.property_units WHERE id = v_unit;
  IF v_unit_status <> 'available' THEN RAISE EXCEPTION 'Unit status should be restored to available, got: %', v_unit_status; END IF;

  RAISE NOTICE 'Step 4 PASSED: Maintenance ticket workflow and unit status transition verified';

  -- 6. Test Cash Desk (Akınsoft Front Cashier)
  v_cash_res := catalog.add_cash_transaction(v_property, 'collection', 'TRY', 'cash', 500000, '101', 'Oda konaklama tahsilatı');
  IF v_cash_res <> 'ok' THEN RAISE EXCEPTION 'Cash transaction failed'; END IF;

  IF NOT EXISTS(SELECT 1 FROM catalog.property_cash_desk_transactions WHERE property_id = v_property AND amount_minor = 500000) THEN
    RAISE EXCEPTION 'Cash transaction not persisted';
  END IF;

  RAISE NOTICE 'Step 5 PASSED: Cash desk transaction verified';

  -- 7. Test Transport Notifications (KABIS / U-ETDS)
  -- External provider delivery is intentionally pending until a real provider
  -- response is verified.  The local record must never fabricate a dispatch
  -- code or report a successful government notification.
  v_trans_res := catalog.dispatch_transport_notification(v_property, 'kabis', '07 ABC 123', 'Hasan Şoför', 'Can Yılmaz', '11223344556', 'Antalya Havalimanı');
  IF v_trans_res <> 'pending' THEN RAISE EXCEPTION 'Transport dispatch should remain pending, got: %', v_trans_res; END IF;

  IF NOT EXISTS(SELECT 1 FROM catalog.property_transport_notifications WHERE property_id = v_property AND plate_code = '07 ABC 123' AND dispatch_status = 'pending' AND dispatch_code = '') THEN
    RAISE EXCEPTION 'KABIS notification record not found or incorrectly marked as verified';
  END IF;

  RAISE NOTICE 'Step 6 PASSED: KABİS notification queued without fabricating provider success';

  -- 8. Test Guest Concierge Requests (ElektraWeb Guest App)
  v_concierge_res := catalog.create_guest_concierge_request(v_property, '101', 'Can Yılmaz', 'housekeeping', '2 ekstra plaj havlusu');
  IF v_concierge_res <> 'ok' THEN RAISE EXCEPTION 'Concierge request creation failed'; END IF;

  DECLARE
    v_gid uuid;
    v_gstat text;
  BEGIN
    SELECT id, status INTO v_gid, v_gstat FROM catalog.property_guest_concierge_requests WHERE property_id = v_property;
    IF v_gstat <> 'pending' THEN RAISE EXCEPTION 'Concierge request should be pending'; END IF;
    PERFORM catalog.resolve_concierge_request(v_gid);
    SELECT status INTO v_gstat FROM catalog.property_guest_concierge_requests WHERE id = v_gid;
    IF v_gstat <> 'completed' THEN RAISE EXCEPTION 'Concierge request should be completed'; END IF;
  END;

  RAISE NOTICE 'Step 7 PASSED: Guest Concierge request creation and resolution verified';

  RAISE NOTICE 'ALL SECTOR BENCHMARKING INTEGRATION TESTS PASSED SUCCESSFULLY!';
END $$;

ROLLBACK;
