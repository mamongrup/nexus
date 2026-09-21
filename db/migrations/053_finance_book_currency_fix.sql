CREATE OR REPLACE FUNCTION finance.post_reservation_ledger(p_reservation_id text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  r booking.reservations%ROWTYPE;
  book_uuid uuid;
  j_id uuid;
  t uuid := nullif(current_setting('app.tenant_id',true),'')::uuid;
  u uuid := nullif(current_setting('app.actor_id',true),'')::uuid;
  calc jsonb;
  gross bigint;
  net bigint;
  nexus_take bigint;
  agency_share bigint;
BEGIN
  SELECT * INTO r FROM booking.reservations WHERE id::text = p_reservation_id;
  IF r.id IS NULL THEN RETURN 'not_found'; END IF;

  SELECT id INTO book_uuid FROM finance.books WHERE tenant_id = r.tenant_id AND currency = r.currency LIMIT 1;
  IF book_uuid IS NULL THEN
    INSERT INTO finance.books(tenant_id, name, currency)
    VALUES(r.tenant_id, 'Ana Muhasebe Defteri (' || r.currency || ')', r.currency)
    RETURNING id INTO book_uuid;
  END IF;

  IF EXISTS (SELECT 1 FROM finance.journals WHERE business_event_id = r.id) THEN
    RETURN 'already_posted';
  END IF;

  gross := coalesce(r.total_minor, 0);
  net := (gross * 88) / 100;
  nexus_take := (gross * 3) / 100;
  agency_share := gross - net - nexus_take;

  INSERT INTO finance.journals(tenant_id, book_id, business_event_id, currency, state)
  VALUES (r.tenant_id, book_uuid, r.id, r.currency, 'posted')
  RETURNING id INTO j_id;

  -- Balanced Double-Entry (Debit = Credit = gross)
  -- Debit 1100 AR
  INSERT INTO finance.journal_lines(tenant_id, journal_id, account_code, side, amount_minor)
  VALUES (r.tenant_id, j_id, '1100', 'D', gross);

  -- Credit 2000 AP (Supplier Net)
  INSERT INTO finance.journal_lines(tenant_id, journal_id, account_code, side, amount_minor)
  VALUES (r.tenant_id, j_id, '2000', 'C', net);

  -- Credit 2100 NEXUS Commission
  INSERT INTO finance.journal_lines(tenant_id, journal_id, account_code, side, amount_minor)
  VALUES (r.tenant_id, j_id, '2100', 'C', nexus_take);

  -- Credit 2200 Agency Markup
  IF agency_share > 0 THEN
    INSERT INTO finance.journal_lines(tenant_id, journal_id, account_code, side, amount_minor)
    VALUES (r.tenant_id, j_id, '2200', 'C', agency_share);
  END IF;

  INSERT INTO finance.settlements(
    tenant_id, reservation_id, supplier_id, agency_id,
    gross_amount_minor, supplier_net_minor, nexus_fee_minor, agency_markup_minor,
    currency, status
  ) VALUES (
    r.tenant_id, r.id, r.tenant_id, r.agency_id,
    gross, net, nexus_take, agency_share,
    r.currency, 'pending'
  ) ON CONFLICT (reservation_id) DO NOTHING;

  INSERT INTO events.audit(tenant_id, actor_id, action, resource_id, payload)
  VALUES (r.tenant_id, u, 'finance.ledger.posted', j_id, jsonb_build_object(
    'reservation_id', r.id, 'gross', gross, 'net', net, 'nexus_fee', nexus_take
  ));

  RETURN 'ok';
END $$;
