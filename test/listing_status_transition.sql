-- 181: catalog.transition_listing_status must run and must share the platform
-- permission rule with catalog.review_listing and catalog.admin_publish.
-- Before 181 the function read core.organizations.platform_role, a column the
-- table does not have, so every call aborted with 42703.
BEGIN;
DO $$
DECLARE
  s uuid := gen_random_uuid();
  n uuid := gen_random_uuid();
  su uuid := gen_random_uuid();
  nu uuid := gen_random_uuid();
  p uuid := gen_random_uuid();
  state text;
  blocked boolean := false;
BEGIN
  INSERT INTO core.organizations(id,legal_name,kind) VALUES(s,'Transition supplier','supplier'),(n,'Transition nexus','nexus');
  INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES
    (su,s,su::text||'@example.invalid','disabled','Supplier','owner'),
    (nu,n,nu::text||'@example.invalid','disabled','Nexus','owner');
  INSERT INTO onboarding.categories(code,name) VALUES('transition-test','Transition test');
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
    VALUES(su,s,'transition-test','Transition supplier','approved','verified');
  INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,schema_managed)
    VALUES(p,s,'Transition listing','Antalya','Complete description',2,10000,'TRY','transition-test',
           '{}'::jsonb,'SEO title','SEO description','["https://example.invalid/transition.jpg"]'::jsonb,true);

  -- Supplier submits the listing: this path must not raise at all.
  PERFORM set_config('app.tenant_id',s::text,true);
  PERFORM set_config('app.actor_id',su::text,true);
  PERFORM catalog.transition_listing_status(s,s,p::text::uuid,'in_review',NULL,NULL);
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'draft/in_review' THEN
    RAISE EXCEPTION 'supplier submission transition failed: %', state;
  END IF;

  -- A supplier may not approve: the platform permission rule must be enforced.
  BEGIN
    PERFORM catalog.transition_listing_status(s,s,p,'approved',NULL,NULL);
  EXCEPTION WHEN insufficient_privilege THEN blocked := true;
  END;
  IF NOT blocked THEN
    RAISE EXCEPTION 'supplier approved a listing through the transition machine';
  END IF;

  -- Platform approves and publishes.
  PERFORM set_config('app.tenant_id',n::text,true);
  PERFORM set_config('app.actor_id',nu::text,true);
  PERFORM catalog.transition_listing_status(s,n,p,'approved','published',NULL);
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'published/approved' THEN
    RAISE EXCEPTION 'platform approval transition failed: %', state;
  END IF;

  -- Platform suspends, which withdraws the listing without losing the record.
  PERFORM catalog.transition_listing_status(s,n,p,'suspended','draft',NULL);
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'draft/suspended' THEN
    RAISE EXCEPTION 'platform suspension transition failed: %', state;
  END IF;

  RAISE NOTICE 'PASS: transition_listing_status runs and enforces the platform permission rule';
END $$;
ROLLBACK;
