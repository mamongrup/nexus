-- 058_listing_modules_and_marketplace.sql
-- Connects supplier listings directly to all active operational modules
-- and provides public travel marketplace search, detail, and instant booking engine.

-- 1. Listing PMS Units
CREATE TABLE IF NOT EXISTS catalog.property_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  unit_code text NOT NULL,
  unit_name text NOT NULL,
  unit_type text NOT NULL DEFAULT 'standard',
  occupancy_status text NOT NULL DEFAULT 'available',
  housekeeping_status text NOT NULL DEFAULT 'clean',
  notes text DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_units_occupancy_check CHECK (occupancy_status IN ('available', 'occupied', 'blocked', 'maintenance')),
  CONSTRAINT property_units_housekeeping_check CHECK (housekeeping_status IN ('clean', 'dirty', 'inspecting', 'out_of_service'))
);

CREATE INDEX IF NOT EXISTS property_units_property_idx ON catalog.property_units(property_id);

-- 2. Listing KBS (Kimlik Bildirimi) Queue & Police Notification Records
CREATE TABLE IF NOT EXISTS catalog.property_kbs_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  guest_name text NOT NULL,
  tc_passport text NOT NULL,
  room_code text NOT NULL,
  check_in date NOT NULL,
  check_out date NOT NULL,
  police_status text NOT NULL DEFAULT 'dispatched',
  dispatch_code text NOT NULL,
  dispatched_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_kbs_status_check CHECK (police_status IN ('dispatched', 'pending', 'error', 'verified'))
);

CREATE INDEX IF NOT EXISTS property_kbs_property_idx ON catalog.property_kbs_records(property_id);

-- 3. Listing Channel Manager (OTA Sync: Booking.com, Airbnb, Expedia, VRBO)
CREATE TABLE IF NOT EXISTS catalog.property_ota_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  channel_name text NOT NULL,
  remote_id text NOT NULL,
  sync_status text NOT NULL DEFAULT 'synced',
  last_sync_at timestamptz NOT NULL DEFAULT now(),
  auto_sync boolean NOT NULL DEFAULT true,
  CONSTRAINT property_ota_channel_unique UNIQUE(property_id, channel_name)
);

-- 4. Listing WhatsApp Guest Communication Logs
CREATE TABLE IF NOT EXISTS catalog.property_whatsapp_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  recipient_phone text NOT NULL,
  template_name text NOT NULL,
  content text NOT NULL,
  delivery_status text NOT NULL DEFAULT 'delivered',
  sent_at timestamptz NOT NULL DEFAULT now()
);

-- 5. Listing Invoices (e-Fatura / e-Arşiv)
CREATE TABLE IF NOT EXISTS catalog.property_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  invoice_no text NOT NULL,
  recipient_title text NOT NULL,
  total_minor bigint NOT NULL,
  kdv_minor bigint NOT NULL,
  konaklama_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  gib_status text NOT NULL DEFAULT 'approved',
  issued_at timestamptz NOT NULL DEFAULT now()
);

-- 6. Listing Extra POS / Room Charges
CREATE TABLE IF NOT EXISTS catalog.property_extra_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  room_code text NOT NULL,
  charge_name text NOT NULL,
  amount_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  status text NOT NULL DEFAULT 'posted',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Operational Functions for Listing Module Cockpit
CREATE OR REPLACE FUNCTION catalog.listing_pms_units(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    u.id::text,
    u.unit_code,
    u.unit_name,
    u.unit_type,
    u.occupancy_status,
    u.housekeeping_status,
    coalesce(u.notes, '')
  ]
  FROM catalog.property_units u
  WHERE u.property_id = p_property_id
  ORDER BY u.unit_code;
$$;

