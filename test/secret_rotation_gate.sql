-- 187: events.secret_rotations pencere geçiş kontrolü.
-- Rotasyon kaydı yoksa 'unknown' (fail-closed), pencere içindeyse 'open',
-- dolduysa 'expired'. events.set_rotation_window ile sır bazlı pencere
-- ayarı doğrulanır. test.ps1 glob'u bu dosyayı otomatik koşar.
BEGIN;
DO $$
DECLARE
  v_state text;
  v_age numeric;
BEGIN
  -- 1. Kayıt yokken unknown (fail-closed) — test sırrı için kayıt yok.
  v_state := events.rotation_window_state('TEST_SECRET_187');
  IF v_state IS DISTINCT FROM 'unknown' THEN
    RAISE EXCEPTION 'expected unknown state without records, got %', v_state;
  END IF;

  -- 2. Kayıt eklenince open.
  INSERT INTO events.secret_rotations(secret_name, source)
  VALUES ('TEST_SECRET_187', 'test');
  v_state := events.rotation_window_state('TEST_SECRET_YOK');
  IF v_state IS DISTINCT FROM 'unknown' THEN
    RAISE EXCEPTION 'missing secret should stay unknown, got %', v_state;
  END IF;
  v_state := events.rotation_window_state('TEST_SECRET_187');
  IF v_state IS DISTINCT FROM 'open' THEN
    RAISE EXCEPTION 'fresh record should be open, got %', v_state;
  END IF;

  -- 3. Pencere dolunca expired: pencereyi 1 saate indir, kaydı 2 saat eskit.
  PERFORM events.set_rotation_window('TEST_SECRET_187', 1);
  UPDATE events.secret_rotations
     SET rotated_at = now() - interval '2 hours'
   WHERE secret_name = 'TEST_SECRET_187';
  v_state := events.rotation_window_state('TEST_SECRET_187');
  IF v_state IS DISTINCT FROM 'expired' THEN
    RAISE EXCEPTION 'aged record should be expired, got %', v_state;
  END IF;
  v_age := events.latest_rotation_age_hours('TEST_SECRET_187');
  IF v_age < 1.9 OR v_age > 2.1 THEN
    RAISE EXCEPTION 'unexpected age %, expected ~2h', v_age;
  END IF;

  -- 4. Pencere tekrar genişletilirse open'a döner (ayar fonksiyonu çalışır).
  PERFORM events.set_rotation_window('TEST_SECRET_187', 48);
  v_state := events.rotation_window_state('TEST_SECRET_187');
  IF v_state IS DISTINCT FROM 'open' THEN
    RAISE EXCEPTION 'widened window should reopen, got %', v_state;
  END IF;

  -- 5. Geçersiz pencere ayarı reddedilir.
  BEGIN
    PERFORM events.set_rotation_window('TEST_SECRET_187', 0);
    RAISE EXCEPTION 'window_hours=0 should be rejected';
  EXCEPTION
    WHEN raise_exception THEN
      NULL; -- beklenen
  END;
  BEGIN
    PERFORM events.set_rotation_window('', 48);
    RAISE EXCEPTION 'empty secret should be rejected';
  EXCEPTION
    WHEN raise_exception THEN
      NULL; -- beklenen
  END;

  RAISE NOTICE 'PASS: events.secret_rotations window gate (unknown/open/expired + settings)';
END;
$$;
ROLLBACK;
