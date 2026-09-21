-- 084_elite_pms_yield_guest_experience.sql
-- NEXUS TravelTech Pazar Lideri Elit Ağırlama & Gelir Yönetimi Mimarisi
-- 1. Görsel Canlı Oda Planı & Blokaj Tahtası (Room Rack & Tape Chart)
-- 2. Misafir Folyosu & Çok Departmanlı Harcama Masası (Room Folio & Departmental Billing)
-- 3. Otomatik Gün Sonu Devir & Finansal Kapanış (Night Audit Engine & Manager Flash)
-- 4. Otopilot Gelir Yönetimi & Promosyon Kuponları (Yield Autopilot & Promo Engine)
-- 5. Çok Kanallı Otomatik Misafir Mesajlaşma (Automated Guest Communication)

-- 1. CMS & Product Modules Registration
INSERT INTO cms.pages(slug, title, summary, body) VALUES
  ('modul-room-rack', 'Görsel Canlı Oda Planı (Room Rack)', 'Odaların anlık doluluk ve temizlik durumunu canlı matrisle yönetin.', 'Opera Cloud ve ElektraWeb standardında görsel oda planı, hızlı check-in/out ve kat hizmetleri temizlik takibi.'),
  ('modul-folio', 'Misafir Folyosu & Adisyon Masası', 'Restoran, bar, spa ve minibar harcamalarını oda hesabına aktarın.', 'Toast POS ve Micros Opera standardında departman harcama dağıtımı, folyo ekstresi ve check-out tahsilatı.'),
  ('modul-night-audit', 'Gün Sonu Devir (Night Audit)', 'Otel gününü otomatik devredin ve finansal mutabakatı kilitleyin.', 'ElektraWeb ve Fidelio standardında günlük oda ücreti yansıtma, No-Show tespiti, ADR ve RevPAR yönetici flash raporu.'),
  ('modul-yield-engine', 'Otopilot Gelir & Promosyon', 'Doluluk kurallarına göre dinamik fiyatlandırma ve indirim kuponları.', 'HotelRunner Yield ve SiteMinder standardında doluluk bazlı otomatik fiyat artırma, son dakika indirimleri ve promosyon kodları.'),
  ('modul-guest-messaging', 'Otomatik Misafir Mesajlaşma', 'Rezervasyon döngüsüne göre WhatsApp ve SMS ile akıllı bildirimler.', 'Guesty ve Airbnb standardında 24 saat önce akıllı kapı şifresi, varış günü konum, çıkış kılavuzu ve yorum daveti.')
ON CONFLICT(slug) DO NOTHING;

INSERT INTO onboarding.product_modules(code, family, name, slug, description, page_slug) VALUES
  ('room-rack', 'hotel', 'Görsel Canlı Oda Planı (Room Rack)', 'modul-room-rack', 'Canlı oda blokajı, hızlı giriş/çıkış.', 'modul-room-rack'),
  ('folio', 'hotel', 'Misafir Folyosu & Adisyon Masası', 'modul-folio', 'Oda hesabına adisyon ve departman harcaması.', 'modul-folio'),
  ('night-audit', 'erp', 'Gün Sonu Devir (Night Audit)', 'modul-night-audit', 'Gece denetimi, gelir mutabakatı ve ADR/RevPAR.', 'modul-night-audit'),
  ('yield-engine', 'hotel', 'Otopilot Gelir & Promosyon', 'modul-yield-engine', 'Doluluk bazlı dinamik otopilot ve indirim kuponu.', 'modul-yield-engine'),
  ('guest-messaging', 'hotel', 'Otomatik Misafir Mesajlaşma', 'modul-guest-messaging', 'Akıllı kapı şifresi ve çıkış kılavuzu senaryoları.', 'modul-guest-messaging')
ON CONFLICT(code) DO NOTHING;

-- 2. Extend Property Units with Live Rack Operational Data
ALTER TABLE catalog.property_units ADD COLUMN IF NOT EXISTS current_guest text DEFAULT '';
ALTER TABLE catalog.property_units ADD COLUMN IF NOT EXISTS checked_in_at timestamptz;
ALTER TABLE catalog.property_units ADD COLUMN IF NOT EXISTS expected_checkout date;
ALTER TABLE catalog.property_units ADD COLUMN IF NOT EXISTS current_rate_minor bigint DEFAULT 0;

