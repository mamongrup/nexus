-- QNB eSolutions document credentials are entered by each workspace owner.
-- settings.save seals secret fields with NEXUS_CONFIG_KEY; no provider call is implied.
INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
 ('qnb_esolutions.mode','QNB eSolutions · Fatura','Ortam','select','disabled,test,live','E-belge gönderimi ayrıca servis doğrulaması gerektirir.',70,'nexus'),
 ('qnb_esolutions.username','QNB eSolutions · Fatura','Hesap / kullanıcı adı','text','','QNB eSolutions hesabınız.',71,'nexus'),
 ('qnb_esolutions.password','QNB eSolutions · Fatura','Parola','secret','','Gizli değer şifreli saklanır.',72,'nexus'),
 ('qnb_esolutions.api_key','QNB eSolutions · Fatura','API anahtarı (varsa)','secret','','Gizli değer şifreli saklanır.',73,'nexus'),
 ('qnb_esolutions.endpoint','QNB eSolutions · Fatura','Servis HTTPS adresi (varsa)','https','','QNB tarafından verilen servis adresi.',74,'nexus'),
 ('agency_qnb_esolutions.mode','QNB eSolutions · Fatura','Ortam','select','disabled,test,live','Acente e-belge erişimi; servis doğrulaması ayrıca yapılır.',70,'agency'),
 ('agency_qnb_esolutions.username','QNB eSolutions · Fatura','Hesap / kullanıcı adı','text','','Acente QNB eSolutions hesabı.',71,'agency'),
 ('agency_qnb_esolutions.password','QNB eSolutions · Fatura','Parola','secret','','Gizli değer şifreli saklanır.',72,'agency'),
 ('agency_qnb_esolutions.api_key','QNB eSolutions · Fatura','API anahtarı (varsa)','secret','','Gizli değer şifreli saklanır.',73,'agency'),
 ('agency_qnb_esolutions.endpoint','QNB eSolutions · Fatura','Servis HTTPS adresi (varsa)','https','','QNB tarafından verilen servis adresi.',74,'agency')
ON CONFLICT (key) DO NOTHING;
