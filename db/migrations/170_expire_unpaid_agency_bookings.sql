ALTER TABLE partners.agency_booking_links
  ADD COLUMN expires_at timestamptz NOT NULL DEFAULT (now()+interval '45 minutes'),
  ADD COLUMN expired_at timestamptz;

CREATE INDEX agency_booking_links_unpaid_expiry_idx
  ON partners.agency_booking_links(expires_at)
  WHERE expired_at IS NULL;

CREATE FUNCTION partners.expire_unpaid_agency_bookings(p_limit int DEFAULT 100)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,booking,inventory,public
AS $$
DECLARE v_link record; v_booking booking.reservations%ROWTYPE; v_count int:=0;
BEGIN
  IF p_limit NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'invalid expiry batch size';
  END IF;
  FOR v_link IN
    SELECT l.agency_id,l.agency_reservation_id,l.booking_id,l.listing_id,
      b.tenant_id
    FROM partners.agency_booking_links l
    JOIN booking.reservations b ON b.id=l.booking_id
    WHERE l.expires_at<=clock_timestamp() AND l.expired_at IS NULL
      AND b.status='confirmed' AND b.payment_status='unpaid'
    ORDER BY l.expires_at,l.booking_id LIMIT p_limit
  LOOP
    -- Same property -> booking lock order as booking and cancellation.
    PERFORM 1 FROM catalog.properties p
    WHERE p.id=v_link.listing_id AND p.tenant_id=v_link.tenant_id FOR UPDATE;
    SELECT * INTO v_booking FROM booking.reservations
    WHERE id=v_link.booking_id AND tenant_id=v_link.tenant_id FOR UPDATE;
    IF v_booking.status='confirmed' AND v_booking.payment_status='unpaid'
       AND EXISTS(SELECT 1 FROM partners.agency_booking_links l
         WHERE l.agency_id=v_link.agency_id
           AND l.agency_reservation_id=v_link.agency_reservation_id
           AND l.expired_at IS NULL AND l.expires_at<=clock_timestamp()) THEN
      UPDATE inventory.days d SET sold=sold-1
      FROM inventory.allocations a
      WHERE a.tenant_id=v_link.tenant_id AND a.hold_id=v_booking.hold_id
        AND d.tenant_id=a.tenant_id AND d.resource_id=a.resource_id
        AND d.service_date=a.service_date;
      UPDATE booking.reservations SET status='cancelled' WHERE id=v_booking.id;
      UPDATE partners.agency_booking_links SET expired_at=now()
      WHERE agency_id=v_link.agency_id
        AND agency_reservation_id=v_link.agency_reservation_id;
      INSERT INTO events.audit(tenant_id,action,resource_id,payload)
      VALUES(v_link.tenant_id,'agency.reservation.payment_expired',v_booking.id,
        jsonb_build_object('agency_id',v_link.agency_id));
      INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload)
      VALUES(v_link.tenant_id,'reservation.cancelled',v_booking.id,2,
        jsonb_build_object('reason','payment_timeout','agency_id',v_link.agency_id));
      v_count:=v_count+1;
    END IF;
  END LOOP;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION partners.expire_unpaid_agency_bookings(int) FROM PUBLIC,nexus_app;

-- Add the deadline to every accepted receipt. A stale receipt cannot authorize
-- a fresh payment session even before the expiry worker has run.
ALTER FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb)
  RENAME TO process_reservation_webhook_undated;
REVOKE ALL ON FUNCTION partners.process_reservation_webhook_undated(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC,nexus_app;

CREATE FUNCTION partners.process_reservation_webhook(
  p_idempotency_key text,p_agency_id text,p_listing_id text,
  p_guest_name text,p_guest_email text,p_guest_phone text,p_tc text,
  p_check_in text,p_check_out text,p_guests int,p_payload jsonb
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,partners,booking,public AS $$
DECLARE v_result jsonb; v_expiry timestamptz; v_paid text;
BEGIN
  v_result := partners.process_reservation_webhook_undated(
    p_idempotency_key,p_agency_id,p_listing_id,p_guest_name,p_guest_email,
    p_guest_phone,p_tc,p_check_in,p_check_out,p_guests,p_payload)::jsonb;
  IF v_result->'ok' IS DISTINCT FROM 'true'::jsonb THEN
    RETURN v_result::text;
  END IF;
  SELECT l.expires_at,b.payment_status INTO v_expiry,v_paid
  FROM partners.agency_booking_links l
  JOIN booking.reservations b ON b.id=l.booking_id
  WHERE l.booking_id=(v_result->>'booking_reference')::uuid;
  IF v_expiry IS NULL OR (v_paid='unpaid' AND v_expiry<=clock_timestamp()) THEN
    RETURN json_build_object('ok',false,'error','booking_expired')::text;
  END IF;
  RETURN (v_result || jsonb_build_object('expires_at',v_expiry))::text;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(
  text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;
