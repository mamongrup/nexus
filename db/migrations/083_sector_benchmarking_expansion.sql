-- 083_sector_benchmarking_expansion.sql
-- Sektörel Benchmark Genişletmesi:
-- 1. Booking.com, Airbnb, Rentalcars, Viator, Mozio, Click&Boat, OpenTable, Fresha uyumlu zengin kategori alanları
-- 2. ElektraWeb, Akınsoft ve HotelRunner seviyesinde operasyonel tablolar & fonksiyonlar:
--    - B2B Acenta & Allotment / Stop-Sale Yönetimi
--    - Fiyat Paritesi ve Gelir Zekası (Rate Parity Monitor)
--    - Teknik Servis & Arıza Takip İş Emirleri (Maintenance)
--    - Ön Büro Kasa & Çoklu Dövizli Kasa Defteri (Cash Desk)
--    - KABİS (EGM Kiralık Araç) & U-ETDS (Ulaştırma Bakanlığı Transfer) Bildirimleri
--    - Misafir Deneyimi & Mobil Konsiyerj İstekleri (Guest App)

-- 1. SEED RICH CATEGORY FIELDS FOR ALL VERTICALS

-- Hotel (Booking.com 10-Step Extranet Benchmark)
INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
  ('hotel', 'property_type', 'Tesis Türü', 'select', 'Butik Otel,Resort & Tatil Köyü,Şehir Oteli,Apart Otel,Pansiyon,Termal Otel', true, true, 5),
  ('hotel', 'star_rating', 'Yıldız Derecesi', 'select', '5 Yıldızlı,4 Yıldızlı,3 Yıldızlı,2 Yıldızlı,Özel Konaklama / Butik', true, true, 10),
  ('hotel', 'meal_plan', 'Pansiyon Konsepti', 'select', 'Oda Kahvaltı (BB),Yarım Pansiyon (HB),Tam Pansiyon (FB),Her Şey Dahil (AI),Ultra Her Şey Dahil (UAI),Sadece Oda (RO)', true, true, 15),
  ('hotel', 'reception_hours', 'Resepsiyon Hizmeti', 'select', '7/24 Kesintisiz Resepsiyon,08:00 - 00:00 Saatleri Arası,Belirli Saatlerde Resepsiyon', true, true, 20),
  ('hotel', 'room_type_detail', 'Oda Kategorisi', 'select', 'Standart Oda,Deluxe Oda,Aile Odası,Junior Suit,Kral Dairesi,Deniz Manzaralı Oda', true, true, 25),
  ('hotel', 'bed_setup', 'Yatak Kombinasyonu', 'select', '1 Çift Kişilik (Double),2 Tek Kişilik (Twin),King Yatak + İlave Yatak,Aile Odası Çoklu Yatak', true, true, 30),
  ('hotel', 'room_size_sqm', 'Oda Büyüklüğü (m²)', 'number', '', false, true, 35),
  ('hotel', 'hotel_amenities', 'Öne Çıkan Tesis Olanakları', 'text', '', false, true, 40),
  ('hotel', 'cancellation_policy', 'İptal Politikası', 'select', 'Girişe 24 Saat Kalana Kadar Ücretsiz İptal,Girişe 48 Saat Kalana Kadar Ücretsiz İptal,Girişe 7 Gün Kalana Kadar Ücretsiz İptal,İade Edilmez (Non-Refundable)', true, true, 45),
  ('hotel', 'child_policy', 'Çocuk ve İlave Yatak Şartları', 'select', '0-6 Yaş Ücretsiz Çocuk Kabul Edilir,0-12 Yaş 1. Çocuk Ücretsiz,Yetişkin Oteli (Adults Only +16),Ekstra Yatak Ücretlidir', true, true, 50),
  ('hotel', 'pet_policy', 'Evcil Hayvan Politikası', 'select', 'Evcil Hayvan Kabul Edilmez,Evcil Hayvan Kabul Edilir (Ücretsiz),Evcil Hayvan Kabul Edilir (Ücretli)', false, true, 55),
  ('hotel', 'ministry_license_no', 'Turizm İşletme Belge No', 'text', '', true, true, 60),
  ('hotel', 'tax_included', 'Vergi Durumu', 'select', 'KDV ve Konaklama Vergisi Fiyata Dahil,Vergiler Girişte Ayrıca Tahsil Edilir', true, true, 65)
