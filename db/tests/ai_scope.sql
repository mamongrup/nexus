BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); other_t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); q uuid:=gen_random_uuid();
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'AI scope A','supplier'),(other_t,'AI scope B','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(u,t,u::text||'@example.test','disabled','AI test','owner');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency) VALUES(p,t,'AI fixture A','Test',1,100,'TRY'),(q,other_t,'AI fixture B','Test',1,100,'TRY');
 INSERT INTO ai.listing_requests(tenant_id,property_id,capability) VALUES(t,p,'content'),(other_t,q,'content');
 PERFORM set_config('app.actor_id',u::text,true); PERFORM set_config('app.tenant_id',t::text,true);
 IF ai.queue_listing_request(p::text,'content','test')<>'already_queued' THEN RAISE EXCEPTION 'Duplicate job accepted'; END IF;
 IF ai.queue_listing_request(q::text,'seo','test')<>'forbidden' THEN RAISE EXCEPTION 'Cross tenant submission accepted'; END IF;
 IF (SELECT count(*) FROM ai.claim_listing_requests(50))<>1 THEN RAISE EXCEPTION 'Unexpected claim count'; END IF;
 IF EXISTS(SELECT FROM ai.listing_requests WHERE property_id=q AND status<>'queued') THEN RAISE EXCEPTION 'Cross-tenant claim'; END IF;
 UPDATE auth.users SET role='viewer' WHERE id=u;
 IF ai.queue_listing_request(p::text,'seo','test')<>'forbidden' THEN RAISE EXCEPTION 'Viewer submitted job'; END IF;
 IF EXISTS(SELECT FROM ai.claim_listing_requests(50)) THEN RAISE EXCEPTION 'Viewer claimed jobs'; END IF;
 PERFORM set_config('app.actor_id','',true); PERFORM set_config('app.tenant_id','',true);
 IF EXISTS(SELECT FROM ai.claim_listing_requests(50)) THEN RAISE EXCEPTION 'Anonymous claim'; END IF;
 RAISE NOTICE 'PASS: AI claim tenant isolation, viewer and anonymous restrictions';
END $$;
ROLLBACK;
