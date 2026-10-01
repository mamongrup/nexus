-- Hijyen migration'ı: platform veritabanına karışmış acente projesi
-- şemaları (agency + agency_auth) temizlenir. Köken: bir noktada acente
-- migration'ları platform DB'sine uygulanmış — bu DB'de acente şema
-- setinin tamamı (agency: 91 tablo; agency_auth: sessions + login/logout/
-- session fonksiyonları) belirdi ve aynı olay platformun auth.logout
-- gövdesini üzerine yazarak logout'u fiilen no-op yapmıştı (189 onardı).
--
-- Güvenlik analizi (uygulama öncesi canlı DB'de doğrulandı):
-- * Platform migration'ları agency/agency_auth şemalarını hiç yaratmaz ve
--   hiçbir platform kodu (src, test, db/tests) bu şemalara referans vermez.
-- * Platformun acente-yönlü fonksiyonları (catalog.agency_listing_feed,
--   partners.*, settings.is_admin vb.) yalnızca platform şemalarını okur;
--   gövdelerdeki "agency" geçişleri meşru iş terimleridir (agency_id
--   kolonları, p_agency parametreleri, 'agency.reservation.paid' olay adları)
--   ve şema referansı DEĞİLDİR.
-- * Post-drop tripwire bu ayrımı yapar: yalnızca search_path satırında
--   agency geçmesi, agency_auth.<x> çağrısı veya (from|join|into|update)
--   agency.<x> referansı ihlal sayılır. pg_get_functiondef aggregate'lerde
--   hata fırlattığından tarama prokind IN ('f','p') ile sınırlıdır.
--
-- Kapsam bilinçli olarak şemalarla sınırlıdır: roller (ör. agency_app)
-- küme-geneldir; migration yanlış kümeye karşı koşarsa acente'nin gerçek
-- rolünü riske atmamak için rol temizliği elle yapılır.
--
-- CI (taze DB) ve gelecekteki kurulumlarda her iki şema yoktur; IF EXISTS
-- sayesinde bu migration orada no-op olur, tripwire'lar temiz geçer.

DO $$
DECLARE
  v_dep int;
BEGIN
  -- 1. Platform görünümleri bu şemalara bağımlıysa CASCADE onları da
  --    sessizce düşer — önce gürültülü dur.
  SELECT count(*) INTO v_dep FROM pg_views
   WHERE schemaname NOT IN ('agency','agency_auth','pg_catalog','information_schema')
     AND ( definition ~* 'agency_auth\.'
        OR definition ~* '(from|join|into|update)\s+agency\.' );
  IF v_dep > 0 THEN
    RAISE EXCEPTION 'agency/agency_auth bulaşmasına bağımlı platform görünümleri var (%)', v_dep;
  END IF;

  SELECT count(*) INTO v_dep FROM pg_matviews
   WHERE schemaname NOT IN ('agency','agency_auth','pg_catalog','information_schema')
     AND ( definition ~* 'agency_auth\.'
        OR definition ~* '(from|join|into|update)\s+agency\.' );
  IF v_dep > 0 THEN
    RAISE EXCEPTION 'agency/agency_auth bulaşmasına bağımlı materialized view var (%)', v_dep;
  END IF;
END $$;

DROP SCHEMA IF EXISTS agency_auth CASCADE;
DROP SCHEMA IF EXISTS agency CASCADE;

DO $$
DECLARE
  v_left int;
BEGIN
  -- 2. Tripwire: bırakma sonrası hiçbir platform fonksiyonu/prosedürü
  --    agency şemasına işaret etmemeli — gelecekteki karışmalara kapalı.
  SELECT count(*) INTO v_left
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.prokind IN ('f','p')
     AND n.nspname NOT IN ('agency','agency_auth','pg_catalog','information_schema')
     AND n.nspname NOT LIKE 'pg\_%'
     AND ( coalesce(substring(pg_get_functiondef(p.oid) from 'SET search_path[^\r\n]*') ~* 'agency', false)
        OR pg_get_functiondef(p.oid) ~* 'agency_auth\.'
        OR pg_get_functiondef(p.oid) ~* '(from|join|into|update)\s+agency\.' );
  IF v_left > 0 THEN
    RAISE EXCEPTION 'agency şemasına işaret eden platform fonksiyonları kaldı (%)', v_left;
  END IF;

  -- 3. Şemalar gerçekten gitti mi (CI'da yoktu — IF EXISTS yolunu da doğrular).
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('agency','agency_auth')) THEN
    RAISE EXCEPTION 'agency/agency_auth şemaları düşürülemedi';
  END IF;
END $$;
