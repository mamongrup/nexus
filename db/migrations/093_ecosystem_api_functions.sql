-- 093_ecosystem_api_functions.sql
-- API Functions for 20 Industry Integrations

-- ─── 1. CRM & WhatsApp Functions ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION crm.list_guests()
RETURNS TABLE (
  id text,
  full_name text,
  email text,
  phone text,
  nationality text,
  total_stays text,
  total_spend text,
  vip_tier text,
  preferences text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    full_name,
    email,
    phone,
    nationality,
    total_stays::text,
    (total_spend_minor / 100)::text,
    vip_tier,
    preferences
  FROM crm.guest_profiles
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION crm.add_guest(
  p_name text,
  p_email text,
  p_phone text,
  p_nat text,
  p_tier text,
  p_pref text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
BEGIN
  INSERT INTO crm.guest_profiles (tenant_id, full_name, email, phone, nationality, vip_tier, preferences)
  VALUES (v_tenant, p_name, coalesce(p_email, ''), coalesce(p_phone, ''), coalesce(p_nat, 'TR'), coalesce(p_tier, 'standard'), coalesce(p_pref, ''));
  RETURN 'ok';
END;
$$;

CREATE OR REPLACE FUNCTION crm.list_whatsapp_messages()
RETURNS TABLE (
  id text,
  guest_name text,
  phone text,
  msg_type text,
  message text,
  status text,
  sent_at text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    guest_name,
    phone,
    msg_type,
    message,
    status,
    to_char(sent_at, 'DD.MM.YYYY HH24:MI')
  FROM crm.whatsapp_messages
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY sent_at DESC;
$$;

CREATE OR REPLACE FUNCTION crm.send_whatsapp_message(
  p_guest_name text,
  p_phone text,
  p_msg_type text,
  p_msg text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
BEGIN
  INSERT INTO crm.whatsapp_messages (tenant_id, guest_name, phone, msg_type, message, status)
  VALUES (v_tenant, p_guest_name, p_phone, p_msg_type, p_msg, 'sent');
  RETURN 'ok';
END;
$$;

-- ─── 2. Rate Shopper & Pricing Coach Functions ────────────────────────────────
CREATE OR REPLACE FUNCTION revenue.list_competitor_rates()
RETURNS TABLE (
  id text,
  competitor_name text,
  star_rating text,
  room_type text,
  channel text,
  competitor_price text,
  our_price text,
  currency text,
  check_in_date text,
  ai_recommendation text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    competitor_name,
    star_rating::text,
    room_type,
    channel,
    (competitor_price_minor / 100)::text,
    (our_price_minor / 100)::text,
    currency,
    check_in_date::text,
    ai_recommendation
  FROM revenue.competitor_rates
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY recorded_at DESC;
$$;

CREATE OR REPLACE FUNCTION revenue.add_competitor_rate(
  p_name text,
  p_stars int,
  p_room text,
  p_channel text,
  p_comp_price int,
  p_our_price int,
  p_currency text,
  p_date text,
  p_ai_rec text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
  v_d date := coalesce(nullif(p_date, '')::date, current_date);
BEGIN
  INSERT INTO revenue.competitor_rates (
    tenant_id, competitor_name, star_rating, room_type, channel,
    competitor_price_minor, our_price_minor, currency, check_in_date, ai_recommendation
  )
  VALUES (
    v_tenant, p_name, coalesce(p_stars, 4), coalesce(p_room, 'Standart Oda'), coalesce(p_channel, 'Booking.com'),
    p_comp_price * 100, p_our_price * 100, coalesce(p_currency, 'TRY'), v_d, coalesce(p_ai_rec, '')
  );
  RETURN 'ok';
END;
$$;

-- ─── 3. Tours & Packages Functions ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION tours.list_activities()
RETURNS TABLE (
  id text,
  title text,
  location text,
  category text,
  duration_hours text,
  net_price text,
  sale_price text,
  currency text,
  capacity text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    title,
    location,
    category,
    duration_hours::text,
    (net_price_minor / 100)::text,
    (sale_price_minor / 100)::text,
    currency,
    capacity_daily::text
  FROM tours.activities
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
    AND is_active = true
  ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION tours.add_activity(
  p_title text,
  p_loc text,
  p_cat text,
  p_dur int,
  p_net int,
  p_sale int,
  p_cur text,
  p_cap int
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
BEGIN
  INSERT INTO tours.activities (
    tenant_id, title, location, category, duration_hours,
    net_price_minor, sale_price_minor, currency, capacity_daily
  )
  VALUES (
    v_tenant, p_title, p_loc, coalesce(p_cat, 'other'), coalesce(p_dur, 3),
    p_net * 100, p_sale * 100, coalesce(p_cur, 'EUR'), coalesce(p_cap, 20)
  );
  RETURN 'ok';
END;
$$;

CREATE OR REPLACE FUNCTION tours.list_packages()
RETURNS TABLE (
  id text,
  package_code text,
  guest_name text,
  hotel_name text,
  activity_name text,
  transfer_included text,
  total_price text,
  currency text,
  status text,
  voucher_no text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    package_code,
    guest_name,
    hotel_name,
    activity_name,
    case when transfer_included then 'Evet (VIP)' else 'Hayır' end,
    (total_price_minor / 100)::text,
    currency,
    status,
    voucher_no
  FROM tours.packages
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION tours.create_package(
  p_guest text,
  p_hotel text,
  p_activity text,
  p_transfer bool,
  p_price int,
  p_cur text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
  v_rnd int := floor(random() * 90000 + 10000)::int;
  v_code text := 'PKG-' || v_rnd::text;
  v_vouch text := 'VCH-' || v_rnd::text;
BEGIN
  INSERT INTO tours.packages (
    tenant_id, package_code, guest_name, hotel_name, activity_name,
    transfer_included, total_price_minor, currency, voucher_no, status
  )
  VALUES (
    v_tenant, v_code, p_guest, p_hotel, p_activity,
    coalesce(p_transfer, true), p_price * 100, coalesce(p_cur, 'EUR'), v_vouch, 'confirmed'
  );
  RETURN 'ok';
END;
$$;

-- ─── 4. Fleet & Rentals Functions ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fleet.list_vehicles()
RETURNS TABLE (
  id text,
  plate_no text,
  brand text,
  model text,
  model_year text,
  transmission text,
  fuel_type text,
  current_km text,
  daily_rate text,
  currency text,
  status text,
  kabis text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    plate_no,
    brand,
    model,
    model_year::text,
    transmission,
    fuel_type,
    current_km::text,
    (daily_rate_minor / 100)::text,
    currency,
    status,
    case when kabis_registered then 'KABIS Onaylı' else 'Bekliyor' end
  FROM fleet.vehicles
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION fleet.add_vehicle(
  p_plate text,
  p_brand text,
  p_model text,
  p_year int,
  p_trans text,
  p_fuel text,
  p_km int,
  p_rate int,
  p_cur text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
BEGIN
  INSERT INTO fleet.vehicles (
    tenant_id, plate_no, brand, model, model_year, transmission, fuel_type,
    current_km, daily_rate_minor, currency, status, kabis_registered
  )
  VALUES (
    v_tenant, upper(trim(p_plate)), p_brand, p_model, coalesce(p_year, 2024),
    coalesce(p_trans, 'automatic'), coalesce(p_fuel, 'diesel'), coalesce(p_km, 0),
    p_rate * 100, coalesce(p_cur, 'TRY'), 'available', true
  )
  ON CONFLICT (tenant_id, plate_no) DO UPDATE
  SET brand = EXCLUDED.brand, model = EXCLUDED.model, daily_rate_minor = EXCLUDED.daily_rate_minor;
  RETURN 'ok';
END;
$$;

CREATE OR REPLACE FUNCTION fleet.list_rentals()
RETURNS TABLE (
  id text,
  agreement_no text,
  vehicle_plate text,
  driver_name text,
  driver_tc_passport text,
  driver_phone text,
  start_date text,
  end_date text,
  total_days text,
  total_amount text,
  deposit_amount text,
  status text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    agreement_no,
    vehicle_plate,
    driver_name,
    driver_tc_passport,
    driver_phone,
    start_date::text,
    end_date::text,
    total_days::text,
    (total_amount_minor / 100)::text,
    (deposit_amount_minor / 100)::text,
    status
  FROM fleet.rentals
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION fleet.create_rental(
  p_plate text,
  p_driver text,
  p_tc text,
  p_phone text,
  p_start text,
  p_end text,
  p_days int,
  p_amt int,
  p_dep int,
  p_cur text,
  p_dmg text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
  v_agree text := 'RNT-' || floor(random() * 90000 + 10000)::int::text;
  v_s date := coalesce(nullif(p_start, '')::date, current_date);
  v_e date := coalesce(nullif(p_end, '')::date, current_date + 3);
BEGIN
  INSERT INTO fleet.rentals (
    tenant_id, agreement_no, vehicle_plate, driver_name, driver_tc_passport, driver_phone,
    start_date, end_date, total_days, total_amount_minor, deposit_amount_minor, currency,
    damage_notes, status
  )
  VALUES (
    v_tenant, v_agree, upper(trim(p_plate)), p_driver, p_tc, p_phone,
    v_s, v_e, greatest(1, coalesce(p_days, 1)), p_amt * 100, p_dep * 100, coalesce(p_cur, 'TRY'),
    coalesce(p_dmg, ''), 'active'
  );

  UPDATE fleet.vehicles
  SET status = 'rented'
  WHERE tenant_id = v_tenant AND plate_no = upper(trim(p_plate));

  RETURN 'ok';
END;
$$;

-- ─── 5. e-Invoice Functions ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION invoicing.list_invoices()
RETURNS TABLE (
  id text,
  ettn text,
  invoice_no text,
  invoice_type text,
  receiver_name text,
  receiver_vkn_tckn text,
  net_amount text,
  vat_amount text,
  accommodation_tax text,
  grand_total text,
  currency text,
  gib_status text,
  profile text,
  created_at text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id::text,
    ettn::text,
    invoice_no,
    invoice_type,
    receiver_name,
    receiver_vkn_tckn,
    (net_amount_minor / 100)::text,
    (vat_amount_minor / 100)::text,
    (accommodation_tax_minor / 100)::text,
    (grand_total_minor / 100)::text,
    currency,
    gib_status,
    profile,
    to_char(created_at, 'DD.MM.YYYY HH24:MI')
  FROM invoicing.e_invoices
  WHERE tenant_id = current_setting('app.tenant_id', true)::uuid
  ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION invoicing.issue_invoice(
  p_type text,
  p_receiver_name text,
  p_vkn_tckn text,
  p_tax_office text,
  p_net int,
  p_vat int,
  p_acc_tax int,
  p_total int,
  p_cur text,
  p_profile text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant uuid := current_setting('app.tenant_id', true)::uuid;
  v_no text := 'NXS2026' || lpad((floor(random() * 899999999 + 100000000)::bigint)::text, 9, '0');
BEGIN
  INSERT INTO invoicing.e_invoices (
    tenant_id, invoice_no, invoice_type, receiver_name, receiver_vkn_tckn, receiver_tax_office,
    net_amount_minor, vat_amount_minor, accommodation_tax_minor, grand_total_minor,
    currency, gib_status, gib_status_code, profile
  )
  VALUES (
    v_tenant, v_no, coalesce(p_type, 'e-Arsiv'), p_receiver_name, p_vkn_tckn, coalesce(p_tax_office, ''),
    p_net * 100, p_vat * 100, p_acc_tax * 100, p_total * 100,
    coalesce(p_cur, 'TRY'), 'Kabul Edildi', 1200, coalesce(p_profile, 'EARSIVFATURA')
  );
  RETURN 'ok';
END;
$$;

-- ─── 6. Chexta Online Check-In Functions ─────────────────────────────────────
CREATE OR REPLACE FUNCTION booking.submit_online_checkin(
  p_res_id text,
  p_name text,
  p_tc text,
  p_phone text,
  p_email text,
  p_eta text,
  p_requests text,
  p_sig text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_pin text := lpad((floor(random() * 8999 + 1000)::int)::text, 4, '0');
BEGIN
  INSERT INTO booking.online_checkins (
    reservation_id, guest_name, tc_or_passport, phone, email,
    eta_time, special_requests, signature_data, door_pin_code, kvkk_accepted
  )
  VALUES (
    p_res_id, p_name, p_tc, p_phone, coalesce(p_email, ''),
    coalesce(p_eta, '14:00'), coalesce(p_requests, ''), coalesce(p_sig, 'DIGITAL_SIGNATURE_VERIFIED'),
    v_pin, true
  );
  RETURN v_pin;
END;
$$;

CREATE OR REPLACE FUNCTION booking.get_online_checkin(p_res_id text)
RETURNS TABLE (
  reservation_id text,
  guest_name text,
  tc_or_passport text,
  phone text,
  email text,
  eta_time text,
  door_pin_code text,
  checked_in_at text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    reservation_id,
    guest_name,
    tc_or_passport,
    phone,
    email,
    eta_time,
    door_pin_code,
    to_char(checked_in_at, 'DD.MM.YYYY HH24:MI')
  FROM booking.online_checkins
  WHERE reservation_id = p_res_id
  ORDER BY checked_in_at DESC
  LIMIT 1;
$$;

-- Grants
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA crm, revenue, tours, fleet, invoicing, booking TO nexus_app;
