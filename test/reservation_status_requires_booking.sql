BEGIN;
DO $$
DECLARE
  v_agency text;
  v_listing text;
  v_reservation text := gen_random_uuid()::text;
  v_result jsonb;
BEGIN
  SELECT c.agency_id::text,p.id::text INTO v_agency,v_listing
  FROM catalog.properties p
  JOIN partners.connections c ON c.supplier_id=p.tenant_id AND c.status='active'
  JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id AND cp.active
  WHERE p.status='published'
    AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN (
      SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)))
  LIMIT 1;
  IF v_agency IS NULL THEN
    v_agency:=gen_random_uuid()::text;
    v_listing:=gen_random_uuid()::text;
  END IF;

  v_result := partners.process_reservation_status_webhook(
    'missing-'||v_reservation,v_agency,v_listing,'cancelled',
    jsonb_build_object('reservation_id',v_reservation));
  IF v_result->>'error'<>'reservation_not_found' THEN
    RAISE EXCEPTION 'unknown_reservation_status_accepted: %',v_result;
  END IF;

  IF NOT EXISTS(SELECT 1 FROM partners.connections c
    WHERE c.agency_id=v_agency::uuid AND c.status='active') THEN
    RAISE NOTICE 'no connected listing; orphan rejection passed';
    RETURN;
  END IF;

  INSERT INTO partners.agency_webhook_inbox(
    idempotency_key,agency_id,event_type,listing_id,payload,booking_reference,status)
  VALUES('created-'||v_reservation,v_agency,'reservation.created',v_listing,
    jsonb_build_object('reservation_id',v_reservation),'TEST-BOOKING','processed');

  v_result := partners.process_reservation_status_webhook(
    'wrong-agency-'||v_reservation,gen_random_uuid()::text,v_listing,'cancelled',
    jsonb_build_object('reservation_id',v_reservation));
  IF v_result->>'error'<>'reservation_not_found' THEN
    RAISE EXCEPTION 'cross_agency_status_accepted: %',v_result;
  END IF;

  v_result := partners.process_reservation_status_webhook(
    'status-'||v_reservation,v_agency,v_listing,'cancelled',
    jsonb_build_object('reservation_id',v_reservation));
  IF v_result->>'error'<>'reservation_not_found' THEN
    RAISE EXCEPTION 'legacy_reference_without_booking_accepted: %',v_result;
  END IF;
  RAISE NOTICE 'reservation status requires a real linked booking passed';
END $$;
ROLLBACK;