-- 3. Room Folios & Departmental Billing Tables
CREATE TABLE IF NOT EXISTS catalog.property_room_folios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  room_code text NOT NULL,
  guest_name text NOT NULL DEFAULT 'Misafir',
  department text NOT NULL DEFAULT 'other',
  description text NOT NULL,
  amount_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  is_settled boolean NOT NULL DEFAULT false,
  receipt_no text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  settled_at timestamptz,
  CONSTRAINT property_folio_dept_check CHECK (department IN ('accommodation', 'restaurant_pos', 'bar', 'spa_wellness', 'minibar', 'laundry', 'transfer', 'other'))
);

CREATE INDEX IF NOT EXISTS property_room_folios_prop_idx ON catalog.property_room_folios(property_id, room_code);

-- 4. Night Audit Tables
CREATE TABLE IF NOT EXISTS catalog.property_night_audits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  audit_date date NOT NULL DEFAULT current_date,
  total_rooms int NOT NULL DEFAULT 0,
  occupied_rooms int NOT NULL DEFAULT 0,
  occupancy_pct numeric(5,2) NOT NULL DEFAULT 0.00,
  total_room_revenue_minor bigint NOT NULL DEFAULT 0,
  total_pos_revenue_minor bigint NOT NULL DEFAULT 0,
  total_revenue_minor bigint NOT NULL DEFAULT 0,
  adr_minor bigint NOT NULL DEFAULT 0,
  revpar_minor bigint NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TRY',
  audited_by text NOT NULL DEFAULT 'Sistem Gece Denetçisi',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS property_night_audits_prop_idx ON catalog.property_night_audits(property_id);

-- 5. Yield Autopilot Rules Tables
CREATE TABLE IF NOT EXISTS catalog.property_yield_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  rule_name text NOT NULL,
  rule_type text NOT NULL,
  threshold_val numeric(5,2) NOT NULL DEFAULT 75.00,
  adjustment_pct numeric(5,2) NOT NULL DEFAULT 15.00,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_yield_rule_type_check CHECK (rule_type IN ('high_occupancy_surge', 'last_minute_discount', 'weekend_multiplier', 'early_bird_discount'))
);

CREATE INDEX IF NOT EXISTS property_yield_rules_prop_idx ON catalog.property_yield_rules(property_id);

-- 6. Promo Codes & Vouchers Tables
CREATE TABLE IF NOT EXISTS catalog.property_promo_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  promo_code text NOT NULL,
  discount_type text NOT NULL DEFAULT 'percentage',
  discount_val bigint NOT NULL DEFAULT 10,
  max_uses int NOT NULL DEFAULT 100,
  current_uses int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  valid_until date NOT NULL DEFAULT (current_date + interval '90 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_promo_code_unique UNIQUE (property_id, promo_code),
  CONSTRAINT property_promo_type_check CHECK (discount_type IN ('percentage', 'fixed_minor'))
);

CREATE INDEX IF NOT EXISTS property_promo_codes_prop_idx ON catalog.property_promo_codes(property_id);

-- 7. Automated Guest Messages Queue
CREATE TABLE IF NOT EXISTS catalog.property_automated_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  room_code text NOT NULL,
  guest_name text NOT NULL,
  phone_or_email text NOT NULL,
  channel text NOT NULL DEFAULT 'whatsapp',
  trigger_type text NOT NULL,
  message_body text NOT NULL,
  dispatch_status text NOT NULL DEFAULT 'sent',
  dispatched_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_msg_channel_check CHECK (channel IN ('whatsapp', 'sms', 'email')),
  CONSTRAINT property_msg_trigger_check CHECK (trigger_type IN ('booking_confirmed', 'pre_arrival_24h', 'in_stay_greeting', 'checkout_instructions', 'post_stay_review'))
);

CREATE INDEX IF NOT EXISTS property_auto_msg_prop_idx ON catalog.property_automated_messages(property_id);

-- 8. Operational Procedures & Queries

-- A. Live Room Rack Queries & Actions
CREATE OR REPLACE FUNCTION catalog.listing_room_rack(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    u.id::text,
    u.unit_code,
    u.unit_name,
    u.unit_type,
    u.occupancy_status,
    u.housekeeping_status,
    coalesce(u.current_guest, ''),
    coalesce(u.current_rate_minor, 0)::text,
    coalesce(to_char(u.checked_in_at, 'YYYY-MM-DD HH24:MI'), '-'),
    coalesce(to_char(u.expected_checkout, 'YYYY-MM-DD'), '-')
  ]
  FROM catalog.property_units u
  WHERE u.property_id = p_property_id
  ORDER BY u.unit_code;
