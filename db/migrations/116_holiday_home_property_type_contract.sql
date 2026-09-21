-- Contract hardening: holiday_home must expose property_type as the canonical subtype field.
-- Villa, Apart, Bungalov, Daire and Residence are subtypes, not main categories.

INSERT INTO onboarding.category_fields(category_code,field_code,label,kind,choices,required,active,position)
VALUES ('holiday_home','property_type','Tatil evi türü','select','Villa,Apart,Bungalov,Daire,Residence',true,true,10)
ON CONFLICT(category_code,field_code) DO UPDATE SET
  label=excluded.label,
  kind=excluded.kind,
  choices=excluded.choices,
  required=excluded.required,
  active=excluded.active,
  position=least(onboarding.category_fields.position, excluded.position);

UPDATE onboarding.category_fields
SET active=false,
    required=false,
    label='Eski alan: Tatil evi türü',
    position=0
WHERE category_code='holiday_home'
  AND field_code IN ('place_type','villa_type');

UPDATE core.contract_versions
SET version='1.1.0', activated_at=now()
WHERE contract_name IN ('nexus.catalog.categories','nexus.supplier_listing');
