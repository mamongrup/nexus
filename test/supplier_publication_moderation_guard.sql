-- 180: A supplier must not publish a listing that platform moderation has not
-- approved. The category approval check alone used to let a direct status
-- update bypass the two layer state machine from migration 176.
BEGIN;
DO $$
DECLARE
  s uuid := gen_random_uuid();
  n uuid := gen_random_uuid();
  su uuid := gen_random_uuid();
  nu uuid := gen_random_uuid();
  p uuid := gen_random_uuid();
  v integer;
  state text;
  blocked boolean := false;
BEGIN
  INSERT INTO core.organizations(id,legal_name,kind) VALUES(s,'Publish guard supplier','supplier'),(n,'Publish guard nexus','nexus');
  INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES
    (su,s,su::text||'@example.invalid','disabled','Supplier','owner'),
    (nu,n,nu::text||'@example.invalid','disabled','Nexus','owner');
  INSERT INTO onboarding.categories(code,name) VALUES('publish-guard','Publish guard test');
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
    VALUES(su,s,'publish-guard','Publish guard supplier','approved','verified');
  INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,seo_title,seo_description,media,schema_managed)
    VALUES(p,s,'Publish guard listing','Antalya','Complete description',2,10000,'TRY','publish-guard','SEO title','SEO description',
            '["https://example.invalid/publish-guard.jpg"]'::jsonb,true);
  SELECT version INTO v FROM catalog.properties WHERE id=p;

  -- The supplier is approved for the category, yet the listing is still in
  -- moderation 'draft'. Publication must be refused.
  SET LOCAL ROLE nexus_app;
  PERFORM set_config('app.tenant_id',s::text,true);
  PERFORM set_config('app.actor_id',su::text,true);
  BEGIN
    UPDATE catalog.properties SET status='published' WHERE id=p;
  EXCEPTION WHEN insufficient_privilege THEN blocked := true;
  END;
  RESET ROLE;
  IF NOT blocked THEN
    RAISE EXCEPTION 'supplier published a listing that moderation had not approved';
  END IF;
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'draft/draft' THEN
    RAISE EXCEPTION 'blocked publication still changed the listing state: %', state;
  END IF;

  -- A genuinely approved listing stays publishable for its supplier, so the
  -- guard does not freeze the normal path.
  SELECT moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'draft' THEN
    RAISE EXCEPTION 'unexpected starting moderation status: %', state;
  END IF;
  RESET ROLE;
  UPDATE catalog.properties SET moderation_status='approved' WHERE id=p;
  SET LOCAL ROLE nexus_app;
  PERFORM set_config('app.tenant_id',s::text,true);
  PERFORM set_config('app.actor_id',su::text,true);
  BEGIN
    UPDATE catalog.properties SET status='published' WHERE id=p;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'approved supplier listing could not be published: %', SQLERRM;
  END;
  RESET ROLE;
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'published/approved' THEN
    RAISE EXCEPTION 'approved publication did not take effect: %', state;
  END IF;

  -- Losing category approval still withdraws publication rights.
  UPDATE onboarding.applications SET status='review'
    WHERE tenant_id=s AND category_code='publish-guard' AND status='approved';
  blocked := false;
  SET LOCAL ROLE nexus_app;
  PERFORM set_config('app.tenant_id',s::text,true);
  PERFORM set_config('app.actor_id',su::text,true);
  BEGIN
    UPDATE catalog.properties SET status='draft' WHERE id=p;
    UPDATE catalog.properties SET status='published' WHERE id=p;
  EXCEPTION WHEN insufficient_privilege THEN blocked := true;
  END;
  RESET ROLE;
  IF NOT blocked THEN
    RAISE EXCEPTION 'supplier republished after category approval was withdrawn';
  END IF;

  RAISE NOTICE 'PASS: supplier publication requires moderation approval and category approval';
END $$;
ROLLBACK;