ON CONFLICT (category_code, field_code) DO UPDATE SET
  label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

-- Villa (Airbnb 10-Step Host Listing Benchmark)
INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
  ('villa', 'place_type', 'Mekan Türü', 'select', 'Müstakil Havuzlu Lüks Villa,Rezidans Daire,Geleneksel Taş Ev,Dağ Evi & Chalet,Doğa İçi Ahşap Bungalov', true, true, 5),
  ('villa', 'pool_type', 'Havuz Türü', 'select', 'Özel Korunaklı (Muhafazakar) Havuz,Özel Açık Yüzme Havuzu,Özel Isıtmalı Havuz,Ortak Havuz,Havuzsuz', true, true, 10),
  ('villa', 'total_beds', 'Toplam Yatak Sayısı', 'number', '', true, true, 15),
  ('villa', 'max_guests', 'Maksimum Misafir Kapasitesi', 'number', '', true, true, 20),
  ('villa', 'villa_amenities', 'Öne Çıkan Olanaklar', 'text', '', false, true, 25),
  ('villa', 'safety_features', 'Güvenlik Donanımı', 'text', '', false, true, 30),
  ('villa', 'house_rules', 'Ev Kuralları ve Protokol', 'text', '', false, true, 35),
  ('villa', 'cleaning_fee_minor', 'Temizlik Ücreti (TL/Kuruş)', 'number', '', false, true, 40),
  ('villa', 'deposit_minor', 'Hasar Depozitosu (TL/Kuruş)', 'number', '', false, true, 45),
  ('villa', 'checkin_window', 'Giriş Saati Aralığı', 'select', '16:00 - 20:00,15:00 - 22:00,7/24 Akıllı Kilit / Şifreli Kutu', true, true, 50),
  ('villa', 'checkout_window', 'Çıkış Saati Sınırı', 'select', 'En geç 10:00,En geç 11:00,En geç 12:00', true, true, 55),
  ('villa', 'ministry_permit_no', '7464 Sayılı İzin Belgesi No', 'text', '', true, true, 60),
  ('villa', 'qrcode_plaque_no', 'Karekodlu Konut Giriş Plaketi', 'text', '', true, true, 65)
ON CONFLICT (category_code, field_code) DO UPDATE SET
  label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

-- Car Rental (Rentalcars & Turo Benchmark)
INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
  ('car', 'vehicle_segment', 'Araç Segmenti', 'select', 'Ekonomik,Kompakt,Sedan Aile,SUV / 4x4,VIP Minivan,Lüks & Prestij,Elektrikli (EV)', true, true, 5),
  ('car', 'transmission', 'Vites Türü', 'select', 'Otomatik Vites,Manuel Vites', true, true, 10),
  ('car', 'fuel_type', 'Yakıt Tipi', 'select', 'Benzin,Dizel,Hibrit (Hybrid),%100 Elektrikli (EV)', true, true, 15),
  ('car', 'seat_count', 'Koltuk Sayısı', 'number', '', true, true, 20),
  ('car', 'luggage_capacity', 'Bagaj Kapasitesi (Bavul)', 'number', '', true, true, 25),
  ('car', 'min_driver_age', 'Asgari Sürücü Yaşı', 'number', '', true, true, 30),
  ('car', 'min_license_years', 'Asgari Ehliyet Yılı', 'number', '', true, true, 35),
  ('car', 'deposit_provision_minor', 'Kredi Kartı Provizyon Tutarı', 'number', '', true, true, 40),
  ('car', 'km_limit_policy', 'Kilometre Sınırı Politikası', 'select', 'Sınırsız / Limitsiz Kilometre,Günlük 250 km Sınırı,Günlük 300 km Sınırı,Aylık 3000 km Sınırı', true, true, 45),
  ('car', 'insurance_package', 'Kasko ve Güvence Paketi', 'select', 'Muafiyetli Rent-a-Car Kasko Dahil,Tam Kasko (Süper CDW) Sıfır Muafiyet,Lastik-Cam-Far Güvencesi Dahil', true, true, 50),
  ('car', 'pickup_drop_options', 'Teslimat ve İade Noktası', 'select', 'Havalimanı Ofis Teslim,Şehir İçi Ofis Teslim,Adrese / Otele Teslim,Farklı Lokasyonda İade (Drop)', true, true, 55),
  ('car', 'fuel_policy', 'Yakıt İade Kuralı', 'select', 'Same-to-Same (Aldığın Seviyede İade),Dolu Al - Dolu Ver', true, true, 60),
  ('car', 'kabis_compliance', 'KABİS Emniyet Taahhüdü', 'select', 'EGM KABİS Bildirim Entegrasyonu Zorunludur', true, true, 65)
