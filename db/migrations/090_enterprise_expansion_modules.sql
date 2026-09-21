-- 090_enterprise_expansion_modules.sql
-- Kurumsal Genişleme Modülleri:
-- 1. Muhasebe & Kasa/Banka (Gelir & Gider Yönetimi)
-- 2. Sosyal Medya Pazarlama & Gönderi Yönetimi
-- 3. Yapay Zeka (AI Hub) İçerik & Analiz Kayıtları
-- 4. İnsan Kaynakları, İşe Alım & Maaş Bordrosu
-- 5. Kat Hizmetleri (Housekeeping), Oda Takibi & Teknik Servis

-- ─── 1. Şemaların Oluşturulması ─────────────────────────
CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS marketing;
CREATE SCHEMA IF NOT EXISTS ai;
CREATE SCHEMA IF NOT EXISTS hr;

-- ─── 2. Muhasebe & Finans Tabloları ─────────────────────
CREATE TABLE IF NOT EXISTS accounting.categories (
  code text PRIMARY KEY,
  category_type text NOT NULL CHECK (category_type IN ('income', 'expense')),
  name text NOT NULL,
  icon text NOT NULL DEFAULT 'tag'
);

INSERT INTO accounting.categories (code, category_type, name, icon) VALUES
  ('room_revenue', 'income', 'Oda & Konaklama Geliri', 'bed'),
  ('pos_fnb', 'income', 'Restoran & Bar POS', 'coffee'),
  ('extra_services', 'income', 'Ekstra Hizmetler & Minibar', 'plus'),
  ('transfer_revenue', 'income', 'VIP Transfer & Ulaşım', 'car'),
  ('spa_wellness', 'income', 'Spa & Masaj Geliri', 'heart'),
  ('other_income', 'income', 'Diğer Gelirler', 'dollar-sign'),
  ('payroll', 'expense', 'Personel Maaş & Avans', 'users'),
  ('utilities', 'expense', 'Elektrik, Su, İnternet, Doğalgaz', 'zap'),
  ('fnb_supply', 'expense', 'Yiyecek & İçecek Tedariki', 'shopping-cart'),
  ('housekeeping_supply', 'expense', 'Temizlik & Sarf Malzeme', 'feather'),
  ('maintenance_repair', 'expense', 'Bakım, Onarım & Teknik', 'tool'),
  ('marketing_ads', 'expense', 'Pazarlama & Sosyal Medya Reklam', 'trending-up'),
  ('tax_legal', 'expense', 'Vergi, SGK & Resmi Harçlar', 'file-text'),
  ('commission_ota', 'expense', 'Kanal & Acente Komisyonları', 'percent'),
  ('other_expense', 'expense', 'Diğer Genel Giderler', 'more-horizontal')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, category_type = EXCLUDED.category_type;

CREATE TABLE IF NOT EXISTS accounting.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  tx_type text NOT NULL CHECK (tx_type IN ('income', 'expense')),
  category text NOT NULL REFERENCES accounting.categories(code),
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
  currency text NOT NULL DEFAULT 'TRY',
  payment_method text NOT NULL DEFAULT 'bank_transfer' CHECK (payment_method IN ('cash', 'bank_transfer', 'credit_card', 'pos', 'other')),
  invoice_no text NOT NULL DEFAULT '',
  receipt_url text NOT NULL DEFAULT '',
  tx_date date NOT NULL DEFAULT current_date,
  created_by text NOT NULL DEFAULT 'Yönetici',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_accounting_tenant_date ON accounting.transactions(tenant_id, tx_date DESC);

-- ─── 3. Sosyal Medya Modülü Tabloları ───────────────────
CREATE TABLE IF NOT EXISTS marketing.social_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  platform text NOT NULL CHECK (platform IN ('instagram', 'facebook', 'tiktok', 'x', 'google_business')),
  account_handle text NOT NULL,
  profile_url text NOT NULL DEFAULT '',
  is_connected boolean NOT NULL DEFAULT true,
  followers_count int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketing_tenant_platform ON marketing.social_accounts(tenant_id, platform);

CREATE TABLE IF NOT EXISTS marketing.social_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  platform text NOT NULL,
  title text NOT NULL,
  caption text NOT NULL,
  media_url text NOT NULL DEFAULT '',
  link_url text NOT NULL DEFAULT '',
  property_id uuid,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'scheduled', 'published')),
  scheduled_for timestamptz,
  published_at timestamptz DEFAULT now(),
  likes_count int NOT NULL DEFAULT 0,
  views_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketing_posts_tenant ON marketing.social_posts(tenant_id, created_at DESC);

