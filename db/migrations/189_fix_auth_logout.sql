-- auth.logout onarımı: canlı veritabanında logout fonksiyonu, platform
-- migration tarihçesi DIŞINDAN gelmiş bir tanımla üzerine yazılmıştı
-- (gövdesi auth.sessions'ta bulunmayan token_digest kolonuna siler ve
-- search_path'inde 'agency' şeması taşır — acente şeması karışması).
-- Sonuç: auth.login oturumu token_hash kolonuna yazarken logout fiilen
-- no-op davranıyor, oturum satırları 8 saatlik TTL'e kadar birikiyordu.
-- (Bu hata, paralel yardımcı üçlüsünün DB kendi-kendi-testi tarafından
-- yakalandı: test/test_env_test.gleam.)
--
-- Onarım:
-- 1) auth.logout, 001/081 soyunun kanonik gövdesine döndürülür
--    (token_hash üzerinden sha256 özetle silme).
-- 2) Kirletmeyle gelen ve hiçbir platform kodunun yazmadığı token_digest
--    kolonu düşürülür (login/session fonksiyonları yalnız token_hash
--    kullanır; auth.session okuması 081'den beri token_hash üzerinedir).

CREATE OR REPLACE FUNCTION auth.logout(p_token text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path=pg_catalog,auth,public
AS $$
  DELETE FROM auth.sessions WHERE token_hash=encode(public.digest(p_token,'sha256'),'hex');
$$;

ALTER TABLE auth.sessions DROP COLUMN IF EXISTS token_digest;
