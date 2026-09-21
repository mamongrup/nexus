CREATE OR REPLACE FUNCTION onboarding.apply(p_category text,p_legal_name text,p_data jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid; application_uuid uuid;
BEGIN
 IF auth.workspace()<>'supplier' OR t IS NULL OR u IS NULL OR NOT EXISTS(SELECT FROM onboarding.categories WHERE code=p_category AND active) OR length(trim(p_legal_name)) NOT BETWEEN 2 AND 180 THEN RETURN 'invalid_application'; END IF;
 IF EXISTS(SELECT FROM onboarding.applications WHERE tenant_id=t AND owner_user_id=u AND status NOT IN ('rejected','deleted')) THEN RETURN 'already_applied'; END IF;
 INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,data) VALUES(u,t,p_category,trim(p_legal_name),coalesce(p_data,'{}')) RETURNING onboarding.applications.id INTO application_uuid;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,u,'onboarding.submitted',application_uuid,jsonb_build_object('category',p_category));
 RETURN application_uuid::text;
END $$;

CREATE FUNCTION onboarding.categories_for_listing() RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[c.code,c.name,c.description] FROM onboarding.categories c
 WHERE c.active AND (onboarding.operator() OR EXISTS(
 SELECT FROM onboarding.applications a WHERE a.category_code=c.code AND a.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
 AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid AND a.status='approved'))
 ORDER BY c.name
$$;

CREATE OR REPLACE FUNCTION catalog.submit_for_review(p_id text,p_version int)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND OR auth.workspace()<>'supplier' OR p.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid
 OR NOT EXISTS(SELECT FROM auth.users u WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.tenant_id=p.tenant_id AND u.role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 IF NOT EXISTS(SELECT FROM onboarding.applications a WHERE a.tenant_id=p.tenant_id AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid AND a.category_code=p.category_code AND a.status='approved') THEN RETURN 'supplier_not_approved'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p.moderation_status NOT IN ('draft','changes_requested') THEN RETURN 'invalid_state'; END IF;
 IF trim(p.description)='' OR trim(p.seo_title)='' OR trim(p.seo_description)='' OR EXISTS(SELECT FROM onboarding.category_fields f WHERE f.category_code=p.category_code AND f.active AND f.required AND coalesce(trim(p.attributes->>f.field_code),'')='') THEN RETURN 'requirements_incomplete'; END IF;
 UPDATE catalog.properties SET status='draft',moderation_status='in_review',review_note='',submitted_at=now(),version=version+1,updated_at=now() WHERE id=p.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(p.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.submitted',p.id,jsonb_build_object('category',p.category_code));
 RETURN 'ok';
END $$;
REVOKE ALL ON FUNCTION onboarding.categories_for_listing() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding.categories_for_listing() TO nexus_app;