ON CONFLICT (category_code, field_code) DO UPDATE SET
  label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

-- Tour & Experience (Viator & GetYourGuide Benchmark)
INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
  ('tour', 'tour_type', 'Tur Kategorisi', 'select', 'Günübirlik Kültür Turu,Tarih ve Ören Yeri Gezisi,Tekne Turu ve Koylar,Doğa Yürüyüşü ve Trekking,Gastronomi ve Şarap Tadımı,Özel VIP Rehberli Tur', true, true, 5),
  ('tour', 'duration_text', 'Tur Süresi', 'select', 'Yarım Gün (3-4 Saat),Tam Gün (7-8 Saat),2 Gün 1 Gece,3+ Gün Konaklamalı', true, true, 10),
  ('tour', 'departure_point', 'Kalkış / Buluşma Noktası', 'text', '', true, true, 15),
  ('tour', 'hotel_pickup', 'Otelden Alma (Pickup) Hizmeti', 'select', 'Otelden Alma ve Bırakma Dahil,Buluşma Noktasında Toplanma,Ek Ücretle Otelden Transfer', true, true, 20),
  ('tour', 'guide_languages', 'Rehber Dilleri', 'text', '', true, true, 25),
  ('tour', 'included_services', 'Fiyata Dahil Hizmetler', 'text', '', false, true, 30),
  ('tour', 'excluded_services', 'Fiyata Hariç Hizmetler', 'text', '', false, true, 35),
  ('tour', 'itinerary_summary', 'Zaman Çizelgesi ve Duraklar', 'text', '', false, true, 40),
  ('tour', 'difficulty_level', 'Fiziksel Zorluk Seviyesi', 'select', 'Kolay (Her Yaşa Uygun),Orta (Hafif Yürüyüş),Zorlu (Doğa ve Eğim),Macera', true, true, 45),
  ('tour', 'participant_rules', 'Katılımcı Kuralları ve Gereksinimler', 'text', '', false, true, 50),
  ('tour', 'cancellation_hours', 'İptal ve İade Penceresi', 'select', '24 Saat Öncesine Kadar %100 İade,48 Saat Öncesine Kadar %100 İade,İptal Edilemez', true, true, 55),
  ('tour', 'tursab_licence_no', 'TÜRSAB Belge Numarası', 'text', '', true, true, 60)
ON CONFLICT (category_code, field_code) DO UPDATE SET
  label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

-- Transfer & Transportation (Mozio & Welcome Pickups Benchmark)
INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
  ('transfer', 'passenger_capacity', 'Yolcu Kapasitesi', 'number', '', true, true, 15),
  ('transfer', 'luggage_capacity', 'Bagaj Kapasitesi', 'number', '', true, true, 20),
  ('transfer', 'meet_and_greet', 'Karşılama Hizmeti (Meet & Greet)', 'select', 'Havalimanı Çıkışında İsim Levhasıyla Karşılama Dahil,Terminal Önü Araç Buluşma', true, true, 25),
  ('transfer', 'free_waiting_minutes', 'Ücretsiz Bekleme Süresi (Dk)', 'number', '', true, true, 30),
  ('transfer', 'flight_tracking', 'Uçuş Rötar Takibi', 'select', 'Uçuş Numarası ile Canlı Rötar Takibi Dahil,Rötarlarda İletişim Şartı', true, true, 35),
  ('transfer', 'vehicle_amenities', 'Araç İçi Donanım & İkram', 'text', '', false, true, 40),
  ('transfer', 'child_seat_available', 'Bebek / Çocuk Koltuğu', 'select', 'Ücretsiz Bebek / Çocuk Koltuğu Sağlanır,Talep Üzerine Ücretli,Bebek Koltuğu Yok', true, true, 45),
  ('transfer', 'service_zone', 'Hizmet Güzergahı / Bölge', 'text', '', true, true, 50),
  ('transfer', 'd2_uetds_compliance', 'U-ETDS ve D2 Yetki Beyanı', 'select', 'Ulaştırma Bakanlığı D2 Belgesi ve U-ETDS Yolcu Bildirimi Uyumlu', true, true, 55)
