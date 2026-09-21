BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); q uuid:=gen_random_uuid(); unit_id uuid:=gen_random_uuid();
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Module test A','supplier'),(b,'Module test B','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(u,t,u::text||'@example.invalid','disabled','Test','owner');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency) VALUES(p,t,'Test A','Test',1,100,'TRY'),(q,b,'Test B','Test',1,100,'TRY');
 INSERT INTO catalog.property_units(id,property_id,unit_code,unit_name) VALUES(unit_id,p,'A1','Test');
 PERFORM set_config('app.actor_id',u::text,true); PERFORM set_config('app.tenant_id',t::text,true);
 IF catalog.can_access_module(p,'pms') THEN RAISE EXCEPTION 'Unassigned module accessible'; END IF;
 INSERT INTO onboarding.supplier_modules(supplier_id,module_code,status,assigned_by) VALUES(t,'pms','enabled',u);
 IF NOT catalog.can_access_module(p,'pms') THEN RAISE EXCEPTION 'Assigned module inaccessible'; END IF;
 IF catalog.can_access_module(q,'pms') THEN RAISE EXCEPTION 'Cross tenant module accessible'; END IF;
 IF catalog.update_unit_status(unit_id,'maintenance','dirty') <> 'ok' THEN RAISE EXCEPTION 'Assigned PMS update failed'; END IF;
 UPDATE onboarding.supplier_modules SET status='paused' WHERE supplier_id=t;
 BEGIN
   PERFORM catalog.update_unit_status(unit_id,'available','clean');
   RAISE EXCEPTION 'Paused module update accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE onboarding.supplier_modules SET status='enabled' WHERE supplier_id=t;
 UPDATE auth.users SET role='viewer' WHERE id=u;
 IF catalog.can_access_module(p,'pms') THEN RAISE EXCEPTION 'Viewer access accepted'; END IF;
 PERFORM set_config('app.actor_id','',true); PERFORM set_config('app.tenant_id','',true);
 SET LOCAL ROLE nexus_app;
 IF EXISTS(SELECT FROM catalog.property_units) THEN RAISE EXCEPTION 'Anonymous unit data leaked'; END IF;
 IF EXISTS(SELECT FROM catalog.listing_modules_cockpit(p)) THEN RAISE EXCEPTION 'Anonymous cockpit leaked'; END IF;
 RESET ROLE;
 RAISE NOTICE 'PASS: module assignment, paused module, viewer, tenant scope and anonymous isolation';
END $$;
ROLLBACK;