-- ─── 4. Yapay Zeka (AI Hub) Kayıtları ───────────────────
CREATE TABLE IF NOT EXISTS ai.generations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  tool_name text NOT NULL,
  prompt_input text NOT NULL,
  generated_output text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_generations_tenant ON ai.generations(tenant_id, created_at DESC);

-- ─── 5. İnsan Kaynakları & Maaş Bordrosu ─────────────────
CREATE TABLE IF NOT EXISTS hr.employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  full_name text NOT NULL,
  national_id text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  department text NOT NULL DEFAULT 'Ön Büro',
  position_title text NOT NULL DEFAULT 'Personel',
  salary_minor bigint NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TRY',
  iban text NOT NULL DEFAULT '',
  start_date date NOT NULL DEFAULT current_date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'on_leave', 'terminated')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hr_employees_tenant ON hr.employees(tenant_id, status);

CREATE TABLE IF NOT EXISTS hr.recruitment_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  candidate_name text NOT NULL,
  position_applied text NOT NULL,
  phone text NOT NULL,
  email text NOT NULL DEFAULT '',
  stage text NOT NULL DEFAULT 'applied' CHECK (stage IN ('applied', 'interview', 'offered', 'hired', 'rejected')),
  notes text NOT NULL DEFAULT '',
  interview_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hr_candidates_tenant ON hr.recruitment_candidates(tenant_id, stage);

CREATE TABLE IF NOT EXISTS hr.payroll_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  employee_id uuid NOT NULL REFERENCES hr.employees(id) ON DELETE CASCADE,
  payment_type text NOT NULL CHECK (payment_type IN ('salary', 'advance', 'bonus', 'overtime')),
  amount_minor bigint NOT NULL,
  currency text NOT NULL DEFAULT 'TRY',
  period_month int NOT NULL DEFAULT EXTRACT(MONTH FROM CURRENT_DATE),
  period_year int NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
  payment_date date NOT NULL DEFAULT current_date,
  status text NOT NULL DEFAULT 'paid' CHECK (status IN ('pending', 'paid')),
  reference_no text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hr_payroll_tenant ON hr.payroll_records(tenant_id, period_year, period_month);

-- ─── 6. Kat Hizmetleri & Oda Takibi ─────────────────────
CREATE TABLE IF NOT EXISTS catalog.housekeeping_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  property_id uuid,
  room_code text NOT NULL,
  assigned_staff text NOT NULL DEFAULT 'Kat Görevlisi',
  task_type text NOT NULL DEFAULT 'daily_clean' CHECK (task_type IN ('daily_clean', 'checkout_deep', 'inspection', 'turndown')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'inspected')),
  notes text NOT NULL DEFAULT '',
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_housekeeping_tenant_prop ON catalog.housekeeping_tasks(tenant_id, property_id);

CREATE TABLE IF NOT EXISTS catalog.room_maintenance_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  property_id uuid,
  room_code text NOT NULL,
  issue_title text NOT NULL,
  description text NOT NULL DEFAULT '',
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'urgent')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),
  reported_by text NOT NULL DEFAULT 'Kat Hizmetleri',
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_room_tickets_tenant_prop ON catalog.room_maintenance_tickets(tenant_id, property_id, status);

-- ─── 7. SQL Fonksiyonları & API Köprüleri ─────────────────

-- Muhasebe Özeti
CREATE OR REPLACE FUNCTION accounting.financial_summary()
RETURNS TABLE(
  total_income text,
  total_expense text,
  net_profit text,
  cash_balance text,
  bank_balance text,
  tx_count text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
  v_inc bigint := 0;
  v_exp bigint := 0;
  v_cash bigint := 0;
  v_bank bigint := 0;
  v_cnt bigint := 0;
BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN tx_type = 'income' THEN amount_minor ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN tx_type = 'expense' THEN amount_minor ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN (CASE WHEN tx_type = 'income' THEN amount_minor ELSE -amount_minor END) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN payment_method IN ('bank_transfer', 'credit_card', 'pos') THEN (CASE WHEN tx_type = 'income' THEN amount_minor ELSE -amount_minor END) ELSE 0 END), 0),
    COUNT(*)
  INTO v_inc, v_exp, v_cash, v_bank, v_cnt
  FROM accounting.transactions
  WHERE (v_tenant IS NULL OR tenant_id = v_tenant);

  RETURN QUERY SELECT
    v_inc::text,
    v_exp::text,
    (v_inc - v_exp)::text,
    v_cash::text,
    v_bank::text,
    v_cnt::text;
END $$;

