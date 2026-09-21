-- 092_advanced_industry_ecosystem_integrations.sql
-- Entegre Edilen 20 Sektörel Platform & Lider Ekosistem Modülleri

CREATE SCHEMA IF NOT EXISTS crm;
CREATE SCHEMA IF NOT EXISTS revenue;
CREATE SCHEMA IF NOT EXISTS tours;
CREATE SCHEMA IF NOT EXISTS fleet;
CREATE SCHEMA IF NOT EXISTS invoicing;

-- ─── 1. IRI CRM & Commoware & Convertel: Misafir CRM & WhatsApp Otomasyonu ────
CREATE TABLE IF NOT EXISTS crm.guest_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  full_name text NOT NULL,
  email text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  nationality text NOT NULL DEFAULT 'TR',
  total_stays int NOT NULL DEFAULT 1,
  total_spend_minor bigint NOT NULL DEFAULT 0,
  vip_tier text NOT NULL DEFAULT 'standard' CHECK (vip_tier IN ('standard', 'silver', 'gold', 'vip', 'platinum')),
  preferences text NOT NULL DEFAULT '',
  tags text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_guest_tenant ON crm.guest_profiles(tenant_id, full_name);

CREATE TABLE IF NOT EXISTS crm.whatsapp_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  guest_name text NOT NULL,
  phone text NOT NULL,
  msg_type text NOT NULL CHECK (msg_type IN ('pre_arrival', 'in_house', 'post_departure', 'promo', 'custom')),
  message text NOT NULL,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('queued', 'sent', 'delivered', 'read', 'failed')),
  sent_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_wa_tenant ON crm.whatsapp_messages(tenant_id, sent_at DESC);

-- ─── 2. Pricing Coach & Exely & Orphex.ai: Rakip Fiyat Takibi & AI Yield ─────
CREATE TABLE IF NOT EXISTS revenue.competitor_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  competitor_name text NOT NULL,
  star_rating int NOT NULL DEFAULT 4,
  room_type text NOT NULL DEFAULT 'Standart Oda',
  channel text NOT NULL DEFAULT 'Booking.com',
  competitor_price_minor bigint NOT NULL,
  our_price_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  check_in_date date NOT NULL DEFAULT current_date,
  ai_recommendation text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_revenue_comp_tenant ON revenue.competitor_rates(tenant_id, recorded_at DESC);

-- ─── 3. Acente2 & AcentaOS & Ezey: Tur Operatörü & Dinamik Paketleme ────────
CREATE TABLE IF NOT EXISTS tours.activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  title text NOT NULL,
  location text NOT NULL,
  category text NOT NULL CHECK (category IN ('balloon', 'boat', 'safari', 'cultural', 'transfer', 'other')),
  duration_hours int NOT NULL DEFAULT 3,
  net_price_minor bigint NOT NULL,
  sale_price_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'EUR',
  capacity_daily int NOT NULL DEFAULT 20,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tours_act_tenant ON tours.activities(tenant_id, category);

CREATE TABLE IF NOT EXISTS tours.packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  package_code text NOT NULL,
  guest_name text NOT NULL,
  hotel_name text NOT NULL,
  activity_name text NOT NULL,
  transfer_included boolean NOT NULL DEFAULT true,
  total_price_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'EUR',
  status text NOT NULL DEFAULT 'confirmed' CHECK (status IN ('draft', 'confirmed', 'vouchered', 'completed', 'cancelled')),
  voucher_no text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tours_pkg_tenant ON tours.packages(tenant_id, created_at DESC);

-- ─── 4. RentSyst: Araç Filo Yönetimi & Dijital Sözleşme ──────────────────────
CREATE TABLE IF NOT EXISTS fleet.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  plate_no text NOT NULL,
  brand text NOT NULL,
  model text NOT NULL,
  model_year int NOT NULL,
  transmission text NOT NULL CHECK (transmission IN ('automatic', 'manual')),
  fuel_type text NOT NULL CHECK (fuel_type IN ('diesel', 'gasoline', 'hybrid', 'electric')),
  current_km int NOT NULL DEFAULT 0,
  daily_rate_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'rented', 'maintenance', 'out_of_service')),
  kabis_registered boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fleet_plate ON fleet.vehicles(tenant_id, plate_no);

CREATE TABLE IF NOT EXISTS fleet.rentals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  agreement_no text NOT NULL,
  vehicle_plate text NOT NULL,
  driver_name text NOT NULL,
  driver_tc_passport text NOT NULL,
  driver_phone text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  total_days int NOT NULL DEFAULT 1,
  total_amount_minor bigint NOT NULL,
  deposit_amount_minor bigint NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TRY',
  damage_notes text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'returned', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fleet_rent_tenant ON fleet.rentals(tenant_id, created_at DESC);

