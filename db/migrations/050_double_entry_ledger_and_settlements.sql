CREATE TABLE IF NOT EXISTS finance.accounts (
  account_code text PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL CHECK(category IN ('asset','liability','equity','revenue','expense')),
  normal_balance character(1) NOT NULL CHECK(normal_balance IN ('D','C')),
  description text NOT NULL
);

INSERT INTO finance.accounts (account_code, name, category, normal_balance, description) VALUES
  ('1000', 'Banka & Ödeme Kuruluşu Takas (PSP Clearing)', 'asset', 'D', 'Tahsil edilen ve hesaba aktarılmayı bekleyen fonlar'),
  ('1100', 'Müşteri & Acente Alacakları (AR)', 'asset', 'D', 'Rezervasyon karşılığı tahsil edilecek tutarlar'),
  ('2000', 'Tedarikçi Hakediş Borçları (AP)', 'liability', 'C', 'Tedarikçiye ödenecek net konaklama/hizmet bedeli'),
  ('2100', 'NEXUS Platform Komisyon Geliri', 'revenue', 'C', 'Platform hizmet ve aracılık komisyonu'),
  ('2200', 'Acente Komisyon / Markup Geliri', 'revenue', 'C', 'Acentenin satıştan elde ettiği brüt kâr payı'),
  ('2300', 'Ödenecek Vergiler & Fonlar (KDV)', 'liability', 'C', 'Hizmet karşılığı devlete ödenecek katma değer vergisi')
ON CONFLICT (account_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS finance.settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  reservation_id uuid NOT NULL REFERENCES booking.reservations(id),
  supplier_id uuid NOT NULL REFERENCES core.organizations(id),
  agency_id uuid REFERENCES core.organizations(id),
  gross_amount_minor bigint NOT NULL CHECK(gross_amount_minor > 0),
  supplier_net_minor bigint NOT NULL CHECK(supplier_net_minor > 0),
  nexus_fee_minor bigint NOT NULL DEFAULT 0,
  agency_markup_minor bigint NOT NULL DEFAULT 0,
  currency character(3) NOT NULL REFERENCES core.currencies(code),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','paid','cancelled')),
  due_date date NOT NULL DEFAULT (CURRENT_DATE + 14),
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(reservation_id)
);

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

  SELECT id INTO book_uuid FROM finance.books WHERE tenant_id = r.tenant_id LIMIT 1;
  IF book_uuid IS NULL THEN
    INSERT INTO finance.books(tenant_id, name) VALUES(r.tenant_id, 'Ana Muhasebe Defteri') RETURNING id INTO book_uuid;
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

CREATE OR REPLACE FUNCTION finance.settlement_directory()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    s.id::text,
    coalesce(r.id::text, '-'),
    supp.legal_name,
    coalesce(ag.legal_name, 'Doğrudan Satış'),
    (s.gross_amount_minor / 100.0)::text || ' ' || s.currency,
    (s.supplier_net_minor / 100.0)::text || ' ' || s.currency,
    (s.nexus_fee_minor / 100.0)::text || ' ' || s.currency,
    (s.agency_markup_minor / 100.0)::text || ' ' || s.currency,
    s.status,
    to_char(s.due_date, 'DD.MM.YYYY')
  ]
  FROM finance.settlements s
  JOIN core.organizations supp ON supp.id = s.supplier_id
  LEFT JOIN core.organizations ag ON ag.id = s.agency_id
  LEFT JOIN booking.reservations r ON r.id = s.reservation_id
  WHERE s.tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR s.supplier_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR s.agency_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR auth.workspace() = 'nexus'
  ORDER BY s.created_at DESC
  LIMIT 50;
$$;

CREATE OR REPLACE FUNCTION finance.journals_directory()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    j.id::text,
    to_char(j.created_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'),
    coalesce(o.legal_name, 'NEXUS'),
    j.currency,
    j.state,
    coalesce(sum(l.amount_minor) FILTER (WHERE l.side = 'D') / 100.0, 0)::text,
    coalesce(sum(l.amount_minor) FILTER (WHERE l.side = 'C') / 100.0, 0)::text
  ]
  FROM finance.journals j
  JOIN core.organizations o ON o.id = j.tenant_id
  LEFT JOIN finance.journal_lines l ON l.journal_id = j.id
  WHERE j.tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR auth.workspace() = 'nexus'
  GROUP BY j.id, j.created_at, o.legal_name, j.currency, j.state
  ORDER BY j.created_at DESC
  LIMIT 50;
$$;
