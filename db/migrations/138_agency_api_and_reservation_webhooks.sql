-- 138_agency_api_and_reservation_webhooks.sql
-- Agency API & Reservation Webhook Idempotency & Inbox

CREATE TABLE IF NOT EXISTS partners.agency_webhook_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE,
  agency_id text NOT NULL DEFAULT '',
  event_type text NOT NULL DEFAULT 'reservation.created',
  listing_id text NOT NULL,
  payload jsonb NOT NULL,
  booking_reference text,
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'processed', 'failed')),
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);

CREATE INDEX IF NOT EXISTS agency_webhook_inbox_agency_idx
  ON partners.agency_webhook_inbox(agency_id, created_at DESC);

CREATE OR REPLACE FUNCTION partners.process_reservation_webhook(
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
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,catalog,partners,public AS $$
DECLARE
  existing_record partners.agency_webhook_inbox%ROWTYPE;
  booking_res text;
  new_id uuid;
BEGIN
  IF trim(coalesce(p_idempotency_key,'')) = '' THEN
    RETURN json_build_object('ok', false, 'error', 'missing_idempotency_key')::text;
  END IF;

  SELECT * INTO existing_record FROM partners.agency_webhook_inbox WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN json_build_object(
      'ok', true,
      'status', 'duplicate_ignored',
      'inbox_id', existing_record.id::text,
      'booking_reference', coalesce(existing_record.booking_reference, '')
    )::text;
  END IF;

  -- Attempt to invoke marketplace booking
  BEGIN
    booking_res := catalog.create_marketplace_booking(
      p_listing_id,
      p_guest_name,
      p_guest_email,
      p_guest_phone,
      coalesce(p_tc, ''),
      p_check_in,
      p_check_out,
      coalesce(p_guests, 1)
    );
  EXCEPTION WHEN OTHERS THEN
    booking_res := 'error: ' || SQLERRM;
  END;

  INSERT INTO partners.agency_webhook_inbox(
    idempotency_key, agency_id, event_type, listing_id, payload, booking_reference, status, processed_at
  ) VALUES (
    p_idempotency_key, coalesce(p_agency_id, ''), 'reservation.created', p_listing_id, p_payload,
    booking_res,
    CASE WHEN booking_res LIKE 'error:%' THEN 'failed' ELSE 'processed' END,
    now()
  ) RETURNING id INTO new_id;

  RETURN json_build_object(
    'ok', true,
    'status', 'processed',
    'inbox_id', new_id::text,
    'booking_reference', booking_res
  )::text;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;

CREATE OR REPLACE FUNCTION partners.receive_reservation_webhook_json(p_payload jsonb)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,catalog,partners,public AS $$
BEGIN
  RETURN partners.process_reservation_webhook(
    coalesce(p_payload->>'idempotency_key', ''),
    coalesce(p_payload->>'agency_id', ''),
    coalesce(p_payload->>'listing_id', ''),
    coalesce(p_payload->>'guest_name', ''),
    coalesce(p_payload->>'guest_email', ''),
    coalesce(p_payload->>'guest_phone', ''),
    coalesce(p_payload->>'tc', ''),
    coalesce(p_payload->>'check_in', ''),
    coalesce(p_payload->>'check_out', ''),
    coalesce(nullif(p_payload->>'guests', '')::int, 1),
    p_payload
  );
END $$;
REVOKE ALL ON FUNCTION partners.receive_reservation_webhook_json(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.receive_reservation_webhook_json(jsonb) TO nexus_app;
GRANT SELECT, INSERT, UPDATE ON partners.agency_webhook_inbox TO nexus_app;

