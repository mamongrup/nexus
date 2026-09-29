-- 184: Yayın görünürlük sözleşmesi okuma tarafına da uygulanır
--
-- 180 iki katmanlı durum makinesini yazma tarafında zorladı: bir ilan ancak
-- moderation_status='approved' iken 'published' olabiliyor. Ancak vitrini,
-- acente kataloğunu ve rezervasyon talebini okuyan fonksiyonlar 004/063
-- döneminden kalma yalnızca status='published' filtresini kullanıyordu.
-- Bunun iki somut sonucu vardı:
--
--   1. 30 günden eski (bayat) ilanlar vitrinde ve acente kataloğunda
--      görünmeye devam ediyordu. catalog.published() bu kuralı uyguluyordu,
--      ancak tek bir tanım olarak hiçbir okuma yolundan çağrılmıyordu.
--   2. Moderasyon onayı olmayan bir kayıt doğrudan rezervasyon talebine
--      dönüşebiliyordu: guard tetikleyicisi yalnızca kind='supplier' olan
--      kuruluşların yazımını denetlediği için platform kuruluşuna ait bir
--      ilan korumadan geçebiliyordu.
--
-- Bu migration okuma tarafını tek bir sözleşmeye hizalar. Yayınlanabilir
-- ilan status='published' AND moderation_status='approved' olmalı ve
-- tedarikçi tarafından son 30 gün içinde teyit edilmiş olmalıdır; bu,
-- catalog.published() ve catalog.admin_publish() ile aynı tanımdır.
--
-- Kapsam değişmez: yalnızca okuma. Tedarikçilerin geçmişe dönük verisi
-- değiştirilmez, hiçbir ilan yayından kaldırılmaz.

-- 1. Acente kataloğu: bağlı tedarikçilerin yayınlanabilir portföyü.
CREATE OR REPLACE FUNCTION partners.agency_catalog() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[p.id::text,p.title,o.legal_name,p.locality,p.nightly_minor::text,p.currency::text]
 FROM catalog.properties p JOIN core.organizations o ON o.id=p.tenant_id JOIN partners.connections c ON c.supplier_id=p.tenant_id
 WHERE auth.workspace()='agency' AND c.agency_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND c.status='active'
   AND p.status='published' AND p.moderation_status='approved' AND p.last_confirmed_at>=now()-interval '30 days'
 ORDER BY p.title LIMIT 100;
$$;

