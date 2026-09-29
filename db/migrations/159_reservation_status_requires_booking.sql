-- Status events must refer to a booking created for this same agency/listing.
-- A status event alone cannot establish a reservation on the central platform.
ALTER FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb)
  RENAME TO process_reservation_status_webhook_unchecked;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook_unchecked(text,text,text,text,jsonb)
  FROM PUBLIC, nexus_app;

CREATE FUNCTION partners.process_reservation_status_webhook(
  p_idempotency_key text,
  p_agency_id text,
  p_listing_id text,
  p_reservation_status text,
  p_payload jsonb
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,public
AS $$
DECLARE
  v_reservation_id text := nullif(btrim(p_payload->>'reservation_id'),'');
BEGIN
  IF v_reservation_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM partners.agency_webhook_inbox i
    WHERE i.agency_id=p_agency_id
      AND i.listing_id=p_listing_id
      AND i.event_type='reservation.created'
      AND i.status='processed'
      AND i.payload->>'reservation_id'=v_reservation_id
      AND nullif(btrim(i.booking_reference),'') IS NOT NULL
  ) THEN
    RETURN json_build_object('ok',false,'error','reservation_not_found')::text;
  END IF;
  RETURN partners.process_reservation_status_webhook_unchecked(
    p_idempotency_key,p_agency_id,p_listing_id,p_reservation_status,p_payload
  );
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb)
  TO nexus_app;
