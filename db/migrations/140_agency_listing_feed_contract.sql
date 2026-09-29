-- API uygulama rolüne iç tabloları açmadan, acente kapsamlı ve sözleşme
-- alanları tamamlanmış ilan feed'i sağlar.
CREATE OR REPLACE FUNCTION catalog.agency_listing_feed(
  p_agency text,
  p_category text DEFAULT '',
  p_locality text DEFAULT '',
  p_query text DEFAULT ''
) RETURNS TABLE(
  id text,
  title text,
  locality text,
  region text,
  category text,
  capacity text,
  price text,
  currency text,
  description text,
  short_description text,
  images text,
  contract_fields text,
  price_unit text,
  availability_mode text,
  contact_policy text,
  cancellation_policy text
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
  WHERE p.status='published'
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

REVOKE ALL ON FUNCTION catalog.agency_listing_feed(text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.agency_listing_feed(text,text,text,text) TO nexus_app;

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
    AND (jsonb_array_length(cp.allowed_categories)=0
      OR p.category_code IN (
        SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)
      ))
  ORDER BY d.service_date
  LIMIT 365
$$;

REVOKE ALL ON FUNCTION inventory.agency_inventory_feed(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory.agency_inventory_feed(text,text) TO nexus_app;
