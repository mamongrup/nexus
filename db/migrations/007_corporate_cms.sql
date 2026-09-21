CREATE SCHEMA cms;
CREATE TABLE cms.pages (
 slug text PRIMARY KEY CHECK(slug ~ '^[a-z][a-z0-9-]{0,59}$'),
 title text NOT NULL, summary text NOT NULL, body text NOT NULL,
 published jsonb, version bigint NOT NULL DEFAULT 1, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE cms.revisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL REFERENCES cms.pages,
 version bigint NOT NULL, content jsonb NOT NULL, actor_id uuid NOT NULL REFERENCES auth.users,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(slug,version)
);
ALTER TABLE cms.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE cms.revisions ENABLE ROW LEVEL SECURITY;
INSERT INTO cms.pages(slug,title,summary,body) VALUES
 ('home','Seyahatin arkasındaki iş, tek bir yerde.','Tedarikçi, NEXUS ve acenteyi aynı operasyon akışında buluşturan seyahat yönetim programı.','Ürünlerinizi hazırlayın, iş ortaklarınızla buluşun ve rezervasyonlarınızı ortak bir çalışma alanından yönetin.'),
 ('program','Operasyonunuza ortak bir dil.','Üründen rezervasyona, her adımın izini takip edin.','NEXUS; tedarikçi ürünlerini, partner bağlantılarını, acente taleplerini ve rezervasyon durumlarını birlikte ele alır. Ayrı çalışma alanları, ekiplerin kendi sorumluluklarına odaklanmasını sağlar.'),
 ('tedarikci','Ürün sizin. Kontrol sizde.','Ürün, takvim ve fiyat yönetimini tek çalışma alanında birleştirin.','İlanlarınızı hazırlayın ve yayınlayın. Tarih bazlı fiyatları ve müsaitliği yönetin. Acente taleplerini inceleyin, uygun taleplere opsiyon verin ve rezervasyonları takip edin.'),
 ('acente','İş ortaklarınıza daha yakın olun.','Bağlı tedarikçilerin ürünlerinden rezervasyona uzanan bir çalışma alanı.','NEXUS üzerinden bağlantı kurduğunuz tedarikçilerin ürünlerini inceleyin. Tarih aralığı için opsiyon talep edin, onaylanan tutarı görün ve rezervasyonunuzu yönetin.'),
 ('hakkimizda','Seyahat teknolojisini birlikte kuruyoruz.','NEXUS TravelTech, seyahat işletmelerinin günlük operasyonlarına odaklanır.','Program yerel geliştirme ve doğrulama aşamasındadır. Mevcut sürüm; ürün, partner, opsiyon ve ödenmemiş rezervasyon akışlarını içerir. Ödeme ve yapay zekâ bağlantıları geliştirme kapsamındadır.');
UPDATE cms.pages SET published=jsonb_build_object('title',title,'summary',summary,'body',body);
CREATE FUNCTION cms.can_edit() RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT coalesce(auth.workspace()='nexus' AND EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND role IN ('owner','editor')),false);
$$;
CREATE FUNCTION cms.public_pages() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[slug,published->>'title',published->>'summary',published->>'body'] FROM cms.pages WHERE published IS NOT NULL ORDER BY slug;
$$;
CREATE FUNCTION cms.editor_pages() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[slug,title,summary,body,version::text,CASE WHEN published IS NULL THEN 'Yayında değil' WHEN published=jsonb_build_object('title',title,'summary',summary,'body',body) THEN 'Yayında' ELSE 'Yayınlanmamış değişiklikler' END] FROM cms.pages WHERE cms.can_edit() ORDER BY slug;
$$;
CREATE FUNCTION cms.save(p_slug text,p_title text,p_summary text,p_body text,p_version bigint) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cms.can_edit() THEN RETURN 'forbidden'; END IF;
 IF p_title IS NULL OR p_summary IS NULL OR p_body IS NULL OR length(trim(p_title)) NOT BETWEEN 3 AND 150 OR length(p_summary)>400 OR length(p_body)>10000 THEN RETURN 'invalid_setting'; END IF;
 UPDATE cms.pages SET title=p_title,summary=p_summary,body=p_body,version=version+1,updated_at=now() WHERE slug=p_slug AND version=p_version;
 IF NOT FOUND THEN RETURN 'setting_conflict'; END IF;
 INSERT INTO cms.revisions(slug,version,content,actor_id) VALUES(p_slug,p_version+1,jsonb_build_object('title',p_title,'summary',p_summary,'body',p_body),nullif(current_setting('app.actor_id',true),'')::uuid);
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,nullif(current_setting('app.actor_id',true),'')::uuid,'cms.draft_saved',gen_random_uuid(),jsonb_build_object('slug',p_slug,'version',p_version+1));
 RETURN 'ok';
END $$;
CREATE FUNCTION cms.publish(p_slug text,p_version bigint,p_publish boolean) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT cms.can_edit() OR NOT EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND role='owner') THEN RETURN 'forbidden'; END IF;
 UPDATE cms.pages SET published=CASE WHEN p_publish THEN jsonb_build_object('title',title,'summary',summary,'body',body) ELSE NULL END,version=version+1,updated_at=now() WHERE slug=p_slug AND version=p_version;
 IF NOT FOUND THEN RETURN 'setting_conflict'; END IF;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(nullif(current_setting('app.tenant_id',true),'')::uuid,nullif(current_setting('app.actor_id',true),'')::uuid,'cms.publication_changed',gen_random_uuid(),jsonb_build_object('slug',p_slug,'published',p_publish));
 RETURN 'ok';
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA cms FROM PUBLIC;
GRANT USAGE ON SCHEMA cms TO nexus_app;
GRANT EXECUTE ON FUNCTION cms.public_pages(),cms.editor_pages(),cms.save(text,text,text,text,bigint),cms.publish(text,bigint,boolean) TO nexus_app;
