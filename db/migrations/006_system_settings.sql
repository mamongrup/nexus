CREATE SCHEMA settings;
CREATE TABLE settings.fields (
 key text PRIMARY KEY, section text NOT NULL, label text NOT NULL, kind text NOT NULL CHECK(kind IN ('text','secret','https','email','select','number')),
 choices text NOT NULL DEFAULT '', description text NOT NULL DEFAULT '', position int NOT NULL,
 workspace text NOT NULL DEFAULT 'nexus' CHECK(workspace IN ('nexus','agency'))
);
INSERT INTO settings.fields(key,section,label,kind,choices,description,position) VALUES
 ('company.name','Şirket ve site','Şirket adı','text','','',10),
 ('company.support_email','Şirket ve site','Destek e-postası','email','','',11),
 ('site.public_origin','Şirket ve site','HTTPS site adresi','https','','Örn. https://nexustraveltech.com. Kaydetmek siteyi otomatik yayınlamaz.',12),
 ('site.default_locale','Şirket ve site','Varsayılan dil','select','tr,en,de,ru,ar,fr','Dil seçimi çevirilerin hazır olduğu anlamına gelmez.',13),
 ('site.default_currency','Şirket ve site','Varsayılan para birimi','select','TRY,EUR,USD,GBP,AED,SAR','',14),
 ('parampos.mode','ParamPOS','Ortam','select','disabled,test,live','Canlı tahsilat ayrıca entegrasyon doğrulaması gerektirir.',20),
 ('parampos.account_type','ParamPOS','Hesap türü','select','marketplace','NEXUS alt üyeli pazaryeri hesabı.',21),
 ('parampos.client_code','ParamPOS','CLIENT_CODE / terminal numarası','number','','',22),
 ('parampos.username','ParamPOS','Üye işyeri kullanıcı adı','secret','','',23),
 ('parampos.password','ParamPOS','Üye işyeri parolası','secret','','',24),
 ('parampos.guid','ParamPOS','Üye işyeri GUID anahtarı','secret','','',25),
 ('parampos.callback_origin','ParamPOS','Ödeme dönüş HTTPS adresi','https','','Dışarıdan erişilebilir uygulama adresi. Localhost kullanmayın.',26),
 ('ai.provider','Yapay zekâ','Varsayılan sağlayıcı','select','disabled,openai,anthropic,gemini,compatible','Kaydetmek AI görevlerini otomatik başlatmaz.',30),
 ('ai.openai_key','Yapay zekâ','OpenAI API anahtarı','secret','','',31),
 ('ai.anthropic_key','Yapay zekâ','Anthropic API anahtarı','secret','','',32),
 ('ai.gemini_key','Yapay zekâ','Gemini API anahtarı','secret','','',33),
 ('ai.compatible_key','Yapay zekâ','Uyumlu servis API anahtarı','secret','','',34),
 ('ai.base_url','Yapay zekâ','Uyumlu servis HTTPS adresi','https','','Bağlantı kurulmadan önce sağlayıcı adresi doğrulanmalıdır.',35),
 ('ai.model','Yapay zekâ','Model adı','text','','',36),
 ('ai.monthly_budget_minor','Yapay zekâ','Aylık bütçe (USD cent)','number','','0 harcamayı kapatır. Bütçe uygulaması worker motorunda ayrıca doğrulanacaktır.',37),
 ('email.smtp_host','E-posta','SMTP sunucusu','text','','',40),
 ('email.smtp_port','E-posta','SMTP portu','number','','',41),
 ('email.smtp_security','E-posta','SMTP güvenliği','select','starttls,tls','',42),
 ('email.smtp_user','E-posta','SMTP kullanıcı adı','secret','','',43),
 ('email.smtp_password','E-posta','SMTP parolası','secret','','',44),
 ('email.from','E-posta','Gönderen adresi','email','','',45),
 ('storage.endpoint','Dosya depolama','S3 uyumlu HTTPS adresi','https','','',50),
 ('storage.bucket','Dosya depolama','Bucket adı','text','','',51),
 ('storage.region','Dosya depolama','Bölge','text','','',52),
 ('storage.access_key','Dosya depolama','Erişim anahtarı','secret','','',53),
 ('storage.secret_key','Dosya depolama','Gizli erişim anahtarı','secret','','',54),
 ('connectivity.provider','Tedarikçi bağlantısı','Sağlayıcı adı','text','','',60),
 ('connectivity.endpoint','Tedarikçi bağlantısı','API HTTPS adresi','https','','',61),
 ('connectivity.account','Tedarikçi bağlantısı','Hesap / tesis kodu','text','','',62),
 ('connectivity.api_key','Tedarikçi bağlantısı','API anahtarı','secret','','',63),
 ('connectivity.api_secret','Tedarikçi bağlantısı','API gizli anahtarı','secret','','',64);