-- Muhasebe İşlem Listesi
CREATE OR REPLACE FUNCTION accounting.list_transactions(p_limit int DEFAULT 50)
RETURNS TABLE(
  id text,
  tx_type text,
  category_name text,
  title text,
  amount text,
  currency text,
  payment_method text,
  invoice_no text,
  tx_date text,
  created_by text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    t.id::text,
    t.tx_type,
    c.name,
    t.title,
    t.amount_minor::text,
    t.currency,
    t.payment_method,
    t.invoice_no,
    to_char(t.tx_date, 'DD.MM.YYYY'),
    t.created_by
  FROM accounting.transactions t
  JOIN accounting.categories c ON c.code = t.category
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR t.tenant_id = current_setting('app.tenant_id', true)::uuid)
  ORDER BY t.tx_date DESC, t.created_at DESC
  LIMIT p_limit;
$$;

-- Sosyal Medya Gönderi Listesi
CREATE OR REPLACE FUNCTION marketing.list_posts(p_limit int DEFAULT 20)
RETURNS TABLE(
  id text,
  platform text,
  title text,
  caption text,
  media_url text,
  status text,
  likes_count text,
  views_count text,
  created_at text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    p.id::text,
    p.platform,
    p.title,
    p.caption,
    p.media_url,
    p.status,
    p.likes_count::text,
    p.views_count::text,
    to_char(p.created_at, 'DD.MM.YYYY HH24:MI')
  FROM marketing.social_posts p
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR p.tenant_id = current_setting('app.tenant_id', true)::uuid)
  ORDER BY p.created_at DESC
  LIMIT p_limit;
$$;

-- İK Personel Listesi
CREATE OR REPLACE FUNCTION hr.list_employees(p_limit int DEFAULT 50)
RETURNS TABLE(
  id text,
  full_name text,
  department text,
  position_title text,
  phone text,
  salary text,
  currency text,
  start_date text,
  status text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    e.id::text,
    e.full_name,
    e.department,
    e.position_title,
    e.phone,
    e.salary_minor::text,
    e.currency,
    to_char(e.start_date, 'DD.MM.YYYY'),
    e.status
  FROM hr.employees e
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR e.tenant_id = current_setting('app.tenant_id', true)::uuid)
  ORDER BY e.status ASC, e.full_name ASC
  LIMIT p_limit;
$$;

-- İK İşe Alım Aday Listesi
CREATE OR REPLACE FUNCTION hr.list_candidates(p_limit int DEFAULT 30)
RETURNS TABLE(
  id text,
  candidate_name text,
  position_applied text,
  phone text,
  stage text,
  interview_date text,
  notes text,
  created_at text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    c.id::text,
    c.candidate_name,
    c.position_applied,
    c.phone,
    c.stage,
    coalesce(to_char(c.interview_date, 'DD.MM.YYYY'), '-'),
    c.notes,
    to_char(c.created_at, 'DD.MM.YYYY')
  FROM hr.recruitment_candidates c
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR c.tenant_id = current_setting('app.tenant_id', true)::uuid)
  ORDER BY c.created_at DESC
  LIMIT p_limit;
$$;

-- İK Maaş & Bordro Listesi
CREATE OR REPLACE FUNCTION hr.list_payrolls(p_limit int DEFAULT 50)
RETURNS TABLE(
  id text,
  employee_name text,
  payment_type text,
  amount text,
  currency text,
  period text,
  payment_date text,
  status text,
  reference_no text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    p.id::text,
    e.full_name,
    p.payment_type,
    p.amount_minor::text,
    p.currency,
    p.period_month::text || '/' || p.period_year::text,
    to_char(p.payment_date, 'DD.MM.YYYY'),
    p.status,
    p.reference_no
  FROM hr.payroll_records p
  JOIN hr.employees e ON e.id = p.employee_id
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR p.tenant_id = current_setting('app.tenant_id', true)::uuid)
  ORDER BY p.payment_date DESC
  LIMIT p_limit;
$$;

