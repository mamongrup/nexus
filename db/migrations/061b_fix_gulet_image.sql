-- 061_fix_gulet_image.sql
-- Update Göcek Gulet photo to verified 200 OK luxury yacht photo

UPDATE catalog.properties
SET media = '["https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=1200&q=80", "https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80"]'::jsonb
WHERE id = '33333333-cccc-4333-8333-333333333333';
