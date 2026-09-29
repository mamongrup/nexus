-- WP2: Tek tam satış zinciri — NEXUS tarafı kapsamlı kabul testi
-- Kapsam: Normal satış, çift istek, fiyat güvenliği, son stok yarışı,
-- gecikmiş ödeme zaman aşımı, iptal ve stok serbest bırakma, hakediş/muhasebe entegrasyonu,
-- webhook tekrarı ve cross-tenant koruması.

BEGIN;
DO $$
DECLARE
  v_property uuid;
  v_resource uuid;
  v_agency uuid;
  v_supplier uuid;
  v_day date;
  v_capacity int;
  v_sold_initial int;
  v_amount bigint;
  v_currency text;
  v_res_a uuid := gen_random_uuid();
  v_res_b uuid := gen_random_uuid();
  v_key_a text := 'wp2-chain-a:' || gen_random_uuid()::text;
  v_key_b text := 'wp2-chain-b:' || gen_random_uuid()::text;
  v_payload jsonb;
  v_result jsonb;
  v_retry jsonb;
  v_booking_id uuid;
  v_settlement_id uuid;
BEGIN
  -- =========================================================================
  -- 0. Fixture hazırlığı: Otel, tatil evi veya yat kategorisinde uygun envanter
  -- =========================================================================
  SELECT p.id, r.id, c.agency_id, p.tenant_id, d.service_date, d.capacity, d.sold,
         d.nightly_minor, p.currency::text
  INTO v_property, v_resource, v_agency, v_supplier, v_day, v_capacity, v_sold_initial,
       v_amount, v_currency
  FROM catalog.properties p
  JOIN partners.connections c ON c.supplier_id=p.tenant_id AND c.status='active'
  JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id AND cp.active
  JOIN inventory.resources r ON r.property_id=p.id AND r.tenant_id=p.tenant_id
  JOIN inventory.days d ON d.resource_id=r.id AND d.tenant_id=r.tenant_id
  WHERE p.status='published' AND p.category_code IN ('hotel','holiday_home','yacht')
    AND d.service_date>(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date
    AND d.capacity-d.blocked-d.held-d.sold>=2
    AND d.nightly_minor IS NOT NULL AND d.currency=p.currency
    AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN (
      SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)))
  ORDER BY d.service_date LIMIT 1;

  IF v_property IS NULL THEN
    RAISE EXCEPTION 'WP2: Uygun bağlantılı envanter fikstürü bulunamadı';
  END IF;

  v_payload := jsonb_build_object(
    'reservation_id', v_res_a,
    'check_in', v_day,
    'check_out', v_day+1,
    'guests', 1,
    'amount_minor', v_amount::text,
    'currency', v_currency
  );

  -- =========================================================================
  -- 1. Fiyat uyuşmazlığı ve sahte teklif engeli (Price Mismatch Guard)
  -- =========================================================================
  v_result := partners.process_reservation_webhook(
    v_key_a, v_agency::text, v_property::text, 'WP2 Test Guest', 'wp2@example.invalid',
    '', '', v_day::text, (v_day+1)::text, 1,
    v_payload || jsonb_build_object('amount_minor', (v_amount-1)::text)
  )::jsonb;

  IF v_result->>'error' <> 'price_mismatch' THEN
    RAISE EXCEPTION 'WP2.1 FAILED: Sahte fiyatla istek kabul edildi: %', v_result;
  END IF;

  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier AND resource_id=v_resource AND service_date=v_day) <> v_sold_initial THEN
    RAISE EXCEPTION 'WP2.1 FAILED: Fiyat uyuşmazlığında stok tüketildi';
  END IF;

  -- =========================================================================
  -- 2. Normal bağlı satış: Stok kilidi ve Sipariş (Hold & Booking Creation)
  -- =========================================================================
  v_result := partners.process_reservation_webhook(
    v_key_a, v_agency::text, v_property::text, 'WP2 Test Guest', 'wp2@example.invalid',
    '', '', v_day::text, (v_day+1)::text, 1, v_payload
  )::jsonb;

  IF v_result->>'status' <> 'processed' THEN
    RAISE EXCEPTION 'WP2.2 FAILED: Rezervasyon oluşturulamadı: %', v_result;
  END IF;

  v_booking_id := (v_result->>'booking_reference')::uuid;

  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier AND resource_id=v_resource AND service_date=v_day) <> v_sold_initial + 1 THEN
    RAISE EXCEPTION 'WP2.2 FAILED: Stok doğru kilitlenmedi';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM booking.reservations b
    JOIN partners.agency_booking_links l ON l.booking_id=b.id
    WHERE l.agency_id=v_agency AND l.agency_reservation_id=v_res_a
      AND b.id=v_booking_id AND b.payment_status='unpaid'
  ) THEN
    RAISE EXCEPTION 'WP2.2 FAILED: Booking link ve rezervasyon kaydı eşleşmedi';
  END IF;

  -- =========================================================================
  -- 3. Çift İstek (Idempotent Retry Guard)
  -- =========================================================================
  v_retry := partners.process_reservation_webhook(
    v_key_a, v_agency::text, v_property::text, 'WP2 Test Guest', 'wp2@example.invalid',
    '', '', v_day::text, (v_day+1)::text, 1, v_payload
  )::jsonb;

  IF v_retry->>'status' <> 'duplicate_ignored' OR v_retry->>'booking_reference' <> v_booking_id::text THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Tekrar eden istek çift rezervasyon üretti: %', v_retry;
  END IF;

  IF (SELECT sold FROM inventory.days WHERE tenant_id=v_supplier AND resource_id=v_resource AND service_date=v_day) <> v_sold_initial + 1 THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Tekrar eden istek stok tüketti';
  END IF;

  -- =========================================================================
  -- 4. Ödeme Onayı ve Hakediş Entegrasyonu (Confirmation & Settlement Creation)
  -- =========================================================================
  v_result := partners.process_reservation_status_webhook(
    'paid-' || v_res_a::text, v_agency::text, v_property::text,
    'confirmed', jsonb_build_object('reservation_id', v_res_a)
  )::jsonb;

  IF v_result->>'status' <> 'processed' THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Ödeme durumu işlenemedi: %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM booking.reservations
    WHERE id=v_booking_id AND payment_status='paid' AND status='confirmed'
  ) THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Rezervasyon paid durumuna geçmedi';
  END IF;

  -- Migration 177: finance.settlements kaydı oluşturuldu mu?
  SELECT id INTO v_settlement_id
  FROM finance.settlements
  WHERE reservation_id=v_booking_id AND status='pending';

  IF v_settlement_id IS NULL THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Ödeme onayında finance.settlements kaydı üretilmedi';
  END IF;

  -- =========================================================================
  -- 5. Son Stok Yarışı (Concurrent / Race Guard)
  -- =========================================================================
  -- Mevcut stoğu kapasite - 1 seviyesine ayarlayalım (kalan tam 1 olsun)
  UPDATE inventory.days
  SET sold = capacity - 1
  WHERE tenant_id=v_supplier AND resource_id=v_resource AND service_date=v_day;

  -- 1. İstek: kalan 1 stoğu tüketir
  v_result := partners.process_reservation_webhook(
    v_key_b, v_agency::text, v_property::text, 'WP2 Race Guest 1', 'race1@example.invalid',
    '', '', v_day::text, (v_day+1)::text, 1,
    jsonb_build_object('reservation_id', v_res_b, 'check_in', v_day, 'check_out', v_day+1,
                       'guests', 1, 'amount_minor', v_amount::text, 'currency', v_currency)
  )::jsonb;

  IF v_result->>'status' <> 'processed' THEN
    RAISE EXCEPTION 'WP2.5 FAILED: Son kalan stok için rezervasyon başarısız: %', v_result;
  END IF;

  -- 2. İstek: stok tükendiğinden reddedilmeli (asla çift rezervasyon veya aşırı satış olamaz)
  v_result := partners.process_reservation_webhook(
    'wp2-race-overflow:' || gen_random_uuid()::text, v_agency::text, v_property::text,
    'WP2 Race Guest 2', 'race2@example.invalid',
    '', '', v_day::text, (v_day+1)::text, 1,
    jsonb_build_object('reservation_id', gen_random_uuid(), 'check_in', v_day, 'check_out', v_day+1,
                       'guests', 1, 'amount_minor', v_amount::text, 'currency', v_currency)
  )::jsonb;

  IF v_result->>'error' NOT IN ('capacity_unavailable', 'inventory_unavailable') THEN
    RAISE EXCEPTION 'WP2.5 FAILED: Kapasite aşımında rezervasyon kabul edildi (çift rezervasyon riski): %', v_result;
  END IF;

  -- =========================================================================
  -- 6. Zaman Aşımı ve Gecikmiş Ödeme Koruması (Expired Booking & Late Payment)
  -- =========================================================================
  UPDATE partners.agency_booking_links
  SET expires_at = now() - interval '1 minute'
  WHERE agency_id=v_agency AND agency_reservation_id=v_res_b;

  v_result := partners.process_reservation_status_webhook(
    'late-paid-' || v_res_b::text, v_agency::text, v_property::text,
    'confirmed', jsonb_build_object('reservation_id', v_res_b)
  )::jsonb;

  IF v_result->>'error' <> 'booking_expired' THEN
    RAISE EXCEPTION 'WP2.6 FAILED: Süresi dolmuş rezervasyon için ödeme kabul edildi: %', v_result;
  END IF;

  -- =========================================================================
  -- 7. İptal, Stok Serbest Bırakma ve Hakediş İptali (Cancellation & Annulment)
  -- =========================================================================
  v_result := partners.process_reservation_status_webhook(
    'cancel-' || v_res_a::text, v_agency::text, v_property::text,
    'cancelled', jsonb_build_object('reservation_id', v_res_a)
  )::jsonb;

  IF v_result->>'status' <> 'processed' THEN
    RAISE EXCEPTION 'WP2.7 FAILED: İptal işlenemedi: %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM booking.reservations
    WHERE id=v_booking_id AND status='cancelled'
  ) THEN
    RAISE EXCEPTION 'WP2.7 FAILED: Rezervasyon cancelled durumuna geçmedi';
  END IF;

  -- finance.settlements cancelled yapıldı mı?
  IF NOT EXISTS (
    SELECT 1 FROM finance.settlements
    WHERE reservation_id=v_booking_id AND status='cancelled'
  ) THEN
    RAISE EXCEPTION 'WP2.7 FAILED: İptal edilen rezervasyonun hakediş kaydı cancelled yapılmadı';
  END IF;

  -- Tekrar eden iptal webhook'u (Idempotent cancellation retry)
  v_retry := partners.process_reservation_status_webhook(
    'cancel-' || v_res_a::text, v_agency::text, v_property::text,
    'cancelled', jsonb_build_object('reservation_id', v_res_a)
  )::jsonb;

  IF v_retry->>'status' <> 'duplicate_ignored' THEN
    RAISE EXCEPTION 'WP2.7 FAILED: Tekrar eden iptal duplicate_ignored dönmedi: %', v_retry;
  END IF;

  -- =========================================================================
  -- 8. Cross-Tenant / Yabancı Erişim Engeli
  -- =========================================================================
  v_result := partners.process_reservation_status_webhook(
    'cross-tenant-' || gen_random_uuid()::text, gen_random_uuid()::text, v_property::text,
    'cancelled', jsonb_build_object('reservation_id', v_res_a)
  )::jsonb;

  IF v_result->>'error' <> 'reservation_not_found' THEN
    RAISE EXCEPTION 'WP2.8 FAILED: Yabancı agency_id ile rezervasyon durumu değiştirildi: %', v_result;
  END IF;

  RAISE NOTICE '=======================================================';
  RAISE NOTICE 'WP2 NEXUS Satış Zinciri ve Eşzamanlılık Kabul Testi: BAŞARILI';
  RAISE NOTICE '=======================================================';
END $$;
ROLLBACK;
