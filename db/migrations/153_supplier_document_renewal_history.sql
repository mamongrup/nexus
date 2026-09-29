ALTER TABLE onboarding.documents ADD COLUMN IF NOT EXISTS expires_on date;

CREATE TABLE IF NOT EXISTS onboarding.document_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES onboarding.documents(id) ON DELETE CASCADE,
  application_id uuid NOT NULL REFERENCES onboarding.applications(id) ON DELETE CASCADE,
  requirement_id uuid NOT NULL REFERENCES onboarding.requirements(id),
  storage_key text NOT NULL,
  original_name text NOT NULL,
  status text NOT NULL,
  expires_on date,
  reviewed_by uuid,
  reviewed_at timestamptz,
  replaced_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION onboarding.archive_document_revision()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF OLD.storage_key IS DISTINCT FROM NEW.storage_key THEN
    INSERT INTO onboarding.document_revisions(document_id,application_id,requirement_id,storage_key,original_name,status,expires_on,reviewed_by,reviewed_at)
      VALUES(OLD.id,OLD.application_id,OLD.requirement_id,OLD.storage_key,OLD.original_name,OLD.status,OLD.expires_on,OLD.reviewed_by,OLD.reviewed_at);
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS archive_document_revision ON onboarding.documents;
CREATE TRIGGER archive_document_revision BEFORE UPDATE ON onboarding.documents
FOR EACH ROW EXECUTE FUNCTION onboarding.archive_document_revision();

CREATE OR REPLACE FUNCTION onboarding.register_document(p_application text,p_requirement text,p_url text,p_name text,p_expires text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a onboarding.applications%ROWTYPE; expiry date;
BEGIN
  SELECT * INTO a FROM onboarding.applications WHERE id::text=p_application FOR UPDATE;
  IF NOT FOUND OR auth.workspace()<>'supplier' OR a.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid OR a.owner_user_id<>nullif(current_setting('app.actor_id',true),'')::uuid THEN RETURN 'forbidden'; END IF;
  IF a.status IN ('rejected','deleted') THEN RETURN 'invalid_state'; END IF;
  IF p_url !~ '^upload:[A-Za-z0-9_-]{20,80}\.(pdf|jpg|jpeg|png)$' OR length(trim(p_name)) NOT BETWEEN 2 AND 255 THEN RETURN 'invalid_document'; END IF;
  IF NOT EXISTS(SELECT 1 FROM onboarding.requirements WHERE id::text=p_requirement AND category_code=a.category_code) THEN RETURN 'not_found'; END IF;
  IF nullif(trim(coalesce(p_expires,'')),'') IS NOT NULL THEN
    IF p_expires !~ '^\d{4}-\d{2}-\d{2}$' THEN RETURN 'invalid_expiry'; END IF;
    expiry := p_expires::date;
    IF expiry<current_date THEN RETURN 'invalid_expiry'; END IF;
  END IF;
  INSERT INTO onboarding.documents(application_id,requirement_id,storage_key,original_name,status,reviewed_by,reviewed_at,expires_on)
    VALUES(a.id,p_requirement::uuid,p_url,trim(p_name),'pending',null,null,expiry)
    ON CONFLICT(application_id,requirement_id) DO UPDATE SET storage_key=excluded.storage_key,original_name=excluded.original_name,status='pending',reviewed_by=null,reviewed_at=null,expires_on=excluded.expires_on;
  UPDATE onboarding.applications SET status='review',updated_at=now() WHERE id=a.id AND identity_status IN ('verified','manual_review');
  INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
    VALUES(a.tenant_id,a.owner_user_id,'supplier.document_submitted',a.id,jsonb_build_object('requirement',p_requirement,'expires_on',expiry));
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION onboarding.my_application_documents(p_application text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[r.id::text,r.label,r.required::text,coalesce(d.original_name,''),coalesce(d.storage_key,''),
   CASE WHEN d.expires_on<current_date THEN 'expired' ELSE coalesce(d.status,'missing') END,coalesce(d.expires_on::text,'')]
 FROM onboarding.applications a JOIN onboarding.requirements r ON r.category_code=a.category_code
 LEFT JOIN onboarding.documents d ON d.application_id=a.id AND d.requirement_id=r.id
 WHERE a.id::text=p_application AND auth.workspace()='supplier'
   AND a.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
   AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid
 ORDER BY r.position,r.label;
$$;

CREATE OR REPLACE FUNCTION onboarding.review_document(p_document text,p_status text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_tenant uuid; v_application uuid;
BEGIN
  IF NOT onboarding.operator() OR p_status NOT IN ('accepted','rejected') THEN RETURN 'forbidden'; END IF;
  SELECT a.tenant_id,a.id INTO v_tenant,v_application FROM onboarding.documents d
    JOIN onboarding.applications a ON a.id=d.application_id
    WHERE d.id::text=p_document AND d.status='pending' AND (d.expires_on IS NULL OR d.expires_on>=current_date)
    FOR UPDATE OF d;
  IF v_application IS NULL THEN RETURN 'not_found_or_expired'; END IF;
  UPDATE onboarding.documents SET status=p_status,reviewed_by=nullif(current_setting('app.actor_id',true),'')::uuid,reviewed_at=now()
    WHERE id::text=p_document;
  INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
    VALUES(v_tenant,nullif(current_setting('app.actor_id',true),'')::uuid,'supplier.document_reviewed',p_document::uuid,jsonb_build_object('status',p_status));
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION onboarding.expiring_documents(p_days int DEFAULT 30)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[a.legal_name,r.label,d.original_name,d.expires_on::text,d.status]
 FROM onboarding.documents d JOIN onboarding.applications a ON a.id=d.application_id
 JOIN onboarding.requirements r ON r.id=d.requirement_id
 WHERE onboarding.operator() AND d.expires_on IS NOT NULL AND d.expires_on<=current_date+least(greatest(p_days,0),365)
 ORDER BY d.expires_on,a.legal_name LIMIT 200;
$$;

REVOKE ALL ON FUNCTION onboarding.register_document(text,text,text,text,text),onboarding.expiring_documents(int) FROM PUBLIC;
GRANT SELECT ON onboarding.document_revisions TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.register_document(text,text,text,text,text),onboarding.expiring_documents(int) TO nexus_app;
