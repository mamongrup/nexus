-- Admin-configurable credentials for official and distribution integrations.
INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
 ('kbs.mode','KBS / Kimlik Bildirimi','Bağlantı durumu','select','disabled,test,live','Canlı gönderim yalnızca resmi kurum hesabı doğrulandıktan sonra açılır.',70,'nexus'),
 ('kbs.endpoint','KBS / Kimlik Bildirimi','Servis HTTPS adresi','https','','KBS veya AKBS servisinin resmi HTTPS adresi.',71,'nexus'),
 ('kbs.facility_code','KBS / Kimlik Bildirimi','Tesis / işletme kodu','text','','',72,'nexus'),
 ('kbs.username','KBS / Kimlik Bildirimi','Kullanıcı adı','secret','','',73,'nexus'),
 ('kbs.password','KBS / Kimlik Bildirimi','Parola','secret','','',74,'nexus'),
 ('kbs.api_key','KBS / Kimlik Bildirimi','API anahtarı','secret','','',75,'nexus'),
 ('einvoice.provider','e-Fatura / e-Arşiv','Sağlayıcı','text','','Örn. özel entegratör adı.',80,'nexus'),
 ('einvoice.endpoint','e-Fatura / e-Arşiv','Servis HTTPS adresi','https','','',81,'nexus'),
 ('einvoice.username','e-Fatura / e-Arşiv','Kullanıcı adı','secret','','',82,'nexus'),
 ('einvoice.password','e-Fatura / e-Arşiv','Parola','secret','','',83,'nexus'),
 ('einvoice.api_key','e-Fatura / e-Arşiv','API anahtarı','secret','','',84,'nexus'),
 ('ota.provider','OTA / Kanal Dağıtımı','Sağlayıcı','text','','Booking, Expedia veya kanal yöneticisi sağlayıcısı.',90,'nexus'),
 ('ota.endpoint','OTA / Kanal Dağıtımı','Servis HTTPS adresi','https','','',91,'nexus'),
 ('ota.property_code','OTA / Kanal Dağıtımı','Tesis kodu','text','','',92,'nexus'),
 ('ota.username','OTA / Kanal Dağıtımı','Kullanıcı adı','secret','','',93,'nexus'),
 ('ota.password','OTA / Kanal Dağıtımı','Parola','secret','','',94,'nexus'),
 ('ota.api_key','OTA / Kanal Dağıtımı','API anahtarı','secret','','',95,'nexus')
ON CONFLICT (key) DO UPDATE SET section=EXCLUDED.section,label=EXCLUDED.label,kind=EXCLUDED.kind,choices=EXCLUDED.choices,description=EXCLUDED.description,position=EXCLUDED.position,workspace=EXCLUDED.workspace;
