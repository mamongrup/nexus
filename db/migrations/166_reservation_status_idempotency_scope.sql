ALTER FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb)
  RENAME TO process_reservation_status_webhook_unscoped;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook_unscoped(
  text,text,text,text,jsonb) FROM PUBLIC,nexus_app;

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
    v_existing.event_type IS DISTINCT FROM 'reservation.status_changed' OR
    nullif(btrim(v_existing.payload->>'reservation_id'),'')
      IS DISTINCT FROM nullif(btrim(p_payload->>'reservation_id'),'') OR
    lower(btrim(coalesce(v_existing.payload->>'reservation_status','')))
      IS DISTINCT FROM lower(btrim(coalesce(p_reservation_status,'')))
  ) THEN
    RETURN json_build_object('ok',false,'error','idempotency_scope_conflict')::text;
  END IF;

  RETURN partners.process_reservation_status_webhook_unscoped(
    p_idempotency_key,p_agency_id,p_listing_id,p_reservation_status,p_payload);
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook(
  text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_status_webhook(
  text,text,text,text,jsonb) TO nexus_app;
