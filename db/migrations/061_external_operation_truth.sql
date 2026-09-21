-- Never manufacture provider acknowledgements or reservation confirmations.
-- These adapters have no transport implementation yet. Fail before side effects.
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
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(p_property_id uuid,p_guest_name text,p_guest_email text,p_guest_phone text,p_tc text,p_check_in date,p_check_out date,p_guests int)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('error','booking_unavailable','message','Bu satış kanalının rezervasyon bağlantısı henüz hazır değil. Rezervasyon oluşturulmadı ve ödeme alınmadı.')
$$;
CREATE OR REPLACE FUNCTION onboarding.trigger_module_action(p_module text,p_action text,p_target text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'This module action has no execution adapter; nothing executed' USING ERRCODE='55000'; END $$;

-- Restrict the unguarded administration functions introduced in migration 060.
CREATE OR REPLACE FUNCTION catalog.all_properties_for_admin()
RETURNS TABLE(id text,title text,locality text,description text,capacity int,nightly_minor int,currency text,status text,version int)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT p.id::text,p.title,p.locality,coalesce(p.description,''),p.capacity,p.nightly_minor::int,p.currency::text,p.status,p.version::int
 FROM catalog.properties p WHERE onboarding.operator() ORDER BY p.created_at DESC LIMIT 100
$$;
CREATE OR REPLACE FUNCTION catalog.admin_publish(p_id text,p_version int,p_status text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT onboarding.operator() THEN RETURN false; END IF;
 IF p_status NOT IN ('published','draft') THEN RETURN false; END IF;
 UPDATE catalog.properties SET status=p_status,version=version+1,updated_at=now()
 WHERE id::text=p_id AND version=p_version;
 RETURN FOUND;
END $$;

ALTER TABLE catalog.property_kbs_records ALTER COLUMN police_status SET DEFAULT 'pending';
ALTER TABLE catalog.property_whatsapp_messages ALTER COLUMN delivery_status SET DEFAULT 'pending';
ALTER TABLE catalog.property_invoices ALTER COLUMN gib_status SET DEFAULT 'draft';
ALTER TABLE catalog.property_ota_channels ALTER COLUMN sync_status SET DEFAULT 'not_connected';

-- Preserve existing records for investigation; do not silently erase or reinterpret them.
COMMENT ON TABLE catalog.property_kbs_records IS 'Legacy migration 058 generated simulated acknowledgements; records are not proof of EGM receipt.';
COMMENT ON TABLE catalog.property_whatsapp_messages IS 'Legacy migration 058 generated simulated delivery statuses; records are not delivery receipts.';
COMMENT ON TABLE catalog.property_invoices IS 'Legacy migration 058 generated simulated approvals; records are not legally issued invoices.';