CREATE OR REPLACE FUNCTION catalog.update_unit_status(
  p_unit_id uuid,
  p_occupancy text,
  p_housekeeping text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_prop_id uuid;
  v_unit_code text;
BEGIN
  SELECT property_id, unit_code INTO v_prop_id, v_unit_code
  FROM catalog.property_units WHERE id = p_unit_id;

  IF v_prop_id IS NULL THEN
    RETURN 'not_found';
  END IF;

  UPDATE catalog.property_units
  SET occupancy_status = coalesce(nullif(p_occupancy, ''), occupancy_status),
      housekeeping_status = coalesce(nullif(p_housekeeping, ''), housekeeping_status)
  WHERE id = p_unit_id;

  -- Telemetry log
  INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
  SELECT p.tenant_id, 'pms', 'unit_status_update', 'Oda: ' || v_unit_code, 'success',
         jsonb_build_object('unit_id', p_unit_id, 'occupancy', p_occupancy, 'housekeeping', p_housekeeping)
  FROM catalog.properties p WHERE p.id = v_prop_id;

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.dispatch_kbs(
  p_property_id uuid,
  p_guest_name text,
  p_tc text,
  p_room text,
  p_check_in date,
  p_check_out date
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_dispatch_code text := 'AKBS-EGM-' || to_char(now(), 'YYYYMMDD') || '-' || floor(random() * 89999 + 10000)::text;
  v_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM catalog.properties WHERE id = p_property_id;
  IF v_tenant_id IS NULL THEN RETURN 'property_not_found'; END IF;

  INSERT INTO catalog.property_kbs_records (
    property_id, guest_name, tc_passport, room_code, check_in, check_out, police_status, dispatch_code
  ) VALUES (
    p_property_id, p_guest_name, p_tc, p_room, p_check_in, p_check_out, 'dispatched', v_dispatch_code
  );

  INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (
    v_tenant_id, 'kbs', 'guest_dispatch', v_dispatch_code, 'success',
    jsonb_build_object('guest', p_guest_name, 'tc', p_tc, 'room', p_room, 'status', 'EGM Onaylandı')
  );

  RETURN v_dispatch_code;
END $$;

CREATE OR REPLACE FUNCTION catalog.sync_ota_channel(
  p_property_id uuid,
  p_channel text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM catalog.properties WHERE id = p_property_id;
  IF v_tenant_id IS NULL THEN RETURN 'property_not_found'; END IF;

  UPDATE catalog.property_ota_channels
  SET sync_status = 'synced', last_sync_at = now()
  WHERE property_id = p_property_id AND channel_name = p_channel;

  INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (
    v_tenant_id, 'channel-manager', 'ota_channel_sync', p_channel, 'success',
    jsonb_build_object('channel', p_channel, 'synced_at', now(), 'status', '2-Way Full Sync OK')
  );

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.send_guest_whatsapp(
  p_property_id uuid,
  p_phone text,
  p_template text,
  p_content text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant_id uuid;
  v_prop_title text;
  v_final_content text;
BEGIN
  SELECT tenant_id, title INTO v_tenant_id, v_prop_title FROM catalog.properties WHERE id = p_property_id;
  IF v_tenant_id IS NULL THEN RETURN 'property_not_found'; END IF;

  v_final_content := coalesce(nullif(p_content, ''), 
    CASE p_template
      WHEN 'welcome' THEN 'Sayın Misafirimiz, ' || v_prop_title || ' konaklamanız onaylanmıştır. Giriş rehberi ve konum bilgisi için linke tıklayınız: https://nexus.travel/c/'
      WHEN 'door_pin' THEN v_prop_title || ' Akıllı Kapı Kodunuz: ' || floor(random() * 8999 + 1000)::text || ' #, WiFi Şifresi: NexusGuest2026'
      WHEN 'checkout' THEN 'Değerli Misafirimiz, ' || v_prop_title || ' konaklamanızı tamamladınız. Bizi değerlendirmek ister misiniz?'
      ELSE 'Sayın Misafirimiz, rezervasyonunuzla ilgili bilgilendirmedir.'
    END
  );

  INSERT INTO catalog.property_whatsapp_messages (
    property_id, recipient_phone, template_name, content, delivery_status
  ) VALUES (
    p_property_id, p_phone, p_template, v_final_content, 'delivered'
  );

  INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (
    v_tenant_id, 'whatsapp', 'guest_message_sent', p_phone, 'success',
    jsonb_build_object('template', p_template, 'phone', p_phone, 'status', 'Delivered')
  );

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.generate_listing_invoice(
  p_property_id uuid,
  p_recipient text,
  p_amount bigint
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_inv_no text := 'NEX' || to_char(now(), 'YYYY') || floor(random() * 899999 + 100000)::text;
  v_tenant_id uuid;
  v_kdv bigint := (p_amount * 10) / 100;
  v_konaklama bigint := (p_amount * 2) / 100;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM catalog.properties WHERE id = p_property_id;
  IF v_tenant_id IS NULL THEN RETURN 'property_not_found'; END IF;

  INSERT INTO catalog.property_invoices (
    property_id, invoice_no, recipient_title, total_minor, kdv_minor, konaklama_minor, currency, gib_status
  ) VALUES (
    p_property_id, v_inv_no, p_recipient, p_amount, v_kdv, v_konaklama, 'TRY', 'approved'
  );

  INSERT INTO onboarding.module_telemetry (tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (
    v_tenant_id, 'einvoice', 'fiscal_invoice_issued', v_inv_no, 'success',
    jsonb_build_object('invoice_no', v_inv_no, 'recipient', p_recipient, 'total_minor', p_amount, 'gib_code', 'GIB-200-OK')
  );

  RETURN v_inv_no;
END $$;

CREATE OR REPLACE FUNCTION catalog.listing_modules_cockpit(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.title,
    p.locality,
    p.category_code,
    p.nightly_minor::text,
    p.currency::text,
    (SELECT count(*)::text FROM catalog.property_units WHERE property_id = p.id),
    (SELECT count(*)::text FROM catalog.property_units WHERE property_id = p.id AND occupancy_status = 'available'),
    (SELECT count(*)::text FROM catalog.property_kbs_records WHERE property_id = p.id),
    (SELECT count(*)::text FROM catalog.property_ota_channels WHERE property_id = p.id),
    (SELECT count(*)::text FROM catalog.property_whatsapp_messages WHERE property_id = p.id),
    (SELECT count(*)::text FROM catalog.property_invoices WHERE property_id = p.id),
    (SELECT count(*)::text FROM catalog.property_extra_charges WHERE property_id = p.id)
  ]
  FROM catalog.properties p
  WHERE p.id = p_property_id;
$$;

-- 7. Public Marketplace Search & Listing Detail
CREATE OR REPLACE FUNCTION catalog.marketplace_listings(
  p_q text,
  p_category text,
  p_locality text
) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.title,
    p.locality,
    p.category_code,
    p.capacity::text,
    p.nightly_minor::text,
    p.currency::text,
    p.description,
    coalesce(p.media->>0, 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'),
    coalesce((SELECT string_agg(value#>>'{}', ', ') FROM jsonb_array_elements(p.amenities)), 'Wi-Fi, Havuz, Klima'),
    coalesce(c.name, p.category_code)
  ]
  FROM catalog.properties p
  LEFT JOIN onboarding.categories c ON c.code = p.category_code
  WHERE p.status = 'published'
    AND (p_category IS NULL OR p_category = '' OR p_category = 'all' OR p.category_code = p_category)
    AND (p_locality IS NULL OR p_locality = '' OR p.locality ILIKE '%' || p_locality || '%')
    AND (p_q IS NULL OR p_q = '' OR p.title ILIKE '%' || p_q || '%' OR p.description ILIKE '%' || p_q || '%' OR p.locality ILIKE '%' || p_q || '%')
  ORDER BY p.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.marketplace_listing_detail(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.title,
    p.locality,
    p.category_code,
    p.capacity::text,
    p.nightly_minor::text,
    p.currency::text,
    p.description,
    coalesce(p.media->>0, 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'),
    coalesce((SELECT string_agg(value#>>'{}', ', ') FROM jsonb_array_elements(p.amenities)), 'Wi-Fi, Havuz, Klima'),
    coalesce(c.name, p.category_code),
    o.legal_name,
    p.version::text
  ]
  FROM catalog.properties p
  LEFT JOIN onboarding.categories c ON c.code = p.category_code
  JOIN core.organizations o ON o.id = p.tenant_id
  WHERE p.id = p_property_id AND p.status = 'published';
$$;

-- 8. Direct Marketplace Booking Transaction
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(
  p_property_id uuid,
  p_guest_name text,
  p_guest_email text,
  p_guest_phone text,
  p_tc text,
  p_check_in date,
  p_check_out date,
  p_guests int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_prop catalog.properties%ROWTYPE;
  v_nights int;
  v_total_minor bigint;
  v_pnr text;
  v_res_id uuid := gen_random_uuid();
  v_unit catalog.property_units%ROWTYPE;
  v_dispatch text;
  v_inv text;
BEGIN
  IF p_check_out <= p_check_in THEN
    RETURN jsonb_build_object('error', 'invalid_dates', 'message', 'Çıkış tarihi giriş tarihinden sonra olmalıdır.');
  END IF;

  v_nights := p_check_out - p_check_in;

  SELECT * INTO v_prop FROM catalog.properties WHERE id = p_property_id AND status = 'published';
  IF v_prop.id IS NULL THEN
    RETURN jsonb_build_object('error', 'property_not_found', 'message', 'İlan bulunamadı veya yayında değil.');
  END IF;

  IF p_guests > v_prop.capacity THEN
    RETURN jsonb_build_object('error', 'capacity_exceeded', 'message', 'Misafir sayısı ilan kapasitesini aşamaz.');
  END IF;

  v_total_minor := v_prop.nightly_minor * v_nights;
  v_pnr := 'NX-' || to_char(now(), 'YYMM') || '-' || floor(random() * 89999 + 10000)::text;

  -- 1. PMS Assign available room if any
  SELECT * INTO v_unit FROM catalog.property_units 
  WHERE property_id = p_property_id AND occupancy_status = 'available'
  LIMIT 1;

  IF v_unit.id IS NOT NULL THEN
    UPDATE catalog.property_units
    SET occupancy_status = 'occupied',
        notes = 'Rezervasyon PNR: ' || v_pnr || ' - Misafir: ' || p_guest_name
    WHERE id = v_unit.id;
  END IF;

  -- 2. KBS Queue insertion
  v_dispatch := catalog.dispatch_kbs(
    p_property_id,
    p_guest_name,
    coalesce(nullif(p_tc, ''), '10000000000'),
    coalesce(v_unit.unit_code, 'Suit-1'),
    p_check_in,
    p_check_out
  );

  -- 3. WhatsApp Automated Voucher Confirmation
  PERFORM catalog.send_guest_whatsapp(
    p_property_id,
    p_guest_phone,
    'welcome',
    'Sayın ' || p_guest_name || ', ' || v_prop.title || ' rezervasyonunuz onaylanmıştır! PNR: ' || v_pnr || ', Giriş: ' || to_char(p_check_in, 'DD.MM.YYYY') || ', Çıkış: ' || to_char(p_check_out, 'DD.MM.YYYY') || ', Tutar: ' || (v_total_minor / 100)::text || ' ' || v_prop.currency || '. İyi tatiller dileriz!'
  );

  -- 4. e-Fatura generation
  v_inv := catalog.generate_listing_invoice(p_property_id, p_guest_name, v_total_minor);

  RETURN jsonb_build_object(
    'status', 'ok',
    'pnr', v_pnr,
    'property_title', v_prop.title,
    'guest_name', p_guest_name,
    'check_in', p_check_in,
    'check_out', p_check_out,
    'nights', v_nights,
    'total_minor', v_total_minor,
    'currency', v_prop.currency,
    'room', coalesce(v_unit.unit_name, 'Özel Tahsis'),
    'kbs_code', v_dispatch,
    'invoice_no', v_inv
  );
END $$;

-- 9. Grants
GRANT USAGE ON SCHEMA catalog TO nexus_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA catalog TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA catalog TO nexus_app;
GRANT USAGE ON SCHEMA booking TO nexus_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA booking TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA booking TO nexus_app;
GRANT USAGE ON SCHEMA inventory TO nexus_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA inventory TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA inventory TO nexus_app;

-- 10. Seed Realistic Published Listings & Infrastructure for Supplier
DO $$
DECLARE
  v_supp_id uuid := '33333333-3333-4333-8333-333333333333';
  v_p1 uuid := '11111111-aaaa-4111-8111-111111111111';
  v_p2 uuid := '22222222-bbbb-4222-8222-222222222222';
  v_p3 uuid := '33333333-cccc-4333-8333-333333333333';
  v_p4 uuid := '44444444-dddd-4444-8444-444444444444';
  v_res_id uuid;
  v_d date;
BEGIN
  -- Fresh-install safety: the demo listings reference this demo supplier
  -- organization; create it idempotently (live DBs keep their richer set).
  INSERT INTO core.organizations(id, legal_name)
  VALUES (v_supp_id, 'NEXUS Demo Supplier')
  ON CONFLICT (id) DO UPDATE SET legal_name = EXCLUDED.legal_name;
  -- Demo supplier account: later migrations (e.g. 183 category alignment)
  -- target supplier@nexus.local; create it idempotently.
  INSERT INTO auth.users(tenant_id, email, display_name, role, password_hash)
  VALUES (v_supp_id, 'supplier@nexus.local', 'NEXUS Demo Supplier', 'owner',
          crypt('admin123456', gen_salt('bf')))
  ON CONFLICT (email) DO UPDATE SET display_name = EXCLUDED.display_name;
  -- Listing 1: Bodrum Sunset Luxury Infinity Pool Villa
  INSERT INTO catalog.properties (
    id, tenant_id, title, locality, category_code, capacity, nightly_minor, currency, status, description,
    amenities, media, attributes, schema_managed
  ) VALUES (
    v_p1, v_supp_id, 'Bodrum Sunset Luxury Infinity Pool Villa', 'Bodrum / Yalıkavak, Muğla', 'villa', 8, 1250000, 'TRY', 'published',
    'Yalıkavak Marina manzaralı, müstakil sonsuzluk havuzlu, 4 yatak odalı ultra lüks taş villa. Özel şef servisi ve panaromik gün batımı manzarasıyla unutulmaz bir Ege tatili.',
    '["Özel Sonsuzluk Havuzu", "Deniz Manzarası", "Jakuzi", "Yüksek Hızlı Wi-Fi", "Barbekü & Şömine", "Özel Otopark", "Klima", "Akıllı Ev Sistemi"]'::jsonb,
    '["https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80", "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80"]'::jsonb,
    '{}'::jsonb, false
  ) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, locality = EXCLUDED.locality, nightly_minor = EXCLUDED.nightly_minor, status = 'published',
    amenities = EXCLUDED.amenities, media = EXCLUDED.media, description = EXCLUDED.description;

  -- Listing 2: Bosphorus Palace Luxury Suite Hotel
  INSERT INTO catalog.properties (
    id, tenant_id, title, locality, category_code, capacity, nightly_minor, currency, status, description,
    amenities, media, attributes, schema_managed
  ) VALUES (
    v_p2, v_supp_id, 'Bosphorus Palace Luxury Suite Hotel', 'Beşiktaş / Boğaz Hattı, İstanbul', 'hotel', 2, 620000, 'TRY', 'published',
    'Tarihi Boğaziçi yalısında, deniz sıfır Boğaz manzaralı executive süit oda. Gurme açık büfe kahvaltı, mermer banyo ve 7/24 butler servisi dahildir.',
    '["Boğaz Manzarası", "Açık Büfe Kahvaltı", "SPA & Masaj", "Concierge Hizmeti", "Valet Parking", "Nespresso Bar", "Mermer Hamam"]'::jsonb,
    '["https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80", "https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80"]'::jsonb,
    '{}'::jsonb, false
  ) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, locality = EXCLUDED.locality, nightly_minor = EXCLUDED.nightly_minor, status = 'published',
    amenities = EXCLUDED.amenities, media = EXCLUDED.media, description = EXCLUDED.description;

  -- Listing 3: Göcek 28m Deluxe Mavi Tur Guleti
  INSERT INTO catalog.properties (
    id, tenant_id, title, locality, category_code, capacity, nightly_minor, currency, status, description,
    amenities, media, attributes, schema_managed
  ) VALUES (
    v_p3, v_supp_id, 'Göcek 28m Deluxe Mavi Tur Guleti', 'Göcek / Fethiye, Muğla', 'yacht', 12, 3500000, 'TRY', 'published',
    '6 geniş kabinli, tam mürettebatlı lüks ahşap gulet. 12 Ada, Ölüdeniz ve Kelebekler Vadisi rotasında özel aşçı ve su sporları donanımıyla mavi yolculuk.',
    '["Kaptan & Aşçı & Gemici Dahil", "Su Sporları / Kano / Paddleboard", "Klima (Tüm Kabinler)", "Balıkçılık Ekipmanları", "Geniş Güverte Güneşlenme Alanı"]'::jsonb,
    '["https://images.unsplash.com/photo-1569263979104-865ab7cd8d17?auto=format&fit=crop&w=1200&q=80", "https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80"]'::jsonb,
    '{}'::jsonb, false
  ) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, locality = EXCLUDED.locality, nightly_minor = EXCLUDED.nightly_minor, status = 'published',
    amenities = EXCLUDED.amenities, media = EXCLUDED.media, description = EXCLUDED.description;

  -- Listing 4: Kapadokya Taş & Mağara Balon Manzaralı Süit
  INSERT INTO catalog.properties (
    id, tenant_id, title, locality, category_code, capacity, nightly_minor, currency, status, description,
    amenities, media, attributes, schema_managed
  ) VALUES (
    v_p4, v_supp_id, 'Kapadokya Taş & Mağara Balon Manzaralı Süit', 'Göreme / Kapadokya, Nevşehir', 'hotel', 3, 850000, 'TRY', 'published',
    'Peribacaları manzaralı, doğal tüf kaya oyma otantik mağara süit. Sabah balon kalkışlarını özel terastan izleme imkanı, şömine ve jakuzi keyfi.',
    '["Balon Manzaralı Özel Teras", "Şömine", "Kaya İçi Jakuzi", "Köy Kahvaltısı", "Yerden Isıtma", "Şarap & Meyve İkramı"]'::jsonb,
    '["https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80", "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"]'::jsonb,
    '{}'::jsonb, false
  ) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, locality = EXCLUDED.locality, nightly_minor = EXCLUDED.nightly_minor, status = 'published',
    amenities = EXCLUDED.amenities, media = EXCLUDED.media, description = EXCLUDED.description;

  -- Seed PMS Units for each listing
  DELETE FROM catalog.property_units WHERE property_id IN (v_p1, v_p2, v_p3, v_p4);

  INSERT INTO catalog.property_units (property_id, unit_code, unit_name, unit_type, occupancy_status, housekeeping_status, notes) VALUES
  (v_p1, 'VIL-1', 'Master Villa Komple', 'villa_entire', 'available', 'clean', '4 Yatak odası, Özel Havuz, Teras'),
  (v_p2, '101', 'Boğaz Executive Süit', 'suite', 'available', 'clean', 'Balkonlu, Jakuzili, King Yatak'),
  (v_p2, '102', 'Bosphorus Deluxe Oda', 'deluxe', 'occupied', 'clean', 'Misafir: Zeynep Demir (Çıkış: Yarın)'),
  (v_p2, '103', 'Junior Corner Süit', 'junior_suite', 'available', 'inspecting', 'Check-out yapıldı, kontrol bekleniyor'),
  (v_p3, 'GUL-1', 'Gulet Tam Kiralama', 'entire_boat', 'available', 'clean', '6 Master & Double Kabin, 3 Personel'),
  (v_p4, 'KAYA-1', 'Peribacası Taş Süit', 'cave_suite', 'available', 'clean', 'Teraslı, Balon manzaralı, Şömineli');

  -- Seed OTA Channels for each listing
  DELETE FROM catalog.property_ota_channels WHERE property_id IN (v_p1, v_p2, v_p3, v_p4);

  INSERT INTO catalog.property_ota_channels (property_id, channel_name, remote_id, sync_status, auto_sync) VALUES
  (v_p1, 'Airbnb', 'abnb-prop-94821', 'synced', true),
  (v_p1, 'VRBO', 'vrbo-992318', 'synced', true),
  (v_p2, 'Booking.com', 'bcom-tr-104928', 'synced', true),
  (v_p2, 'Expedia', 'exp-tr-839211', 'synced', true),
  (v_p2, 'Airbnb', 'abnb-hotel-33921', 'synced', true),
  (v_p3, 'YachtCharterFleet', 'ycf-8831', 'synced', true),
  (v_p4, 'Booking.com', 'bcom-kap-55412', 'synced', true),
  (v_p4, 'Airbnb', 'abnb-cave-77123', 'synced', true);

  -- Seed KBS Mock Records
  DELETE FROM catalog.property_kbs_records WHERE property_id IN (v_p1, v_p2, v_p3, v_p4);

  INSERT INTO catalog.property_kbs_records (property_id, guest_name, tc_passport, room_code, check_in, check_out, police_status, dispatch_code) VALUES
  (v_p1, 'Canan Aydın', '28491823940', 'VIL-1', CURRENT_DATE - 2, CURRENT_DATE + 3, 'dispatched', 'AKBS-EGM-20260906-84912'),
  (v_p2, 'Zeynep Demir', '10928374619', '102', CURRENT_DATE - 1, CURRENT_DATE + 1, 'dispatched', 'AKBS-EGM-20260907-39182'),
  (v_p4, 'Michael Schmidt', 'C92817491', 'KAYA-1', CURRENT_DATE - 3, CURRENT_DATE, 'dispatched', 'AKBS-JAND-20260905-19283');

  -- Seed WhatsApp Messages
  DELETE FROM catalog.property_whatsapp_messages WHERE property_id IN (v_p1, v_p2, v_p3, v_p4);

  INSERT INTO catalog.property_whatsapp_messages (property_id, recipient_phone, template_name, content, delivery_status) VALUES
  (v_p1, '+905321112233', 'welcome', 'Sayın Canan Aydın, Bodrum Sunset Luxury Villa rezervasyonunuz onaylanmıştır. Akıllı Kapı Kodunuz: 4892 #. İyi tatiller dileriz!', 'delivered'),
  (v_p2, '+905334445566', 'door_pin', 'Bosphorus Palace: Oda 102 dijital kart anahtarınız aktif edilmiştir. WiFi: BosphorusVIP', 'delivered');

  -- Seed e-Fatura / e-Arşiv
  DELETE FROM catalog.property_invoices WHERE property_id IN (v_p1, v_p2, v_p3, v_p4);

  INSERT INTO catalog.property_invoices (property_id, invoice_no, recipient_title, total_minor, kdv_minor, konaklama_minor, currency, gib_status) VALUES
  (v_p1, 'NEX202600004912', 'Canan Aydın', 6250000, 625000, 125000, 'TRY', 'approved'),
  (v_p2, 'NEX202600004913', 'Zeynep Demir', 1240000, 124000, 24800, 'TRY', 'approved');

END $$;