-- ─── 5. Uyumsoft: GİB e-Fatura, e-Arşiv & Konaklama Vergisi ──────────────────
CREATE TABLE IF NOT EXISTS invoicing.e_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  ettn uuid NOT NULL DEFAULT gen_random_uuid(),
  invoice_no text NOT NULL,
  invoice_type text NOT NULL CHECK (invoice_type IN ('e-Fatura', 'e-Arsiv', 'e-Irsaliye', 'e-SMM')),
  receiver_name text NOT NULL,
  receiver_vkn_tckn text NOT NULL,
  receiver_tax_office text NOT NULL DEFAULT '',
  net_amount_minor bigint NOT NULL,
  vat_amount_minor bigint NOT NULL,
  accommodation_tax_minor bigint NOT NULL DEFAULT 0,
  grand_total_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  gib_status text NOT NULL DEFAULT 'Kabul Edildi' CHECK (gib_status IN ('Kuyrukta', 'GIB''e Iletildi', 'Kabul Edildi', 'Reddedildi', 'Iptal')),
  gib_status_code int NOT NULL DEFAULT 1200,
  profile text NOT NULL DEFAULT 'TICARIFATURA' CHECK (profile IN ('TICARIFATURA', 'TEMELFATURA', 'EARSIVFATURA')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoicing_tenant ON invoicing.e_invoices(tenant_id, created_at DESC);

-- ─── 6. Chexta App & HMS: Misafir Mobil Online Check-In & Dijital İmza ───────
CREATE TABLE IF NOT EXISTS booking.online_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id text NOT NULL,
  guest_name text NOT NULL,
  tc_or_passport text NOT NULL,
  phone text NOT NULL,
  email text NOT NULL DEFAULT '',
  eta_time text NOT NULL DEFAULT '14:00',
  special_requests text NOT NULL DEFAULT '',
  signature_data text NOT NULL DEFAULT '',
  kvkk_accepted boolean NOT NULL DEFAULT true,
  door_pin_code text NOT NULL DEFAULT '',
  checked_in_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_online_checkin_res ON booking.online_checkins(reservation_id);

-- ─── 7. İzinler (Permissions) ────────────────────────────────────────────────
GRANT USAGE ON SCHEMA crm, revenue, tours, fleet, invoicing TO nexus_app;
GRANT ALL ON ALL TABLES IN SCHEMA crm, revenue, tours, fleet, invoicing TO nexus_app;
GRANT ALL ON ALL SEQUENCES IN SCHEMA crm, revenue, tours, fleet, invoicing TO nexus_app;
GRANT ALL ON TABLE booking.online_checkins TO nexus_app;

-- ─── 8. Başlangıç Tohum Verileri (Seed Data) ─────────────────────────────────
INSERT INTO tours.activities (tenant_id, title, location, category, duration_hours, net_price_minor, sale_price_minor, currency, capacity_daily)
VALUES
  ('33333333-3333-4333-8333-333333333333', 'Kapadokya Gün Doğumu Lüks Sıcak Hava Balon Turu', 'Göreme / Kapadokya', 'balloon', 3, 16000, 22000, 'EUR', 16),
  ('33333333-3333-4333-8333-333333333333', 'Göcek 12 Adalar Özel Gulet Yat Gezisi', 'Göcek / Fethiye', 'boat', 7, 35000, 50000, 'EUR', 12),
  ('33333333-3333-4333-8333-333333333333', 'Kapadokya Kırmızı Tur & Yeraltı Şehri Rehberli Gezi', 'Kapadokya', 'cultural', 6, 4500, 7500, 'EUR', 25)
ON CONFLICT DO NOTHING;

INSERT INTO fleet.vehicles (tenant_id, plate_no, brand, model, model_year, transmission, fuel_type, current_km, daily_rate_minor, currency, status, kabis_registered)
VALUES
  ('33333333-3333-4333-8333-333333333333', '34 NEX 777', 'Mercedes-Benz', 'E-Class AMG', 2024, 'automatic', 'hybrid', 14200, 450000, 'TRY', 'available', true),
  ('33333333-3333-4333-8333-333333333333', '07 VIL 888', 'BMW', 'X5 xDrive40i', 2024, 'automatic', 'gasoline', 8900, 650000, 'TRY', 'available', true)
ON CONFLICT DO NOTHING;

INSERT INTO crm.guest_profiles (tenant_id, full_name, email, phone, nationality, total_stays, total_spend_minor, vip_tier, preferences, tags)
VALUES
  ('33333333-3333-4333-8333-333333333333', 'Alperen Yılmaz', 'alperen@example.com', '+905321112233', 'TR', 4, 18500000, 'vip', 'Deniz manzaralı yüksek kat, ekstra havlu, glutensiz kahvaltı', ARRAY['Repeat Guest', 'High Spender', 'Direct Booker']),
  ('33333333-3333-4333-8333-333333333333', 'Michael Henderson', 'michael@uktravel.com', '+447911123456', 'GB', 2, 9200000, 'gold', 'Havalimanı VIP transferi talep ediyor, late check-out', ARRAY['UK Market', 'Luxury Villa'])
ON CONFLICT DO NOTHING;
