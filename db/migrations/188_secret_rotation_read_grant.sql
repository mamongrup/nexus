-- Rotasyon penceresi /health gorunurlugu: uygulama kullanıcısı (nexus_app)
-- pencere durumunu /v1/secret-rotation-window ucu uzerinden raporlar.
-- Yalnizca okuma: rotasyon kaydi ve pencere ayari yine owner'e aittir
-- (yazma izni verilmez). Acente tarafindaki okuma modeliyle uyumludur:
-- izleme sır tarihlerini okur, degistiremez.

GRANT SELECT ON events.secret_rotations TO nexus_app;
GRANT SELECT ON events.secret_rotation_settings TO nexus_app;