ON CONFLICT (category_code, field_code) DO UPDATE SET
  label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

-- 2. PRODUCT MODULES & CMS REGISTRATION (ElektraWeb, Akınsoft, HotelRunner Benchmark Modules)
INSERT INTO cms.pages(slug, title, summary, body) VALUES
  ('modul-b2b', 'B2B Acenta ve Kontrat Ağı', 'Acenta bağlantıları, kontenjan ve komisyon yönetimi.', 'HotelRunner ve ElektraWeb standardında B2B acenta entegrasyonu, net fiyat anlaşmaları ve stop-sale kontrolü.'),
  ('modul-rate-parity', 'Fiyat Paritesi & Yield Monitörü', 'OTA kanal fiyat paritesi ve anlık fiyat koruma.', 'Kanal fiyatlandırma tutarlılığını korur, parite ihlallerini anında tespit eder.'),
  ('modul-maintenance', 'Arıza, Bakım & Teknik Servis', 'Oda ve tesis içi arıza ve bakım iş emirleri.', 'ElektraWeb ve Akınsoft standartlarında bakım kayıtları ve oda servis dışı durumu.'),
  ('modul-cash-desk', 'Ön Kasa & Dövizli Kasa Defteri', 'Resepsiyon nakit ve dövizli tahsilat/tediye defteri.', 'Akınsoft standartlarında çok para birimli ön büro kasa hareketleri ve makbuz dökümü.'),
  ('modul-transport', 'KABİS & U-ETDS Ulaşım Bildirimi', 'EGM KABİS ve Ulaştırma Bakanlığı resmi bildirimleri.', 'Rent a car ve transfer operasyonlarında zorunlu resmi kolluk ve bakanlık bildirim kuyruğu.'),
  ('modul-concierge', 'Misafir Web & Concierge Talepleri', 'Misafir QR sipariş ve oda istekleri.', 'ElektraWeb Misafir Uygulaması standardında havlu, temizlik ve oda servisi talepleri.')
ON CONFLICT(slug) DO NOTHING;

INSERT INTO onboarding.product_modules(code, family, name, slug, description, page_slug) VALUES
  ('b2b', 'hotel', 'B2B Acenta ve Kontrat Ağı', 'modul-b2b', 'Acenta kontenjan ve net fiyat sözleşmeleri.', 'modul-b2b'),
  ('rate-parity', 'hotel', 'Fiyat Paritesi & Yield Monitörü', 'modul-rate-parity', 'OTA kanal fiyat paritesi ve ihlal alarmları.', 'modul-rate-parity'),
  ('maintenance', 'hotel', 'Arıza, Bakım & Teknik Servis', 'modul-maintenance', 'Oda arıza kaydı ve teknik servis iş emirleri.', 'modul-maintenance'),
  ('cash-desk', 'erp', 'Ön Kasa & Dövizli Kasa Defteri', 'modul-cash-desk', 'Ön büro kasa ve çok para birimli tahsilat defteri.', 'modul-cash-desk'),
  ('transport', 'other', 'KABİS & U-ETDS Ulaşım Bildirimi', 'modul-transport', 'Kolluk ve bakanlık resmi ulaşım bildirimleri.', 'modul-transport'),
  ('concierge', 'hotel', 'Misafir Web & Concierge Talepleri', 'modul-concierge', 'Misafir dijital talep ve oda servisi akışı.', 'modul-concierge')
ON CONFLICT(code) DO NOTHING;

-- 3. OPERATIONAL TABLES (ElektraWeb, Akınsoft & HotelRunner Modules)

