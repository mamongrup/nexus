-- Idempotency keys must never be shared across agency/listing scopes.
ALTER FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb)
  RENAME TO process_reservation_webhook_unscoped;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook_unscoped(
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
SET search_path=pg_catalog,partners,public
AS $$
DECLARE v_existing partners.agency_webhook_inbox%ROWTYPE;
BEGIN
  IF nullif(btrim(p_idempotency_key),'') IS NULL THEN
    RETURN json_build_object('ok',false,'error','missing_idempotency_key')::text;
  END IF;

  SELECT * INTO v_existing
  FROM partners.agency_webhook_inbox
  WHERE idempotency_key=p_idempotency_key FOR UPDATE;
  IF FOUND AND (
    v_existing.agency_id IS DISTINCT FROM p_agency_id OR
    v_existing.listing_id IS DISTINCT FROM p_listing_id OR
    v_existing.event_type IS DISTINCT FROM 'reservation.created' OR
    nullif(btrim(v_existing.payload->>'reservation_id'),'')
      IS DISTINCT FROM nullif(btrim(p_payload->>'reservation_id'),'')
  ) THEN
    RETURN json_build_object('ok',false,'error','idempotency_scope_conflict')::text;
  END IF;

  RETURN partners.process_reservation_webhook_unscoped(
    p_idempotency_key,p_agency_id,p_listing_id,p_guest_name,p_guest_email,
    p_guest_phone,p_tc,p_check_in,p_check_out,p_guests,p_payload);
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;
