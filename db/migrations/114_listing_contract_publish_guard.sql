-- Shared supplier/listing contract guard for NEXUS central supplier panel.
-- The acente project stores the same versioned category/listing contract locally;
-- this side validates NEXUS listings against onboarding.category_fields.

CREATE OR REPLACE FUNCTION catalog.listing_contract_required_complete(p_property_id text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path=pg_catalog
AS $$
 SELECT NOT EXISTS (
   SELECT 1
   FROM catalog.properties p
   JOIN onboarding.category_fields f
     ON f.category_code = p.category_code
    AND f.active
    AND f.required
   WHERE p.id::text = p_property_id
     AND nullif(trim(coalesce(p.attributes->>f.field_code, '')), '') IS NULL
 )
$$;

COMMENT ON FUNCTION catalog.listing_contract_required_complete(text)
IS 'Returns true when every active required category field from the shared supplier/listing contract is present on the listing attributes.';

CREATE OR REPLACE FUNCTION catalog.submit_for_review(p_id text,p_version int)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog
AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND OR auth.workspace()<>'supplier' OR p.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid
 OR NOT EXISTS(SELECT FROM auth.users u WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.tenant_id=p.tenant_id AND u.role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 IF NOT EXISTS(SELECT FROM onboarding.applications a WHERE a.tenant_id=p.tenant_id AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid AND a.category_code=p.category_code AND a.status='approved') THEN RETURN 'supplier_not_approved'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p.moderation_status NOT IN ('draft','changes_requested') THEN RETURN 'invalid_state'; END IF;
 IF trim(p.description)='' OR trim(p.seo_title)='' OR trim(p.seo_description)='' OR NOT catalog.listing_contract_required_complete(p.id::text) THEN RETURN 'requirements_incomplete'; END IF;
 UPDATE catalog.properties SET status='draft',moderation_status='in_review',review_note='',submitted_at=now(),version=version+1,updated_at=now() WHERE id=p.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(p.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.submitted',p.id,jsonb_build_object('category',p.category_code,'contract_version','1.0.0'));
 RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.review_listing(p_id text,p_version int,p_decision text,p_note text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog
AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 IF NOT onboarding.operator() THEN RETURN 'forbidden'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p_decision NOT IN ('approved','changes_requested','suspended') THEN RETURN 'invalid_decision'; END IF;
 IF p_decision='approved' AND p.moderation_status<>'in_review' THEN RETURN 'invalid_state'; END IF;
 IF p_decision='approved' AND NOT catalog.listing_contract_required_complete(p.id::text) THEN RETURN 'requirements_incomplete'; END IF;
 UPDATE catalog.properties SET
  moderation_status=p_decision,
  review_note=coalesce(p_note,''),
  reviewed_at=now(),
  reviewed_by=nullif(current_setting('app.actor_id',true),'')::uuid,
  status=CASE WHEN p_decision='approved' THEN 'published' ELSE 'draft' END,
  last_confirmed_at=CASE WHEN p_decision='approved' THEN now() ELSE last_confirmed_at END,
  version=version+1,
  updated_at=now()
 WHERE id=p.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(p.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.reviewed',p.id,jsonb_build_object('decision',p_decision,'note',p_note,'contract_version','1.0.0'));
 RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.admin_publish(p_id text,p_version int,p_status text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog
AS $$
BEGIN
 IF NOT onboarding.operator() THEN RETURN false; END IF;
 IF p_status NOT IN ('published','draft') THEN RETURN false; END IF;
 IF p_status='published' AND NOT catalog.listing_contract_required_complete(p_id) THEN RETURN false; END IF;
 UPDATE catalog.properties SET status=p_status,version=version+1,updated_at=now()
 WHERE id::text=p_id AND version=p_version;
 RETURN FOUND;
END $$;

REVOKE ALL ON FUNCTION catalog.listing_contract_required_complete(text), catalog.submit_for_review(text,int), catalog.review_listing(text,int,text,text), catalog.admin_publish(text,int,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.listing_contract_required_complete(text), catalog.submit_for_review(text,int), catalog.review_listing(text,int,text,text), catalog.admin_publish(text,int,text) TO nexus_app;
