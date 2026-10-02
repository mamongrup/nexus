-- Rotasyon denetimi karar tablosu (notify-rotation-overdue.ps1 muadili).
--
-- Betik daha once karari kendi icinde switch ile veriyordu; bu tablo
-- karari SQL'e tasir ve betik bu fonksiyonu cagirir. Boylece
-- scripts/test-rotation-overdue-decisions.sql (test/*.sql kabul katmani)
-- dört senaryoyu (open / overdue / unknown / expired+previous) gürültülü
-- olarak dogrulayabilir ve test, betigin karar mantiginin kopyasi
-- degil, betigin kullandigi TEK kaynagi test eder.
--
-- Girdi/çıktı sözleşmesi betikle birebir aynıdır:
--   p_state            events.rotation_window_state() ciktisi
--                      ('open' | 'expired' | 'unknown')
--   p_age_hours        events.latest_rotation_age_hours() ciktisi
--                      (kayit yoksa NULL)
--   p_max_days         -SecretKeyRotationMaxDays (varsayilan 180)
--   p_previous_present SECRET_KEY_BASE_PREVIOUS .env'de tanimli mi
--
--   exit_code    betigin PowerShell cikis kodu (0 saglikli, 1 uyari,
--                2 denetim yapilamadi/beklenmeyen durum)
--   severity     'ok' | 'warn' | 'error' (uyari kanalina gonderilir mi)
--   alert_kind   operatore gonderilecek mesajin turu:
--                'none' | 'overdue' | 'window_expired_previous_present'
--                | 'no_record' | 'unexpected_state'
--
-- SIRA ÖNEMLİ: betikte yaş kapısı (overdue) switch'ten ÖNCE gelir,
-- dolayısıyla beklenmeyen bir durumda bile yaş kapısı önce değerlendirilir.
-- Bu sıra burada birebir korunur.

CREATE OR REPLACE FUNCTION events.rotation_check_decision(
  p_state text,
  p_age_hours numeric,
  p_max_days int,
  p_previous_present boolean
)
RETURNS TABLE(exit_code int, severity text, alert_kind text)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_age_days numeric;
BEGIN
  -- 1) Yas kapisi: pencere durumundan bagimsiz, en ust oncelikli. Kayit
  --    yoksa yas NULL'dir ve bu adim atlanir (fail-closed degeri asagida
  --    'no_record' olarak uretilir).
  IF p_age_hours IS NOT NULL THEN
    v_age_days := round((p_age_hours / 24.0)::numeric, 2);
    IF p_max_days IS NOT NULL AND v_age_days > p_max_days THEN
      RETURN QUERY SELECT 1, 'warn', 'overdue'::text;
      RETURN;
    END IF;
  END IF;

  -- 2) Pencere durumu.
  CASE p_state
    WHEN 'open' THEN
      -- Rotasyon yeni ve PREVIOUS kalabilir: saglikli durum, uyari yok.
      RETURN QUERY SELECT 0, 'ok', 'none'::text;
    WHEN 'expired' THEN
      -- Pencere doldu. PREVIOUS hala .env'de ise uyari; kaldirilmissa
      -- saglikli durum (eski deger artik kullanilmiyor).
      IF COALESCE(p_previous_present, false) THEN
        RETURN QUERY SELECT 1, 'warn', 'window_expired_previous_present'::text;
      ELSE
        RETURN QUERY SELECT 0, 'ok', 'none'::text;
      END IF;
    WHEN 'unknown' THEN
      -- Kayitsiz sir denetlenemez: fail-closed, uyari uretilir.
      RETURN QUERY SELECT 1, 'warn', 'no_record'::text;
    ELSE
      -- Beklenmeyen durum: denetim yapilamadi (cikis 2).
      RETURN QUERY SELECT 2, 'error', 'unexpected_state'::text;
  END CASE;
END;
$$;

COMMENT ON FUNCTION events.rotation_check_decision(text, numeric, int, boolean) IS
  'notify-rotation-overdue.ps1 karar tablosu: (exit_code, severity, alert_kind). Yas kapisi pencere durumundan onceliklidir.';
