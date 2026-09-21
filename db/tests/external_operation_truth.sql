BEGIN;
SET LOCAL ROLE nexus_app;
DO $$
DECLARE result jsonb;
BEGIN
 IF EXISTS(SELECT FROM catalog.all_properties_for_admin()) THEN
   RAISE EXCEPTION 'Anonymous caller can read administrative listings';
 END IF;
 IF catalog.admin_publish('11111111-aaaa-4111-8111-111111111111',1,'published') THEN
   RAISE EXCEPTION 'Anonymous caller can publish';
 END IF;
 BEGIN
   PERFORM catalog.dispatch_kbs(gen_random_uuid(),'Test','test','test',current_date,current_date+1);
   RAISE EXCEPTION 'Fake KBS success';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN
   PERFORM catalog.sync_ota_channel(gen_random_uuid(),'Test');
   RAISE EXCEPTION 'Fake OTA success';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN
   PERFORM catalog.send_guest_whatsapp(gen_random_uuid(),'test','test','test');
   RAISE EXCEPTION 'Fake WhatsApp success';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN
   PERFORM catalog.generate_listing_invoice(gen_random_uuid(),'Test',100);
   RAISE EXCEPTION 'Fake invoice success';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 BEGIN
   PERFORM onboarding.trigger_module_action('pms','test','test');
   RAISE EXCEPTION 'Fake generic module execution';
 EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
 result := catalog.create_marketplace_booking(gen_random_uuid(),'Test','test@example.invalid','','',current_date,current_date+1,1);
 IF result->>'error' IS DISTINCT FROM 'booking_unavailable' OR result ? 'pnr' THEN
   RAISE EXCEPTION 'Fake marketplace confirmation';
 END IF;
 RAISE NOTICE 'PASS: no fabricated external success, no fake PNR, administrative scope';
END $$;
ROLLBACK;
