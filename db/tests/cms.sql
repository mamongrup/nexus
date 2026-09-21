\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); v bigint;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'CMS test','nexus');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name) VALUES(u,t,u||'@test.local','disabled','CMS');
 PERFORM set_config('app.tenant_id',t::text,true),set_config('app.actor_id',u::text,true);
 SELECT version INTO v FROM cms.pages WHERE slug='home';
 IF cms.save('home','CMS secret draft','Draft summary','<script>test</script>',v)<>'ok' THEN RAISE EXCEPTION 'Draft save failed'; END IF;
 IF EXISTS(SELECT FROM cms.public_pages() WHERE data[2]='CMS secret draft') THEN RAISE EXCEPTION 'Draft leaked'; END IF;
 IF cms.publish('home',v,true)<>'setting_conflict' THEN RAISE EXCEPTION 'Stale publish accepted'; END IF;
 UPDATE auth.users SET role='editor' WHERE id=u;
 IF cms.publish('home',v+1,true)<>'forbidden' THEN RAISE EXCEPTION 'Editor published'; END IF;
 UPDATE auth.users SET role='owner' WHERE id=u;
 IF cms.publish('home',v+1,true)<>'ok' THEN RAISE EXCEPTION 'Publish failed'; END IF;
 IF NOT EXISTS(SELECT FROM cms.public_pages() WHERE data[2]='CMS secret draft') THEN RAISE EXCEPTION 'Published content missing'; END IF;
 IF cms.publish('home',v+2,false)<>'ok' THEN RAISE EXCEPTION 'Unpublish failed'; END IF;
 IF EXISTS(SELECT FROM cms.public_pages() WHERE data[1]='home') THEN RAISE EXCEPTION 'Unpublished content leaked'; END IF;
 UPDATE core.organizations SET kind='agency' WHERE id=t;
 IF EXISTS(SELECT FROM cms.editor_pages()) THEN RAISE EXCEPTION 'Agency CMS access'; END IF;
 IF cms.save('home','Agency attempt','','',v+3)<>'forbidden' THEN RAISE EXCEPTION 'Agency modified CMS'; END IF;
END $$;
ROLLBACK;
\echo 'PASS: CMS draft separation, publish/unpublish, optimistic version and role boundaries'
