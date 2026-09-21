CREATE SCHEMA onboarding;
CREATE TABLE onboarding.categories (
 code text PRIMARY KEY, name text NOT NULL, description text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT true
);
INSERT INTO onboarding.categories(code,name,description) VALUES
 ('villa','Villa / tatil evi','Konaklama tesisi ve özel konut'),
 ('hotel','Otel / konaklama tesisi','Otel, apart ve pansiyon'),
 ('tour','Tur / deneyim','Günübirlik tur, aktivite ve deneyim'),
 ('transfer','Transfer / ulaşım','Havalimanı, araç ve özel transfer'),
 ('restaurant','Restoran / gastronomi','Masa, menü ve gastronomi deneyimi');
CREATE TABLE onboarding.requirements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_code text NOT NULL REFERENCES onboarding.categories, code text NOT NULL, label text NOT NULL, kind text NOT NULL CHECK(kind IN ('text','number','date','document','boolean')), required boolean NOT NULL DEFAULT true, position int NOT NULL, UNIQUE(category_code,code)
);
INSERT INTO onboarding.requirements(category_code,code,label,kind,required,position) VALUES
 ('villa','license','Turizm / işletme izin belgesi','document',true,10),('villa','address','Tesis açık adresi','text',true,20),('villa','capacity','Misafir kapasitesi','number',true,30),
 ('hotel','license','İşletme belgesi','document',true,10),('hotel','address','Tesis adresi','text',true,20),('hotel','rooms','Oda sayısı','number',true,30),
 ('tour','license','Turizm işletme belgesi','document',true,10),('tour','insurance','Sorumluluk sigortası','document',true,20),('tour','route','Tur / rota açıklaması','text',true,30),
 ('transfer','license','Taşımacılık / yetki belgesi','document',true,10),('transfer','vehicles','Araç bilgileri','text',true,20),('transfer','insurance','Sigorta belgesi','document',true,30),
 ('restaurant','license','İşyeri açma ruhsatı','document',true,10),('restaurant','address','İşyeri adresi','text',true,20),('restaurant','capacity','Masa kapasitesi','number',true,30);
