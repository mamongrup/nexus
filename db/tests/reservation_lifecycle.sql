\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE s uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); n uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
 su uuid:=gen_random_uuid(); au uuid:=gen_random_uuid(); nu uuid:=gen_random_uuid(); xu uuid:=gen_random_uuid();
 p uuid:=gen_random_uuid(); r uuid; b uuid; d date:=(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date+10; answer text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(s,'Test supplier','supplier'),(a,'Test agency','agency'),(n,'Test nexus','nexus'),(stranger,'Other agency','agency');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name) VALUES(su,s,s||'@test.local','disabled','S'),(au,a,a||'@test.local','disabled','A'),(nu,n,n||'@test.local','disabled','N'),(xu,stranger,stranger||'@test.local','disabled','X');
 INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
 VALUES(su,s,'hotel','Test supplier','approved','verified');
 INSERT INTO catalog.properties(id,tenant_id,title,description,locality,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,status,moderation_status)
 VALUES(p,s,'Reservation fixture','Reservation lifecycle test listing','Test',2,10000,'TRY','hotel',
        '{"room_type":"double","property_type":"hotel","room_types":"double","board_type":"room_only","check_in_time":"14:00","check_out_time":"11:00"}'::jsonb,
        'Reservation fixture','Reservation lifecycle test listing',
        '["https://example.invalid/reservation-fixture.jpg"]'::jsonb,'published','approved');
 PERFORM set_config('app.tenant_id',s::text,true),set_config('app.actor_id',su::text,true);
 IF inventory.configure(p::text,d::text,(d+2)::text,10000,false)<>'ok' THEN RAISE EXCEPTION 'Configure failed'; END IF;
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF booking.request_option(p::text,d::text,(d+2)::text,30,'test-request-key-0001')<>'forbidden' THEN RAISE EXCEPTION 'Disconnected agency accepted'; END IF;
 PERFORM set_config('app.tenant_id',n::text,true),set_config('app.actor_id',nu::text,true);
 IF partners.connect(s::text,a::text,'active')<>'ok' THEN RAISE EXCEPTION 'Connection failed'; END IF;
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF booking.request_option(p::text,d::text,(d+2)::text,30,'test-request-key-0001')<>'ok' THEN RAISE EXCEPTION 'Request failed'; END IF;
 SELECT id INTO r FROM booking.option_requests WHERE agency_id=a;
 IF booking.confirm_request(r::text)<>'not_approved' THEN RAISE EXCEPTION 'Unapproved reservation accepted'; END IF;
 IF EXISTS(SELECT FROM inventory.days WHERE tenant_id=s AND held<>0) THEN RAISE EXCEPTION 'Pending request held stock'; END IF;
 PERFORM set_config('app.tenant_id',s::text,true),set_config('app.actor_id',su::text,true);
 IF booking.decide_request(r::text,'approved')<>'ok' THEN RAISE EXCEPTION 'Approval failed'; END IF;
 IF inventory.create_hold(p::text,d::text,(d+2)::text,30,'another-hold-key-001')<>'unavailable' THEN RAISE EXCEPTION 'Overbooking accepted'; END IF;
 PERFORM set_config('app.tenant_id',stranger::text,true),set_config('app.actor_id',xu::text,true);
 IF booking.confirm_request(r::text)<>'not_found' THEN RAISE EXCEPTION 'Foreign confirmation accepted'; END IF;
 IF EXISTS(SELECT FROM booking.requests()) THEN RAISE EXCEPTION 'Foreign request leaked'; END IF;
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF booking.confirm_request(r::text)<>'ok' THEN RAISE EXCEPTION 'Confirmation failed'; END IF;
 IF booking.confirm_request(r::text)<>'already_booked' THEN RAISE EXCEPTION 'Duplicate confirmation not handled'; END IF;
 IF (SELECT count(*) FROM booking.reservations WHERE request_id=r)<>1 THEN RAISE EXCEPTION 'Duplicate reservation'; END IF;
 IF EXISTS(SELECT FROM inventory.days WHERE tenant_id=s AND (held<>0 OR sold<>1)) THEN RAISE EXCEPTION 'Stock conversion incorrect'; END IF;
 SELECT id INTO b FROM booking.reservations WHERE request_id=r AND total_minor=20000 AND payment_status='unpaid';
 IF b IS NULL THEN RAISE EXCEPTION 'Snapshot or unpaid status incorrect'; END IF;
 PERFORM set_config('app.tenant_id',s::text,true),set_config('app.actor_id',su::text,true);
 IF booking.cancel_reservation(b::text)<>'ok' OR booking.cancel_reservation(b::text)<>'ok' THEN RAISE EXCEPTION 'Cancellation idempotency failed'; END IF;
 IF EXISTS(SELECT FROM inventory.days WHERE tenant_id=s AND (held<>0 OR sold<>0)) THEN RAISE EXCEPTION 'Cancellation stock incorrect'; END IF;
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF booking.request_option(p::text,d::text,(d+2)::text,30,'test-request-key-0002')<>'ok' THEN RAISE EXCEPTION 'Second request failed'; END IF;
 SELECT id INTO r FROM booking.option_requests WHERE agency_id=a AND request_key='test-request-key-0002';
 PERFORM set_config('app.tenant_id',s::text,true),set_config('app.actor_id',su::text,true);
 IF booking.decide_request(r::text,'approved')<>'ok' THEN RAISE EXCEPTION 'Second approval failed'; END IF;
 UPDATE booking.holds SET expires_at=clock_timestamp()-interval '1 second' WHERE id=(SELECT hold_id FROM booking.option_requests WHERE id=r);
 PERFORM set_config('app.tenant_id',a::text,true),set_config('app.actor_id',au::text,true);
 IF booking.confirm_request(r::text)<>'expired' THEN RAISE EXCEPTION 'Expired confirmation accepted'; END IF;
 IF EXISTS(SELECT FROM inventory.days WHERE tenant_id=s AND (held<>0 OR sold<>0)) THEN RAISE EXCEPTION 'Expiry stock incorrect'; END IF;
 RAISE NOTICE 'PASS: connection, approval, last stock, agency isolation, confirmation, idempotency, snapshot, cancellation, expiry';
END $$;
ROLLBACK;
