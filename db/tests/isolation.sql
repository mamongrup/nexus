\set ON_ERROR_STOP on
BEGIN;
INSERT INTO core.organizations(id,legal_name) VALUES ('22222222-2222-4222-8222-222222222222','Isolation test tenant');
INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency)
VALUES('22222222-2222-4222-8222-222222222222','Private isolation fixture','Test',2,100,'TRY');
SET LOCAL ROLE nexus_app;
DO $$ BEGIN
 IF (SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname=current_user) THEN RAISE EXCEPTION 'Runtime role is privileged'; END IF;
 IF EXISTS (SELECT FROM catalog.properties) THEN RAISE EXCEPTION 'Rows leaked without tenant context'; END IF;
 IF has_table_privilege(current_user,'auth.users','SELECT') THEN RAISE EXCEPTION 'Passwords visible'; END IF;
 IF has_table_privilege(current_user,'finance.journals','UPDATE') THEN RAISE EXCEPTION 'Ledger writable'; END IF;
END $$;
SELECT set_config('app.tenant_id','11111111-1111-4111-8111-111111111111',true);
DO $$ BEGIN
 IF EXISTS (SELECT FROM catalog.properties WHERE tenant_id='22222222-2222-4222-8222-222222222222') THEN RAISE EXCEPTION 'Cross-tenant read'; END IF;
 BEGIN
  INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency)
  VALUES('22222222-2222-4222-8222-222222222222','Forbidden cross tenant','Test',2,100,'TRY');
  RAISE EXCEPTION 'Cross-tenant write succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency)
  VALUES('11111111-1111-4111-8111-111111111111','Invalid amount fixture','Test',2,-1,'TRY');
  RAISE EXCEPTION 'Negative price accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
END $$;
ROLLBACK;
\echo 'PASS: tenant isolation, role restrictions, amount constraint (fixtures rolled back)'

