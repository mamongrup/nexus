BEGIN;
DO $$
DECLARE
  v_key text := 'scope-' || gen_random_uuid()::text;
  v_agency text := gen_random_uuid()::text;
  v_listing text := gen_random_uuid()::text;
  v_reservation text := gen_random_uuid()::text;
  v_result jsonb;
BEGIN
  INSERT INTO partners.agency_webhook_inbox(
    idempotency_key,agency_id,event_type,listing_id,payload,
    booking_reference,status)
  VALUES(v_key,v_agency,'reservation.created',v_listing,
    jsonb_build_object('reservation_id',v_reservation),'TEST-BOOKING','processed');

  v_result := partners.process_reservation_webhook(
    v_key,gen_random_uuid()::text,v_listing,'Guest','','','',
    (current_date+1)::text,(current_date+2)::text,1,
    jsonb_build_object('reservation_id',v_reservation,'amount_minor','100',
      'currency','TRY'))::jsonb;
  IF v_result->>'error'<>'idempotency_scope_conflict' THEN
    RAISE EXCEPTION 'cross_agency_key_accepted: %',v_result;
  END IF;

  v_result := partners.process_reservation_webhook(
    v_key,v_agency,gen_random_uuid()::text,'Guest','','','',
    (current_date+1)::text,(current_date+2)::text,1,
    jsonb_build_object('reservation_id',v_reservation,'amount_minor','100',
      'currency','TRY'))::jsonb;
  IF v_result->>'error'<>'idempotency_scope_conflict' THEN
    RAISE EXCEPTION 'cross_listing_key_accepted: %',v_result;
  END IF;

  v_result := partners.process_reservation_webhook(
    v_key,v_agency,v_listing,'Guest','','','',
    (current_date+1)::text,(current_date+2)::text,1,
    jsonb_build_object('reservation_id',gen_random_uuid()::text,
      'amount_minor','100','currency','TRY'))::jsonb;
  IF v_result->>'error'<>'idempotency_scope_conflict' THEN
    RAISE EXCEPTION 'cross_reservation_key_accepted: %',v_result;
  END IF;

  v_result := partners.process_reservation_webhook(
    v_key,v_agency,v_listing,'Guest','','','',
    (current_date+1)::text,(current_date+2)::text,1,
    jsonb_build_object('reservation_id',v_reservation,'amount_minor','100',
      'currency','TRY'))::jsonb;
  IF v_result->>'error'<>'legacy_booking_unverified' THEN
    RAISE EXCEPTION 'legacy_booking_reference_accepted: %',v_result;
  END IF;
  RAISE NOTICE 'reservation webhook idempotency scope passed';
END $$;
ROLLBACK;