-- Kat Hizmetleri Görev Listesi
CREATE OR REPLACE FUNCTION catalog.list_housekeeping_tasks(p_property_id uuid DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE(
  id text,
  room_code text,
  assigned_staff text,
  task_type text,
  status text,
  notes text,
  created_at text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    h.id::text,
    h.room_code,
    h.assigned_staff,
    h.task_type,
    h.status,
    h.notes,
    to_char(h.created_at, 'DD.MM.YYYY HH24:MI')
  FROM catalog.housekeeping_tasks h
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR h.tenant_id = current_setting('app.tenant_id', true)::uuid)
    AND (p_property_id IS NULL OR h.property_id = p_property_id)
  ORDER BY CASE h.status WHEN 'pending' THEN 1 WHEN 'in_progress' THEN 2 ELSE 3 END, h.created_at DESC
  LIMIT p_limit;
$$;

-- Oda Arıza / Teknik Servis Listesi
CREATE OR REPLACE FUNCTION catalog.list_maintenance_tickets(p_property_id uuid DEFAULT NULL, p_limit int DEFAULT 30)
RETURNS TABLE(
  id text,
  room_code text,
  issue_title text,
  description text,
  priority text,
  status text,
  reported_by text,
  created_at text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT
    m.id::text,
    m.room_code,
    m.issue_title,
    m.description,
    m.priority,
    m.status,
    m.reported_by,
    to_char(m.created_at, 'DD.MM.YYYY HH24:MI')
  FROM catalog.room_maintenance_tickets m
  WHERE (nullif(current_setting('app.tenant_id', true), '') IS NULL OR m.tenant_id = current_setting('app.tenant_id', true)::uuid)
    AND (p_property_id IS NULL OR m.property_id = p_property_id)
  ORDER BY CASE m.priority WHEN 'urgent' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, m.created_at DESC
  LIMIT p_limit;
$$;

-- ─── 8. Ürün Modülleri Kataloğu Kayıtları ─────────────────
INSERT INTO cms.pages (slug, title, summary, body) VALUES
  ('modul-accounting', 'Muhasebe & Kasa/Banka', 'Tüm gelir, gider, kasa ve banka hareketlerini yönetin.', 'Gelir gider takibi, kasa ve banka bakiyeleri, faturalar ve kâr/zarar tabloları.'),
  ('modul-social-media', 'Sosyal Medya Otomasyonu', 'İlan ve kampanyalarınızı sosyal medyada otomatik yayınlayın.', 'Instagram, TikTok, Facebook, X ve Google Business entegrasyonu.'),
  ('modul-ai-hub', 'Yapay Zeka Merkezi (AI Hub)', 'İlan metinleri, SEO başlıkları ve sosyal medya içerik üretimi.', 'Yapay zeka destekli metin, sosyal medya postu ve misafir yorum yanıtlayıcı.'),
  ('modul-hr', 'İnsan Kaynakları & Bordro', 'Personel kartları, işe alım adayları ve maaş bordrosu.', 'Personel özlük bilgileri, mülakat aşamaları, maaş ve avans ödemeleri takibi.'),
  ('modul-housekeeping', 'Kat Hizmetleri & Oda Takibi', 'Oda temizlik durumları, kat görevlisi atamaları ve teknik servis.', 'Canlı oda temizlik matrisi, kat görevlileri ve arıza bildirimleri.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO onboarding.product_modules (code, family, name, slug, description, page_slug) VALUES
  ('accounting', 'erp', 'Muhasebe & Kasa/Banka', 'modul-accounting', 'Gelir, gider, kasa ve mali kâr/zarar takibi.', 'modul-accounting'),
  ('social-media', 'hotel', 'Sosyal Medya Otomasyonu', 'modul-social-media', 'Otomatik kampanya, ilan paylaşımı ve içerik takvimi.', 'modul-social-media'),
  ('ai-hub', 'erp', 'Yapay Zeka Merkezi (AI Hub)', 'modul-ai-hub', 'İlan metni, SEO, sosyal medya ve misafir yanıt sihirbazı.', 'modul-ai-hub'),
  ('hr-payroll', 'erp', 'İnsan Kaynakları & Bordro', 'modul-hr', 'Personel kartları, aday mülakatları ve maaş bordrosu.', 'modul-hr'),
  ('housekeeping', 'hotel', 'Kat Hizmetleri & Oda Takibi', 'modul-housekeeping', 'Oda temizlik durum matrisi, kat görevlileri ve teknik servis.', 'modul-housekeeping')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ─── 9. Yetki İzinleri (Grants) ──────────────────────────
GRANT USAGE ON SCHEMA accounting TO nexus_app;
GRANT USAGE ON SCHEMA marketing TO nexus_app;
GRANT USAGE ON SCHEMA ai TO nexus_app;
GRANT USAGE ON SCHEMA hr TO nexus_app;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA accounting TO nexus_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA marketing TO nexus_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ai TO nexus_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr TO nexus_app;

GRANT ALL PRIVILEGES ON catalog.housekeeping_tasks TO nexus_app;
GRANT ALL PRIVILEGES ON catalog.room_maintenance_tickets TO nexus_app;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA accounting TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA marketing TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hr TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.list_housekeeping_tasks(uuid, int) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.list_maintenance_tickets(uuid, int) TO nexus_app;
