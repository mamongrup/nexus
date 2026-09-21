\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); op uuid; row_count int;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Worker fixture','supplier');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency) VALUES(p,t,'Worker property','Test',1,100,'TRY');
 PERFORM set_config('app.tenant_id',t::text,true);
 op:=events.enqueue_external_operation(t::text,p::text,'worker-1','ota','sync','{}');
 SELECT count(*) INTO row_count FROM events.claim_next_external_operation();
 IF row_count<>1 THEN RAISE EXCEPTION 'Worker did not claim one operation'; END IF;
 SELECT count(*) INTO row_count FROM events.claim_next_external_operation();
 IF row_count<>0 THEN RAISE EXCEPTION 'Running operation was claimed twice'; END IF;
 SELECT count(*) INTO row_count FROM events.external_operation_status();
 IF row_count<>1 THEN RAISE EXCEPTION 'Operator status missing'; END IF;
 IF events.finish_external_operation(op::text,'succeeded','','ota-ref-1')<>'ok' THEN RAISE EXCEPTION 'Completion failed'; END IF;
 RAISE NOTICE 'PASS: worker claim is exclusive and operator status is tenant scoped';
END $$;
ROLLBACK;
