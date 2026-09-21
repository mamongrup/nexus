\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE
 t uuid:=gen_random_uuid(); other_t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid();
 q uuid:=gen_random_uuid(); h uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); journal uuid;
 initial_snapshot jsonb:='{"supplier_net_minor":9100,"nexus_fee_minor":200,"agency_markup_minor":0,"tax_minor":700,"customer_price_minor":10000,"currency":"TRY"}';
 answer text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Ledger fixture','supplier'),(other_t,'Other supplier','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(u,t,u::text||'@example.invalid','disabled','Test','owner');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency) VALUES(p,t,'Ledger property','Test',1,10000,'TRY');
 INSERT INTO booking.quotes(id,tenant_id,property_id,total_minor,currency,snapshot,expires_at) VALUES(q,t,p,10000,'TRY',initial_snapshot,now()+interval '1 hour');
 INSERT INTO booking.holds(id,tenant_id,quote_id,check_in,check_out,expires_at,status) VALUES(h,t,q,current_date,current_date+1,now()+interval '1 hour','consumed');
 INSERT INTO booking.reservations(id,tenant_id,hold_id,total_minor,currency,status,payment_status) VALUES(r,t,h,10000,'TRY','confirmed','unpaid');
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'forbidden' THEN RAISE EXCEPTION 'Anonymous posting'; END IF;
 PERFORM set_config('app.tenant_id',other_t::text,true),set_config('app.actor_id',u::text,true);
 IF finance.post_reservation_ledger(r::text)<>'forbidden' THEN RAISE EXCEPTION 'Cross-tenant actor accepted'; END IF;
 PERFORM set_config('app.tenant_id',t::text,true);
 RESET ROLE;
 UPDATE auth.users SET role='viewer' WHERE id=u;
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'forbidden' THEN RAISE EXCEPTION 'Viewer posting'; END IF;
 RESET ROLE;
 UPDATE auth.users SET role='owner' WHERE id=u;
 UPDATE booking.quotes SET snapshot='{}' WHERE id=q;
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'invalid_snapshot' THEN RAISE EXCEPTION 'Missing snapshot accepted'; END IF;
 RESET ROLE;
 UPDATE booking.quotes SET snapshot=jsonb_set(snapshot,'{supplier_net_minor}','9200') WHERE id=q;
 UPDATE booking.quotes SET snapshot=jsonb_set(snapshot || '{"customer_price_minor":10000,"nexus_fee_minor":200,"agency_markup_minor":0,"tax_minor":700,"currency":"TRY"}','{supplier_net_minor}','9200') WHERE id=q;
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'invalid_snapshot' THEN RAISE EXCEPTION 'Unbalanced snapshot accepted'; END IF;
 RESET ROLE;
 UPDATE booking.quotes SET snapshot=jsonb_set(snapshot,'{supplier_net_minor}','null') WHERE id=q;
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'invalid_snapshot' THEN RAISE EXCEPTION 'Null amount accepted'; END IF;
 RESET ROLE;
 UPDATE booking.quotes SET snapshot='{"supplier_net_minor":9100,"nexus_fee_minor":200,"agency_markup_minor":0,"tax_minor":700,"customer_price_minor":10000,"currency":"TRY"}' WHERE id=q;
 UPDATE booking.reservations SET status='cancelled' WHERE id=r;
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'invalid_status' THEN RAISE EXCEPTION 'Cancelled posting'; END IF;
 RESET ROLE;
 UPDATE booking.reservations SET status='confirmed' WHERE id=r;
 SET LOCAL ROLE nexus_app;
 IF finance.post_reservation_ledger(r::text)<>'ok' THEN RAISE EXCEPTION 'Valid posting failed'; END IF;
 IF finance.post_reservation_ledger(r::text)<>'already_posted' THEN RAISE EXCEPTION 'Duplicate posting'; END IF;
 RESET ROLE;
 SELECT id INTO journal FROM finance.journals WHERE business_event_id=r;
 IF (SELECT count(*) FROM finance.journals WHERE business_event_id=r)<>1 THEN RAISE EXCEPTION 'Duplicate journal'; END IF;
 IF (SELECT sum(CASE side WHEN 'D' THEN amount_minor ELSE -amount_minor END) FROM finance.journal_lines WHERE journal_id=journal)<>0 THEN RAISE EXCEPTION 'Unbalanced ledger'; END IF;
 IF NOT EXISTS(SELECT FROM finance.journal_lines WHERE journal_id=journal AND account_code='2300' AND amount_minor=700) THEN RAISE EXCEPTION 'Tax missing'; END IF;
 IF NOT EXISTS(SELECT FROM finance.settlements WHERE reservation_id=r AND supplier_net_minor=9100 AND nexus_fee_minor=200 AND agency_markup_minor=0) THEN RAISE EXCEPTION 'Frozen amounts not used'; END IF;
 RAISE NOTICE 'PASS: caller scope, roles, invalid snapshots, status, frozen amounts, tax, duplicate posting';
END $$;
ROLLBACK;

