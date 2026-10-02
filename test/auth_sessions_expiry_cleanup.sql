-- auth.purge_expired_sessions kabul testi (migration 191 sonrasi kalici).
-- Zamanlanmis bakim iscisi (scripts/auth-session-expiry-worker.ps1) bu
-- fonksiyona guvenir; bu dosya sozlesmeyi DB seviyesinde bekletir:
--   - suresi dolmus oturum satirlari silinir (en az fixture edilenler),
--   - gecerli oturumlar (expires_at > now()) yasamaya devam eder,
--   - ikinci cagri idempotenttir: 0 doner.
-- test.ps1 / run-db-tests.ps1 kabul katmani bu dosyayi otomatik kosar
-- (PGOWNER, ON_ERROR_STOP, ROLLBACK ile izole).
BEGIN;
DO $$
DECLARE
  v_org uuid := '00000000-0000-0000-0000-000000000001';
  v_email text := 'session-purge-test@nexus.local';
  v_expired_token text := 'session-purge-expired-token-0123456789abcdef';
  v_valid_token text := 'session-purge-valid-token-01234567890abcdef';
  v_user_id uuid;
  v_deleted bigint;
  v_count int;
BEGIN
  -- 0. Fixture: test organizasyonu + benzersiz owner hesabi (rollback'te temizlenir).
  INSERT INTO core.organizations(id, legal_name)
  VALUES (v_org, 'NEXUS Test Organization')
  ON CONFLICT (id) DO UPDATE SET legal_name = excluded.legal_name;
  INSERT INTO auth.users(tenant_id, email, display_name, role, password_hash)
  VALUES (v_org, v_email, 'Session Purge Test', 'owner', crypt('admin123456', gen_salt('bf')))
  ON CONFLICT (email) DO UPDATE
    SET active = true, password_hash = excluded.password_hash,
        failed_attempts = 0, locked_until = NULL;
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

  -- Bir suresi dolmus + bir gecerli oturum satiri ekleyelim.
  INSERT INTO auth.sessions(token_hash, user_id, expires_at) VALUES
    (encode(public.digest(v_expired_token, 'sha256'), 'hex'), v_user_id, now() - interval '2 hours'),
    (encode(public.digest(v_valid_token, 'sha256'), 'hex'), v_user_id, now() + interval '8 hours');

  -- 1. Purge suresi dolmus satirlari silmeli (en az fixture edilenler).
  SELECT auth.purge_expired_sessions() INTO v_deleted;
  IF v_deleted < 1 THEN
    RAISE EXCEPTION 'purge should delete at least the seeded expired session; deleted %', v_deleted;
  END IF;
  SELECT count(*) INTO v_count
    FROM auth.sessions
   WHERE token_hash = encode(public.digest(v_expired_token, 'sha256'), 'hex');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'expired session survived purge (% row)', v_count;
  END IF;

  -- 2. Gecerli oturum silinmemeli.
  SELECT count(*) INTO v_count
    FROM auth.sessions
   WHERE token_hash = encode(public.digest(v_valid_token, 'sha256'), 'hex');
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'valid session must survive purge; found % row(s)', v_count;
  END IF;

  -- 3. Idempotent: ikinci kosum silinecek sey kalmadiysa 0 donmeli.
  SELECT auth.purge_expired_sessions() INTO v_deleted;
  IF v_deleted <> 0 THEN
    RAISE EXCEPTION 'second purge should be a no-op; deleted %', v_deleted;
  END IF;

  RAISE NOTICE 'PASS: auth.purge_expired_sessions removes only expired sessions (valid kept, idempotent)';
END;
$$;
ROLLBACK;