CREATE TABLE onboarding.applications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_user_id uuid NOT NULL REFERENCES auth.users, tenant_id uuid REFERENCES core.organizations, category_code text NOT NULL REFERENCES onboarding.categories,
 legal_name text NOT NULL, status text NOT NULL DEFAULT 'identity_pending' CHECK(status IN ('identity_pending','identity_failed','documents_pending','review','approved','rejected','deleted')),
 identity_status text NOT NULL DEFAULT 'pending' CHECK(identity_status IN ('pending','verified','failed','manual_review')), identity_provider text NOT NULL DEFAULT 'nvi_kps', identity_checked_at timestamptz, identity_reference text,
 data jsonb NOT NULL DEFAULT '{}', rejection_reason text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE onboarding.documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), application_id uuid NOT NULL REFERENCES onboarding.applications ON DELETE CASCADE, requirement_id uuid NOT NULL REFERENCES onboarding.requirements, storage_key text NOT NULL, original_name text NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected')), reviewed_by uuid REFERENCES auth.users, reviewed_at timestamptz
);
CREATE TABLE onboarding.identity_checks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), application_id uuid NOT NULL REFERENCES onboarding.applications ON DELETE CASCADE, provider text NOT NULL, request_hash text NOT NULL, result text NOT NULL CHECK(result IN ('verified','failed','manual_review')), response_code text, checked_at timestamptz NOT NULL DEFAULT now(), UNIQUE(application_id,request_hash)
);
CREATE TABLE onboarding.syndication_targets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, base_url text NOT NULL, active boolean NOT NULL DEFAULT true, adapter text NOT NULL DEFAULT 'nexus_corporate', settings_key text
);
INSERT INTO onboarding.syndication_targets(name,base_url,adapter) VALUES ('NEXUS ana site','https://nexustraveltech.com','nexus_corporate') ON CONFLICT DO NOTHING;
CREATE TABLE onboarding.syndication_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), application_id uuid NOT NULL REFERENCES onboarding.applications, target_id uuid NOT NULL REFERENCES onboarding.syndication_targets, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sent','failed')), attempts int NOT NULL DEFAULT 0, last_error text, sent_at timestamptz, UNIQUE(application_id,target_id)
);
ALTER TABLE onboarding.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding.identity_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding.syndication_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding.syndication_events ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION onboarding.operator() RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT coalesce(auth.workspace()='nexus' AND EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND role IN ('owner','editor')),false) $$;
CREATE FUNCTION onboarding.categories_for_signup() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[code,name,description] FROM onboarding.categories WHERE active ORDER BY name $$;
CREATE FUNCTION onboarding.requirements_for(p_category text) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[code,label,kind,required::text] FROM onboarding.requirements WHERE category_code=p_category ORDER BY position $$;
CREATE FUNCTION onboarding.apply(p_category text,p_legal_name text,p_data jsonb) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid; id uuid; BEGIN IF NOT EXISTS(SELECT FROM onboarding.categories WHERE code=p_category AND active) OR length(trim(p_legal_name)) NOT BETWEEN 2 AND 180 THEN RETURN 'invalid_application'; END IF; INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,data) VALUES(u,t,p_category,p_legal_name,coalesce(p_data,'{}')) RETURNING id INTO id; INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,u,'onboarding.submitted',id,jsonb_build_object('category',p_category)); RETURN id::text; END $$;
CREATE FUNCTION onboarding.identity_result(p_application text,p_result text,p_provider text,p_reference text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a onboarding.applications%ROWTYPE; h text:=encode(public.digest(coalesce(p_application,'')||coalesce(p_provider,'')||coalesce(p_reference,''),'sha256'),'hex'); BEGIN IF NOT onboarding.operator() OR p_result NOT IN ('verified','failed','manual_review') THEN RETURN 'forbidden'; END IF; SELECT * INTO a FROM onboarding.applications WHERE id::text=p_application FOR UPDATE; IF NOT FOUND THEN RETURN 'not_found'; END IF; INSERT INTO onboarding.identity_checks(application_id,provider,request_hash,result,response_code) VALUES(a.id,p_provider,h,p_result,p_reference) ON CONFLICT DO NOTHING; UPDATE onboarding.applications SET identity_status=p_result,identity_provider=p_provider,identity_checked_at=now(),identity_reference=p_reference,status=CASE WHEN p_result='verified' THEN 'documents_pending' WHEN p_result='failed' THEN 'identity_failed' ELSE 'review' END,updated_at=now() WHERE id=a.id; RETURN 'ok'; END $$;
CREATE FUNCTION onboarding.decide(p_application text,p_decision text,p_reason text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a onboarding.applications%ROWTYPE; BEGIN IF NOT onboarding.operator() OR p_decision NOT IN ('approved','rejected','deleted') THEN RETURN 'forbidden'; END IF; SELECT * INTO a FROM onboarding.applications WHERE id::text=p_application FOR UPDATE; IF NOT FOUND THEN RETURN 'not_found'; END IF; IF p_decision='approved' AND (a.identity_status<>'verified' OR EXISTS(SELECT FROM onboarding.requirements r WHERE r.category_code=a.category_code AND r.required AND NOT EXISTS(SELECT FROM onboarding.documents d WHERE d.application_id=a.id AND d.requirement_id=r.id AND d.status='accepted'))) THEN RETURN 'requirements_incomplete'; END IF; UPDATE onboarding.applications SET status=p_decision,rejection_reason=CASE WHEN p_decision='rejected' THEN p_reason ELSE NULL END,updated_at=now() WHERE id=a.id; IF p_decision='approved' THEN INSERT INTO onboarding.syndication_events(application_id,target_id) SELECT a.id,id FROM onboarding.syndication_targets WHERE active ON CONFLICT DO NOTHING; END IF; INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(a.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'onboarding.'||p_decision,a.id,jsonb_build_object('reason',p_reason)); RETURN 'ok'; END $$;
CREATE FUNCTION onboarding.queue() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[a.id::text,a.legal_name,c.name,a.identity_status,a.status,a.created_at::text] FROM onboarding.applications a JOIN onboarding.categories c ON c.code=a.category_code WHERE onboarding.operator() AND a.status NOT IN ('approved','rejected','deleted') ORDER BY a.created_at DESC LIMIT 200 $$;
CREATE FUNCTION onboarding.publishable() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT ARRAY[a.id::text,a.legal_name,c.name,a.status] FROM onboarding.applications a JOIN onboarding.categories c ON c.code=a.category_code WHERE a.status='approved' $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA onboarding FROM PUBLIC;
GRANT USAGE ON SCHEMA onboarding TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.categories_for_signup(),onboarding.requirements_for(text),onboarding.apply(text,text,jsonb),onboarding.identity_result(text,text,text,text),onboarding.decide(text,text,text),onboarding.queue(),onboarding.publishable() TO nexus_app;
