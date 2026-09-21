-- Category contract v1.1.0: holiday_home is the main category.
-- Villa, apart, bungalow, daire and residence are property_type subtypes.

INSERT INTO core.contract_versions(contract_name,version)
VALUES ('nexus.catalog.categories','1.1.0'),('nexus.supplier_listing','1.1.0')
ON CONFLICT(contract_name) DO UPDATE SET version=excluded.version,activated_at=now();

INSERT INTO onboarding.categories(code,name,description,active,contract_version,position)
VALUES ('holiday_home','Tatil Evi','Tatil evi; villa, apart, bungalov, daire ve residence alt türlerini kapsar',true,'1.1.0',2)
ON CONFLICT(code) DO UPDATE SET
 name=excluded.name,
 description=excluded.description,
 active=true,
 contract_version=excluded.contract_version,
 position=excluded.position;

INSERT INTO onboarding.category_fields(category_code,field_code,label,kind,choices,required,active,position)
SELECT 'holiday_home', field_code, label, kind, choices, required, active, position
FROM onboarding.category_fields
WHERE category_code='villa'
ON CONFLICT(category_code,field_code) DO UPDATE SET
 label=excluded.label,
 kind=excluded.kind,
 choices=excluded.choices,
 required=excluded.required,
 active=excluded.active,
 position=excluded.position;

UPDATE onboarding.category_fields
SET label='Tatil evi türü',
    choices='Villa,Apart,Bungalov,Daire,Residence',
    required=true,
    active=true
WHERE category_code='holiday_home' AND field_code='property_type';

INSERT INTO onboarding.requirements(category_code,code,label,kind,required,position)
SELECT 'holiday_home', code, label, kind, required, position
FROM onboarding.requirements
WHERE category_code='villa'
ON CONFLICT(category_code,code) DO UPDATE SET
 label=excluded.label,
 kind=excluded.kind,
 required=excluded.required,
 position=excluded.position;

INSERT INTO onboarding.category_procedures(category_code,procedure_title,legal_basis,badge_text,steps,guidelines,required_documents,operational_rules)
SELECT 'holiday_home', procedure_title, legal_basis, badge_text, steps, guidelines, required_documents, operational_rules
FROM onboarding.category_procedures
WHERE category_code='villa'
ON CONFLICT(category_code) DO UPDATE SET
 procedure_title=excluded.procedure_title,
 legal_basis=excluded.legal_basis,
 badge_text=excluded.badge_text,
 steps=excluded.steps,
 guidelines=excluded.guidelines,
 required_documents=excluded.required_documents,
 operational_rules=excluded.operational_rules;

UPDATE catalog.properties SET category_code='holiday_home' WHERE category_code='villa';
UPDATE onboarding.applications SET category_code='holiday_home' WHERE category_code='villa';

DELETE FROM onboarding.category_fields WHERE category_code='villa';
DELETE FROM onboarding.requirements WHERE category_code='villa';

UPDATE onboarding.categories
SET active=false,
    name='Villa (Tatil Evi alt türü)',
    description='Ana kategori değildir; holiday_home.property_type alt türüdür',
    contract_version='1.1.0',
    position=0
WHERE code='villa';

UPDATE onboarding.categories
SET contract_version='1.1.0'
WHERE code IN (
 'hotel','holiday_home','yacht','tour','activity','flight','car','cruise',
 'pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus'
);
