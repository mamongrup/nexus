-- ══════════════════════════════════════════════════════════════════
-- 091_staff_roles_and_granular_rbac.sql
-- Tedarikçi İçi Kadrolaşma, Departman Rolleri & Yetki Dağıtımı (RBAC)
-- ══════════════════════════════════════════════════════════════════

-- 1. auth.users tablosundaki role kısıtını 10 kurumsal departman rolüne genişlet
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS check_role;
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS users_role_check1;
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS auth_users_role_check;

ALTER TABLE auth.users ADD CONSTRAINT users_role_check CHECK (role IN (
  'owner',            -- Patron / İşletme Sahibi (Tam Yetki & Yetki Dağıtımı)
  'general_manager',  -- Genel Müdür (Tam Yetki & Yetki Dağıtımı)
  'housekeeping',     -- Kat Hizmetleri / Temizlikçi (Oda Temizlik Bildirimi)
  'purchasing',       -- Satın Alma Sorumlusu (Ürün, Fiş/Fatura No & Gider Girişi)
  'accounting',       -- Muhasebe & Finans (Gelir, Gider, Kasa/Banka, Bordro)
  'frontdesk',        -- Ön Büro / Resepsiyon (Oda Takibi, Check-in/out, Folyo)
  'sales',            -- Satış Departmanı (İlanlar, Takvim, Fiyatlar, Kampanyalar)
  'marketing',        -- Reklam & Tanıtım (Sosyal Medya, AI Hub, Kampanyalar)
  'editor',           -- Editör (Genel İçerik & İlan Yönetimi)
  'viewer'            -- Görüntüleyici (Salt Okunur)
));

-- 2. Yeni Üye Oluşturma: Patron ('owner') VEYA Genel Müdür ('general_manager') dağıtabilir
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
  -- Sadece Patron veya Genel Müdür yeni üye ekleyebilir
  IF caller_role NOT IN ('owner', 'general_manager') THEN
    RETURN 'forbidden';
  END IF;

  IF auth.workspace() <> 'nexus' THEN
    target := nullif(current_setting('app.tenant_id', true), '')::uuid;
  END IF;

  IF target IS NULL OR NOT EXISTS(SELECT FROM core.organizations WHERE id = target)
     OR p_role NOT IN (
       'owner', 'general_manager', 'housekeeping', 'purchasing',
       'accounting', 'frontdesk', 'sales', 'marketing', 'editor', 'viewer'
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

-- 3. Üye Güncelleme & Yetki Değiştirme: Patron veya Genel Müdür dağıtabilir
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
     OR caller_role NOT IN ('owner', 'general_manager')
     OR (auth.workspace() <> 'nexus' AND target.tenant_id <> nullif(current_setting('app.tenant_id', true), '')::uuid)
     OR p_role NOT IN (
       'owner', 'general_manager', 'housekeeping', 'purchasing',
       'accounting', 'frontdesk', 'sales', 'marketing', 'editor', 'viewer'
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

-- 4. Şifre Sıfırlama: Patron veya Genel Müdür sıfırlayabilir
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
     OR caller_role NOT IN ('owner', 'general_manager')
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

-- 5. İlan yazma yetkisi (Satış, Editör, Patron ve Genel Müdür)
CREATE OR REPLACE FUNCTION inventory.require_editor() RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
BEGIN
  IF auth.workspace() <> 'supplier' OR NOT EXISTS (
    SELECT FROM auth.users
    WHERE tenant_id = t
      AND id = nullif(current_setting('app.actor_id', true), '')::uuid
      AND role IN ('owner', 'general_manager', 'sales', 'editor')
  ) THEN
    RAISE EXCEPTION 'Supplier editor required' USING ERRCODE = '42501';
  END IF;
  RETURN t;
END $$;

-- 6. Temizlikçinin tek tıkla oda temizleme fonksiyonu
CREATE OR REPLACE FUNCTION catalog.quick_mark_clean(p_property_id uuid, p_room_code text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_tenant uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
BEGIN
  -- Unit tablosunu güncelle (oda numarasına veya adına göre)
  UPDATE catalog.units u
  SET housekeeping = 'clean', updated_at = now()
  FROM catalog.properties p
  WHERE u.property_id = p.id
    AND (v_tenant IS NULL OR p.tenant_id = v_tenant)
    AND (p_property_id IS NULL OR p.id = p_property_id)
    AND (u.unit_number = p_room_code OR u.name = p_room_code);

  -- Bekleyen veya süreçteki temizlik görevini tamamlandı yap
  UPDATE catalog.housekeeping_tasks
  SET status = 'completed', completed_at = now()
  WHERE (v_tenant IS NULL OR tenant_id = v_tenant)
    AND (p_property_id IS NULL OR property_id = p_property_id)
    AND room_code = p_room_code
    AND status IN ('pending', 'in_progress');

  RETURN 'ok';
END $$;

-- 7. İzinleri nexus_app rolüne tanımla
GRANT EXECUTE ON FUNCTION auth.create_managed_user(text, text, text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION auth.update_managed_user(text, text, text, boolean) TO nexus_app;
GRANT EXECUTE ON FUNCTION auth.reset_managed_password(text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION inventory.require_editor() TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.quick_mark_clean(uuid, text) TO nexus_app;
