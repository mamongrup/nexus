-- 059_robust_function_signatures.sql
-- Overload functions to accept text parameters directly for reliable driver parameter binding

CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(
  p_property_id text,
  p_guest_name text,
  p_guest_email text,
  p_guest_phone text,
  p_tc text,
  p_check_in text,
  p_check_out text,
  p_guests int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_pid uuid;
  v_cin date;
  v_cout date;
BEGIN
  BEGIN
    v_pid := p_property_id::uuid;
    v_cin := p_check_in::date;
    v_cout := p_check_out::date;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('error', 'invalid_params', 'message', 'Geçersiz parametre formatı');
  END;

  RETURN catalog.create_marketplace_booking(
    v_pid,
    p_guest_name,
    p_guest_email,
    p_guest_phone,
    p_tc,
    v_cin,
    v_cout,
    p_guests
  );
END $$;

CREATE OR REPLACE FUNCTION catalog.dispatch_kbs(
  p_property_id text,
  p_guest_name text,
  p_tc text,
  p_room text,
  p_check_in text,
  p_check_out text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_pid uuid;
  v_cin date;
  v_cout date;
BEGIN
  BEGIN
    v_pid := p_property_id::uuid;
    v_cin := p_check_in::date;
    v_cout := p_check_out::date;
  EXCEPTION WHEN others THEN
    RETURN 'invalid_params';
  END;

  RETURN catalog.dispatch_kbs(
    v_pid,
    p_guest_name,
    p_tc,
    p_room,
    v_cin,
    v_cout
  );
END $$;

CREATE OR REPLACE FUNCTION catalog.listing_modules_cockpit(p_property_id text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT * FROM catalog.listing_modules_cockpit(p_property_id::uuid);
$$;

CREATE OR REPLACE FUNCTION catalog.listing_pms_units(p_property_id text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT * FROM catalog.listing_pms_units(p_property_id::uuid);
$$;

CREATE OR REPLACE FUNCTION catalog.update_unit_status(
  p_unit_id text,
  p_occupancy text,
  p_housekeeping text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  RETURN catalog.update_unit_status(p_unit_id::uuid, p_occupancy, p_housekeeping);
END $$;

CREATE OR REPLACE FUNCTION catalog.sync_ota_channel(
  p_property_id text,
  p_channel text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  RETURN catalog.sync_ota_channel(p_property_id::uuid, p_channel);
END $$;

CREATE OR REPLACE FUNCTION catalog.send_guest_whatsapp(
  p_property_id text,
  p_phone text,
  p_template text,
  p_content text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  RETURN catalog.send_guest_whatsapp(p_property_id::uuid, p_phone, p_template, p_content);
END $$;

CREATE OR REPLACE FUNCTION catalog.generate_listing_invoice(
  p_property_id text,
  p_recipient text,
  p_amount bigint
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  RETURN catalog.generate_listing_invoice(p_property_id::uuid, p_recipient, p_amount);
END $$;

CREATE OR REPLACE FUNCTION catalog.marketplace_listing_detail(p_property_id text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT * FROM catalog.marketplace_listing_detail(p_property_id::uuid);
$$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA catalog TO nexus_app;
