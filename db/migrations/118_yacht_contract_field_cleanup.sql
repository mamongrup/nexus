-- Keep yacht listing fields aligned with supplier-listing contract v1.1.0.
-- Yat works like holiday_home: subtypes are modeled under yacht.yacht_type.

UPDATE onboarding.category_fields
SET active=false,
    required=false
WHERE category_code='yacht'
  AND field_code NOT IN (
    'yacht_type',
    'capacity',
    'cabin_count',
    'departure_port',
    'route',
    'captain_included',
    'fuel_policy'
  );

INSERT INTO onboarding.category_fields(category_code,field_code,label,kind,choices,required,active,position)
VALUES
  ('yacht','yacht_type','Yat / tekne türü','select','Gulet,Motoryat,Yelkenli,Katamaran,Tekne',true,true,10),
  ('yacht','capacity','Kapasite','number','',true,true,20),
  ('yacht','cabin_count','Kabin sayısı','number','',false,true,30),
  ('yacht','departure_port','Kalkış limanı','text','',true,true,40),
  ('yacht','route','Rota','text','',true,true,50),
  ('yacht','captain_included','Kaptan dahil','boolean','',true,true,60),
  ('yacht','fuel_policy','Yakıt politikası','text','',false,true,70)
ON CONFLICT(category_code,field_code) DO UPDATE SET
  label=excluded.label,
  kind=excluded.kind,
  choices=excluded.choices,
  required=excluded.required,
  active=true,
  position=excluded.position;
