CREATE FUNCTION catalog.edit_values(p_id text) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY INVOKER AS $$
 SELECT ARRAY[k.key,k.value] FROM catalog.properties p,
 LATERAL jsonb_each_text(jsonb_build_object('id',p.id,'version',p.version,'title',p.title,'locality',p.locality,'description',p.description,'capacity',p.capacity,'price',(p.nightly_minor::numeric/100)::text,'currency',p.currency,'seo_title',p.seo_title,'seo_description',p.seo_description,'category_code',p.category_code)) k WHERE p.id::text=p_id
 UNION ALL SELECT ARRAY['attr_'||k.key,k.value] FROM catalog.properties p,LATERAL jsonb_each_text(p.attributes) k WHERE p.id::text=p_id
$$;
REVOKE ALL ON FUNCTION catalog.edit_values(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.edit_values(text) TO nexus_app;
