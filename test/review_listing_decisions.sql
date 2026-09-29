-- 182: A platform decision of 'draft' restores a suspended listing to draft.
-- Before 182 catalog.review_listing rejected the decision with invalid_decision,
-- so the platform could suspend a listing but never bring it back through the UI.
-- The decision must stay restricted to suspended listings, otherwise moderation
-- would be reversible at will.
BEGIN;
DO $$
DECLARE
  s uuid := gen_random_uuid();
  n uuid := gen_random_uuid();
  su uuid := gen_random_uuid();
  nu uuid := gen_random_uuid();
  p uuid := gen_random_uuid();
  state text;
  answer text;
BEGIN
  INSERT INTO core.organizations(id,legal_name,kind) VALUES(s,'Decision supplier','supplier'),(n,'Decision nexus','nexus');
  INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES
    (su,s,su::text||'@example.invalid','disabled','Supplier','owner'),
    (nu,n,nu::text||'@example.invalid','disabled','Nexus','owner');
  INSERT INTO onboarding.categories(code,name) VALUES('decision-test','Decision test');
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
    VALUES(su,s,'decision-test','Decision supplier','approved','verified');
  INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,schema_managed)
    VALUES(p,s,'Decision listing','Antalya','Complete description',2,10000,'TRY','decision-test',
           '{}'::jsonb,'SEO title','SEO description','["https://example.invalid/decision.jpg"]'::jsonb,true);

  PERFORM set_config('app.tenant_id',n::text,true);
  PERFORM set_config('app.actor_id',nu::text,true);

  -- A draft listing may not be "restored" straight back to draft.
  answer := catalog.review_listing(p::text,1,'draft','');
  IF answer <> 'invalid_state' THEN
    RAISE EXCEPTION 'draft decision accepted for a non suspended listing: %', answer;
  END IF;

  -- Platform approves, which publishes the listing. Approval is only defined
  -- for a listing the supplier already submitted for review.
  UPDATE catalog.properties SET moderation_status='in_review' WHERE id=p;
  answer := catalog.review_listing(p::text,1,'approved','');
  IF answer <> 'ok' THEN RAISE EXCEPTION 'approval failed: %', answer; END IF;
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'published/approved' THEN
    RAISE EXCEPTION 'approval did not publish: %', state;
  END IF;

  -- An approved listing must not be reset to draft either.
  answer := catalog.review_listing(p::text,2,'draft','');
  IF answer <> 'invalid_state' THEN
    RAISE EXCEPTION 'draft decision accepted for an approved listing: %', answer;
  END IF;

  -- Platform suspends, then restores it to draft.
  answer := catalog.review_listing(p::text,2,'suspended','test suspension');
  IF answer <> 'ok' THEN RAISE EXCEPTION 'suspension failed: %', answer; END IF;
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'draft/suspended' THEN
    RAISE EXCEPTION 'suspension did not withdraw the listing: %', state;
  END IF;

  answer := catalog.review_listing(p::text,3,'draft','test restore');
  IF answer <> 'ok' THEN
    RAISE EXCEPTION 'restore to draft failed: %', answer;
  END IF;
  SELECT status||'/'||moderation_status INTO state FROM catalog.properties WHERE id=p;
  IF state <> 'draft/draft' THEN
    RAISE EXCEPTION 'restore did not produce a draft: %', state;
  END IF;

  RAISE NOTICE 'PASS: platform restore-to-draft decision works and stays restricted to suspended listings';
END $$;
ROLLBACK;