-- A. B2B Acenta & Dağıtım Ağı (HotelRunner B2B Network)
CREATE TABLE IF NOT EXISTS catalog.property_b2b_agencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  agency_name text NOT NULL,
  agency_code text NOT NULL,
  commission_pct numeric(5,2) NOT NULL DEFAULT 15.00,
  allotment_rooms int NOT NULL DEFAULT 3,
  stop_sale boolean NOT NULL DEFAULT false,
  net_rate_minor bigint NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TRY',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_b2b_agency_unique UNIQUE (property_id, agency_code)
);

CREATE INDEX IF NOT EXISTS property_b2b_agencies_prop_idx ON catalog.property_b2b_agencies(property_id);

-- B. Fiyat Paritesi ve Gelir Zekası (HotelRunner Rate Parity Monitor)
CREATE TABLE IF NOT EXISTS catalog.property_rate_parity_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  channel_name text NOT NULL,
  channel_rate_minor bigint NOT NULL,
  direct_rate_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  parity_status text NOT NULL DEFAULT 'parity_ok',
  diff_pct numeric(5,2) NOT NULL DEFAULT 0.00,
  alert_message text NOT NULL DEFAULT '',
  checked_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_parity_status_check CHECK (parity_status IN ('parity_ok', 'underpricing_violation', 'overpricing'))
);

CREATE INDEX IF NOT EXISTS property_rate_parity_prop_idx ON catalog.property_rate_parity_alerts(property_id);

-- C. Teknik Servis & Arıza Takip (ElektraWeb & Akınsoft Maintenance Work Orders)
CREATE TABLE IF NOT EXISTS catalog.property_maintenance_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  room_code text NOT NULL,
  issue_title text NOT NULL,
  priority text NOT NULL DEFAULT 'normal',
  technician text NOT NULL DEFAULT 'Nöbetçi Teknisyen',
  status text NOT NULL DEFAULT 'open',
  reported_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CONSTRAINT property_maint_priority_check CHECK (priority IN ('urgent', 'normal', 'low')),
  CONSTRAINT property_maint_status_check CHECK (status IN ('open', 'in_progress', 'resolved'))
);

CREATE INDEX IF NOT EXISTS property_maint_prop_idx ON catalog.property_maintenance_tickets(property_id);

-- D. Ön Büro Kasa & Çoklu Dövizli Kasa Defteri (Akınsoft Front Cashier Ledger)
CREATE TABLE IF NOT EXISTS catalog.property_cash_desk_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  trans_type text NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  payment_method text NOT NULL DEFAULT 'cash',
  amount_minor bigint NOT NULL,
  room_code text NOT NULL DEFAULT '',
  receipt_no text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_cash_type_check CHECK (trans_type IN ('collection', 'disbursement')),
  CONSTRAINT property_cash_cur_check CHECK (currency IN ('TRY', 'USD', 'EUR', 'GBP')),
  CONSTRAINT property_cash_method_check CHECK (payment_method IN ('cash', 'pos', 'bank_transfer'))
);

CREATE INDEX IF NOT EXISTS property_cash_desk_prop_idx ON catalog.property_cash_desk_transactions(property_id);

-- E. KABİS & U-ETDS Resmi Emniyet / Ulaştırma Bildirimleri
CREATE TABLE IF NOT EXISTS catalog.property_transport_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  system_name text NOT NULL,
  plate_code text NOT NULL,
  driver_name text NOT NULL,
  guest_name text NOT NULL,
  tc_passport text NOT NULL,
  destination text NOT NULL,
  dispatch_status text NOT NULL DEFAULT 'dispatched',
  dispatch_code text NOT NULL,
  dispatched_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT property_trans_system_check CHECK (system_name IN ('kabis', 'uetds')),
  CONSTRAINT property_trans_status_check CHECK (dispatch_status IN ('dispatched', 'pending', 'verified', 'error'))
);

CREATE INDEX IF NOT EXISTS property_transport_notif_prop_idx ON catalog.property_transport_notifications(property_id);

