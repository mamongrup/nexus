-- Accept reservation lifecycle updates from agencies without creating another
-- marketplace booking. Creation remains handled by reservation.created.
CREATE OR REPLACE FUNCTION partners.process_reservation_status_webhook(
  p_idempotency_key text,
  p_agency_id text,
  p_listing_id text,
  p_reservation_status text,
  p_payload jsonb
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,catalog,partners,public
AS $$
DECLARE
  existing_record partners.agency_webhook_inbox%ROWTYPE;
  new_id uuid;
  normalized_status text;
  has_existing boolean := false;
BEGIN
  normalized_status := lower(trim(coalesce(p_reservation_status,'')));

  IF trim(coalesce(p_idempotency_key,'')) = '' THEN
    RETURN json_build_object('ok',false,'error','missing_idempotency_key')::text;
  END IF;
  IF coalesce(p_agency_id,'') !~ '^[0-9a-fA-F-]{36}$'
     OR coalesce(p_listing_id,'') !~ '^[0-9a-fA-F-]{36}$' THEN
    RETURN json_build_object('ok',false,'error','invalid_scope')::text;
  END IF;
  IF normalized_status NOT IN ('inquiry','option','confirmed','cancelled','completed') THEN
    RETURN json_build_object('ok',false,'error','invalid_reservation_status')::text;
  END IF;

  SELECT *
    INTO existing_record
    FROM partners.agency_webhook_inbox
   WHERE idempotency_key=p_idempotency_key
   FOR UPDATE;

  IF FOUND AND existing_record.status='processed' THEN
    RETURN json_build_object(
      'ok',true,'status','duplicate_ignored',
      'inbox_id',existing_record.id::text,
      'reservation_status',coalesce(existing_record.payload->>'reservation_status','')
    )::text;
  END IF;
  has_existing := FOUND;

  IF NOT EXISTS (
    SELECT 1
      FROM catalog.properties p
      JOIN partners.connections c
        ON c.supplier_id=p.tenant_id
       AND c.agency_id=p_agency_id::uuid
       AND c.status='active'
      JOIN partners.connection_policies cp
        ON cp.agency_id=c.agency_id AND cp.active
     WHERE p.id=p_listing_id::uuid
       AND p.status='published'
       AND (jsonb_array_length(cp.allowed_categories)=0
         OR p.category_code IN (
           SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)
         ))
  ) THEN
    RETURN json_build_object('ok',false,'error','agency_listing_not_connected')::text;
  END IF;

  IF has_existing THEN
    UPDATE partners.agency_webhook_inbox
       SET agency_id=p_agency_id,
           listing_id=p_listing_id,
           event_type='reservation.status_changed',
           payload=p_payload || jsonb_build_object('reservation_status', normalized_status),
           booking_reference='',
           status='processed',
           error_message=NULL,
           processed_at=now()
     WHERE id=existing_record.id
     RETURNING id INTO new_id;
  ELSE
    INSERT INTO partners.agency_webhook_inbox(
      idempotency_key,agency_id,event_type,listing_id,payload,
      booking_reference,status,error_message,processed_at
    ) VALUES (
      p_idempotency_key,p_agency_id,'reservation.status_changed',p_listing_id,
      p_payload || jsonb_build_object('reservation_status', normalized_status),
      '','processed',NULL,now()
    )
    RETURNING id INTO new_id;
  END IF;

  RETURN json_build_object(
    'ok',true,
    'status','processed',
    'inbox_id',new_id::text,
    'reservation_status',normalized_status
  )::text;
END
$$;

CREATE OR REPLACE FUNCTION partners.receive_reservation_webhook_json(p_payload jsonb)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,catalog,partners,public
AS $$
DECLARE
  incoming_event text := coalesce(nullif(p_payload->>'event_type',''),'reservation.created');
BEGIN
  IF incoming_event = 'reservation.status_changed' THEN
    RETURN partners.process_reservation_status_webhook(
      coalesce(p_payload->>'idempotency_key', ''),
      coalesce(p_payload->>'agency_id', ''),
      coalesce(p_payload->>'listing_id', ''),
      coalesce(p_payload->>'reservation_status', p_payload->>'status', ''),
      p_payload
    );
  END IF;

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
END
$$;

REVOKE ALL ON FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION partners.receive_reservation_webhook_json(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_status_webhook(text,text,text,text,jsonb) TO nexus_app;
GRANT EXECUTE ON FUNCTION partners.receive_reservation_webhook_json(jsonb) TO nexus_app;
