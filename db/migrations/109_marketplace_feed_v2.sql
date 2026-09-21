-- Stable, typed contract for NEXUS -> Agency synchronization.
CREATE OR REPLACE FUNCTION catalog.marketplace_listings_v2(p_q text DEFAULT '',p_category text DEFAULT '',p_locality text DEFAULT '')
RETURNS TABLE(id text,title text,locality text,category text,capacity text,price text,currency text,description text,images jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT p.id::text,p.title,p.locality,p.category_code,p.capacity::text,p.nightly_minor::text,
   p.currency::text,p.description,coalesce(p.media,'[]'::jsonb)
 FROM catalog.properties p
 WHERE p.status='published'
   AND (coalesce(p_category,'')='' OR p.category_code=p_category)
   AND (coalesce(p_locality,'')='' OR p.locality ILIKE '%'||p_locality||'%')
   AND (coalesce(p_q,'')='' OR p.title ILIKE '%'||p_q||'%' OR p.description ILIKE '%'||p_q||'%' OR p.locality ILIKE '%'||p_q||'%')
 ORDER BY p.created_at DESC
$$;
REVOKE ALL ON FUNCTION catalog.marketplace_listings_v2(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.marketplace_listings_v2(text,text,text) TO nexus_app;
