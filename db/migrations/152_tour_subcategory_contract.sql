-- Shared optional tour facet v1.2.0; matches acente migration 134.
INSERT INTO onboarding.category_fields(
  category_code,field_code,label,kind,choices,required,active,position
)
VALUES (
  'tour','tour_subcategory','Tur alt kategorisi','select',
  'tour_abroad,tour_culture,tour_cruise,tour_daily,tour_religious',false,true,11
)
ON CONFLICT(category_code,field_code) DO UPDATE SET
  label=excluded.label,kind=excluded.kind,choices=excluded.choices,
  required=excluded.required,active=excluded.active,position=excluded.position;

WITH tour_group AS (
  INSERT INTO onboarding.category_filter_groups(
    category_code,group_key,title,help_text,display_type,multiple,position,active
  )
  VALUES (
    'tour','tour_subcategory','Tur alt kategorisi',
    'Tur ilanlarını alt kategoriye göre görüntüleyin.','chips',false,5,true
  )
  ON CONFLICT(category_code,group_key) DO UPDATE SET active=true,updated_at=now()
  RETURNING id
), items(item_key,title,position) AS (
  VALUES
    ('tour_abroad','Yurtdışı Turlar',10),
    ('tour_culture','Kültür Turları',20),
    ('tour_cruise','Gemi Turları',30),
    ('tour_daily','Günlük Turlar',40),
    ('tour_religious','Dini Turlar',50)
)
INSERT INTO onboarding.category_filter_items(
  group_id,item_key,title,contract_field_code,contract_value,position,active
)
SELECT g.id,i.item_key,i.title,'tour_subcategory',i.item_key,i.position,true
FROM tour_group g CROSS JOIN items i
ON CONFLICT(group_id,item_key) DO UPDATE SET
  active=true,contract_field_code=excluded.contract_field_code,
  contract_value=excluded.contract_value,updated_at=now();

SELECT onboarding.queue_category_filter_translations('group',id,'tr')
FROM onboarding.category_filter_groups WHERE category_code='tour' AND group_key='tour_subcategory';
SELECT onboarding.queue_category_filter_translations('item',i.id,'tr')
FROM onboarding.category_filter_items i
JOIN onboarding.category_filter_groups g ON g.id=i.group_id
WHERE g.category_code='tour' AND g.group_key='tour_subcategory';

UPDATE core.contract_versions SET version='1.2.0',activated_at=now()
WHERE contract_name='nexus.supplier_listing';
