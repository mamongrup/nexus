BEGIN;
DO $$
DECLARE
  t uuid := gen_random_uuid();
  ag uuid := gen_random_uuid();
  u uuid := gen_random_uuid();
  p uuid := gen_random_uuid();
  hold_u uuid := gen_random_uuid();
  quote_u uuid := gen_random_uuid();
  res_u uuid := gen_random_uuid();
  act_id uuid;
  status_res text;
  offer_calc jsonb;
  twin_data jsonb;
  journal_uuid uuid;
  total_debit bigint;
  total_credit bigint;
BEGIN
  -- Setup Organizations & User
  INSERT INTO core.organizations(id, legal_name, kind) VALUES
    (t, 'Test Tedarikçi AS', 'supplier'),
    (ag, 'Test Acente Ltd', 'agency');

  INSERT INTO auth.users(id, tenant_id, email, password_hash, display_name, role)
  VALUES (u, t, 'gov_test@nexus.local', 'disabled', 'Gov Tester', 'owner');

  INSERT INTO catalog.properties(id, tenant_id, title, locality, capacity, nightly_minor, currency)
  VALUES (p, t, 'Kalkan Villa Blue', 'Kalkan / Kaş', 6, 1500000, 'TRY');

  PERFORM set_config('app.actor_id', u::text, true);
  PERFORM set_config('app.tenant_id', t::text, true);

  -- 1. Test AI Action Bus (AUTO vs APPROVAL)
  status_res := ai.post_action('listing_worker', 'CREATE_LISTING', p::text, '{"field":"photos"}'::jsonb, 10, 'Normalize photos');
  IF status_res <> 'executed' THEN
    RAISE EXCEPTION 'Expected listing_worker with risk 10 to execute AUTO, got %', status_res;
  END IF;

  status_res := ai.post_action('price_guardian', 'UPDATE_PRICE', p::text, '{"new_price":1600000}'::jsonb, 45, 'Peak demand surge');
  IF status_res <> 'pending_approval' THEN
    RAISE EXCEPTION 'Expected price_guardian with risk 45 to require approval, got %', status_res;
  END IF;

  SELECT id INTO act_id FROM ai.actions WHERE tenant_id = t AND action_type = 'UPDATE_PRICE' ORDER BY created_at DESC LIMIT 1;
  IF ai.decide_action(act_id::text, 'approved', 'Fiyat güncellemesi onaylandı') <> 'ok' THEN
    RAISE EXCEPTION 'Action approval failed';
  END IF;

  -- 2. Test Commercial Rules & Pricing Calculation
  INSERT INTO pricing.commercial_rules(tenant_id, rule_name, rule_type, priority, commission_rate_bps, markup_rate_bps, nexus_take_bps, tax_rate_bps)
  VALUES (t, 'Kalkan Villa Özel Kuralı', 'product_rule', 20, 1200, 500, 300, 1000);

  offer_calc := pricing.calculate_offer(p::text, ag::text, 'agency', '2026-10-01', '2026-10-06');
  IF (offer_calc->>'nights')::int <> 5 THEN
    RAISE EXCEPTION 'Expected 5 nights, got %', offer_calc->>'nights';
  END IF;

  IF (offer_calc->>'customer_price_minor')::bigint <= (offer_calc->>'supplier_net_minor')::bigint THEN
    RAISE EXCEPTION 'Customer price must be greater than supplier net';
  END IF;

  -- 3. Test Double-Entry Ledger Posting for Confirmed Reservation
  INSERT INTO booking.quotes(id, tenant_id, property_id, total_minor, currency, snapshot, expires_at)
  VALUES (quote_u, t, p, (offer_calc->>'customer_price_minor')::bigint, 'TRY', offer_calc, now() + interval '2 hours');

  INSERT INTO booking.holds(id, tenant_id, quote_id, check_in, check_out, expires_at, status)
  VALUES (hold_u, t, quote_u, '2026-10-01', '2026-10-06', now() + interval '2 hours', 'active');

  INSERT INTO booking.reservations(id, tenant_id, hold_id, agency_id, total_minor, currency, status, payment_status)
  VALUES (res_u, t, hold_u, ag, (offer_calc->>'customer_price_minor')::bigint, 'TRY', 'confirmed', 'paid');

  IF finance.post_reservation_ledger(res_u::text) <> 'ok' THEN
    RAISE EXCEPTION 'Ledger posting failed';
  END IF;

  IF finance.post_reservation_ledger(res_u::text) <> 'already_posted' THEN
    RAISE EXCEPTION 'Ledger idempotency check failed';
  END IF;

  SELECT id INTO journal_uuid FROM finance.journals WHERE business_event_id = res_u;
  SELECT sum(amount_minor) FILTER (WHERE side = 'D'), sum(amount_minor) FILTER (WHERE side = 'C')
  INTO total_debit, total_credit
  FROM finance.journal_lines WHERE journal_id = journal_uuid;

  IF total_debit <> total_credit THEN
    RAISE EXCEPTION 'Double entry imbalance: Debit=%, Credit=%', total_debit, total_credit;
  END IF;

  -- 4. Test Business Digital Twin
  twin_data := organization.digital_twin(t::text);
  IF (twin_data->>'products_total')::int <> 1 THEN
    RAISE EXCEPTION 'Digital twin product count mismatch';
  END IF;

  IF (twin_data->>'cashflow_forecast_7d_minor')::bigint <= 0 THEN
    RAISE EXCEPTION 'Digital twin cash flow forecast missing';
  END IF;

  RAISE NOTICE 'PASS: AI action bus, commercial pricing engine, double-entry balanced ledger and digital twin';
END $$;
ROLLBACK;
