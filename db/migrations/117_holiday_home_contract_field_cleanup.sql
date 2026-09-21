-- Keep holiday_home listing fields aligned with supplier-listing contract v1.1.0.
-- Sözleşme dışı eski alanlar silinmez; sadece aktif form alanı olmaktan çıkarılır.

UPDATE onboarding.category_fields
SET active=false,
    required=false
WHERE category_code='holiday_home'
  AND field_code NOT IN (
    'property_type',
    'bedroom_count',
    'bathroom_count',
    'guest_capacity',
    'pool_type',
    'kitchen',
    'season_rules'
  );

INSERT INTO onboarding.category_fields(category_code,field_code,label,kind,choices,required,active,position)
VALUES
  ('holiday_home','property_type','Tatil evi türü','select','Villa,Apart,Bungalov,Daire,Residence',true,true,10),
  ('holiday_home','bedroom_count','Yatak odası sayısı','number','',true,true,20),
  ('holiday_home','bathroom_count','Banyo sayısı','number','',true,true,30),
  ('holiday_home','guest_capacity','Misafir kapasitesi','number','',true,true,40),
  ('holiday_home','pool_type','Havuz tipi','select','Yok,Özel Havuz,Ortak Havuz,Isıtmalı Havuz,Korunaklı Havuz',false,true,50),
  ('holiday_home','kitchen','Mutfak','select','Yok,Mini Mutfak,Tam Donanımlı Mutfak,Açık Mutfak',false,true,60),
  ('holiday_home','season_rules','Sezon kuralları','text','',false,true,70)
ON CONFLICT(category_code,field_code) DO UPDATE SET
  label=excluded.label,
  kind=excluded.kind,
  choices=excluded.choices,
  required=excluded.required,
  active=true,
  position=excluded.position;
