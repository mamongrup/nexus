BEGIN;
DO $$
DECLARE
  v_property uuid;
  v_resource uuid;
  v_agency uuid;
  v_supplier uuid;
  v_day date;
  v_capacity int;
  v_sold int;
  v_amount bigint;
  v_currency text;
  v_reservation uuid := gen_random_uuid();
  v_key text := 'agency-reservation:' || gen_random_uuid()::text;
  v_payload jsonb;
  v_result jsonb;
  v_retry jsonb;
BEGIN
  SELECT p.id,r.id,c.agency_id,p.tenant_id,d.service_date,d.capacity,d.sold,
    d.nightly_minor,p.currency::text
  INTO v_property,v_resource,v_agency,v_supplier,v_day,v_capacity,v_sold,
    v_amount,v_currency
  FROM catalog.properties p
  JOIN partners.connections c ON c.supplier_id=p.tenant_id AND c.status='active'
  JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id AND cp.active
  JOIN inventory.resources r ON r.property_id=p.id AND r.tenant_id=p.tenant_id
  JOIN inventory.days d ON d.resource_id=r.id AND d.tenant_id=r.tenant_id
  WHERE p.status='published' AND p.category_code IN ('hotel','holiday_home','yacht')
    AND d.service_date>(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date
    AND d.capacity-d.blocked-d.held-d.sold>=1
    AND d.nightly_minor IS NOT NULL AND d.currency=p.currency
    AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN (
      SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)))
  ORDER BY d.service_date LIMIT 1;
  IF v_property IS NULL THEN
    RAISE EXCEPTION 'No connected lodging inventory fixture';
  END IF;
  v_payload := jsonb_build_object('reservation_id',v_reservation,
    'check_in',v_day,'check_out',v_day+1,'guests',1,
    'amount_minor',v_amount::text,'currency',v_currency);

  v_result := partners.process_reservation_webhook(v_key,v_agency::text,
    v_property::text,'Inventory Test','test@example.invalid','','',
    v_day::text,(v_day+1)::text,1,
    v_payload || jsonb_build_object('amount_minor',(v_amount-1)::text))::jsonb;
  IF v_result->>'error'<>'price_mismatch' OR EXISTS (
    SELECT 1 FROM partners.agency_booking_links l
    WHERE l.agency_id=v_agency AND l.agency_reservation_id=v_reservation) THEN
    RAISE EXCEPTION 'price_mismatch_created_booking: %',v_result;
  END IF;
  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier
      AND resource_id=v_resource AND service_date=v_day)<>v_sold THEN
    RAISE EXCEPTION 'price_mismatch_consumed_inventory';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM partners.agency_booking_failures f
    WHERE f.idempotency_key=v_key AND f.error_code='price_mismatch'
      AND f.agency_id=v_agency::text AND f.listing_id=v_property::text) THEN
    RAISE EXCEPTION 'price_mismatch_not_audited';
  END IF;

  v_result := partners.process_reservation_webhook(v_key,v_agency::text,
    v_property::text,'Inventory Test','test@example.invalid','','',
    v_day::text,(v_day+1)::text,1,v_payload)::jsonb;
  IF v_result->>'status'<>'processed' THEN
    RAISE EXCEPTION 'inventory_booking_failed: %',v_result;
  END IF;
  IF (v_result->>'expires_at')::timestamptz<=clock_timestamp() THEN
    RAISE EXCEPTION 'booking_deadline_missing: %',v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM partners.agency_booking_links l
    JOIN booking.reservations b ON b.id=l.booking_id
    WHERE l.agency_id=v_agency AND l.agency_reservation_id=v_reservation
      AND b.id=(v_result->>'booking_reference')::uuid
      AND b.tenant_id=v_supplier AND b.status='confirmed'
      AND b.payment_status='unpaid') THEN
    RAISE EXCEPTION 'missing_real_booking: %',v_result;
  END IF;
  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier
      AND resource_id=v_resource AND service_date=v_day)<>v_sold+1 THEN
    RAISE EXCEPTION 'inventory_not_consumed';
  END IF;

  v_retry := partners.process_reservation_webhook(v_key,v_agency::text,
    v_property::text,'Inventory Test','test@example.invalid','','',
    v_day::text,(v_day+1)::text,1,v_payload)::jsonb;
  IF v_retry->>'status'<>'duplicate_ignored'
     OR v_retry->>'booking_reference'<>v_result->>'booking_reference' THEN
    RAISE EXCEPTION 'retry_created_duplicate: %',v_retry;
  END IF;
  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier
      AND resource_id=v_resource AND service_date=v_day)<>v_sold+1 THEN
    RAISE EXCEPTION 'retry_consumed_inventory';
  END IF;
  v_result := partners.process_reservation_status_webhook(
    'paid-'||v_reservation::text,v_agency::text,v_property::text,
    'confirmed',jsonb_build_object('reservation_id',v_reservation))::jsonb;
  IF v_result->>'status'<>'processed' OR NOT EXISTS (
    SELECT 1 FROM booking.reservations b
    JOIN partners.agency_booking_links l ON l.booking_id=b.id
    WHERE l.agency_id=v_agency AND l.agency_reservation_id=v_reservation
      AND b.payment_status='paid') THEN
    RAISE EXCEPTION 'payment_status_not_linked: %',v_result;
  END IF;
  v_retry := partners.process_reservation_status_webhook(
    'paid-'||v_reservation::text,v_agency::text,v_property::text,
    'cancelled',jsonb_build_object('reservation_id',v_reservation))::jsonb;
  IF v_retry->>'error'<>'idempotency_scope_conflict' THEN
    RAISE EXCEPTION 'status_key_scope_conflict_missing: %',v_retry;
  END IF;
  v_result := partners.process_reservation_status_webhook(
    'cancel-'||v_reservation::text,v_agency::text,v_property::text,
    'cancelled',jsonb_build_object('reservation_id',v_reservation))::jsonb;
  IF v_result->>'status'<>'processed' OR NOT EXISTS (
    SELECT 1 FROM booking.reservations b
    JOIN partners.agency_booking_links l ON l.booking_id=b.id
    WHERE l.agency_id=v_agency AND l.agency_reservation_id=v_reservation
      AND b.status='cancelled' AND b.payment_status='paid') THEN
    RAISE EXCEPTION 'cancellation_not_linked: %',v_result;
  END IF;
  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier
      AND resource_id=v_resource AND service_date=v_day)<>v_sold THEN
    RAISE EXCEPTION 'cancellation_did_not_release_inventory';
  END IF;
  v_retry := partners.process_reservation_status_webhook(
    'cancel-'||v_reservation::text,v_agency::text,v_property::text,
    'cancelled',jsonb_build_object('reservation_id',v_reservation))::jsonb;
  IF v_retry->>'status'<>'duplicate_ignored' THEN
    RAISE EXCEPTION 'cancellation_retry_failed: %',v_retry;
  END IF;

  v_reservation := gen_random_uuid();
  v_key := 'agency-reservation:'||gen_random_uuid()::text;
  v_payload := v_payload || jsonb_build_object('reservation_id',v_reservation);
  v_result := partners.process_reservation_webhook(v_key,v_agency::text,
    v_property::text,'Inventory Test','test@example.invalid','','',
    v_day::text,(v_day+1)::text,1,v_payload)::jsonb;
  IF v_result->>'status'<>'processed' THEN
    RAISE EXCEPTION 'second_booking_failed: %',v_result;
  END IF;
  UPDATE partners.agency_booking_links SET expires_at=now()-interval '1 minute'
  WHERE agency_id=v_agency AND agency_reservation_id=v_reservation;
  v_retry := partners.process_reservation_status_webhook(
    'late-paid-'||v_reservation::text,v_agency::text,v_property::text,
    'confirmed',jsonb_build_object('reservation_id',v_reservation))::jsonb;
  IF v_retry->>'error'<>'booking_expired' THEN
    RAISE EXCEPTION 'late_payment_accepted: %',v_retry;
  END IF;
  IF partners.expire_unpaid_agency_bookings(100)<1 THEN
    RAISE EXCEPTION 'unpaid_booking_not_expired';
  END IF;
  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier
      AND resource_id=v_resource AND service_date=v_day)<>v_sold THEN
    RAISE EXCEPTION 'expired_booking_did_not_release_inventory';
  END IF;
  RAISE NOTICE 'connected agency inventory booking passed';
END $$;
ROLLBACK;
