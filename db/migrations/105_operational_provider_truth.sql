-- Keep local operations useful while never claiming an unverified external delivery.
CREATE OR REPLACE FUNCTION catalog.dispatch_transport_notification(
  p_property_id uuid,p_system_name text,p_plate_code text,p_driver_name text,
  p_guest_name text,p_tc_passport text,p_destination text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF p_system_name NOT IN ('kabis','uetds') THEN RETURN 'invalid_system'; END IF;
  INSERT INTO catalog.property_transport_notifications(
    property_id,system_name,plate_code,driver_name,guest_name,tc_passport,destination,
    dispatch_status,dispatch_code
  ) VALUES (
    p_property_id,p_system_name,upper(trim(p_plate_code)),trim(p_driver_name),
    trim(p_guest_name),trim(p_tc_passport),trim(p_destination),'pending',''
  );
  RETURN 'pending';
END $$;

CREATE OR REPLACE FUNCTION catalog.quick_check_in(
  p_property_id uuid,p_room_code text,p_guest_name text,p_nights int,p_rate_minor bigint
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_unit_id uuid; v_cur text; v_rate bigint; v_nights int := greatest(coalesce(p_nights,1),1);
BEGIN
  SELECT nightly_minor,currency INTO v_rate,v_cur FROM catalog.properties WHERE id=p_property_id;
  IF v_cur IS NULL THEN RETURN 'not_found'; END IF;
  IF p_rate_minor IS NOT NULL AND p_rate_minor > 0 THEN v_rate:=p_rate_minor; END IF;
  UPDATE catalog.property_units SET occupancy_status='occupied',housekeeping_status='clean',
    current_guest=trim(p_guest_name),checked_in_at=now(),
    expected_checkout=current_date+v_nights,current_rate_minor=v_rate
    WHERE property_id=p_property_id AND unit_code=trim(p_room_code)
    RETURNING id INTO v_unit_id;
  IF v_unit_id IS NULL THEN RETURN 'room_not_found'; END IF;
  INSERT INTO catalog.property_room_folios(property_id,room_code,guest_name,department,description,amount_minor,currency)
    VALUES(p_property_id,trim(p_room_code),trim(p_guest_name),'accommodation',
      'Oda Konaklama Bedeli ('||v_nights||' Gece)',v_rate*v_nights,v_cur);
  -- KBS transport is an external adapter; queue a pending record without inventing identity data.
  INSERT INTO catalog.property_kbs_records(property_id,guest_name,tc_passport,room_code,check_in,check_out,police_status,dispatch_code)
    VALUES(p_property_id,trim(p_guest_name),'',trim(p_room_code),current_date,current_date+v_nights,'pending','');
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.dispatch_guest_automated_message(
  p_property_id uuid,p_room_code text,p_guest_name text,p_phone text,p_trigger_type text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_title text; v_loc text; v_msg text; v_guest text:=coalesce(nullif(trim(p_guest_name),''),'Değerli Misafirimiz');
BEGIN
  SELECT title,locality INTO v_title,v_loc FROM catalog.properties WHERE id=p_property_id;
  IF v_title IS NULL THEN RETURN 'not_found'; END IF;
  v_msg:=CASE p_trigger_type
    WHEN 'booking_confirmed' THEN 'Sayın '||v_guest||', rezervasyon talebiniz alınmıştır. Dış bildirim doğrulaması bekleniyor.'
    WHEN 'pre_arrival_24h' THEN 'Sayın '||v_guest||', yarın sizi ağırlamaktan mutluluk duyacağız. Oda no: '||coalesce(nullif(trim(p_room_code),''),'Genel')||'.'
    WHEN 'in_stay_greeting' THEN 'Sayın '||v_guest||', konaklamanızla ilgili destek için bizimle iletişime geçebilirsiniz.'
    WHEN 'checkout_instructions' THEN 'Sayın '||v_guest||', çıkış işlemleri için resepsiyonla iletişime geçebilirsiniz.'
    ELSE 'Sayın '||v_guest||', talebiniz alınmıştır.'
  END;
  INSERT INTO catalog.property_automated_messages(property_id,room_code,guest_name,phone_or_email,channel,trigger_type,message_body,dispatch_status)
    VALUES(p_property_id,coalesce(nullif(trim(p_room_code),''),'Genel'),v_guest,trim(p_phone),'whatsapp',coalesce(p_trigger_type,'booking_confirmed'),v_msg,'pending');
  RETURN 'pending';
END $$;

REVOKE ALL ON FUNCTION catalog.dispatch_transport_notification(uuid,text,text,text,text,text,text),catalog.quick_check_in(uuid,text,text,int,bigint),catalog.dispatch_guest_automated_message(uuid,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.dispatch_transport_notification(uuid,text,text,text,text,text,text),catalog.quick_check_in(uuid,text,text,int,bigint),catalog.dispatch_guest_automated_message(uuid,text,text,text,text) TO nexus_app;
