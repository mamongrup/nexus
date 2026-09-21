-- 094_checkin_list_and_ecosystem_enhancements.sql
-- Real-time Chexta / HMS front-desk monitoring for online check-ins

CREATE OR REPLACE FUNCTION booking.list_online_checkins()
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
  ORDER BY checked_in_at DESC
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION booking.list_online_checkins() TO nexus_app;
