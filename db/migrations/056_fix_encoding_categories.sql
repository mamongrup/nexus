-- 056_fix_encoding_categories.sql
UPDATE onboarding.categories SET name = 'Uçak / Bilet' WHERE code = 'flight';
