\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); result jsonb;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'External truth fixture','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(u,t,u::text||'@example.invalid','disabled','Test','owner');
 INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
 VALUES(u,t,'hotel','External truth fixture','approved','verified');
 INSERT INTO catalog.properties(id,tenant_id,title,description,locality,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,status)
 VALUES(p,t,'Real fixture','External operation truth test listing','Test',2,10000,'TRY','hotel',
        '{"room_type":"double","property_type":"hotel","room_types":"double","board_type":"room_only","check_in_time":"14:00","check_out_time":"11:00"}'::jsonb,
        'Real fixture','External operation truth test listing','["https://example.invalid/external-fixture.jpg"]'::jsonb,'published');
 PERFORM set_config('app.tenant_id',t::text,true),set_config('app.actor_id',u::text,true);
 -- Use a real property and valid owner context: random missing IDs hid the regression.
 SET LOCAL ROLE nexus_app;
 BEGIN PERFORM catalog.dispatch_kbs(p,'Test','test','A1',current_date,current_date+1);
 RAISE EXCEPTION 'Fake KBS success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.dispatch_kbs(p::text,'Test','test','A1',current_date::text,(current_date+1)::text);
 RAISE EXCEPTION 'Fake KBS wrapper success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.sync_ota_channel(p,'Test');
 RAISE EXCEPTION 'Fake OTA success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.sync_ota_channel(p::text,'Test');
 RAISE EXCEPTION 'Fake OTA wrapper success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.send_guest_whatsapp(p,'test','welcome','test');
 RAISE EXCEPTION 'Fake WhatsApp success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.send_guest_whatsapp(p::text,'test','welcome','test');
 RAISE EXCEPTION 'Fake WhatsApp wrapper success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.generate_listing_invoice(p,'Test',100::bigint);
 RAISE EXCEPTION 'Fake invoice success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM catalog.generate_listing_invoice(p::text,'Test',100::bigint);
 RAISE EXCEPTION 'Fake invoice wrapper success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN PERFORM onboarding.trigger_module_action('pms','run',p::text);
 RAISE EXCEPTION 'Fake module success'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 result:=catalog.create_marketplace_booking(p,'Test','test@example.invalid','','',current_date,current_date+1,1);
 IF result->>'error' IS DISTINCT FROM 'booking_unavailable' OR result ? 'pnr' THEN RAISE EXCEPTION 'Fake booking'; END IF;
 result:=catalog.create_marketplace_booking(p,'Test','test@example.invalid','','',current_date,current_date+1,1,'PROMO');
 IF result->>'error' IS DISTINCT FROM 'booking_unavailable' OR result ? 'pnr' THEN RAISE EXCEPTION 'Fake promo booking'; END IF;
 result:=catalog.create_marketplace_booking(p::text,'Test','test@example.invalid','','',current_date::text,(current_date+1)::text,1);
 IF result->>'error' IS DISTINCT FROM 'booking_unavailable' OR result ? 'pnr' THEN RAISE EXCEPTION 'Fake wrapper booking'; END IF;
 RESET ROLE;
 IF EXISTS(SELECT FROM catalog.property_kbs_records WHERE property_id=p)
 OR EXISTS(SELECT FROM catalog.property_whatsapp_messages WHERE property_id=p)
 OR EXISTS(SELECT FROM catalog.property_invoices WHERE property_id=p)
 OR EXISTS(SELECT FROM onboarding.module_telemetry WHERE tenant_id=t)
 OR EXISTS(SELECT FROM booking.reservations WHERE tenant_id=t)
 THEN RAISE EXCEPTION 'Unavailable operation wrote records'; END IF;
 RAISE NOTICE 'PASS: existing listing, owner context, all wrappers, no side effects';
END $$;
ROLLBACK;
