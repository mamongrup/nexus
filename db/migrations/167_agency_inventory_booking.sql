-- Connected-agency lodging bookings use the same locked inventory days as
-- supplier calendar and option bookings. No external notification is claimed.
CREATE TABLE partners.agency_booking_links (
  agency_id uuid NOT NULL REFERENCES core.organizations(id),
  agency_reservation_id uuid NOT NULL,
  listing_id uuid NOT NULL REFERENCES catalog.properties(id),
  booking_id uuid NOT NULL UNIQUE REFERENCES booking.reservations(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(agency_id,agency_reservation_id)
);

REVOKE ALL ON partners.agency_booking_links FROM PUBLIC;

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
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,catalog,inventory,booking,public
AS $$
DECLARE
  v_inbox partners.agency_webhook_inbox%ROWTYPE;
  v_property catalog.properties%ROWTYPE;
  v_resource uuid;
  v_reservation uuid;
  v_agency_reservation uuid;
  v_check_in date;
  v_check_out date;
  v_days int;
  v_total bigint;
  v_snapshot jsonb;
  v_quote uuid;
  v_hold uuid;
  v_inbox_id uuid;
BEGIN
  IF nullif(btrim(p_idempotency_key),'') IS NULL THEN
    RETURN json_build_object('ok',false,'error','missing_idempotency_key')::text;
  END IF;
  IF coalesce(p_agency_id,'') !~ '^[0-9a-fA-F-]{36}$'
     OR coalesce(p_listing_id,'') !~ '^[0-9a-fA-F-]{36}$'
     OR coalesce(p_payload->>'reservation_id','') !~ '^[0-9a-fA-F-]{36}$' THEN
    RETURN json_build_object('ok',false,'error','invalid_scope')::text;
  END IF;
  BEGIN
    v_agency_reservation := (p_payload->>'reservation_id')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN json_build_object('ok',false,'error','invalid_scope')::text;
  END;
  BEGIN
    v_check_in := p_check_in::date;
    v_check_out := p_check_out::date;
  EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
    RETURN json_build_object('ok',false,'error','invalid_dates')::text;
  END;
  IF v_check_in IS NULL OR v_check_out IS NULL
     OR v_check_out<=v_check_in OR v_check_out-v_check_in>90
     OR v_check_in<(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date
     OR nullif(btrim(p_guest_name),'') IS NULL
     OR p_guests IS NULL OR p_guests NOT BETWEEN 1 AND 50 THEN
    RETURN json_build_object('ok',false,'error','invalid_booking')::text;
  END IF;

  SELECT * INTO v_inbox FROM partners.agency_webhook_inbox
  WHERE idempotency_key=p_idempotency_key FOR UPDATE;
  IF FOUND THEN
    IF v_inbox.agency_id IS DISTINCT FROM p_agency_id
       OR v_inbox.listing_id IS DISTINCT FROM p_listing_id
       OR v_inbox.event_type IS DISTINCT FROM 'reservation.created'
       OR v_inbox.payload->>'reservation_id' IS DISTINCT FROM v_agency_reservation::text THEN
      RETURN json_build_object('ok',false,'error','idempotency_scope_conflict')::text;
    END IF;
    IF v_inbox.status='processed' THEN
      SELECT l.booking_id INTO v_reservation
      FROM partners.agency_booking_links l
      JOIN booking.reservations b ON b.id=l.booking_id
      WHERE l.agency_id=p_agency_id::uuid
        AND l.agency_reservation_id=v_agency_reservation
        AND l.listing_id=p_listing_id::uuid
        AND b.status<>'cancelled';
      IF v_reservation IS NULL THEN
        RETURN json_build_object('ok',false,'error','legacy_booking_unverified')::text;
      END IF;
      RETURN json_build_object('ok',true,'status','duplicate_ignored',
        'inbox_id',v_inbox.id::text,'booking_reference',v_reservation::text)::text;
    END IF;
  END IF;

  -- All calendar writers lock this property before touching inventory days.
  SELECT p.* INTO v_property FROM catalog.properties p
  JOIN partners.connections c ON c.supplier_id=p.tenant_id
    AND c.agency_id=p_agency_id::uuid AND c.status='active'
  JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id
    AND cp.active
  WHERE p.id=p_listing_id::uuid AND p.status='published'
    AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN (
      SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)))
  FOR UPDATE OF p;
  IF NOT FOUND THEN
    RETURN json_build_object('ok',false,'error','agency_listing_not_connected')::text;
  END IF;
  IF v_property.category_code NOT IN ('hotel','holiday_home','yacht') THEN
    RETURN json_build_object('ok',false,'error','booking_unavailable')::text;
  END IF;
  IF p_guests>v_property.capacity THEN
    RETURN json_build_object('ok',false,'error','capacity_exceeded')::text;
  END IF;

  -- A second webhook key cannot book the same agency reservation again.
  SELECT l.booking_id INTO v_reservation FROM partners.agency_booking_links l
  WHERE l.agency_id=p_agency_id::uuid AND l.agency_reservation_id=v_agency_reservation;
  IF FOUND THEN
    RETURN json_build_object('ok',false,'error','reservation_key_conflict')::text;
  END IF;

  SELECT r.id INTO v_resource FROM inventory.resources r
  WHERE r.tenant_id=v_property.tenant_id AND r.property_id=v_property.id;
  IF v_resource IS NULL THEN
    RETURN json_build_object('ok',false,'error','inventory_unavailable')::text;
  END IF;
  PERFORM inventory.expire_locked(v_property.tenant_id,v_resource);
  SELECT count(*),sum(d.nightly_minor),
    jsonb_agg(jsonb_build_object('date',d.service_date,'minor',d.nightly_minor)
      ORDER BY d.service_date)
  INTO v_days,v_total,v_snapshot
  FROM inventory.days d
  WHERE d.tenant_id=v_property.tenant_id AND d.resource_id=v_resource
    AND d.service_date>=v_check_in AND d.service_date<v_check_out
    AND d.capacity-d.blocked-d.held-d.sold>=1
    AND d.nightly_minor IS NOT NULL AND d.currency=v_property.currency;
  IF v_days<>v_check_out-v_check_in OR v_total IS NULL THEN
    RETURN json_build_object('ok',false,'error','inventory_unavailable')::text;
  END IF;

  INSERT INTO booking.quotes(tenant_id,property_id,total_minor,currency,snapshot,expires_at)
  VALUES(v_property.tenant_id,v_property.id,v_total,v_property.currency,
    jsonb_build_object('nights',v_snapshot,'check_in',v_check_in,
      'check_out',v_check_out,'pricing_model','nightly_no_extras',
      'source','connected_agency','agency_id',p_agency_id,
      'agency_reservation_id',v_agency_reservation),
    clock_timestamp()+interval '30 minutes') RETURNING id INTO v_quote;
  INSERT INTO booking.holds(tenant_id,quote_id,status,expires_at,
    resource_id,check_in,check_out,request_key)
  VALUES(v_property.tenant_id,v_quote,'consumed',clock_timestamp()+interval '30 minutes',
    v_resource,v_check_in,v_check_out,'agency-reservation:'||v_agency_reservation::text)
  RETURNING id INTO v_hold;
  INSERT INTO inventory.allocations(tenant_id,hold_id,resource_id,service_date)
  SELECT v_property.tenant_id,v_hold,v_resource,v_check_in+i
  FROM generate_series(0,v_check_out-v_check_in-1) i;
  UPDATE inventory.days d SET sold=sold+1
  WHERE d.tenant_id=v_property.tenant_id AND d.resource_id=v_resource
    AND d.service_date>=v_check_in AND d.service_date<v_check_out;
  INSERT INTO booking.reservations(tenant_id,hold_id,status,agency_id,total_minor,currency)
  VALUES(v_property.tenant_id,v_hold,'confirmed',p_agency_id::uuid,
    v_total,v_property.currency) RETURNING id INTO v_reservation;
  INSERT INTO partners.agency_booking_links(
    agency_id,agency_reservation_id,listing_id,booking_id)
  VALUES(p_agency_id::uuid,v_agency_reservation,v_property.id,v_reservation);
  INSERT INTO events.audit(tenant_id,action,resource_id,payload)
  VALUES(v_property.tenant_id,'agency.reservation.created',v_reservation,
    jsonb_build_object('agency_id',p_agency_id,'agency_reservation_id',v_agency_reservation,
      'guest_name',p_guest_name,'total_minor',v_total));
  INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload)
  VALUES(v_property.tenant_id,'reservation.confirmed',v_reservation,1,
    jsonb_build_object('agency_id',p_agency_id,'source','connected_agency'));

  IF v_inbox.id IS NULL THEN
    INSERT INTO partners.agency_webhook_inbox(idempotency_key,agency_id,event_type,
      listing_id,payload,booking_reference,status,processed_at)
    VALUES(p_idempotency_key,p_agency_id,'reservation.created',p_listing_id,
      p_payload,v_reservation::text,'processed',now()) RETURNING id INTO v_inbox_id;
  ELSE
    UPDATE partners.agency_webhook_inbox SET payload=p_payload,
      booking_reference=v_reservation::text,status='processed',error_message=NULL,
      processed_at=now() WHERE id=v_inbox.id RETURNING id INTO v_inbox_id;
  END IF;
  RETURN json_build_object('ok',true,'status','processed','inbox_id',v_inbox_id::text,
    'booking_reference',v_reservation::text)::text;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;
