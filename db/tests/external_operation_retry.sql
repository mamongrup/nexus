\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); op uuid; answer text; current_status text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Retry fixture','supplier');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency) VALUES(p,t,'Retry property','Test',1,100,'TRY');
 PERFORM set_config('app.tenant_id',t::text,true);
 op:=events.enqueue_external_operation(t::text,p::text,'retry-1','ota','sync','{}');
 PERFORM events.claim_next_external_operation();
 IF events.finish_external_operation(op::text,'failed','timeout','')<>'ok' THEN RAISE EXCEPTION 'Fail transition failed'; END IF;
 IF events.retry_external_operation(op::text,'manual retry')<>'ok' THEN RAISE EXCEPTION 'Retry failed'; END IF;
 SELECT status INTO current_status FROM events.external_operations WHERE id=op;
 IF current_status<>'pending' THEN RAISE EXCEPTION 'Retry did not return to pending'; END IF;
 IF events.retry_external_operation(op::text,'duplicate retry')<>'not_retryable' THEN RAISE EXCEPTION 'Pending retry accepted'; END IF;
 UPDATE events.external_operations SET next_attempt_at=now() WHERE id=op;
 PERFORM events.claim_next_external_operation();
 IF events.finish_external_operation(op::text,'succeeded','','provider-ok')<>'ok' THEN RAISE EXCEPTION 'Success transition failed'; END IF;
 IF events.retry_external_operation(op::text,'after success')<>'not_retryable' THEN RAISE EXCEPTION 'Successful operation was retried'; END IF;
 RAISE NOTICE 'PASS: bounded retry policy and terminal immutability';
END $$;
ROLLBACK;
