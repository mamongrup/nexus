-- Keep the shared baseline filter keys aligned with the agency's editable
-- holiday-home and yacht themes. Existing administrator edits are preserved.
INSERT INTO onboarding.category_filter_groups
  (category_code,group_key,title,help_text,display_type,multiple,position,active)
VALUES
  ('holiday_home','theme','Tema','Tatil evlerini deniz, doğa ve konaklama özelliklerine göre keşfedin.','chips',true,20,true),
  ('yacht','theme','Tema','Yatları ve tekne gezilerini deniz deneyimine göre keşfedin.','chips',true,20,true)
ON CONFLICT(category_code,group_key) DO NOTHING;

WITH seed(category_code,item_key,title,position) AS (
  VALUES
    ('holiday_home','beachfront','Denize Sıfır',10),
    ('holiday_home','sea_view','Deniz Manzaralı',20),
    ('holiday_home','sheltered','Muhafazakar',30),
    ('holiday_home','jacuzzi','Jakuzili',40),
    ('holiday_home','forest_view','Orman Manzaralı',50),
    ('holiday_home','pool','Havuzlu',60),
    ('yacht','private_cruise','Özel Tur',10),
    ('yacht','sunset_cruise','Gün Batımı',20),
    ('yacht','swimming','Yüzme',30),
    ('yacht','fishing','Balık Tutma',40),
    ('yacht','luxury','Lüks',50)
)
INSERT INTO onboarding.category_filter_items
  (group_id,item_key,title,contract_field_code,contract_value,position,active)
SELECT g.id,s.item_key,s.title,'amenities',s.item_key,s.position,true
FROM seed s JOIN onboarding.category_filter_groups g
  ON g.category_code=s.category_code AND g.group_key='theme'
ON CONFLICT(group_id,item_key) DO NOTHING;

SELECT onboarding.queue_category_filter_translations('group',id,'tr')
FROM onboarding.category_filter_groups
WHERE group_key='theme' AND category_code IN ('holiday_home','yacht');
SELECT onboarding.queue_category_filter_translations('item',i.id,'tr')
FROM onboarding.category_filter_items i
JOIN onboarding.category_filter_groups g ON g.id=i.group_id
WHERE g.group_key='theme' AND g.category_code IN ('holiday_home','yacht');
