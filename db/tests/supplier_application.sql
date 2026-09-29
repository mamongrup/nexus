BEGIN;
DO $$
DECLARE s uuid:=gen_random_uuid(); n uuid:=gen_random_uuid(); su uuid:=gen_random_uuid(); nu uuid:=gen_random_uuid(); v_application_id text; requirement_id text; document_id text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(s,'Application supplier','supplier'),(n,'Application nexus','nexus');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(su,s,su::text||'@example.invalid','disabled','Supplier','owner'),(nu,n,nu::text||'@example.invalid','disabled','Nexus','owner');
 PERFORM set_config('app.tenant_id',s::text,true); PERFORM set_config('app.actor_id',su::text,true);
 v_application_id:=onboarding.apply('holiday_home','Application supplier','{"full_name":"Test Supplier","tc":"12345678901"}');
 IF v_application_id IN ('invalid_application','forbidden') THEN RAISE EXCEPTION 'application creation failed'; END IF;
 SELECT r.id::text INTO requirement_id FROM onboarding.requirements r WHERE r.category_code='holiday_home' AND r.kind='document' LIMIT 1;
 IF onboarding.register_document(v_application_id,requirement_id,'https://unsafe.example/doc','Belge')<>'invalid_document' THEN RAISE EXCEPTION 'external document URL accepted'; END IF;
 IF onboarding.register_document(v_application_id,requirement_id,'upload:12345678901234567890123456789012.pdf','Faaliyet belgesi')<>'ok' THEN RAISE EXCEPTION 'document registration failed'; END IF;
 SELECT d.id::text INTO document_id FROM onboarding.documents d WHERE d.application_id::text=v_application_id;
 PERFORM set_config('app.tenant_id',n::text,true); PERFORM set_config('app.actor_id',nu::text,true);
 IF onboarding.review_document(document_id,'accepted')<>'ok' THEN RAISE EXCEPTION 'document review failed'; END IF;
 IF NOT EXISTS(SELECT FROM onboarding.documents WHERE id::text=document_id AND status='accepted' AND reviewed_by=nu) THEN RAISE EXCEPTION 'review not persisted'; END IF;
 RAISE NOTICE 'PASS: supplier application, secure document reference and NEXUS review';
END $$;
ROLLBACK;
