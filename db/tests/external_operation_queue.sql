\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); first_id uuid; second_id uuid; row_count int; answer text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Queue fixture','supplier');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency) VALUES(p,t,'Queue property','Test',1,100,'TRY');
 PERFORM set_config('app.tenant_id',t::text,true);
 first_id:=events.enqueue_external_operation(t::text,p::text,'k-1','whatsapp','message','{"to":"+90555"}'::jsonb);
 second_id:=events.enqueue_external_operation(t::text,p::text,'k-1','whatsapp','message','{"to":"+90555"}'::jsonb);
 IF first_id<>second_id THEN RAISE EXCEPTION 'Idempotency key created duplicate'; END IF;
 SELECT count(*) INTO row_count FROM events.external_operations WHERE tenant_id=t;
 IF row_count<>1 THEN RAISE EXCEPTION 'Queue duplicate count: %',row_count; END IF;
 IF NOT EXISTS(SELECT FROM events.claim_external_operation(first_id::text)) THEN RAISE EXCEPTION 'Claim failed'; END IF;
 answer:=events.finish_external_operation(first_id::text,'failed','provider timeout','');
 IF answer<>'ok' THEN RAISE EXCEPTION 'Failure update failed'; END IF;
 IF events.finish_external_operation(first_id::text,'succeeded','','provider-1')<>'not_found' THEN RAISE EXCEPTION 'Finished operation claimed twice'; END IF;
 RAISE NOTICE 'PASS: external queue idempotency, claim and terminal state';
END $$;
ROLLBACK;
