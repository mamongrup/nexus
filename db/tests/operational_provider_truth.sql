\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid; room uuid; answer text;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Operational truth fixture','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(u,t,u::text||'@example.invalid','disabled','Owner','owner');
 INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency,status) VALUES(t,'Truth Hotel','Test',2,10000,'TRY','published') RETURNING id INTO p;
 INSERT INTO catalog.property_units(property_id,unit_code,unit_name) VALUES(p,'101','Room 101') RETURNING id INTO room;
 PERFORM set_config('app.tenant_id',t::text,true),set_config('app.actor_id',u::text,true),set_config('app.role','owner',true);
 answer:=catalog.quick_check_in(p,'101','Guest',2,10000);
 IF answer<>'ok' THEN RAISE EXCEPTION 'Check-in failed: %',answer; END IF;
 IF NOT EXISTS(SELECT FROM catalog.property_kbs_records WHERE property_id=p AND police_status='pending' AND dispatch_code='') THEN RAISE EXCEPTION 'KBS was not pending'; END IF;
 answer:=catalog.dispatch_transport_notification(p,'kabis','34 ABC 123','Driver','Guest','123','Airport');
 IF answer<>'pending' OR EXISTS(SELECT FROM catalog.property_transport_notifications WHERE property_id=p AND dispatch_status='verified') THEN RAISE EXCEPTION 'Transport was falsely verified'; END IF;
 answer:=catalog.dispatch_guest_automated_message(p,'101','Guest','+90555','pre_arrival_24h');
 IF answer<>'pending' OR EXISTS(SELECT FROM catalog.property_automated_messages WHERE property_id=p AND dispatch_status='sent') THEN RAISE EXCEPTION 'Message was falsely sent'; END IF;
 IF (SELECT occupancy_status FROM catalog.property_units WHERE id=room)<>'occupied' THEN RAISE EXCEPTION 'Local check-in missing'; END IF;
 RAISE NOTICE 'PASS: local check-in preserved, external KBS/transport/message remain pending';
END $$;
ROLLBACK;
