-- notify-rotation-overdue.ps1 karar senaryolari (gürültülü kabul testi).
--
-- Betigin dort karar senaryosunu uctan uca dogrular:
--   open                      -> exit 0, uyari yok
--   overdue (yas > sinir)     -> exit 1, kok-neden uyarisi
--   unknown (kayit yok)       -> exit 1, fail-closed
--   expired + PREVIOUS var    -> exit 1, PREVIOUS kaldirilmali
--
-- Karar tablosu migration 192'de events.rotation_check_decision() olarak
-- YASAR ve notify-rotation-overdue.ps1 BU FONKSIYONU CAGIRIR. Buradaki
-- test kararin kopyasini degil, betigin kullandigi tek kaynagi dogrular;
-- iki taraf birbirinden ayrilirsa test kirmizi olur.
--
-- "Gürültülü" kasitlidir: her senaryo icin beklenen karar, girdiler ve
-- gerekce RAISE NOTICE ile basilir; test/*.sql zinciri CI loglarinda
-- karar tablosunu satir satir okunabilir halde gosterir.
--
-- Zincirde alfabetik sirayla kosulur; BEGIN/ROLLBACK ile izole eder,
-- SECRET_KEY_BASE kaydina DOKUNMAZ (test sirlari kullanir).

BEGIN;

-- Beklenen karari dogrular ve gerekcesiyle birlikte gurultu uretir.
CREATE OR REPLACE FUNCTION pg_temp.assert_rotation_decision(
  p_label text,
  p_state text,
  p_age_hours numeric,
  p_max_days int,
  p_previous_present boolean,
  p_expected_exit int,
  p_expected_kind text,
  p_why text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_exit int;
  v_severity text;
  v_kind text;
BEGIN
  SELECT d.exit_code, d.severity, d.alert_kind
    INTO v_exit, v_severity, v_kind
  FROM events.rotation_check_decision(
         p_state, p_age_hours, p_max_days, p_previous_present) AS d;

  IF v_exit IS DISTINCT FROM p_expected_exit OR v_kind IS DISTINCT FROM p_expected_kind THEN
    RAISE EXCEPTION '% senaryosu basarisiz: beklenen exit=% kind=% ama exit=% kind=%',
      p_label, p_expected_exit, p_expected_kind, v_exit, v_kind;
  END IF;

  RAISE NOTICE '  [%] exit=% severity=% kind=%  <- %',
    p_label, v_exit, v_severity, v_kind, p_why;
END;
$$;

-- Gercek pencere hesabi: state/age yalnizca fonksiyon parametresi
-- olarak degil, migration 187'den GELEREK uretilir. Boylece karar tablosu
-- ile pencere kapisi arasindaki baglanti da dogrulanir.
CREATE OR REPLACE FUNCTION pg_temp.rotation_state_of(p_secret text)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT events.rotation_window_state(p_secret);
$$;

-- SENARYO 1'in state'i migration 187'den GELIR (yapay olarak 'open' yazmaz):
-- test sirina taze kayit eklenir, boylece rotation_window_state gercekten
-- 'open' doner. Kayit yalnizca bu transaction icinde yasar (ROLLBACK).
INSERT INTO events.secret_rotations(secret_name, source)
VALUES ('DECISION_TEST_SECRET', 'test');

-- Senaryolar ve gurultu bir DO blogunda: RAISE NOTICE yalnizca plpgsql
-- icinde gecerlidir.
DO $$
BEGIN

  -- -------------------------------------------------------------------
  -- SENARYO 1: open -> saglikli, cikis 0
  -- Rotasyon yeni, PREVIOUS .env'de olsa bile uyari yok: pencere
  -- icindeyken PREVIOUS kalabilir. state migration 187'den gelir.
  -- -------------------------------------------------------------------
  PERFORM pg_temp.assert_rotation_decision(
  'open', pg_temp.rotation_state_of('DECISION_TEST_SECRET'), 0.5, 180, true,
  0, 'none',
  'pencere icinde; PREVIOUS kalabilir, uyari uretilmez');

-- ---------------------------------------------------------------------
-- SENARYO 2: overdue -> kok-neden uyarisi, cikis 1
-- Yas 200 gun > 180 gun siniri. state bilerek 'open' verildi: yas kapisi
-- pencere durumundan BAGIMSIZDIR ve onceliklidir. Gercek yas 200 gun
-- oldugu icin state zaten 'expired' olurdu; buradaki deger siralama
-- (overdue once degerlendirilir) sözlesmesini gosterir.
-- ---------------------------------------------------------------------
PERFORM pg_temp.assert_rotation_decision(
  'overdue', 'open', 200 * 24, 180, false,
  1, 'overdue',
  'yas 200 gun > 180 gun; kok-neden uyarisi, pencereden bagimsiz');

-- overdue + PREVIOUS birlikteliginde de karar overdue kalir (ayni
-- kok-neden; PREVONLY ek satiri mesaj govdesine eklenir).
PERFORM pg_temp.assert_rotation_decision(
  'overdue+previous', 'expired', 200 * 24, 180, true,
  1, 'overdue',
  'yas kapisi once gelir; expired+previous degil, overdue uyarilir');

-- ---------------------------------------------------------------------
-- SENARYO 3: unknown -> fail-closed, cikis 1
-- Kayit yok: yas NULL. Kayitsiz sir denetlenemez, uyari uretilir.
-- ---------------------------------------------------------------------
PERFORM pg_temp.assert_rotation_decision(
  'unknown', 'unknown', NULL, 180, false,
  1, 'no_record',
  'kayit yok; fail-closed, denetlenemeyen sir uyarilir');

-- unknown + PREVIOUS olsa da sonuc ayni (fail-closed).
PERFORM pg_temp.assert_rotation_decision(
  'unknown+previous', 'unknown', NULL, 180, true,
  1, 'no_record',
  'PREVIOUS varligi fail-closed kararini degistirmez');

-- ---------------------------------------------------------------------
-- SENARYO 4: expired + PREVIOUS var -> cikis 1, PREVIOUS kaldirilmali
-- ---------------------------------------------------------------------
PERFORM pg_temp.assert_rotation_decision(
  'expired+previous', 'expired', 72, 180, true,
  1, 'window_expired_previous_present',
  'pencere doldu ve PREVIOUS hala .env''de; kaldirilmali');

-- ---------------------------------------------------------------------
-- SENARYO 4b: expired + PREVIOUS YOK -> saglikli, cikis 0
-- Pencere doldu ama eski deger kaldirildi; artik kullanilmiyor. Sicak
-- durum DEGIL: cikis 0, uyari yok.
-- ---------------------------------------------------------------------
PERFORM pg_temp.assert_rotation_decision(
  'expired-no-previous', 'expired', 72, 180, false,
  0, 'none',
  'pencere doldu ama PREVIOUS kaldirilmis; saglikli durum');

-- ---------------------------------------------------------------------
-- SINIR DURUMLARI (yanlis kurgu ve asiri gevseklik tuzaklari)
-- ---------------------------------------------------------------------
-- Tam sınırda (180 gun) overdue DEĞİL: kural '>' (esitlik uyarı değil).
-- Aynı yaş 'expired' + previous ile uyarılır; 'open' ile uyarı vermez.
PERFORM pg_temp.assert_rotation_decision(
  'boundary-exactly-180d-open', 'open', 180 * 24, 180, false,
  0, 'none',
  'yas tam sinirda: overdue degil (> kurali), open saglikli');

PERFORM pg_temp.assert_rotation_decision(
  'boundary-exactly-180d-expired', 'expired', 180 * 24, 180, true,
  1, 'window_expired_previous_present',
  'yas tam sinirda overdue degil; expired+previous uyarir');

-- Sinirin bir gun uzeri overdue olur.
PERFORM pg_temp.assert_rotation_decision(
  'boundary-181d', 'open', 181 * 24, 180, false,
  1, 'overdue',
  'sinirin 1 gun uzeri: overdue');

-- Beklenmeyen durum -> cikis 2 (denetim yapilamadi), uyari uretilmez.
PERFORM pg_temp.assert_rotation_decision(
  'unexpected-state', 'weird_state', 1, 180, false,
  2, 'unexpected_state',
  'beklenmeyen pencere durumu: denetim yapilamadi, uyari yok');

-- NULL state de beklenmeyen sayilir (fail-closed: sessizce gecme yok).
PERFORM pg_temp.assert_rotation_decision(
  'null-state', NULL, 1, 180, false,
  2, 'unexpected_state',
  'NULL durum: sessizce gecmek yerine cikis 2');

-- NULL p_max_days sinir uygulanmaz; yas kapisi atlanir, pencere karari
-- belirleyicidir (overdue uretilmez).
PERFORM pg_temp.assert_rotation_decision(
  'null-max-days', 'open', 5000 * 24, NULL, false,
  0, 'none',
  'sinir tanimsiz: yas kapisi atlanir, pencere karari gecerli');

  RAISE NOTICE '';
  RAISE NOTICE 'PASS: notify-rotation-overdue karar tablosu (open/overdue/unknown/expired+previous + 6 sinir durumu)';
END;
$$;

DROP FUNCTION pg_temp.rotation_state_of(text);
DROP FUNCTION pg_temp.assert_rotation_decision(text, text, numeric, int, boolean, int, text, text);

ROLLBACK;
