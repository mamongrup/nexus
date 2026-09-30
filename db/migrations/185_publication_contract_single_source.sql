-- 185: Yayınlanabilirlik tek kaynaktan yönetilir; acente feed yolları da sözleşmeye bağlanır
--
-- 184 görünürlük kuralını altı okuma yoluna elle yazdı: status='published' AND
-- moderation_status='approved' AND last_confirmed_at >= now()-interval '30 days'.
-- Kural doğruydu, ancak iki yol kapsam dışı kaldı ve bir sonraki alan kolayca
-- atlayabilir durumda bırakıldı:
--
--   * catalog.agency_listing_feed (141) — acentenin asıl ilan feed'i. Yalnızca
--     status='published' ve ortak sözleşmenin zorunlu alanlarının dolu olduğunu
--     denetliyordu; moderasyon onayı ve tazelik şartı yoktu. Onaylanmamış veya
--     30 günden eski ilanlar acente sitesine akıyordu.
--   * inventory.agency_inventory_feed (140) — hiçbir yayın filtresi taşımıyordu.
--     Aktif bağlantı ve politika yeterliydi, bu yüzden taslak veya askıya alınmış
--     bir ilanın günlük fiyatı ve müsaitliği okunabiliyordu. Bu, sözleşmenin en
--     ağır ihlaliydi: moderasyon kararının ilanın varlığını, fiyatını ve
--     müsaitliğini gizlemesi gerekir.
--
-- Bu migration iki şeyi birden yapar:
--   1. Kuralı catalog.is_publishable() adlı tek bir tanıma taşır. 184'teki altı
--      fonksiyon yeniden tanımlanıp bu tanımı kullanır; kural bir kez yazılır.
--   2. İki acente feed yolunu da sözleşmeye bağlar.
--
-- Kapsam değişmez: yalnızca okuma. Hiçbir veri yazılmaz, hiçbir ilan durum
-- değiştirmez, hiçbir tedarikçi başvurusu etkilenmez.