-- 2. Opsiyon talebi: yalnızca yayınlanabilir bir ilan için açılabilir.
CREATE OR REPLACE FUNCTION booking.request_option(p_property text,p_start text,p_end text,p_minutes int,p_key text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; p catalog.properties%ROWTYPE; a date; b date; old booking.option_requests%ROWTYPE;
BEGIN
 IF auth.workspace()<>'agency' OR NOT EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 BEGIN a:=p_start::date; b:=p_end::date; EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN 'invalid_dates'; END;
 IF a IS NULL OR b IS NULL OR b<=a OR b-a>90 OR a<(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date OR p_minutes IS NULL OR p_minutes NOT BETWEEN 1 AND 1440 OR length(p_key) NOT BETWEEN 16 AND 128 THEN RETURN 'invalid_range'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_property AND status='published' AND moderation_status='approved' AND last_confirmed_at>=now()-interval '30 days';
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 PERFORM 1 FROM partners.connections WHERE supplier_id=p.tenant_id AND agency_id=t AND status='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'forbidden'; END IF;
 SELECT * INTO old FROM booking.option_requests WHERE agency_id=t AND request_key=p_key;
 IF FOUND THEN
  IF old.property_id<>p.id OR old.check_in<>a OR old.check_out<>b OR old.minutes<>p_minutes THEN RETURN 'key_conflict'; END IF;
  RETURN 'ok';
 END IF;
 INSERT INTO booking.option_requests(supplier_id,agency_id,property_id,check_in,check_out,minutes,request_key) VALUES(p.tenant_id,t,p.id,a,b,p_minutes,p_key);
 RETURN 'ok';
END $$;

-- 3. Genel vitrin listesi (kampanya rozetli sürüm).
CREATE OR REPLACE FUNCTION catalog.marketplace_listings(
  p_q text,
  p_category text,
  p_locality text
) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.title,
    p.locality,
    p.category_code,
    p.capacity::text,
    p.nightly_minor::text,
    p.currency::text,
    p.description,
    coalesce(p.media->>0, 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'),
    coalesce((SELECT string_agg(value#>>'{}', ', ') FROM jsonb_array_elements(p.amenities)), 'Wi-Fi, Havuz, Klima'),
    coalesce(c.name, p.category_code),
    coalesce((SELECT badge_text FROM catalog.campaigns cp WHERE cp.is_active = true AND cp.used_count < cp.usage_limit AND current_date BETWEEN cp.start_date AND cp.end_date AND (cp.property_id = p.id OR (cp.property_id IS NULL AND (cp.category_code IS NULL OR cp.category_code = p.category_code) AND cp.tenant_id = p.tenant_id)) ORDER BY cp.discount_val DESC LIMIT 1), ''),
    coalesce((SELECT discount_val::text FROM catalog.campaigns cp WHERE cp.is_active = true AND cp.used_count < cp.usage_limit AND current_date BETWEEN cp.start_date AND cp.end_date AND (cp.property_id = p.id OR (cp.property_id IS NULL AND (cp.category_code IS NULL OR cp.category_code = p.category_code) AND cp.tenant_id = p.tenant_id)) ORDER BY cp.discount_val DESC LIMIT 1), '0')
  ]
  FROM catalog.properties p
  LEFT JOIN onboarding.categories c ON c.code = p.category_code
  WHERE p.status = 'published'
    AND p.moderation_status = 'approved'
    AND p.last_confirmed_at >= now() - interval '30 days'
    AND (p_category IS NULL OR p_category = '' OR p_category = 'all' OR p.category_code = p_category)
    AND (p_locality IS NULL OR p_locality = '' OR p.locality ILIKE '%' || p_locality || '%')
    AND (p_q IS NULL OR p_q = '' OR p.title ILIKE '%' || p_q || '%' OR p.description ILIKE '%' || p_q || '%' OR p.locality ILIKE '%' || p_q || '%')
  ORDER BY p.created_at DESC;
$$;

-- 4. Genel vitrin detayı.
CREATE OR REPLACE FUNCTION catalog.marketplace_listing_detail(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.title,
    p.locality,
    p.category_code,
    p.capacity::text,
    p.nightly_minor::text,
    p.currency::text,
    p.description,
    coalesce(p.media->>0, 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'),
    coalesce((SELECT string_agg(value#>>'{}', ', ') FROM jsonb_array_elements(p.amenities)), 'Wi-Fi, Havuz, Klima'),
    coalesce(c.name, p.category_code),
    o.legal_name,
    p.version::text,
    coalesce(p.media::text, '[]'),
    coalesce(p.attributes->>'video_url', '')
  ]
  FROM catalog.properties p
  LEFT JOIN onboarding.categories c ON c.code = p.category_code
  JOIN core.organizations o ON o.id = p.tenant_id
  WHERE p.id = p_property_id
    AND p.status = 'published'
    AND p.moderation_status = 'approved'
    AND p.last_confirmed_at >= now() - interval '30 days';
$$;

-- 5. NEXUS -> acente senkronizasyon sözleşmesi.
CREATE OR REPLACE FUNCTION catalog.marketplace_listings_v2(p_q text DEFAULT '',p_category text DEFAULT '',p_locality text DEFAULT '')
RETURNS TABLE(id text,title text,locality text,category text,capacity text,price text,currency text,description text,images jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT p.id::text,p.title,p.locality,p.category_code,p.capacity::text,p.nightly_minor::text,
   p.currency::text,p.description,coalesce(p.media,'[]'::jsonb)
 FROM catalog.properties p
 WHERE p.status='published'
   AND p.moderation_status='approved'
   AND p.last_confirmed_at>=now()-interval '30 days'
   AND (coalesce(p_category,'')='' OR p.category_code=p_category)
   AND (coalesce(p_locality,'')='' OR p.locality ILIKE '%'||p_locality||'%')
   AND (coalesce(p_q,'')='' OR p.title ILIKE '%'||p_q||'%' OR p.description ILIKE '%'||p_q||'%' OR p.locality ILIKE '%'||p_q||'%')
 ORDER BY p.created_at DESC
$$;

-- 6. Bağlantı politikasına göre acente portföyü.
CREATE OR REPLACE FUNCTION catalog.marketplace_listings_for_agency(p_agency text)
RETURNS TABLE(id text,title text,locality text,category text,capacity text,price text,currency text,description text,images jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH policy AS (
   SELECT agency_id,allowed_categories,listing_limit
   FROM partners.connection_policies
   WHERE agency_id=p_agency::uuid AND active
 )
 SELECT p.id::text,p.title,p.locality,p.category_code,p.capacity::text,p.nightly_minor::text,
   p.currency::text,p.description,coalesce(p.media,'[]'::jsonb)
 FROM catalog.properties p CROSS JOIN policy x
 WHERE p.status='published'
   AND p.moderation_status='approved'
   AND p.last_confirmed_at>=now()-interval '30 days'
   AND (jsonb_array_length(x.allowed_categories)=0 OR p.category_code IN (SELECT value FROM jsonb_array_elements_text(x.allowed_categories)))
 ORDER BY p.created_at DESC
 LIMIT (SELECT listing_limit FROM policy)
$$;

-- Doğrulama: tanım tek bir kaynaktan geliyor. Yayınlanabilirlik koşulunu
-- yanlışlıkla gevşeten bir okuma yolu kalmadığını doğrular.
DO $$
DECLARE
  v_stale_visible integer;
BEGIN
  SELECT count(*) INTO v_stale_visible
  FROM catalog.properties p
  WHERE p.status = 'published'
    AND p.moderation_status = 'approved'
    AND (p.last_confirmed_at IS NULL OR p.last_confirmed_at < now() - interval '30 days');

  IF v_stale_visible > 0 THEN
    RAISE NOTICE '184: % published listing(s) are past the 30 day freshness window and are no longer publicly visible', v_stale_visible;
  END IF;
END $$;
