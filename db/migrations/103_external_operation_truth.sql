-- The current adapters have no verified provider transport. Fail before writes.
-- Do not rewrite historic records: their provider evidence needs a separate audit.
CREATE OR REPLACE FUNCTION catalog.dispatch_kbs(p_property_id uuid,p_guest_name text,p_tc text,p_room text,p_check_in date,p_check_out date)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'KBS integration is not configured; no notification sent' USING ERRCODE='55000'; END $$;
CREATE OR REPLACE FUNCTION catalog.sync_ota_channel(p_property_id uuid,p_channel text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'OTA integration is not configured; no synchronization performed' USING ERRCODE='55000'; END $$;
CREATE OR REPLACE FUNCTION catalog.send_guest_whatsapp(p_property_id uuid,p_phone text,p_template text,p_content text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'WhatsApp integration is not configured; no message sent' USING ERRCODE='55000'; END $$;
CREATE OR REPLACE FUNCTION catalog.generate_listing_invoice(p_property_id uuid,p_recipient text,p_amount bigint)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Fiscal integration is not configured; no invoice issued' USING ERRCODE='55000'; END $$;
CREATE OR REPLACE FUNCTION onboarding.trigger_module_action(p_module text,p_action text,p_target text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'This module action has no execution adapter; nothing executed' USING ERRCODE='55000'; END $$;

-- All legacy entry points remain callable but cannot fabricate a confirmation.
-- The HTTP boundary supplies localized customer copy and HTTP 503.
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(p_property_id uuid,p_guest_name text,p_guest_email text,p_guest_phone text,p_tc text,p_check_in date,p_check_out date,p_guests int,p_promo_code text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('error','booking_unavailable','status','unavailable')
$$;
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(p_property_id uuid,p_guest_name text,p_guest_email text,p_guest_phone text,p_tc text,p_check_in date,p_check_out date,p_guests int)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT catalog.create_marketplace_booking(p_property_id,p_guest_name,p_guest_email,p_guest_phone,p_tc,p_check_in,p_check_out,p_guests,'')
$$;
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(p_property_id text,p_guest_name text,p_guest_email text,p_guest_phone text,p_tc text,p_check_in text,p_check_out text,p_guests int)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('error','booking_unavailable','status','unavailable')
$$;

-- Remove implicit PUBLIC access, including text wrappers from migration 059.
DO $$
DECLARE signature regprocedure;
BEGIN
 FOR signature IN
  SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE (n.nspname='catalog' AND p.proname IN ('dispatch_kbs','sync_ota_channel','send_guest_whatsapp','generate_listing_invoice','create_marketplace_booking'))
     OR (n.nspname='onboarding' AND p.proname='trigger_module_action')
 LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO nexus_app',signature);
 END LOOP;
END $$;

