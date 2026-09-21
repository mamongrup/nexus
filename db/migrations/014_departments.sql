CREATE SCHEMA organization;
CREATE TABLE organization.departments (
 code text NOT NULL, workspace text NOT NULL CHECK(workspace IN ('nexus','supplier')), name text NOT NULL, description text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT true, PRIMARY KEY(code,workspace)
);
CREATE TABLE organization.org_departments (
 organization_id uuid NOT NULL REFERENCES core.organizations ON DELETE CASCADE, department_code text NOT NULL, workspace text NOT NULL, status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','paused')), lead_user_id uuid REFERENCES auth.users, PRIMARY KEY(organization_id,department_code), FOREIGN KEY(department_code,workspace) REFERENCES organization.departments(code,workspace)
);
INSERT INTO organization.departments(code,workspace,name,description) VALUES
 ('executive','nexus','Yönetim Kurulu / Genel Yönetim','Strateji, hedef, risk ve karar yönetimi'),
 ('product','nexus','Ürün ve Program Yönetimi','NEXUS ürünleri, modüller ve roadmap'),
 ('marketing','nexus','Pazarlama','Marka, kampanya ve talep üretimi'),
 ('social-media','nexus','Sosyal Medya','İçerik takvimi, topluluk ve kanal yönetimi'),
 ('ai','nexus','Yapay Zekâ ve Otomasyon','AI worker, bütçe, araç yetkileri ve insan onayı'),
 ('accounting','nexus','Muhasebe ve Finans','Ledger, mutabakat, ödeme ve hakediş'),
 ('seo','nexus','SEO ve İçerik','Teknik SEO, landing sayfaları ve arama görünürlüğü'),
 ('translation','nexus','Çeviri ve Yerelleştirme','Dil, locale, RTL ve çeviri onayı'),
 ('sales','nexus','Satış ve İş Geliştirme','Tedarikçi, acente ve kurumsal satış'),
 ('operations','nexus','Operasyon Merkezi','Talep, rezervasyon, destek ve insan görevleri'),
 ('legal','nexus','Hukuk ve Uyum','Sözleşme, KVKK, KYC ve politika'),
 ('risk-security','nexus','Risk ve Bilgi Güvenliği','Erişim, audit, olay ve güvenlik'),
 ('hr','nexus','İnsan ve Kültür','Yetkinlik, işe alım ve performans'),
 ('procurement','nexus','Satın Alma ve Tedarik','Tedarik, araç ve hizmet alımı'),
 ('technology','nexus','Teknoloji ve Altyapı','Geliştirme, deploy, yedek ve gözlemleme'),
 ('customer-success','nexus','Müşteri Başarısı','Onboarding, destek ve geri bildirim'),
 ('supplier-management','nexus','Tedarikçi Yönetimi','Tedarikçi başvurusu, belge ve aktivasyon'),
 ('agency-success','nexus','Acente Başarısı','Acente bağlantısı, eğitim ve satış aktivasyonu'),
 ('management','supplier','İşletme Yönetimi','İşletme hedefleri, onay ve sorumluluk'),
 ('marketing','supplier','Pazarlama','Ürün tanıtımı ve talep yönetimi'),
 ('social-media','supplier','Sosyal Medya','İşletme sosyal kanalları ve içerik'),
 ('ai','supplier','Yapay Zekâ Yardımcısı','İçerik, fiyat ve operasyon önerileri'),
 ('accounting','supplier','Muhasebe ve Finans','Gelir, gider, hakediş ve mutabakat'),
 ('seo','supplier','SEO','İşletme ve ürün görünürlüğü'),
 ('translation','supplier','Çeviri','Ürün ve işletme içeriği yerelleştirme'),
 ('sales','supplier','Satış','Teklif, partner ve müşteri ilişkisi'),
 ('operations','supplier','Operasyon','Takvim, görev, rezervasyon ve hizmet'),
 ('reservations','supplier','Rezervasyon','Talep, opsiyon, rezervasyon ve voucher'),
 ('housekeeping','supplier','Kat Hizmetleri','Temizlik, bakım ve hazır olma'),
 ('procurement','supplier','Satın Alma','Malzeme, hizmet ve tedarik'),
 ('hr','supplier','İnsan Kaynakları','Personel, vardiya ve puantaj'),
 ('technology','supplier','Teknoloji','Entegrasyonlar, cihaz ve kullanıcı desteği'),
 ('compliance','supplier','Uyum ve Belgeler','Ruhsat, izin, sigorta ve belge süresi'),
 ('customer-service','supplier','Müşteri Hizmetleri','Misafir, acente ve şikâyet yönetimi');
CREATE FUNCTION organization.directory(p_workspace text) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[d.code,d.name,d.description,coalesce(od.status,'unassigned')] FROM organization.departments d LEFT JOIN organization.org_departments od ON od.department_code=d.code AND od.workspace=d.workspace AND od.organization_id=nullif(current_setting('app.tenant_id',true),'')::uuid WHERE d.workspace=p_workspace AND ((p_workspace='nexus' AND onboarding.operator()) OR (p_workspace='supplier' AND auth.workspace()='supplier')) ORDER BY d.name $$;
CREATE FUNCTION organization.assign(p_org text,p_workspace text,p_code text,p_status text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN IF auth.workspace()<>'nexus' OR NOT onboarding.operator() OR p_workspace NOT IN ('nexus','supplier') OR p_status NOT IN ('active','paused') THEN RETURN 'forbidden'; END IF; IF NOT EXISTS(SELECT FROM core.organizations WHERE id::text=p_org AND kind=p_workspace) OR NOT EXISTS(SELECT FROM organization.departments WHERE workspace=p_workspace AND code=p_code) THEN RETURN 'not_found'; END IF; INSERT INTO organization.org_departments(organization_id,department_code,workspace,status,lead_user_id) VALUES(p_org::uuid,p_code,p_workspace,p_status,nullif(current_setting('app.actor_id',true),'')::uuid) ON CONFLICT(organization_id,department_code) DO UPDATE SET status=EXCLUDED.status,lead_user_id=EXCLUDED.lead_user_id; RETURN 'ok'; END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA organization FROM PUBLIC;
GRANT USAGE ON SCHEMA organization TO nexus_app;
GRANT EXECUTE ON FUNCTION organization.directory(text),organization.assign(text,text,text,text) TO nexus_app;
