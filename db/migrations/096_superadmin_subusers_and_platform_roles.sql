-- 096_superadmin_subusers_and_platform_roles.sql
-- NEXUS TravelTech Süper Yönetici (Platform Merkezi) Alt Kullanıcıları ve Rolleri
-- 1. Rol kısıtlamasının genişletilmesi
-- 2. Yetki kontrol fonksiyonlarının güncellenmesi
-- 3. Süper Admin kadrosunun örnek hesaplarla tohumlanması

-- 1. Check Constraint Güncellemesi
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE auth.users ADD CONSTRAINT users_role_check CHECK (
  role = ANY (ARRAY[
    -- Platform / Süper Admin Rolleri
    'owner',                    -- Platform Sahibi / Süper Admin (Tam Yetki)
    'operations_director',     -- Operasyon Direktörü (Genel Operasyon & Başvuru/İlan Onay)
    'content_moderator',       -- İlan & İçerik Moderatörü (İlan İnceleme, Kalite & Prosedür)
    'finance_manager',         -- Finans & Mutabakat Müdürü (Komisyon, Hakediş & e-Fatura)
    'onboarding_specialist',   -- Tedarikçi İlişkileri & Onboarding Uzmanı (Evrak & Puanlama)
    'ai_pricing_specialist',   -- Yapay Zeka & Fiyatlama Mühendisi (AI Hub, Yield & Rate Shopper)
    'support_specialist',      -- Sistem & Müşteri Destek Sorumlusu (İletişim & Telemetri)
    
    -- Tedarikçi / İşletme Rolleri
    'general_manager',         -- Tesis Genel Müdürü
    'housekeeping',            -- Kat Hizmetleri / Temizlikçi
    'purchasing',              -- Satın Alma Sorumlusu
    'accounting',              -- Tesis Muhasebe & Kasa
    'frontdesk',               -- Ön Büro & Resepsiyon
    'sales',                   -- Satış Departmanı
    'marketing',               -- Reklam & Tanıtım
    'editor',                  -- Editör
    'viewer'                   -- Görüntüleyici
  ])
);