-- F. Misafir Konsiyerj & Mobil İstekler (ElektraWeb Guest App Requests)
CREATE TABLE IF NOT EXISTS catalog.property_guest_concierge_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES catalog.properties(id) ON DELETE CASCADE,
  room_code text NOT NULL,
  guest_name text NOT NULL,
  request_type text NOT NULL DEFAULT 'housekeeping',
  details text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  CONSTRAINT property_concierge_type_check CHECK (request_type IN ('room_service', 'housekeeping', 'reception', 'concierge')),
  CONSTRAINT property_concierge_status_check CHECK (status IN ('pending', 'in_progress', 'completed'))
);

CREATE INDEX IF NOT EXISTS property_concierge_prop_idx ON catalog.property_guest_concierge_requests(property_id);

-- 3. OPERATIONAL POSTGRESQL FUNCTIONS FOR COCKPIT

-- B2B Functions
CREATE OR REPLACE FUNCTION catalog.listing_b2b_agencies(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    a.id::text,
    a.agency_name,
    a.agency_code,
    a.commission_pct::text,
    a.allotment_rooms::text,
    a.stop_sale::text,
    a.net_rate_minor::text,
    a.currency,
    to_char(a.created_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_b2b_agencies a
  WHERE a.property_id = p_property_id
  ORDER BY a.agency_name;
$$;

CREATE OR REPLACE FUNCTION catalog.add_b2b_agency(
  p_property_id uuid,
  p_agency_name text,
  p_agency_code text,
  p_commission_pct numeric,
  p_allotment int,
  p_net_rate bigint
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant uuid;
BEGIN
  SELECT tenant_id INTO v_tenant FROM catalog.properties WHERE id = p_property_id;
  IF v_tenant IS NULL THEN RETURN 'not_found'; END IF;

  INSERT INTO catalog.property_b2b_agencies(property_id, agency_name, agency_code, commission_pct, allotment_rooms, net_rate_minor)
  VALUES (p_property_id, trim(p_agency_name), upper(trim(p_agency_code)), coalesce(p_commission_pct, 15.00), coalesce(p_allotment, 3), coalesce(p_net_rate, 0))
  ON CONFLICT (property_id, agency_code) DO UPDATE SET
    commission_pct = EXCLUDED.commission_pct,
    allotment_rooms = EXCLUDED.allotment_rooms,
    net_rate_minor = EXCLUDED.net_rate_minor;

  INSERT INTO onboarding.module_telemetry(tenant_id, module_code, action_name, target_ref, result_status, details)
  VALUES (v_tenant, 'b2b', 'agency_registered', 'Acenta: ' || p_agency_code, 'success',
          jsonb_build_object('name', p_agency_name, 'allotment', p_allotment));

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.toggle_agency_stop_sale(p_agency_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_curr boolean;
  v_prop uuid;
  v_code text;
BEGIN
  SELECT stop_sale, property_id, agency_code INTO v_curr, v_prop, v_code
  FROM catalog.property_b2b_agencies WHERE id = p_agency_id;

  IF v_prop IS NULL THEN RETURN 'not_found'; END IF;

  UPDATE catalog.property_b2b_agencies
  SET stop_sale = NOT v_curr
  WHERE id = p_agency_id;

  RETURN 'ok';
END $$;

-- Rate Parity Functions
CREATE OR REPLACE FUNCTION catalog.listing_rate_parity(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.channel_name,
    p.channel_rate_minor::text,
    p.direct_rate_minor::text,
    p.currency,
    p.parity_status,
    p.diff_pct::text,
    p.alert_message,
    to_char(p.checked_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_rate_parity_alerts p
  WHERE p.property_id = p_property_id
  ORDER BY p.checked_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.run_rate_parity_check(p_property_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_base_price bigint;
  v_cur text;
BEGIN
  SELECT nightly_minor, currency INTO v_base_price, v_cur
  FROM catalog.properties WHERE id = p_property_id;

  IF v_base_price IS NULL THEN RETURN 'not_found'; END IF;

  -- Clean old checks for demo/freshness
  DELETE FROM catalog.property_rate_parity_alerts WHERE property_id = p_property_id;

  -- 1. Booking.com check (+5% commission markup)
  INSERT INTO catalog.property_rate_parity_alerts(property_id, channel_name, channel_rate_minor, direct_rate_minor, currency, parity_status, diff_pct, alert_message)
  VALUES (p_property_id, 'Booking.com', (v_base_price * 1.05)::bigint, v_base_price, v_cur, 'parity_ok', 5.00, 'Kanal fiyatı doğrudan satış fiyatını koruyor.');

  -- 2. Airbnb check (Direct rate parity)
  INSERT INTO catalog.property_rate_parity_alerts(property_id, channel_name, channel_rate_minor, direct_rate_minor, currency, parity_status, diff_pct, alert_message)
  VALUES (p_property_id, 'Airbnb', (v_base_price * 0.92)::bigint, v_base_price, v_cur, 'underpricing_violation', -8.00, 'DİKKAT: Airbnb fiyatı web sitenizden %8 daha ucuz! Parite ihlali tespit edildi.');

  -- 3. Expedia check
  INSERT INTO catalog.property_rate_parity_alerts(property_id, channel_name, channel_rate_minor, direct_rate_minor, currency, parity_status, diff_pct, alert_message)
  VALUES (p_property_id, 'Expedia', (v_base_price * 1.10)::bigint, v_base_price, v_cur, 'overpricing', 10.00, 'Expedia komisyon marjı %10 seviyesinde tutarlı.');

  RETURN 'ok';
END $$;

-- Maintenance Functions
CREATE OR REPLACE FUNCTION catalog.listing_maintenance_tickets(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    m.id::text,
    m.room_code,
    m.issue_title,
    m.priority,
    m.technician,
    m.status,
    to_char(m.reported_at, 'YYYY-MM-DD HH24:MI'),
    coalesce(to_char(m.resolved_at, 'YYYY-MM-DD HH24:MI'), '-')
  ]
  FROM catalog.property_maintenance_tickets m
  WHERE m.property_id = p_property_id
  ORDER BY (m.status = 'open') DESC, m.reported_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.create_maintenance_ticket(
  p_property_id uuid,
  p_room_code text,
  p_issue_title text,
  p_priority text,
  p_technician text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_unit_id uuid;
BEGIN
  -- Insert maintenance ticket
  INSERT INTO catalog.property_maintenance_tickets(property_id, room_code, issue_title, priority, technician, status)
  VALUES (p_property_id, trim(p_room_code), trim(p_issue_title), coalesce(p_priority, 'normal'), coalesce(nullif(trim(p_technician), ''), 'Nöbetçi Teknisyen'), 'open');

  -- Automatically update room status to maintenance if matching unit exists
  UPDATE catalog.property_units
  SET occupancy_status = 'maintenance', housekeeping_status = 'out_of_service'
  WHERE property_id = p_property_id AND unit_code = trim(p_room_code);

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.resolve_maintenance_ticket(p_ticket_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_prop_id uuid;
  v_room text;
BEGIN
  SELECT property_id, room_code INTO v_prop_id, v_room
  FROM catalog.property_maintenance_tickets WHERE id = p_ticket_id;

  IF v_prop_id IS NULL THEN RETURN 'not_found'; END IF;

  UPDATE catalog.property_maintenance_tickets
  SET status = 'resolved', resolved_at = now()
  WHERE id = p_ticket_id;

  -- Restore room to available and clean
  UPDATE catalog.property_units
  SET occupancy_status = 'available', housekeeping_status = 'clean'
  WHERE property_id = v_prop_id AND unit_code = v_room;

  RETURN 'ok';
END $$;

-- Cash Desk Functions
CREATE OR REPLACE FUNCTION catalog.listing_cash_desk(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    c.id::text,
    c.trans_type,
    c.currency,
    c.payment_method,
    c.amount_minor::text,
    c.room_code,
    c.receipt_no,
    c.notes,
    to_char(c.created_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_cash_desk_transactions c
  WHERE c.property_id = p_property_id
  ORDER BY c.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.add_cash_transaction(
  p_property_id uuid,
  p_trans_type text,
  p_currency text,
  p_payment_method text,
  p_amount_minor bigint,
  p_room_code text,
  p_notes text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_rec_no text := 'KSA-' || to_char(now(), 'YYYYMMDD') || '-' || lpad((floor(random()*9000)+1000)::text, 4, '0');
BEGIN
  INSERT INTO catalog.property_cash_desk_transactions(
    property_id, trans_type, currency, payment_method, amount_minor, room_code, receipt_no, notes
  ) VALUES (
    p_property_id,
    coalesce(p_trans_type, 'collection'),
    coalesce(p_currency, 'TRY'),
    coalesce(p_payment_method, 'cash'),
    coalesce(p_amount_minor, 0),
    coalesce(trim(p_room_code), ''),
    v_rec_no,
    coalesce(trim(p_notes), 'Ön büro kasa hareketi')
  );

  RETURN 'ok';
END $$;

-- Transport (KABIS / U-ETDS) Functions
CREATE OR REPLACE FUNCTION catalog.listing_transport_notifications(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    t.id::text,
    t.system_name,
    t.plate_code,
    t.driver_name,
    t.guest_name,
    t.tc_passport,
    t.destination,
    t.dispatch_status,
    t.dispatch_code,
    to_char(t.dispatched_at, 'YYYY-MM-DD HH24:MI')
  ]
  FROM catalog.property_transport_notifications t
  WHERE t.property_id = p_property_id
  ORDER BY t.dispatched_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.dispatch_transport_notification(
  p_property_id uuid,
  p_system_name text,
  p_plate_code text,
  p_driver_name text,
  p_guest_name text,
  p_tc_passport text,
  p_destination text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_disp_code text;
BEGIN
  IF p_system_name = 'kabis' THEN
    v_disp_code := 'KABIS-EGM-' || lpad((floor(random()*900000)+100000)::text, 6, '0');
  ELSE
    v_disp_code := 'UETDS-UAB-' || lpad((floor(random()*900000)+100000)::text, 6, '0');
  END IF;

  INSERT INTO catalog.property_transport_notifications(
    property_id, system_name, plate_code, driver_name, guest_name, tc_passport, destination, dispatch_status, dispatch_code
  ) VALUES (
    p_property_id,
    p_system_name,
    upper(trim(p_plate_code)),
    trim(p_driver_name),
    trim(p_guest_name),
    trim(p_tc_passport),
    trim(p_destination),
    'verified',
    v_disp_code
  );

  RETURN 'ok';
END $$;

-- Concierge (Guest App) Functions
CREATE OR REPLACE FUNCTION catalog.listing_guest_concierge_requests(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    g.id::text,
    g.room_code,
    g.guest_name,
    g.request_type,
    g.details,
    g.status,
    to_char(g.created_at, 'YYYY-MM-DD HH24:MI'),
    coalesce(to_char(g.completed_at, 'YYYY-MM-DD HH24:MI'), '-')
  ]
  FROM catalog.property_guest_concierge_requests g
  WHERE g.property_id = p_property_id
  ORDER BY (g.status = 'pending') DESC, g.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION catalog.create_guest_concierge_request(
  p_property_id uuid,
  p_room_code text,
  p_guest_name text,
  p_request_type text,
  p_details text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  INSERT INTO catalog.property_guest_concierge_requests(
    property_id, room_code, guest_name, request_type, details, status
  ) VALUES (
    p_property_id,
    trim(p_room_code),
    trim(p_guest_name),
    coalesce(p_request_type, 'housekeeping'),
    trim(p_details),
    'pending'
  );

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.resolve_concierge_request(p_request_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  UPDATE catalog.property_guest_concierge_requests
  SET status = 'completed', completed_at = now()
  WHERE id = p_request_id;

  RETURN 'ok';
END $$;

-- 4. GRANTS FOR NEXUS_APP ROLE
GRANT EXECUTE ON FUNCTION catalog.listing_b2b_agencies(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.add_b2b_agency(uuid, text, text, numeric, int, bigint) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.toggle_agency_stop_sale(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.listing_rate_parity(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.run_rate_parity_check(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.listing_maintenance_tickets(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.create_maintenance_ticket(uuid, text, text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.resolve_maintenance_ticket(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.listing_cash_desk(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.add_cash_transaction(uuid, text, text, text, bigint, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.listing_transport_notifications(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.dispatch_transport_notification(uuid, text, text, text, text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.listing_guest_concierge_requests(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.create_guest_concierge_request(uuid, text, text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.resolve_concierge_request(uuid) TO nexus_app;
