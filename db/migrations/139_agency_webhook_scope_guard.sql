-- Rezervasyon webhook'u yalnızca onaylı acente ile aktif bağlantısı bulunan
-- tedarikçi ilanları için işlenebilir. Global API anahtarı tek başına kapsam
-- aşmaya yetmez.
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
    RETURN json_build_object('ok',false,'error','missing_idempotency_key')::text;
  END IF;
  IF coalesce(p_agency_id,'') !~ '^[0-9a-fA-F-]{36}$'
     OR coalesce(p_listing_id,'') !~ '^[0-9a-fA-F-]{36}$' THEN
    RETURN json_build_object('ok',false,'error','invalid_scope')::text;
  END IF;

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

  SELECT * INTO existing_record
  FROM partners.agency_webhook_inbox
  WHERE idempotency_key=p_idempotency_key;
  IF FOUND THEN
    RETURN json_build_object(
      'ok',true,'status','duplicate_ignored',
      'inbox_id',existing_record.id::text,
      'booking_reference',coalesce(existing_record.booking_reference,'')
    )::text;
  END IF;

  BEGIN
    booking_res := catalog.create_marketplace_booking(
      p_listing_id,p_guest_name,p_guest_email,p_guest_phone,coalesce(p_tc,''),
      p_check_in,p_check_out,coalesce(p_guests,1)
    );
  EXCEPTION WHEN OTHERS THEN
    booking_res := 'error: ' || SQLERRM;
  END;

  INSERT INTO partners.agency_webhook_inbox(
    idempotency_key,agency_id,event_type,listing_id,payload,
    booking_reference,status,processed_at
  ) VALUES (
    p_idempotency_key,p_agency_id,'reservation.created',p_listing_id,p_payload,
    booking_res,
    CASE WHEN booking_res LIKE 'error:%' THEN 'failed' ELSE 'processed' END,
    now()
  ) RETURNING id INTO new_id;

  RETURN json_build_object(
    'ok',booking_res NOT LIKE 'error:%',
    'status',CASE WHEN booking_res LIKE 'error:%' THEN 'failed' ELSE 'processed' END,
    'inbox_id',new_id::text,'booking_reference',booking_res
  )::text;
END $$;

REVOKE ALL ON FUNCTION partners.process_reservation_webhook(text,text,text,text,text,text,text,text,text,int,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.process_reservation_webhook(text,text,text,text,text,text,text,text,text,int,jsonb) TO nexus_app;
