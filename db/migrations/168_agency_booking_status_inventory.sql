-- Apply agency reservation lifecycle events to the linked central booking.
CREATE OR REPLACE FUNCTION partners.process_reservation_status_webhook(
  p_idempotency_key text,
  p_agency_id text,
  p_listing_id text,
  p_reservation_status text,
  p_payload jsonb
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,catalog,inventory,booking,public
AS $$
DECLARE
  v_existing partners.agency_webhook_inbox%ROWTYPE;
  v_booking booking.reservations%ROWTYPE;
  v_booking_id uuid;
  v_supplier uuid;
  v_property uuid;
  v_status text := lower(btrim(coalesce(p_reservation_status,'')));
  v_agency_reservation uuid;
  v_inbox_id uuid;
BEGIN
  IF nullif(btrim(p_idempotency_key),'') IS NULL THEN
    RETURN json_build_object('ok',false,'error','missing_idempotency_key')::text;
  END IF;
  IF v_status NOT IN ('inquiry','option','confirmed','cancelled','completed') THEN
    RETURN json_build_object('ok',false,'error','invalid_reservation_status')::text;
  END IF;
  BEGIN
    v_agency_reservation := (p_payload->>'reservation_id')::uuid;
    PERFORM p_agency_id::uuid;
    PERFORM p_listing_id::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN json_build_object('ok',false,'error','invalid_scope')::text;
  END;
  IF v_agency_reservation IS NULL OR p_agency_id IS NULL OR p_listing_id IS NULL THEN
    RETURN json_build_object('ok',false,'error','invalid_scope')::text;
  END IF;

  SELECT * INTO v_existing FROM partners.agency_webhook_inbox
  WHERE idempotency_key=p_idempotency_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing.agency_id IS DISTINCT FROM p_agency_id
       OR v_existing.listing_id IS DISTINCT FROM p_listing_id
       OR v_existing.event_type IS DISTINCT FROM 'reservation.status_changed'
       OR v_existing.payload->>'reservation_id' IS DISTINCT FROM v_agency_reservation::text
       OR v_existing.payload->>'reservation_status' IS DISTINCT FROM v_status THEN
      RETURN json_build_object('ok',false,'error','idempotency_scope_conflict')::text;
    END IF;
    IF v_existing.status='processed' THEN
      RETURN json_build_object('ok',true,'status','duplicate_ignored',
        'inbox_id',v_existing.id::text,'reservation_status',v_status)::text;
    END IF;
  END IF;

  SELECT l.booking_id,p.tenant_id,p.id
  INTO v_booking_id,v_supplier,v_property
  FROM partners.agency_booking_links l
  JOIN catalog.properties p ON p.id=l.listing_id
  WHERE l.agency_id=p_agency_id::uuid
    AND l.agency_reservation_id=v_agency_reservation
    AND l.listing_id=p_listing_id::uuid;
  IF NOT FOUND THEN
    RETURN json_build_object('ok',false,'error','reservation_not_found')::text;
  END IF;

  -- Preserve the inventory lock order used by calendar writes.
  PERFORM 1 FROM catalog.properties
  WHERE id=v_property AND tenant_id=v_supplier FOR UPDATE;
  SELECT * INTO v_booking FROM booking.reservations
  WHERE id=v_booking_id AND tenant_id=v_supplier FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('ok',false,'error','reservation_not_found')::text;
  END IF;
  IF v_status='confirmed' THEN
    IF v_booking.status<>'confirmed' THEN
      RETURN json_build_object('ok',false,'error','invalid_transition')::text;
    END IF;
    IF v_booking.payment_status='unpaid' THEN
      UPDATE booking.reservations SET payment_status='paid' WHERE id=v_booking.id;
      INSERT INTO events.audit(tenant_id,action,resource_id,payload)
      VALUES(v_supplier,'agency.reservation.paid',v_booking.id,
        jsonb_build_object('agency_id',p_agency_id));
    END IF;
  ELSIF v_status='cancelled' THEN
    IF v_booking.status='fulfilled' THEN
      RETURN json_build_object('ok',false,'error','invalid_transition')::text;
    END IF;
    IF v_booking.status='confirmed' THEN
      UPDATE inventory.days d SET sold=sold-1
      FROM inventory.allocations a
      WHERE a.tenant_id=v_supplier AND a.hold_id=v_booking.hold_id
        AND d.tenant_id=a.tenant_id AND d.resource_id=a.resource_id
        AND d.service_date=a.service_date;
      UPDATE booking.reservations SET status='cancelled' WHERE id=v_booking.id;
      INSERT INTO events.audit(tenant_id,action,resource_id,payload)
      VALUES(v_supplier,'agency.reservation.cancelled',v_booking.id,
        jsonb_build_object('agency_id',p_agency_id,
          'payment_status',v_booking.payment_status,
          'refund_review_required',v_booking.payment_status='paid'));
      INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload)
      VALUES(v_supplier,'reservation.cancelled',v_booking.id,2,
        jsonb_build_object('agency_id',p_agency_id));
    END IF;
  ELSIF v_status='completed' THEN
    IF v_booking.status NOT IN ('confirmed','fulfilled') THEN
      RETURN json_build_object('ok',false,'error','invalid_transition')::text;
    END IF;
    IF v_booking.status='confirmed' THEN
      UPDATE booking.reservations SET status='fulfilled' WHERE id=v_booking.id;
      INSERT INTO events.audit(tenant_id,action,resource_id,payload)
      VALUES(v_supplier,'agency.reservation.fulfilled',v_booking.id,
        jsonb_build_object('agency_id',p_agency_id));
    END IF;
  END IF;

  IF v_existing.id IS NULL THEN
    INSERT INTO partners.agency_webhook_inbox(idempotency_key,agency_id,event_type,
      listing_id,payload,booking_reference,status,processed_at)
    VALUES(p_idempotency_key,p_agency_id,'reservation.status_changed',p_listing_id,
      p_payload || jsonb_build_object('reservation_status',v_status),
      v_booking_id::text,'processed',now()) RETURNING id INTO v_inbox_id;
  ELSE
    UPDATE partners.agency_webhook_inbox SET
      payload=p_payload || jsonb_build_object('reservation_status',v_status),
      booking_reference=v_booking_id::text,status='processed',
      error_message=NULL,processed_at=now()
    WHERE id=v_existing.id RETURNING id INTO v_inbox_id;
  END IF;
  RETURN json_build_object('ok',true,'status','processed',
    'inbox_id',v_inbox_id::text,'reservation_status',v_status)::text;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook(
  text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_status_webhook(
  text,text,text,text,jsonb) TO nexus_app;
