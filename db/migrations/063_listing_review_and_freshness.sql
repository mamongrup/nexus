ALTER TABLE catalog.properties
  ADD COLUMN moderation_status text NOT NULL DEFAULT 'draft'
    CHECK (moderation_status IN ('draft','in_review','approved','changes_requested','suspended')),
  ADD COLUMN review_note text NOT NULL DEFAULT '',
  ADD COLUMN submitted_at timestamptz,
  ADD COLUMN reviewed_at timestamptz,
  ADD COLUMN reviewed_by uuid REFERENCES auth.users(id),
  ADD COLUMN last_confirmed_at timestamptz;

UPDATE catalog.properties SET moderation_status='approved',reviewed_at=updated_at,last_confirmed_at=updated_at
WHERE status='published';

CREATE OR REPLACE FUNCTION catalog.submit_for_review(p_id text,p_version int)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND OR auth.workspace()<>'supplier' OR p.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid
 OR NOT EXISTS(SELECT FROM auth.users u WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.tenant_id=p.tenant_id AND u.role IN ('owner','editor'))
 THEN RETURN 'forbidden'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p.moderation_status NOT IN ('draft','changes_requested') THEN RETURN 'invalid_state'; END IF;
 IF trim(p.description)='' OR trim(p.seo_title)='' OR trim(p.seo_description)='' OR
 EXISTS(SELECT FROM onboarding.category_fields f WHERE f.category_code=p.category_code AND f.active AND f.required AND coalesce(trim(p.attributes->>f.field_code),'')='')
 THEN RETURN 'requirements_incomplete'; END IF;
 UPDATE catalog.properties SET status='draft',moderation_status='in_review',review_note='',submitted_at=now(),version=version+1,updated_at=now() WHERE id=p.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(p.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.submitted',p.id,jsonb_build_object('category',p.category_code));
 RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.review_listing(p_id text,p_version int,p_decision text,p_note text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 IF NOT onboarding.operator() OR p_decision NOT IN ('approved','changes_requested','suspended') THEN RETURN 'forbidden'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p_decision='approved' AND p.moderation_status<>'in_review' THEN RETURN 'invalid_state'; END IF;
 IF p_decision IN ('changes_requested','suspended') AND trim(coalesce(p_note,''))='' THEN RETURN 'reason_required'; END IF;
 UPDATE catalog.properties SET
 status=CASE WHEN p_decision='approved' THEN 'published' ELSE 'draft' END,
 moderation_status=p_decision,review_note=coalesce(p_note,''),reviewed_at=now(),reviewed_by=nullif(current_setting('app.actor_id',true),'')::uuid,
 last_confirmed_at=CASE WHEN p_decision='approved' THEN now() ELSE last_confirmed_at END,version=version+1,updated_at=now()
 WHERE id=p.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload) VALUES(p.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.reviewed',p.id,jsonb_build_object('decision',p_decision,'note',coalesce(p_note,'')));
 RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.confirm_listing_current(p_id text,p_version int)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND OR auth.workspace()<>'supplier' OR p.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid
 OR NOT EXISTS(SELECT FROM auth.users u WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.tenant_id=p.tenant_id AND u.role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p.status<>'published' OR p.moderation_status<>'approved' THEN RETURN 'invalid_state'; END IF;
 UPDATE catalog.properties SET last_confirmed_at=now(),version=version+1,updated_at=now() WHERE id=p.id;
 RETURN 'ok';
END $$;

DROP FUNCTION catalog.all_properties_for_admin();
CREATE FUNCTION catalog.all_properties_for_admin()
RETURNS TABLE(id text,title text,locality text,description text,capacity int,nightly_minor int,currency text,status text,version int,moderation_status text,review_note text,freshness text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT p.id::text,p.title,p.locality,coalesce(p.description,''),p.capacity,p.nightly_minor::int,p.currency::text,p.status,p.version::int,p.moderation_status,p.review_note,
 CASE WHEN p.last_confirmed_at IS NULL THEN 'never' WHEN p.last_confirmed_at<now()-interval '30 days' THEN 'stale' ELSE 'current' END
 FROM catalog.properties p WHERE onboarding.operator() ORDER BY (p.moderation_status='in_review') DESC,p.updated_at DESC LIMIT 100
$$;

DROP FUNCTION catalog.published();
CREATE FUNCTION catalog.published()
RETURNS TABLE(id text,title text,locality text,description text,capacity int,nightly_minor bigint,currency text,status text,version bigint,moderation_status text,review_note text,freshness text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,catalog AS $$
 SELECT id::text,title,locality,description,capacity,nightly_minor,currency::text,status,version,moderation_status,review_note,'current'
 FROM catalog.properties WHERE status='published' AND moderation_status='approved' AND last_confirmed_at>=now()-interval '30 days' ORDER BY created_at DESC LIMIT 100
$$;

REVOKE ALL ON FUNCTION catalog.submit_for_review(text,int),catalog.review_listing(text,int,text,text),catalog.confirm_listing_current(text,int),catalog.all_properties_for_admin(),catalog.published() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.submit_for_review(text,int),catalog.review_listing(text,int,text,text),catalog.confirm_listing_current(text,int),catalog.all_properties_for_admin(),catalog.published() TO nexus_app;
