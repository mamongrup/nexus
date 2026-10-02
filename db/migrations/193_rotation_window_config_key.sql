-- NEXUS_CONFIG_KEY rotasyon penceresi sozlesmesi (247/188 acente muadili).
--
-- 187 yalniz iki satir seed'lerdi:
--   SECRET_KEY_BASE, SECRET_KEY_BASE_PREVIOUS
-- NEXUS_CONFIG_KEY ise satirsiz kaldi ve rotation_window_hours() varsayilan
-- degeri (48 saat) geri dusuyordu. Ayarli degistirilemese de (asagida)
-- pencere DEGERI artik acikca yazilidir ve iki sifrinin pencereleri
-- ayri ayri olusturulabilir.
--
-- KAPSAM: bu sır ENFORMATIFtir. Platformda settings.values satirlarini
-- AES-256-GCM ile simreleyen ust anahtardir ve kayipsiz degistirilemez:
-- scripts/config-key.ps1 simreli kayitlar varken anahtari yeniden uretmez.
-- Dolayisiyla:
--   * PREVIOUS karsiligi YOKTUR; 'expired' durumunda kaldirilacak bir
--     deger bulunmaz.
--   * YAS kapisi (overdue) Gecerlidir ve uyari uretir: anahtarin ne kadar
--     suredir degistirilmedigi izlenir.
--   * 'expired' yalnizca RAPRORLANIR, zorlama uygulanmaz. Bu ayrim
--     record-secret-rotation.ps1 ve notify-rotation-overdue.ps1'nin
--     NEXUS_CONFIG_KEY metniyle tutarlidir.
--
-- Bu migration 187'yi DEGISTIRMEZ (checksum korunur); yalnizca yeni bir
-- ayar satiri ekler. Ayni migration acente'de 272 numarasidadir ve
-- govdesi burasiyla birebir ayni sozlesmeyi ifade eder.
--
-- Idempotent: ON CONFLICT DO NOTHING ile mevcut operator ayari
-- (varsa set_rotation_window ile degistirilmis) ASLA ezilmez.

INSERT INTO events.secret_rotation_settings(secret_name, window_hours)
VALUES
  ('NEXUS_CONFIG_KEY', 48)
ON CONFLICT (secret_name) DO NOTHING;

COMMENT ON FUNCTION events.rotation_window_state(text) IS
  'unknown=no record (fail-closed), open=within window, expired=remove previous secret. NEXUS_CONFIG_KEY icin PREVIOUS karsiligi yoktur: expired yalnizca raporlanir, overdue gecerlidir.';
