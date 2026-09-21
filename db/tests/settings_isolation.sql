\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); au uuid:=gen_random_uuid(); bu uuid:=gen_random_uuid();
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(a,'Settings agency A','agency'),(b,'Settings agency B','agency');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name) VALUES(au,a,a||'@test.local','disabled','A'),(bu,b,b||'@test.local','disabled','B');
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF settings.save('agency_pos.client_code','10001',0)<>'ok' THEN RAISE EXCEPTION 'Agency A save failed'; END IF;
 IF settings.save('parampos.client_code','10001',0)<>'not_found' THEN RAISE EXCEPTION 'Agency changed NEXUS config'; END IF;
 PERFORM set_config('app.tenant_id',b::text,true),set_config('app.actor_id',bu::text,true);
 IF EXISTS(SELECT FROM settings.list() WHERE data[7]='10001') THEN RAISE EXCEPTION 'Agency A value leaked'; END IF;
 IF settings.save('agency_pos.client_code','20002',0)<>'ok' THEN RAISE EXCEPTION 'Agency B save failed'; END IF;
 IF (SELECT count(*) FROM settings.values WHERE key='agency_pos.client_code' AND tenant_id IN(a,b))<>2 THEN RAISE EXCEPTION 'Settings not tenant scoped'; END IF;
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF NOT EXISTS(SELECT FROM settings.list() WHERE data[7]='10001') THEN RAISE EXCEPTION 'Own setting lost'; END IF;
 IF EXISTS(SELECT FROM settings.list() WHERE data[7]='20002') THEN RAISE EXCEPTION 'Agency B value leaked'; END IF;
 UPDATE auth.users SET role='viewer' WHERE id=au;
 IF settings.save('agency_pos.client_code','1',1)<>'forbidden' THEN RAISE EXCEPTION 'Viewer wrote setting'; END IF;
 IF EXISTS(SELECT FROM settings.list()) THEN RAISE EXCEPTION 'Viewer read settings'; END IF;
 PERFORM set_config('app.actor_id','',true);
 IF settings.save('agency_pos.client_code','1',1)<>'forbidden' THEN RAISE EXCEPTION 'Missing actor accepted'; END IF;
END $$;
SET LOCAL ROLE nexus_app;
DO $$ BEGIN
 IF has_table_privilege(current_user,'settings.values','SELECT') OR has_table_privilege(current_user,'settings.values','UPDATE') THEN RAISE EXCEPTION 'Raw settings accessible'; END IF;
END $$;
ROLLBACK;
\echo 'PASS: agency settings isolation, owner-only access, no direct secret table access'
