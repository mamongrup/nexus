-- Sözleşme korumasından önce eklenmiş iki sabit demo oteli, yalnızca eksik
-- alanları tamamlayarak v1.1 ilan sözleşmesine taşır. Gerçek tedarikçi
-- kayıtlarına veya mevcut dolu değerlere dokunmaz.
UPDATE catalog.properties
SET attributes = coalesce(attributes,'{}'::jsonb) || jsonb_strip_nulls(
  jsonb_build_object(
    'property_type', CASE WHEN nullif(attributes->>'property_type','') IS NULL THEN 'Otel' END,
    'room_types', CASE WHEN nullif(attributes->>'room_types','') IS NULL THEN '["Süit"]' END,
    'board_type', CASE WHEN nullif(attributes->>'board_type','') IS NULL THEN 'Oda Kahvaltı' END,
    'check_in_time', CASE WHEN nullif(attributes->>'check_in_time','') IS NULL THEN '14:00' END,
    'check_out_time', CASE WHEN nullif(attributes->>'check_out_time','') IS NULL THEN '12:00' END
  )
),
seo_title=coalesce(nullif(seo_title,''),left(title,70)),
seo_description=coalesce(nullif(seo_description,''),left(description,320)),
updated_at=now(), version=version+1
WHERE id IN (
  '22222222-bbbb-4222-8222-222222222222'::uuid,
  '44444444-dddd-4444-8444-444444444444'::uuid
)
AND category_code='hotel'
AND NOT catalog.listing_contract_required_complete(id::text);
