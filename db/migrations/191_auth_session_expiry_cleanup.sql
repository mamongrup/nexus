-- Zamanlanmis oturum bakimi: suresi dolmus auth.sessions satirlarinin
-- temizligi. auth.login her oturumu 8 saatlik TTL ile yazar; zincirde
-- temizlik mekanizmasi yokken satirlar birikiyor (canli veritabaninda
-- 253/253 satirin suresi dolmustu). scripts/auth-session-expiry-worker.ps1
-- bu fonksiyonu donemli cagirir; kabul testi:
-- test/auth_sessions_expiry_cleanup.sql
--
-- Sozlesme:
--   auth.purge_expired_sessions() -> bigint
--   - Yalnizca expires_at < now() satirlarini siler; gecerli oturumlara
--     dokunmaz (auth.session okumasindaki expires_at > now() esigiyle ayni
--     taraf).
--   - Idempotent: silinecek suresi dolmus satir kalmadiysa 0 doner.
--   - SECURITY DEFINER + sabit search_path (189 kalibi): isci yalnizca bu
--     fonksiyonu cagirir, tabloya dogrudan yazmaz.
CREATE OR REPLACE FUNCTION auth.purge_expired_sessions()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path=pg_catalog,auth,public
AS $$
  WITH deleted AS (
    DELETE FROM auth.sessions WHERE expires_at < now() RETURNING 1
  )
  SELECT count(*) FROM deleted;
$$;

-- expiry indeksi migration zincirinin disindan gelmisti: canli
-- veritabaninda birebir ayni iki indeks vardi (auth_sessions_expiry_idx +
-- sessions_expires_at_idx), taze kurulumlarda ise hicbiri yoktu. Kanonik
-- indeks burada tanimlanir; tekrari dusurulur.
CREATE INDEX IF NOT EXISTS auth_sessions_expiry_idx ON auth.sessions (expires_at);
DROP INDEX IF EXISTS auth.sessions_expires_at_idx;
