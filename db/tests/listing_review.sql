BEGIN;
DO $$
DECLARE s uuid:=gen_random_uuid(); n uuid:=gen_random_uuid(); su uuid:=gen_random_uuid(); nu uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); v int; answer text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(s,'Review supplier','supplier'),(n,'Review nexus','nexus');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES
 (su,s,su::text||'@example.invalid','disabled','Supplier','owner'),(nu,n,nu::text||'@example.invalid','disabled','Nexus','owner');
 INSERT INTO onboarding.categories(code,name) VALUES('review-test','Review test');
 INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status) VALUES(su,s,'review-test','Review supplier','approved','verified');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,seo_title,seo_description,schema_managed)
 VALUES(p,s,'Review listing','Antalya','Complete description',2,10000,'TRY','review-test','SEO title','SEO description',true);
 SELECT version INTO v FROM catalog.properties WHERE id=p;
 SET LOCAL ROLE nexus_app;
 PERFORM set_config('app.tenant_id',s::text,true); PERFORM set_config('app.actor_id',su::text,true);
 answer:=catalog.submit_for_review(p::text,v); IF answer<>'ok' THEN RAISE EXCEPTION 'submit failed: %',answer; END IF;
 SELECT version INTO v FROM catalog.properties WHERE id=p;
 IF catalog.confirm_listing_current(p::text,v)<>'invalid_state' THEN RAISE EXCEPTION 'unapproved confirmation accepted'; END IF;
 PERFORM set_config('app.tenant_id',n::text,true); PERFORM set_config('app.actor_id',nu::text,true);
 answer:=catalog.review_listing(p::text,v,'approved',''); IF answer<>'ok' THEN RAISE EXCEPTION 'approval failed: %',answer; END IF;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM catalog.properties WHERE id=p AND status='published' AND moderation_status='approved') THEN RAISE EXCEPTION 'not published'; END IF;
 SELECT version INTO v FROM catalog.properties WHERE id=p;
 SET LOCAL ROLE nexus_app;
 PERFORM set_config('app.tenant_id',s::text,true); PERFORM set_config('app.actor_id',su::text,true);
 answer:=catalog.confirm_listing_current(p::text,v); IF answer<>'ok' THEN RAISE EXCEPTION 'freshness confirmation failed'; END IF;
 RESET ROLE;
 UPDATE catalog.properties SET last_confirmed_at=now()-interval '31 days' WHERE id=p;
 SET LOCAL ROLE nexus_app;
 IF EXISTS(SELECT FROM catalog.published() x WHERE x.id=p::text) THEN RAISE EXCEPTION 'stale listing stayed public'; END IF;
 RESET ROLE;
 RAISE NOTICE 'PASS: supplier submit, NEXUS approval and freshness expiry';
END $$;
ROLLBACK;
