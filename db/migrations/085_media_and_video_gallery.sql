-- Migration 085: Media Gallery and Video Integration
-- Adds hero image, gallery array, and video URL support to property editing and public marketplace

CREATE OR REPLACE FUNCTION catalog.edit_values(p_id text)
RETURNS SETOF text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[k.key,k.value] FROM catalog.properties p,
  LATERAL jsonb_each_text(jsonb_build_object(
    'id',p.id,'version',p.version,'title',p.title,'locality',p.locality,'description',p.description,
    'capacity',p.capacity,'price',(p.nightly_minor::numeric/100)::numeric(14,2)::text,
    'currency',p.currency,'seo_title',p.seo_title,'seo_description',p.seo_description,'category_code',p.category_code,
    'hero_image', coalesce(p.media->>0, ''),
    'gallery_images', coalesce((SELECT string_agg(elem, E'\n') FROM jsonb_array_elements_text(p.media) arr(elem) OFFSET 1), ''),
    'video_url', coalesce(p.attributes->>'video_url', '')
  )) k WHERE p.id::text=p_id
  UNION ALL SELECT ARRAY['attr_'||k.key,k.value] FROM catalog.properties p,LATERAL jsonb_each_text(p.attributes) k WHERE p.id::text=p_id;
$$;

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
  WHERE p.id = p_property_id AND p.status = 'published';
$$;

CREATE OR REPLACE FUNCTION catalog.marketplace_listing_detail(p_property_id text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT * FROM catalog.marketplace_listing_detail(p_property_id::uuid);
$$;

GRANT EXECUTE ON FUNCTION catalog.edit_values(text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.marketplace_listing_detail(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.marketplace_listing_detail(text) TO nexus_app;