INSERT INTO settings.fields(key,section,label,kind,choices,description,position,workspace) VALUES
 ('agency_pos.mode','Acente ParamPOS','Ortam','select','disabled,test,live','Acentenin kendi standart POS hesabı.',10,'agency'),
 ('agency_pos.account_type','Acente ParamPOS','Hesap türü','select','standard','Standart sanal POS.',11,'agency'),
 ('agency_pos.client_code','Acente ParamPOS','CLIENT_CODE / terminal numarası','number','','',12,'agency'),
 ('agency_pos.username','Acente ParamPOS','Üye işyeri kullanıcı adı','secret','','',13,'agency'),
 ('agency_pos.password','Acente ParamPOS','Üye işyeri parolası','secret','','',14,'agency'),
 ('agency_pos.guid','Acente ParamPOS','Üye işyeri GUID anahtarı','secret','','',15,'agency'),
 ('agency_pos.callback_origin','Acente ParamPOS','Ödeme dönüş HTTPS adresi','https','','Acentenin ödeme dönüş adresi.',16,'agency');
CREATE TABLE settings.values (
 tenant_id uuid NOT NULL REFERENCES core.organizations, key text NOT NULL REFERENCES settings.fields, value text NOT NULL,
 PRIMARY KEY(tenant_id,key),
 version bigint NOT NULL CHECK(version>0), updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid NOT NULL REFERENCES auth.users
);
ALTER TABLE settings.values ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings.fields ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION settings.is_admin() RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT coalesce(auth.workspace() IN ('nexus','agency') AND EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND role='owner'),false);
$$;
CREATE FUNCTION settings.list() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[f.key,f.section,f.label,f.kind,f.choices,f.description,CASE WHEN f.kind='secret' THEN '' ELSE coalesce(v.value,'') END,CASE WHEN coalesce(v.value,'')<>'' THEN 'saved' ELSE 'empty' END,coalesce(v.version,0)::text]
 FROM settings.fields f LEFT JOIN settings.values v ON v.key=f.key AND v.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid WHERE settings.is_admin() AND f.workspace=auth.workspace() ORDER BY f.position;
$$;
CREATE FUNCTION settings.save(p_key text,p_value text,p_version bigint) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE f settings.fields%ROWTYPE; old_version bigint;
BEGIN
 IF NOT settings.is_admin() THEN RETURN 'forbidden'; END IF;
 SELECT * INTO f FROM settings.fields WHERE key=p_key AND workspace=auth.workspace();
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF p_value IS NULL OR length(p_value)>16000 OR p_version IS NULL THEN RETURN 'invalid_setting'; END IF;
 IF p_value<>'' AND f.kind='secret' AND p_value NOT LIKE 'v1:%' THEN RETURN 'invalid_setting'; END IF;
 IF p_value<>'' AND f.kind='select' AND NOT p_value=ANY(string_to_array(f.choices,',')) THEN RETURN 'invalid_setting'; END IF;
 IF p_value<>'' AND f.kind='number' AND p_value !~ '^[0-9]{1,12}$' THEN RETURN 'invalid_setting'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(current_setting('app.tenant_id')||p_key,706));
 SELECT version INTO old_version FROM settings.values WHERE key=p_key AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid;
 IF coalesce(old_version,0)<>p_version THEN RETURN 'setting_conflict'; END IF;
 INSERT INTO settings.values(tenant_id,key,value,version,updated_by) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,p_key,p_value,p_version+1,nullif(current_setting('app.actor_id',true),'')::uuid)
 ON CONFLICT(tenant_id,key) DO UPDATE SET value=EXCLUDED.value,version=EXCLUDED.version,updated_at=now(),updated_by=EXCLUDED.updated_by;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,nullif(current_setting('app.actor_id',true),'')::uuid,'settings.changed',gen_random_uuid(),jsonb_build_object('key',p_key,'version',p_version+1,'cleared',p_value=''));
 RETURN 'ok';
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA settings FROM PUBLIC;
GRANT USAGE ON SCHEMA settings TO nexus_app;
GRANT EXECUTE ON FUNCTION settings.list(),settings.save(text,text,bigint) TO nexus_app;
