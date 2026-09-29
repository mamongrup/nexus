CREATE TABLE partners.agency_booking_failures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL,
  agency_id text NOT NULL DEFAULT '',
  listing_id text NOT NULL DEFAULT '',
  agency_reservation_id text NOT NULL DEFAULT '',
  error_code text NOT NULL,
  attempts int NOT NULL DEFAULT 1,
  first_at timestamptz NOT NULL DEFAULT now(),
  last_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(idempotency_key,error_code)
);
CREATE INDEX agency_booking_failures_recent_idx
  ON partners.agency_booking_failures(last_at DESC);
REVOKE ALL ON partners.agency_booking_failures FROM PUBLIC;

ALTER FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb)
  RENAME TO process_reservation_webhook_unlogged;
REVOKE ALL ON FUNCTION partners.process_reservation_webhook_unlogged(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC,nexus_app;

CREATE FUNCTION partners.process_reservation_webhook(
  p_idempotency_key text,p_agency_id text,p_listing_id text,
  p_guest_name text,p_guest_email text,p_guest_phone text,p_tc text,
  p_check_in text,p_check_out text,p_guests int,p_payload jsonb
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,public AS $$
DECLARE v_result jsonb; v_error text;
BEGIN
  v_result := partners.process_reservation_webhook_unlogged(
    p_idempotency_key,p_agency_id,p_listing_id,p_guest_name,p_guest_email,
    p_guest_phone,p_tc,p_check_in,p_check_out,p_guests,p_payload)::jsonb;
  IF v_result->'ok' IS DISTINCT FROM 'true'::jsonb THEN
    v_error := left(coalesce(nullif(v_result->>'error',''),'unknown_error'),80);
    INSERT INTO partners.agency_booking_failures(idempotency_key,agency_id,
      listing_id,agency_reservation_id,error_code)
    VALUES(coalesce(p_idempotency_key,''),coalesce(p_agency_id,''),
      coalesce(p_listing_id,''),coalesce(p_payload->>'reservation_id',''),v_error)
    ON CONFLICT(idempotency_key,error_code) DO UPDATE SET
      attempts=partners.agency_booking_failures.attempts+1,
      last_at=now();
  END IF;
  RETURN v_result::text;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;