-- 2. Yeni Üye Ekleme Fonksiyonu
CREATE OR REPLACE FUNCTION auth.create_managed_user(
  p_tenant text,
  p_email text,
  p_name text,
  p_role text,
  p_password text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE
  target uuid := nullif(p_tenant, '')::uuid;
  caller_role text := current_setting('app.role', true);
BEGIN
  -- Patron, Genel Müdür veya Operasyon Direktörü üye ekleyebilir
  IF caller_role NOT IN ('owner', 'general_manager', 'operations_director') THEN
    RETURN 'forbidden';
  END IF;

  IF auth.workspace() <> 'nexus' THEN
    target := nullif(current_setting('app.tenant_id', true), '')::uuid;
  END IF;

  IF target IS NULL OR NOT EXISTS(SELECT FROM core.organizations WHERE id = target)
     OR p_role NOT IN (
       'owner', 'operations_director', 'content_moderator', 'finance_manager',
       'onboarding_specialist', 'ai_pricing_specialist', 'support_specialist',
       'general_manager', 'housekeeping', 'purchasing', 'accounting',
       'frontdesk', 'sales', 'marketing', 'editor', 'viewer'
     )
     OR length(trim(p_name)) NOT BETWEEN 2 AND 100
     OR p_email <> lower(trim(p_email))
     OR p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
     OR length(p_password) NOT BETWEEN 10 AND 72 THEN
    RETURN 'invalid_user';
  END IF;

  INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
  VALUES (target, trim(p_email), crypt(p_password, gen_salt('bf', 12)), trim(p_name), p_role);

  RETURN 'ok';
EXCEPTION WHEN unique_violation THEN
  RETURN 'email_exists';
END $$;

-- 3. Üye Güncelleme & Yetki Değiştirme Fonksiyonu
CREATE OR REPLACE FUNCTION auth.update_managed_user(
  p_user text,
  p_name text,
  p_role text,
  p_active boolean
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  target auth.users%ROWTYPE;
  caller_role text := current_setting('app.role', true);
BEGIN
  SELECT * INTO target FROM auth.users WHERE id::text = p_user;

  IF NOT FOUND
     OR caller_role NOT IN ('owner', 'general_manager', 'operations_director')
     OR (auth.workspace() <> 'nexus' AND target.tenant_id <> nullif(current_setting('app.tenant_id', true), '')::uuid)
     OR p_role NOT IN (
       'owner', 'operations_director', 'content_moderator', 'finance_manager',
       'onboarding_specialist', 'ai_pricing_specialist', 'support_specialist',
       'general_manager', 'housekeeping', 'purchasing', 'accounting',
       'frontdesk', 'sales', 'marketing', 'editor', 'viewer'
     )
     OR length(trim(p_name)) NOT BETWEEN 2 AND 100
     OR (target.id = nullif(current_setting('app.actor_id', true), '')::uuid AND NOT p_active) THEN
    RETURN 'forbidden';
  END IF;

  UPDATE auth.users
  SET display_name = trim(p_name), role = p_role, active = p_active
  WHERE id = target.id;

  IF NOT p_active THEN
    DELETE FROM auth.sessions WHERE user_id = target.id;
  END IF;

  RETURN 'ok';
END $$;

-- 4. Şifre Sıfırlama Fonksiyonu
CREATE OR REPLACE FUNCTION auth.reset_managed_password(
  p_user text,
  p_password text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE
  target auth.users%ROWTYPE;
  caller_role text := current_setting('app.role', true);
BEGIN
  SELECT * INTO target FROM auth.users WHERE id::text = p_user;

  IF NOT FOUND
     OR caller_role NOT IN ('owner', 'general_manager', 'operations_director')
     OR (auth.workspace() <> 'nexus' AND target.tenant_id <> nullif(current_setting('app.tenant_id', true), '')::uuid)
     OR length(p_password) NOT BETWEEN 10 AND 72 THEN
    RETURN 'forbidden';
  END IF;

  UPDATE auth.users
  SET password_hash = crypt(p_password, gen_salt('bf', 12)), failed_attempts = 0, locked_until = null
  WHERE id = target.id;

  DELETE FROM auth.sessions
  WHERE user_id = target.id AND target.id <> nullif(current_setting('app.actor_id', true), '')::uuid;

  RETURN 'ok';
END $$;

-- 5. Süper Yönetici (NEXUS TravelTech) Alt Kadro Örnek Hesaplarını Oluştur
DO $$
DECLARE
  v_nexus_id uuid;
BEGIN
  SELECT id INTO v_nexus_id FROM core.organizations WHERE kind = 'nexus' LIMIT 1;

  IF v_nexus_id IS NOT NULL THEN
    -- Operasyon Direktörü
    INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
    VALUES (v_nexus_id, 'operasyon@nexus.local', crypt('password123', gen_salt('bf', 12)), 'Burak Operasyon Direktörü', 'operations_director')
    ON CONFLICT (email) DO UPDATE SET role = 'operations_director', display_name = 'Burak Operasyon Direktörü';

    -- İlan & İçerik Moderatörü
    INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
    VALUES (v_nexus_id, 'moderator@nexus.local', crypt('password123', gen_salt('bf', 12)), 'Deniz İlan Moderatörü', 'content_moderator')
    ON CONFLICT (email) DO UPDATE SET role = 'content_moderator', display_name = 'Deniz İlan Moderatörü';

    -- Finans & Mutabakat Müdürü
    INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
    VALUES (v_nexus_id, 'finans@nexus.local', crypt('password123', gen_salt('bf', 12)), 'Zeynep Finans Müdürü', 'finance_manager')
    ON CONFLICT (email) DO UPDATE SET role = 'finance_manager', display_name = 'Zeynep Finans Müdürü';

    -- Tedarikçi İlişkileri & Onboarding Uzmanı
    INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
    VALUES (v_nexus_id, 'onboarding@nexus.local', crypt('password123', gen_salt('bf', 12)), 'Murat Onboarding Uzmanı', 'onboarding_specialist')
    ON CONFLICT (email) DO UPDATE SET role = 'onboarding_specialist', display_name = 'Murat Onboarding Uzmanı';

    -- Yapay Zeka & Fiyatlama Mühendisi
    INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
    VALUES (v_nexus_id, 'ai-muhendis@nexus.local', crypt('password123', gen_salt('bf', 12)), 'Arda AI & Fiyatlama Mühendisi', 'ai_pricing_specialist')
    ON CONFLICT (email) DO UPDATE SET role = 'ai_pricing_specialist', display_name = 'Arda AI & Fiyatlama Mühendisi';

    -- Platform Destek Sorumlusu
    INSERT INTO auth.users(tenant_id, email, password_hash, display_name, role)
    VALUES (v_nexus_id, 'destek@nexus.local', crypt('password123', gen_salt('bf', 12)), 'Cem Destek Sorumlusu', 'support_specialist')
    ON CONFLICT (email) DO UPDATE SET role = 'support_specialist', display_name = 'Cem Destek Sorumlusu';
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION auth.create_managed_user(text, text, text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION auth.update_managed_user(text, text, text, boolean) TO nexus_app;
GRANT EXECUTE ON FUNCTION auth.reset_managed_password(text, text) TO nexus_app;
