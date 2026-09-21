CREATE OR REPLACE FUNCTION onboarding.register_document(p_application text,p_requirement text,p_url text,p_name text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a onboarding.applications%ROWTYPE;
BEGIN
 SELECT * INTO a FROM onboarding.applications WHERE id::text=p_application FOR UPDATE;
 IF NOT FOUND OR auth.workspace()<>'supplier' OR a.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid OR a.owner_user_id<>nullif(current_setting('app.actor_id',true),'')::uuid THEN RETURN 'forbidden'; END IF;
 IF a.status IN ('approved','rejected','deleted') THEN RETURN 'invalid_state'; END IF;
 IF left(p_url,8)<>'https://' OR p_url~'[[:space:]]' OR length(p_url) NOT BETWEEN 14 AND 1000 OR length(trim(p_name)) NOT BETWEEN 2 AND 255 THEN RETURN 'invalid_document'; END IF;
 IF NOT EXISTS(SELECT FROM onboarding.requirements WHERE id::text=p_requirement AND category_code=a.category_code) THEN RETURN 'not_found'; END IF;
 INSERT INTO onboarding.documents(application_id,requirement_id,storage_key,original_name,status,reviewed_by,reviewed_at)
 VALUES(a.id,p_requirement::uuid,p_url,trim(p_name),'pending',null,null)
 ON CONFLICT(application_id,requirement_id) DO UPDATE SET storage_key=excluded.storage_key,original_name=excluded.original_name,status='pending',reviewed_by=null,reviewed_at=null;
 UPDATE onboarding.applications SET status='review',updated_at=now() WHERE id=a.id AND identity_status IN ('verified','manual_review');
 RETURN 'ok';
END $$;