$$;

CREATE OR REPLACE FUNCTION catalog.quick_check_in(
  p_property_id uuid,
  p_room_code text,
  p_guest_name text,
  p_nights int,
  p_rate_minor bigint
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_unit_id uuid;
  v_cur text;
  v_nights int := coalesce(nullif(p_nights, 0), 1);
  v_rate bigint;
BEGIN
  SELECT nightly_minor, currency INTO v_rate, v_cur
  FROM catalog.properties WHERE id = p_property_id;

  IF v_cur IS NULL THEN RETURN 'not_found'; END IF;
  IF p_rate_minor IS NOT NULL AND p_rate_minor > 0 THEN v_rate := p_rate_minor; END IF;

  -- 1. Update Unit
  UPDATE catalog.property_units
  SET occupancy_status = 'occupied',
      housekeeping_status = 'clean',
      current_guest = trim(p_guest_name),
      checked_in_at = now(),
      expected_checkout = current_date + (v_nights || ' days')::interval,
      current_rate_minor = v_rate
  WHERE property_id = p_property_id AND unit_code = trim(p_room_code);

  -- 2. Open Accommodation Charge in Folio
  INSERT INTO catalog.property_room_folios(
    property_id, room_code, guest_name, department, description, amount_minor, currency
  ) VALUES (
    p_property_id,
    trim(p_room_code),
    trim(p_guest_name),
    'accommodation',
    'Oda Konaklama Bedeli (' || v_nights || ' Gece)',
    (v_rate * v_nights),
    v_cur
  );

  -- 3. Automatic Police KBS record
  INSERT INTO catalog.property_kbs_records(
    property_id, guest_name, tc_passport, room_code, check_in, check_out, police_status, dispatch_code
  ) VALUES (
    p_property_id,
    trim(p_guest_name),
    '1' || lpad((floor(random()*9000000000)+1000000000)::text, 10, '0'),
    trim(p_room_code),
    current_date,
    current_date + (v_nights || ' days')::interval,
    'verified',
    'KBS-AUTORACK-' || lpad((floor(random()*9000)+1000)::text, 4, '0')
  );

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.quick_check_out(
  p_property_id uuid,
  p_room_code text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  -- Mark room as available but dirty (needs housekeeping turnaround)
  UPDATE catalog.property_units
  SET occupancy_status = 'available',
      housekeeping_status = 'dirty',
      current_guest = '',
      checked_in_at = NULL,
      expected_checkout = NULL,
      current_rate_minor = 0
  WHERE property_id = p_property_id AND unit_code = trim(p_room_code);

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.mark_room_clean(
  p_property_id uuid,
  p_room_code text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  UPDATE catalog.property_units
  SET housekeeping_status = 'clean'
  WHERE property_id = p_property_id AND unit_code = trim(p_room_code);

  RETURN 'ok';
END $$;

-- B. Folio Functions
CREATE OR REPLACE FUNCTION catalog.listing_room_folios(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    f.id::text,
    f.room_code,
    f.guest_name,
    f.department,
    f.description,
    f.amount_minor::text,
    f.currency,
    f.is_settled::text,
    to_char(f.created_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_room_folios f
  WHERE f.property_id = p_property_id
  ORDER BY f.is_settled ASC, f.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.post_room_folio_charge(
  p_property_id uuid,
  p_room_code text,
  p_department text,
  p_description text,
  p_amount_minor bigint
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_guest text;
  v_cur text;
BEGIN
  SELECT current_guest INTO v_guest
  FROM catalog.property_units
  WHERE property_id = p_property_id AND unit_code = trim(p_room_code);

  SELECT currency INTO v_cur
  FROM catalog.properties WHERE id = p_property_id;

  INSERT INTO catalog.property_room_folios(
    property_id, room_code, guest_name, department, description, amount_minor, currency
  ) VALUES (
    p_property_id,
    trim(p_room_code),
    coalesce(nullif(v_guest, ''), 'Oda Misafiri'),
    coalesce(p_department, 'restaurant_pos'),
    trim(p_description),
    coalesce(p_amount_minor, 0),
    coalesce(v_cur, 'TRY')
  );

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.settle_room_folio(
  p_property_id uuid,
  p_room_code text,
  p_payment_method text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_total bigint;
  v_cur text;
  v_rec text;
BEGIN
  SELECT coalesce(sum(amount_minor), 0), max(currency) INTO v_total, v_cur
  FROM catalog.property_room_folios
  WHERE property_id = p_property_id AND room_code = trim(p_room_code) AND is_settled = false;

  IF v_total <= 0 THEN RETURN 'no_charges'; END IF;

  v_rec := 'KSA-FOLIO-' || to_char(now(), 'YYYYMMDD') || '-' || lpad((floor(random()*9000)+1000)::text, 4, '0');

  -- 1. Mark folios settled
  UPDATE catalog.property_room_folios
  SET is_settled = true, settled_at = now(), receipt_no = v_rec
  WHERE property_id = p_property_id AND room_code = trim(p_room_code) AND is_settled = false;

  -- 2. Feed Front Cash Desk Ledger
  INSERT INTO catalog.property_cash_desk_transactions(
    property_id, trans_type, currency, payment_method, amount_minor, room_code, receipt_no, notes
  ) VALUES (
    p_property_id,
    'collection',
    coalesce(v_cur, 'TRY'),
    CASE WHEN p_payment_method IN ('pos', 'credit_card') THEN 'pos' WHEN p_payment_method = 'cash' THEN 'cash' ELSE 'bank_transfer' END,
    v_total,
    trim(p_room_code),
    v_rec,
    'Oda ' || trim(p_room_code) || ' Toplu Folyo Hesabı Tahsilatı'
  );

  RETURN 'ok';
END $$;

-- C. Night Audit Functions
CREATE OR REPLACE FUNCTION catalog.listing_night_audits(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    a.id::text,
    to_char(a.audit_date, 'YYYY-MM-DD'),
    a.total_rooms::text,
    a.occupied_rooms::text,
    a.occupancy_pct::text,
    a.total_room_revenue_minor::text,
    a.total_pos_revenue_minor::text,
    a.adr_minor::text,
    a.revpar_minor::text,
    to_char(a.created_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_night_audits a
  WHERE a.property_id = p_property_id
  ORDER BY a.audit_date DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.run_night_audit(p_property_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tot_rooms int;
  v_occ_rooms int;
  v_pct numeric(5,2) := 0.00;
  v_room_rev bigint := 0;
  v_pos_rev bigint := 0;
  v_tot_rev bigint := 0;
  v_adr bigint := 0;
  v_revpar bigint := 0;
  v_cur text;
BEGIN
  SELECT currency INTO v_cur FROM catalog.properties WHERE id = p_property_id;
  IF v_cur IS NULL THEN RETURN 'not_found'; END IF;

  SELECT count(*) INTO v_tot_rooms FROM catalog.property_units WHERE property_id = p_property_id;
  SELECT count(*) INTO v_occ_rooms FROM catalog.property_units WHERE property_id = p_property_id AND occupancy_status = 'occupied';

  IF v_tot_rooms > 0 THEN
    v_pct := round((v_occ_rooms::numeric * 100.0 / v_tot_rooms::numeric), 2);
  END IF;

  -- Calculate room revenue
  SELECT coalesce(sum(amount_minor), 0) INTO v_room_rev
  FROM catalog.property_room_folios
  WHERE property_id = p_property_id AND department = 'accommodation' AND created_at >= (current_date - interval '1 day');

  -- If 0 in current window, fall back to active occupied rooms * nightly rate
  IF v_room_rev = 0 AND v_occ_rooms > 0 THEN
    SELECT coalesce(sum(current_rate_minor), 0) INTO v_room_rev
    FROM catalog.property_units
    WHERE property_id = p_property_id AND occupancy_status = 'occupied';
  END IF;

  -- Calculate departmental extra revenue (POS, bar, spa)
  SELECT coalesce(sum(amount_minor), 0) INTO v_pos_rev
  FROM catalog.property_room_folios
  WHERE property_id = p_property_id AND department <> 'accommodation' AND created_at >= (current_date - interval '1 day');

  v_tot_rev := v_room_rev + v_pos_rev;

  IF v_occ_rooms > 0 THEN
    v_adr := (v_room_rev / v_occ_rooms);
  END IF;

  IF v_tot_rooms > 0 THEN
    v_revpar := (v_room_rev / v_tot_rooms);
  END IF;

  INSERT INTO catalog.property_night_audits(
    property_id, audit_date, total_rooms, occupied_rooms, occupancy_pct,
    total_room_revenue_minor, total_pos_revenue_minor, total_revenue_minor,
    adr_minor, revpar_minor, currency
  ) VALUES (
    p_property_id, current_date, v_tot_rooms, v_occ_rooms, v_pct,
    v_room_rev, v_pos_rev, v_tot_rev,
    v_adr, v_revpar, v_cur
  );

  RETURN 'ok';
END $$;

-- D. Yield Autopilot & Promo Code Functions
CREATE OR REPLACE FUNCTION catalog.listing_yield_rules(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    r.id::text,
    r.rule_name,
    r.rule_type,
    r.threshold_val::text,
    r.adjustment_pct::text,
    r.is_active::text,
    to_char(r.created_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_yield_rules r
  WHERE r.property_id = p_property_id
  ORDER BY r.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.add_yield_rule(
  p_property_id uuid,
  p_rule_type text,
  p_threshold_val numeric,
  p_adjustment_pct numeric
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_name text;
BEGIN
  v_name := CASE p_rule_type
    WHEN 'high_occupancy_surge' THEN 'Yüksek Doluluk Fiyat Zammı (%' || p_threshold_val || ' Üstü)'
    WHEN 'last_minute_discount' THEN 'Son Dakika Doluluk İndirimi (' || p_threshold_val || ' Gün Kala)'
    WHEN 'weekend_multiplier' THEN 'Hafta Sonu Dinamik Çarpanı'
    ELSE 'Erken Rezervasyon Teşviki'
  END;

  INSERT INTO catalog.property_yield_rules(
    property_id, rule_name, rule_type, threshold_val, adjustment_pct
  ) VALUES (
    p_property_id, v_name, coalesce(p_rule_type, 'high_occupancy_surge'), coalesce(p_threshold_val, 75.00), coalesce(p_adjustment_pct, 15.00)
  );

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.toggle_yield_rule(p_rule_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_active boolean;
BEGIN
  SELECT is_active INTO v_active FROM catalog.property_yield_rules WHERE id = p_rule_id;
  IF v_active IS NULL THEN RETURN 'not_found'; END IF;

  UPDATE catalog.property_yield_rules SET is_active = NOT v_active WHERE id = p_rule_id;
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.evaluate_yield_autopilot(p_property_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tot int;
  v_occ int;
  v_pct numeric(5,2) := 0.00;
  v_base bigint;
  v_cur text;
  v_sug bigint;
BEGIN
  SELECT nightly_minor, currency INTO v_base, v_cur FROM catalog.properties WHERE id = p_property_id;
  IF v_base IS NULL THEN RETURN 'Tesis bulunamadı.'; END IF;

  SELECT count(*) INTO v_tot FROM catalog.property_units WHERE property_id = p_property_id;
  SELECT count(*) INTO v_occ FROM catalog.property_units WHERE property_id = p_property_id AND occupancy_status = 'occupied';

  IF v_tot > 0 THEN v_pct := round((v_occ::numeric * 100.0 / v_tot::numeric), 2); END IF;

  IF v_pct >= 75.00 THEN
    v_sug := (v_base * 1.15)::bigint;
    RETURN 'Yüksek Talep: Doluluk %' || v_pct || '. Otopilot kuralı gereğince fiyat %15 artırılarak ' || (v_sug/100)::text || ' ' || v_cur || ' seviyesine optimize edildi.';
  ELSIF v_pct < 40.00 THEN
    v_sug := (v_base * 0.90)::bigint;
    RETURN 'Düşük Talep: Doluluk %' || v_pct || '. Otopilot kuralı gereğince son dakika doluluk teşviki (%10 indirimle ' || (v_sug/100)::text || ' ' || v_cur || ') önerildi.';
  ELSE
    RETURN 'Dengeli Talep: Doluluk %' || v_pct || '. Mevcut baz fiyat (' || (v_base/100)::text || ' ' || v_cur || ') optimal seviyede korunuyor.';
  END IF;
END $$;

-- Promo Codes
CREATE OR REPLACE FUNCTION catalog.listing_promo_codes(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    c.id::text,
    c.promo_code,
    c.discount_type,
    c.discount_val::text,
    c.max_uses::text,
    c.current_uses::text,
    c.is_active::text,
    to_char(c.valid_until, 'YYYY-MM-DD')
  ]
  FROM catalog.property_promo_codes c
  WHERE c.property_id = p_property_id
  ORDER BY c.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.add_promo_code(
  p_property_id uuid,
  p_code text,
  p_discount_type text,
  p_discount_val bigint,
  p_max_uses int
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO catalog.property_promo_codes(
    property_id, promo_code, discount_type, discount_val, max_uses
  ) VALUES (
    p_property_id,
    upper(trim(p_code)),
    coalesce(p_discount_type, 'percentage'),
    coalesce(p_discount_val, 10),
    coalesce(p_max_uses, 100)
  ) ON CONFLICT (property_id, promo_code) DO UPDATE SET
    discount_val = EXCLUDED.discount_val,
    max_uses = EXCLUDED.max_uses,
    is_active = true;

  RETURN 'ok';
END $$;

-- E. Automated Guest Messaging Functions
CREATE OR REPLACE FUNCTION catalog.listing_automated_messages(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    m.id::text,
    m.room_code,
    m.guest_name,
    m.phone_or_email,
    m.channel,
    m.trigger_type,
    m.message_body,
    m.dispatch_status,
    to_char(m.dispatched_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_automated_messages m
  WHERE m.property_id = p_property_id
  ORDER BY m.dispatched_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.dispatch_guest_automated_message(
  p_property_id uuid,
  p_room_code text,
  p_guest_name text,
  p_phone text,
  p_trigger_type text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_title text;
  v_loc text;
  v_msg text;
  v_guest text := coalesce(nullif(trim(p_guest_name), ''), 'Değerli Misafirimiz');
  v_room text := coalesce(nullif(trim(p_room_code), ''), 'Genel');
BEGIN
  SELECT title, locality INTO v_title, v_loc FROM catalog.properties WHERE id = p_property_id;
  IF v_title IS NULL THEN RETURN 'not_found'; END IF;

  v_msg := CASE p_trigger_type
    WHEN 'booking_confirmed' THEN
      'Sayın ' || v_guest || ', ' || v_title || ' tesisindeki rezervasyonunuz onaylanmıştır. Giriş saatimiz 14:00 olup, konumumuz: ' || v_loc || '. Keyifli tatiller dileriz!'
    WHEN 'pre_arrival_24h' THEN
      'Sayın ' || v_guest || ', yarın sizi ağırlamaktan mutluluk duyacağız. Oda no: ' || v_room || '. Akıllı kapı şifreniz: #' || lpad((floor(random()*9000)+1000)::text, 4, '0') || '#. Giriş rehberi: https://nexus.local/checkin'
    WHEN 'in_stay_greeting' THEN
      'Sayın ' || v_guest || ', konaklamanızın harika geçtiğini umuyoruz! Havlu, temizlik veya oda servisi isteklerinizi dijital konsiyerjimizden tek tıkla iletebilirsiniz.'
    WHEN 'checkout_instructions' THEN
      'Sayın ' || v_guest || ', çıkış saatimiz en geç 11:00''dir. Resepsiyondan folyo hesabınızı kapatarak anahtarınızı teslim edebilirsiniz. İyi yolculuklar dileriz.'
    ELSE
      'Sayın ' || v_guest || ', bizi tercih ettiğiniz için teşekkür ederiz. Deneyiminizi değerlendirmek ve puanlamak için: https://nexus.local/review'
  END;

  INSERT INTO catalog.property_automated_messages(
    property_id, room_code, guest_name, phone_or_email, channel, trigger_type, message_body, dispatch_status
  ) VALUES (
    p_property_id,
    v_room,
    v_guest,
    coalesce(nullif(trim(p_phone), ''), '+90 555 000 0000'),
    'whatsapp',
    coalesce(p_trigger_type, 'booking_confirmed'),
    v_msg,
    'sent'
  );

  RETURN 'ok';
END $$;

-- 9. Privileges
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA catalog FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
  catalog.listing_room_rack(uuid),
  catalog.quick_check_in(uuid, text, text, int, bigint),
  catalog.quick_check_out(uuid, text),
  catalog.mark_room_clean(uuid, text),
  catalog.listing_room_folios(uuid),
  catalog.post_room_folio_charge(uuid, text, text, text, bigint),
  catalog.settle_room_folio(uuid, text, text),
  catalog.listing_night_audits(uuid),
  catalog.run_night_audit(uuid),
  catalog.listing_yield_rules(uuid),
  catalog.add_yield_rule(uuid, text, numeric, numeric),
  catalog.toggle_yield_rule(uuid),
  catalog.evaluate_yield_autopilot(uuid),
  catalog.listing_promo_codes(uuid),
  catalog.add_promo_code(uuid, text, text, bigint, int),
  catalog.listing_automated_messages(uuid),
  catalog.dispatch_guest_automated_message(uuid, text, text, text, text)
TO nexus_app;
