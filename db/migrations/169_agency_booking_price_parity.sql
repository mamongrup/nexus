-- The agency must charge exactly the locked supplier quote in this first
-- connected checkout contract. A mismatch rolls the booking transaction back.
ALTER FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb)
  RENAME TO process_reservation_webhook_unpriced;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook_unpriced(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC,nexus_app;

CREATE FUNCTION partners.process_reservation_webhook(
  p_idempotency_key text,
  p_agency_id text,
  p_listing_id text,
  p_guest_name text,
  p_guest_email text,
  p_guest_phone text,
  p_tc text,
  p_check_in text,
  p_check_out text,
  p_guests int,
  p_payload jsonb
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,booking,public
AS $$
DECLARE
  v_amount bigint;
  v_currency text := upper(btrim(coalesce(p_payload->>'currency','')));
  v_result jsonb;
  v_booking booking.reservations%ROWTYPE;
BEGIN
  IF coalesce(p_payload->>'amount_minor','') !~ '^[1-9][0-9]{0,14}$'
     OR v_currency !~ '^[A-Z]{3}$' THEN
    RETURN json_build_object('ok',false,'error','missing_price_snapshot')::text;
  END IF;
  v_amount := (p_payload->>'amount_minor')::bigint;

  BEGIN
    v_result := partners.process_reservation_webhook_unpriced(
      p_idempotency_key,p_agency_id,p_listing_id,p_guest_name,p_guest_email,
      p_guest_phone,p_tc,p_check_in,p_check_out,p_guests,p_payload)::jsonb;
    IF v_result->'ok' IS DISTINCT FROM 'true'::jsonb THEN
      RETURN v_result::text;
    END IF;
    SELECT b.* INTO v_booking FROM booking.reservations b
    WHERE b.id=(v_result->>'booking_reference')::uuid;
    IF NOT FOUND OR v_booking.total_minor IS DISTINCT FROM v_amount
       OR v_booking.currency::text IS DISTINCT FROM v_currency THEN
      RAISE EXCEPTION 'price_mismatch' USING ERRCODE='PZ001';
    END IF;
    RETURN (v_result || jsonb_build_object('total_minor',v_booking.total_minor,
      'currency',v_booking.currency))::text;
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN
    RETURN json_build_object('ok',false,'error','price_mismatch')::text;
  END;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;
