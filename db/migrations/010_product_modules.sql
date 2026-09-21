CREATE TABLE onboarding.product_modules (
 code text PRIMARY KEY, family text NOT NULL CHECK(family IN ('hotel','pos','erp','other')), name text NOT NULL, slug text NOT NULL UNIQUE,
 description text NOT NULL, active boolean NOT NULL DEFAULT true, page_slug text NOT NULL REFERENCES cms.pages(slug)
);
CREATE TABLE onboarding.supplier_modules (
 supplier_id uuid NOT NULL REFERENCES core.organizations, module_code text NOT NULL REFERENCES onboarding.product_modules, status text NOT NULL DEFAULT 'assigned' CHECK(status IN ('assigned','enabled','paused')), assigned_by uuid NOT NULL REFERENCES auth.users, assigned_at timestamptz NOT NULL DEFAULT now(), UNIQUE(supplier_id,module_code)
);
INSERT INTO cms.pages(slug,title,summary,body) VALUES
 ('modul-pms','Ön Büro (PMS) & Oda Yönetimi','Oda, rezervasyon, misafir ve günlük operasyonu tek ekranda yönetin.','PMS modülü; tesis envanterini, oda durumunu, rezervasyon akışını ve operasyon notlarını aynı çalışma alanında toplar.'),
 ('modul-online-rezervasyon','Online Rezervasyon Motoru','Doğrudan satış kanalınızı kendi kurallarınızla yönetin.','Fiyat, müsaitlik ve rezervasyon adımlarını NEXUS altyapısında birleştirin.'),
 ('modul-channel-manager','Kanal Yönetimi','Dağıtım kanallarındaki fiyat ve müsaitliği senkron tutun.','Kanal bağlantıları için sağlayıcı adaptörleri, idempotent güncelleme ve hata kuyruğu.'),
 ('modul-dinamik-fiyat','Dinamik Fiyatlandırma (AI)','Talep ve müsaitliğe göre fiyat önerileri üretin.','AI fiyat önerileri insan onayı ve bütçe sınırlarıyla çalışır.'),
 ('modul-pos','Restoran POS Yönetim Programı','Masa, satış ve operasyon akışını yönetin.','Restoran işletmeleri için POS, masa ve vardiya süreçlerini ortak veriyle izleyin.'),
 ('modul-erp','Muhasebe & Cari Yönetimi','Operasyon verisini finansal görünürlükle birleştirin.','Cari, stok, satın alma ve finans bağlantılarını tek program çatısında yönetin.'),
 ('modul-tur-operatoru','Tur Operatörü & Paket Tur','Paketleri, kontenjanı ve satış kanallarını yönetin.','Tur ve paket ürünlerinin içerik, fiyat ve rezervasyon akışını yönetin.'),
 ('modul-villa','Villa & Devremülk Yönetimi','Özel konut envanterini takvim ve fiyatla yönetin.','Villa ve devremülk tedarikçileri için ürün, belge, müsaitlik ve talep yönetimi.');
INSERT INTO onboarding.product_modules(code,family,name,slug,description,page_slug) VALUES
 ('pms','hotel','Ön Büro (PMS) & Oda Yönetimi','modul-pms','Oda, rezervasyon ve misafir operasyonu.','modul-pms'),
 ('booking-engine','hotel','Online Rezervasyon Motoru','modul-online-rezervasyon','Doğrudan rezervasyon kanalı.','modul-online-rezervasyon'),
 ('channel-manager','hotel','Kanal Yönetimi (Channel Manager)','modul-channel-manager','Dağıtım kanalı senkronizasyonu.','modul-channel-manager'),
 ('dynamic-pricing','hotel','Dinamik Fiyatlandırma (AI)','modul-dinamik-fiyat','AI destekli fiyat önerisi.','modul-dinamik-fiyat'),
 ('restaurant-pos','pos','Restoran POS Yönetim Programı','modul-pos','Masa ve satış yönetimi.','modul-pos'),
 ('erp-finance','erp','Muhasebe & Cari Yönetimi','modul-erp','Cari, stok ve finans bağlantısı.','modul-erp'),
 ('tour-operator','other','Tur Operatörü & Paket Tur','modul-tur-operatoru','Tur ve paket yönetimi.','modul-tur-operatoru'),
 ('villa-management','other','Villa & Devremülk Yönetimi','modul-villa','Villa envanter ve takvim yönetimi.','modul-villa');
CREATE FUNCTION onboarding.module_directory() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[m.code,m.family,m.name,m.description,coalesce(count(sm.supplier_id),0)::text] FROM onboarding.product_modules m LEFT JOIN onboarding.supplier_modules sm ON sm.module_code=m.code AND sm.status<>'paused' WHERE onboarding.operator() GROUP BY m.code,m.family,m.name,m.description ORDER BY m.family,m.name $$;
CREATE FUNCTION onboarding.assign_module(p_supplier text,p_module text,p_status text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN IF NOT onboarding.operator() OR p_status NOT IN ('assigned','enabled','paused') THEN RETURN 'forbidden'; END IF; IF NOT EXISTS(SELECT FROM core.organizations WHERE id::text=p_supplier AND kind='supplier') OR NOT EXISTS(SELECT FROM onboarding.product_modules WHERE code=p_module AND active) THEN RETURN 'not_found'; END IF; INSERT INTO onboarding.supplier_modules(supplier_id,module_code,status,assigned_by) VALUES(p_supplier::uuid,p_module,p_status,nullif(current_setting('app.actor_id',true),'')::uuid) ON CONFLICT(supplier_id,module_code) DO UPDATE SET status=EXCLUDED.status,assigned_by=EXCLUDED.assigned_by,assigned_at=now(); RETURN 'ok'; END $$;
CREATE FUNCTION onboarding.supplier_module_catalog(p_supplier text) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[m.code,m.name,sm.status,m.page_slug] FROM onboarding.supplier_modules sm JOIN onboarding.product_modules m ON m.code=sm.module_code WHERE sm.supplier_id::text=p_supplier AND onboarding.operator() ORDER BY m.name $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA onboarding FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding.module_directory(),onboarding.assign_module(text,text,text),onboarding.supplier_module_catalog(text) TO nexus_app;
