CREATE OR REPLACE FUNCTION onboarding.apply(p_category text,p_legal_name text,p_data jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid; application_uuid uuid; full_name text:=trim(coalesce(p_data->>'full_name','')); tc text:=trim(coalesce(p_data->>'tc',''));
BEGIN
 IF auth.workspace()<>'supplier' OR t IS NULL OR u IS NULL OR NOT EXISTS(SELECT FROM onboarding.categories WHERE code=p_category AND active) OR length(trim(p_legal_name)) NOT BETWEEN 2 AND 180 OR length(full_name) NOT BETWEEN 5 AND 120 OR tc !~ '^[0-9]{11}$' THEN RETURN 'invalid_application'; END IF;
 IF EXISTS(SELECT FROM onboarding.applications WHERE tenant_id=t AND owner_user_id=u AND status NOT IN ('rejected','deleted')) THEN RETURN 'already_applied'; END IF;
 INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,data,identity_status,identity_provider,status,identity_reference)
 VALUES(u,t,p_category,trim(p_legal_name),jsonb_build_object('full_name',full_name,'tc_digest',encode(public.digest(tc,'sha256'),'hex')),'manual_review','nvi_kps','review','automatic_check_queued') RETURNING id INTO application_uuid;
 INSERT INTO onboarding.identity_checks(application_id,provider,request_hash,result,response_code) VALUES(application_uuid,'nvi_kps',encode(public.digest(application_uuid::text||tc,'sha256'),'hex'),'manual_review','queued') ON CONFLICT DO NOTHING;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(t,u,'onboarding.identity_check_queued',application_uuid,jsonb_build_object('provider','nvi_kps','mode','automatic_then_manual_fallback'));
 RETURN application_uuid::text;
END $$;
