CREATE OR REPLACE FUNCTION catalog.quality_report(p_id text) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH own AS (SELECT * FROM catalog.properties WHERE id::text=p_id AND tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid AND auth.workspace()='supplier')
 SELECT ARRAY[f.label,CASE WHEN coalesce(trim(p.attributes->>f.field_code),'')='' THEN 'Eksik' ELSE 'Dolu' END] FROM own p JOIN onboarding.category_fields f ON f.category_code=p.category_code AND f.active AND f.required
 UNION ALL SELECT ARRAY['Açıklama',CASE WHEN trim(description)='' THEN 'Eksik' ELSE 'Dolu' END] FROM own
 UNION ALL SELECT ARRAY['SEO başlığı',CASE WHEN trim(seo_title)='' THEN 'Eksik' ELSE 'Dolu' END] FROM own
 UNION ALL SELECT ARRAY['SEO açıklaması',CASE WHEN trim(seo_description)='' THEN 'Eksik' ELSE 'Dolu' END] FROM own
$$;