-- 1. Tek doğruluk kaynağı.
--    St SECURITY DEFINER: SECURITY INVOKER olarak RLS'e tabi olurdu, bu yüzden
--    çağıran SECURITY DEFINER feed fonksiyonları satırı göremezdi.
CREATE OR REPLACE FUNCTION catalog.is_publishable(p_id text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT EXISTS (
    SELECT 1 FROM catalog.properties p
    WHERE p.id::text = p_id
      AND p.status = 'published'
      AND p.moderation_status = 'approved'
      AND p.last_confirmed_at IS NOT NULL
      AND p.last_confirmed_at >= now() - interval '30 days'
  )
$$;

REVOKE ALL ON FUNCTION catalog.is_publishable(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.is_publishable(text) TO nexus_app;

-- 2. 184'ün tanımladığı katalog.published() de aynı kaynağa bağlanır.
CREATE OR REPLACE FUNCTION catalog.published()
RETURNS TABLE(id text,title text,locality text,description text,capacity int,nightly_minor bigint,currency text,status text,version bigint,moderation_status text,review_note text,freshness text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,catalog AS $$
 SELECT p.id::text,p.title,p.locality,p.description,p.capacity,p.nightly_minor,p.currency::text,p.status,p.version::bigint,p.moderation_status,p.review_note,'current'
 FROM catalog.properties p
 WHERE catalog.is_publishable(p.id::text)
 ORDER BY p.created_at DESC LIMIT 100
$$;

-- 3. 184'ün altı fonksiyonu: gövde aynı, kural tek tanımdan.
--    partners.agency_catalog()
CREATE OR REPLACE FUNCTION partners.agency_catalog() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[p.id::text,p.title,o.legal_name,p.locality,p.nightly_minor::text,p.currency::text]
 FROM catalog.properties p JOIN core.organizations o ON o.id=p.tenant_id JOIN partners.connections c ON c.supplier_id=p.tenant_id
 WHERE auth.workspace()='agency' AND c.agency_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND c.status='active'
   AND catalog.is_publishable(p.id::text)
 ORDER BY p.title LIMIT 100;
$$;

--    booking.request_option()
CREATE OR REPLACE FUNCTION booking.request_option(p_property text,p_start text,p_end text,p_minutes int,p_key text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; p catalog.properties%ROWTYPE; a date; b date; old booking.option_requests%ROWTYPE;
BEGIN
 IF auth.workspace()<>'agency' OR NOT EXISTS(SELECT FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid AND role IN ('owner','editor')) THEN RETURN 'forbidden'; END IF;
 BEGIN a:=p_start::date; b:=p_end::date; EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN 'invalid_dates'; END;
 IF a IS NULL OR b IS NULL OR b<=a OR b-a>90 OR a<(clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date OR p_minutes IS NULL OR p_minutes NOT BETWEEN 1 AND 1440 OR length(p_key) NOT BETWEEN 16 AND 128 THEN RETURN 'invalid_range'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_property AND catalog.is_publishable(p_property);
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

--    catalog.marketplace_listings() (kampanya rozetli sürüm)
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
  WHERE catalog.is_publishable(p.id::text)
    AND (p_category IS NULL OR p_category = '' OR p_category = 'all' OR p.category_code = p_category)
    AND (p_locality IS NULL OR p_locality = '' OR p.locality ILIKE '%' || p_locality || '%')
    AND (p_q IS NULL OR p_q = '' OR p.title ILIKE '%' || p_q || '%' OR p.description ILIKE '%' || p_q || '%' OR p.locality ILIKE '%' || p_q || '%')
  ORDER BY p.created_at DESC;
$$;

--    catalog.marketplace_listing_detail(uuid)
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
    AND catalog.is_publishable(p.id::text);
$$;

--    catalog.marketplace_listings_v2()
CREATE OR REPLACE FUNCTION catalog.marketplace_listings_v2(p_q text DEFAULT '',p_category text DEFAULT '',p_locality text DEFAULT '')
RETURNS TABLE(id text,title text,locality text,category text,capacity text,price text,currency text,description text,images jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT p.id::text,p.title,p.locality,p.category_code,p.capacity::text,p.nightly_minor::text,
   p.currency::text,p.description,coalesce(p.media,'[]'::jsonb)
 FROM catalog.properties p
 WHERE catalog.is_publishable(p.id::text)
   AND (coalesce(p_category,'')='' OR p.category_code=p_category)
   AND (coalesce(p_locality,'')='' OR p.locality ILIKE '%'||p_locality||'%')
   AND (coalesce(p_q,'')='' OR p.title ILIKE '%'||p_q||'%' OR p.description ILIKE '%'||p_q||'%' OR p.locality ILIKE '%'||p_q||'%')
 ORDER BY p.created_at DESC
$$;

--    catalog.marketplace_listings_for_agency()
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
 WHERE catalog.is_publishable(p.id::text)
   AND (jsonb_array_length(x.allowed_categories)=0 OR p.category_code IN (SELECT value FROM jsonb_array_elements_text(x.allowed_categories)))
 ORDER BY p.created_at DESC
 LIMIT (SELECT listing_limit FROM policy)
$$;

-- 4. Acente ilan feed'i: 184 kuralı artık burada da geçerli.
CREATE OR REPLACE FUNCTION catalog.agency_listing_feed(
  p_agency text,
  p_category text DEFAULT '',
  p_locality text DEFAULT '',
  p_query text DEFAULT ''
) RETURNS TABLE(
  id text,title text,locality text,region text,category text,capacity text,
  price text,currency text,description text,short_description text,images text,
  contract_fields text,price_unit text,availability_mode text,
  contact_policy text,cancellation_policy text
) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH policy AS (
    SELECT agency_id,allowed_categories,listing_limit
    FROM partners.connection_policies
    WHERE agency_id=p_agency::uuid AND active
  )
  SELECT p.id::text,p.title,p.locality,p.locality,p.category_code,
    p.capacity::text,p.nightly_minor::text,p.currency::text,p.description,
    coalesce(nullif(p.seo_description,''),left(p.description,180)),
    coalesce(p.media,'[]'::jsonb)::text,
    coalesce(p.attributes,'{}'::jsonb)::text,
    CASE
      WHEN p.category_code IN ('hotel','holiday_home') THEN 'night'
      WHEN p.category_code IN ('tour','activity','cruise','pilgrimage') THEN 'person'
      WHEN p.category_code IN ('car','yacht','beach') THEN 'day'
      ELSE 'service'
    END,
    'request'::text,'agency_managed'::text,'supplier_policy'::text
  FROM catalog.properties p
  JOIN partners.connections c
    ON c.supplier_id=p.tenant_id
   AND c.agency_id=p_agency::uuid
   AND c.status='active'
  CROSS JOIN policy x
  WHERE catalog.is_publishable(p.id::text)
    AND catalog.listing_contract_required_complete(p.id::text)
    AND (jsonb_array_length(x.allowed_categories)=0
      OR p.category_code IN (
        SELECT value FROM jsonb_array_elements_text(x.allowed_categories)
      ))
    AND (coalesce(p_category,'')='' OR p.category_code=p_category)
    AND (coalesce(p_locality,'')='' OR p.locality ILIKE '%' || p_locality || '%')
    AND (coalesce(p_query,'')='' OR p.title ILIKE '%' || p_query || '%'
      OR p.description ILIKE '%' || p_query || '%')
  ORDER BY p.created_at DESC
  LIMIT (SELECT listing_limit FROM policy)
$$;

-- 5. Acente envanter feed'i: düzeltilen asıl sızıntı. 140 bu yolda hiçbir
--    yayın koşulu taşımıyordu; bağlantı ve politika yeterliydi.
CREATE OR REPLACE FUNCTION inventory.agency_inventory_feed(
  p_agency text,
  p_listing text
) RETURNS TABLE(service_date text,status text,price_minor int)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT d.service_date::text,
    CASE WHEN d.blocked+d.held+d.sold>=d.capacity
      THEN 'unavailable' ELSE 'available' END,
    coalesce(d.nightly_minor,p.nightly_minor)::int
  FROM inventory.days d
  JOIN inventory.resources r
    ON r.id=d.resource_id AND r.tenant_id=d.tenant_id
  JOIN catalog.properties p
    ON p.id=r.property_id AND p.tenant_id=r.tenant_id
  JOIN partners.connections c
    ON c.supplier_id=p.tenant_id
   AND c.agency_id=p_agency::uuid
   AND c.status='active'
  JOIN partners.connection_policies cp
    ON cp.agency_id=c.agency_id AND cp.active
  WHERE p.id=p_listing::uuid
    AND catalog.is_publishable(p.id::text)
    AND (jsonb_array_length(cp.allowed_categories)=0
      OR p.category_code IN (
        SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)
      ))
  ORDER BY d.service_date
  LIMIT 365
$$;

-- Doğrulama: yeni kural geriye dönük hiçbir veriyi sildi. Sadece görünürlük
-- daraldı; askıya alınmış veya onaysız ilanlar artık acente yollarından da
-- okunamıyor, ancak kayıtları ve durumları yerinde kalıyor.
DO $$
DECLARE
  v_feed_leak integer;
BEGIN
  SELECT count(*) INTO v_feed_leak
  FROM catalog.properties p
  JOIN partners.connections c ON c.supplier_id = p.tenant_id AND c.status = 'active'
  JOIN partners.connection_policies cp ON cp.agency_id = c.agency_id AND cp.active
  WHERE p.status = 'published'
    AND NOT catalog.is_publishable(p.id::text);

  IF v_feed_leak > 0 THEN
    RAISE NOTICE '185: % published listing(s) connected to at least one agency are no longer exposed through the agency feeds', v_feed_leak;
  END IF;
END $$;
