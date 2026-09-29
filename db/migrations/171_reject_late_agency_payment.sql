ALTER FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb)
  RENAME TO process_reservation_status_webhook_without_deadline;
REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook_without_deadline(
  text,text,text,text,jsonb) FROM PUBLIC,nexus_app;

CREATE FUNCTION partners.process_reservation_status_webhook(
  p_idempotency_key text,p_agency_id text,p_listing_id text,
  p_reservation_status text,p_payload jsonb
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,booking,public AS $$
DECLARE v_expired boolean;
BEGIN
  IF lower(btrim(coalesce(p_reservation_status,''))) IN ('confirmed','completed') THEN
    BEGIN
      SELECT l.expires_at<=clock_timestamp()
        AND b.payment_status='unpaid'
      INTO v_expired
      FROM partners.agency_booking_links l
      JOIN booking.reservations b ON b.id=l.booking_id
      WHERE l.agency_id=p_agency_id::uuid
        AND l.listing_id=p_listing_id::uuid
        AND l.agency_reservation_id=(p_payload->>'reservation_id')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN json_build_object('ok',false,'error','invalid_scope')::text;
    END;
    IF v_expired THEN
      RETURN json_build_object('ok',false,'error','booking_expired')::text;
    END IF;
  END IF;
  RETURN partners.process_reservation_status_webhook_without_deadline(
    p_idempotency_key,p_agency_id,p_listing_id,p_reservation_status,p_payload);
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook(
  text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_status_webhook(
  text,text,text,text,jsonb) TO nexus_app;
