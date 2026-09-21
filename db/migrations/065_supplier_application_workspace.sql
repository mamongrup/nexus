ALTER TABLE onboarding.documents ADD CONSTRAINT documents_application_requirement_unique UNIQUE(application_id,requirement_id);

CREATE FUNCTION onboarding.my_application() RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[a.id::text,a.category_code,a.legal_name,a.status,a.identity_status,a.created_at::text]
 FROM onboarding.applications a
 WHERE auth.workspace()='supplier' AND a.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
 AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid
 ORDER BY a.created_at DESC LIMIT 1
$$;

CREATE FUNCTION onboarding.my_application_documents(p_application text) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[r.id::text,r.label,r.required::text,coalesce(d.original_name,''),coalesce(d.storage_key,''),coalesce(d.status,'missing')]
 FROM onboarding.applications a JOIN onboarding.requirements r ON r.category_code=a.category_code
 LEFT JOIN onboarding.documents d ON d.application_id=a.id AND d.requirement_id=r.id
 WHERE a.id::text=p_application AND auth.workspace()='supplier'
 AND a.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid
 ORDER BY r.position,r.label
$$;

CREATE FUNCTION onboarding.register_document(p_application text,p_requirement text,p_url text,p_name text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a onboarding.applications%ROWTYPE;
BEGIN
 SELECT * INTO a FROM onboarding.applications WHERE id::text=p_application FOR UPDATE;
 IF NOT FOUND OR auth.workspace()<>'supplier' OR a.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid OR a.owner_user_id<>nullif(current_setting('app.actor_id',true),'')::uuid THEN RETURN 'forbidden'; END IF;
 IF a.status IN ('approved','rejected','deleted') THEN RETURN 'invalid_state'; END IF;
 IF p_url !~ '^https://[^[:space:]]{5,1000}$' OR length(trim(p_name)) NOT BETWEEN 2 AND 255 THEN RETURN 'invalid_document'; END IF;
 IF NOT EXISTS(SELECT FROM onboarding.requirements WHERE id::text=p_requirement AND category_code=a.category_code) THEN RETURN 'not_found'; END IF;
 INSERT INTO onboarding.documents(application_id,requirement_id,storage_key,original_name,status,reviewed_by,reviewed_at)
 VALUES(a.id,p_requirement::uuid,p_url,trim(p_name),'pending',null,null)
 ON CONFLICT(application_id,requirement_id) DO UPDATE SET storage_key=excluded.storage_key,original_name=excluded.original_name,status='pending',reviewed_by=null,reviewed_at=null;
 UPDATE onboarding.applications SET status='review',updated_at=now() WHERE id=a.id AND identity_status IN ('verified','manual_review');
 RETURN 'ok';
END $$;

CREATE FUNCTION onboarding.documents_for_review() RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[d.id::text,a.legal_name,r.label,d.original_name,d.storage_key,d.status]
 FROM onboarding.documents d JOIN onboarding.applications a ON a.id=d.application_id JOIN onboarding.requirements r ON r.id=d.requirement_id
 WHERE onboarding.operator() ORDER BY (d.status='pending') DESC,a.updated_at DESC
$$;

CREATE FUNCTION onboarding.review_document(p_document text,p_status text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT onboarding.operator() OR p_status NOT IN ('accepted','rejected') THEN RETURN 'forbidden'; END IF;
 UPDATE onboarding.documents SET status=p_status,reviewed_by=nullif(current_setting('app.actor_id',true),'')::uuid,reviewed_at=now() WHERE id::text=p_document;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 RETURN 'ok';
END $$;

REVOKE ALL ON FUNCTION onboarding.my_application(),onboarding.my_application_documents(text),onboarding.register_document(text,text,text,text),onboarding.documents_for_review(),onboarding.review_document(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding.my_application(),onboarding.my_application_documents(text),onboarding.register_document(text,text,text,text),onboarding.documents_for_review(),onboarding.review_document(text,text) TO nexus_app;
