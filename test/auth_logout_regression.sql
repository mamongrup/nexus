-- auth.logout regresyon testi (migration 189 sonrası kalıcı kabul).
-- Geçmişte canlı auth.logout gövdesi auth.sessions'ta bulunmayan
-- token_digest kolonuna sildiği için logout fiilen no-op'tu: auth.login
-- oturumu token_hash kolonuna yazıyor, logout hiçbir satır silmiyordu ve
-- oturumlar 8 saatlik TTL'e kadar birikiyordu. Migration 189 fonksiyonu
-- kanonik gövdeye döndürdü; bu dosya sözleşmeyi DB seviyesinde bekletir:
-- auth.login sonrası auth.logout çağrılınca auth.session BOŞ dönmeli.
-- test.ps1 glob'u bu dosyayı otomatik koşar (PGOWNER, ON_ERROR_STOP).
BEGIN;
DO $$
DECLARE
  v_org uuid := '00000000-0000-0000-0000-000000000001';
  v_email text := 'logout-regression-test@nexus.local';
  v_token text := 'logout-regression-token-0123456789abcdef';
  v_token2 text := 'logout-regression-token-ikinci-oturum';
  v_count int;
BEGIN
  -- 0. Fixture: test organizasyonu + benzersiz owner hesabı (rollback'te temizlenir).
  INSERT INTO core.organizations(id, legal_name)
  VALUES (v_org, 'NEXUS Test Organization')
  ON CONFLICT (id) DO UPDATE SET legal_name = excluded.legal_name;
  INSERT INTO auth.users(tenant_id, email, display_name, role, password_hash)
  VALUES (v_org, v_email, 'Logout Regression Test', 'owner', crypt('admin123456', gen_salt('bf')))
  ON CONFLICT (email) DO UPDATE
    SET active = true, password_hash = excluded.password_hash,
        failed_attempts = 0, locked_until = NULL;

  -- 1. Login oturum açmalı: auth.session satır döndürmeli.
  PERFORM auth.login(v_email, 'admin123456', v_token);
  SELECT count(*) INTO v_count FROM auth.session(v_token);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'auth.login should create a session; auth.session returned % rows', v_count;
  END IF;

  -- 2. REGRESYON: logout oturumu kapatmalı; auth.session BOŞ dönmeli.
  PERFORM auth.logout(v_token);
  SELECT count(*) INTO v_count FROM auth.session(v_token);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'REGRESSION: auth.session still returns % row(s) after auth.logout', v_count;
  END IF;

  -- 3. Oturum satırı fiziksel olarak silinmiş olmalı (token_hash üzerinden).
  SELECT count(*) INTO v_count
    FROM auth.sessions
   WHERE token_hash = encode(public.digest(v_token, 'sha256'), 'hex');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'REGRESSION: auth.sessions row still exists after auth.logout (% row)', v_count;
  END IF;

  -- 4. İkinci logout idempotent olmalı: hata yok, oturum hâlâ boş.
  PERFORM auth.logout(v_token);
  SELECT count(*) INTO v_count FROM auth.session(v_token);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'second auth.logout should be a no-op; auth.session returned % rows', v_count;
  END IF;

  -- 5. Kapsam: logout yalnızca verilen token'ı kapatmalı — aynı kullanıcının
  --    diğer oturumu yaşamaya devam etmeli (kullanıcı geneli kilitleme yok).
  PERFORM auth.login(v_email, 'admin123456', v_token);
  PERFORM auth.login(v_email, 'admin123456', v_token2);
  SELECT count(*) INTO v_count FROM auth.session(v_token2);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'second login should create its own session; got % rows', v_count;
  END IF;
  PERFORM auth.logout(v_token);
  SELECT count(*) INTO v_count FROM auth.session(v_token2);
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'logout must be token-scoped: the other session should survive; got % rows', v_count;
  END IF;

  RAISE NOTICE 'PASS: auth.logout closes the session (auth.session empty, token-scoped, idempotent)';
END;
$$;
ROLLBACK;
