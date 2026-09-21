-- 055_fix_category_encoding_and_seed_fields.sql
-- Fixes UTF-8 character encoding for categories and provides rich standard fields for all verticals

UPDATE onboarding.categories SET name = 'Uçak / Bilet' WHERE code = 'flight';

INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
  -- Pilgrimage (Hac / Umre)
  ('pilgrimage', 'program_type', 'Program Türü', 'select', 'Hac,Umre,Kudüs & Umre,Ramazan Umresi', true, true, 10),
  ('pilgrimage', 'hotel_distance_makkah', 'Mekke Otel Mesafesi (metre)', 'number', '', true, true, 20),
  ('pilgrimage', 'hotel_distance_madinah', 'Medine Otel Mesafesi (metre)', 'number', '', true, true, 30),
  ('pilgrimage', 'visa_included', 'Vize Hizmeti Dahil', 'boolean', '', true, true, 40),
  ('pilgrimage', 'guidance_language', 'Rehberlik Dili', 'text', '', false, true, 50),

  -- Yacht & Marina
  ('yacht', 'boat_type', 'Tekne Tipi', 'select', 'Gulet,Motoryat,Katamaran,Yelkenli', true, true, 10),
  ('yacht', 'cabin_count', 'Kabin Sayısı', 'number', '', true, true, 20),
  ('yacht', 'capacity', 'Maksimum Yolcu', 'number', '', true, true, 30),
  ('yacht', 'crew_included', 'Mürettebat Dahil', 'boolean', '', true, true, 40),
  ('yacht', 'departure_marina', 'Kalkış Marinası', 'text', '', true, true, 50),

  -- Flight / Ticket (Uçak / Bilet)
  ('flight', 'airline_code', 'Havayolu Kodu', 'text', '', true, true, 10),
  ('flight', 'cabin_class', 'Kabin Sınıfı', 'select', 'Economy,Premium Economy,Business,First Class', true, true, 20),
  ('flight', 'baggage_kg', 'Bagaj Hakkı (kg)', 'number', '', true, true, 30),
  ('flight', 'refundable', 'İade Edilebilir Bilet', 'boolean', '', true, true, 40),

  -- Package (Paket / Dinamik Paket)
  ('package', 'duration_days', 'Süre (Gün)', 'number', '', true, true, 10),
  ('package', 'includes_flight', 'Uçak Bileti Dahil', 'boolean', '', true, true, 20),
  ('package', 'includes_transfer', 'Transfer Dahil', 'boolean', '', true, true, 30),
  ('package', 'meal_plan', 'Pansiyon Tipi', 'select', 'Her Şey Dahil,Ultra Her Şey Dahil,Oda Kahvaltı,Yarım Pansiyon', true, true, 40),

  -- Spa & Wellness
  ('spa', 'treatment_type', 'Bakım / Terapi Türü', 'text', '', true, true, 10),
  ('spa', 'duration_minutes', 'Seans Süresi (Dakika)', 'number', '', true, true, 20),
  ('spa', 'therapist_gender', 'Terapist Tercihi', 'select', 'Farketmez,Kadın,Erkek', false, true, 30),

  -- Restaurant & Gastronomy
  ('restaurant', 'cuisine_type', 'Mutfak Türü', 'text', '', true, true, 10),
  ('restaurant', 'seating_capacity', 'Masa Kapasitesi', 'number', '', true, true, 20),
  ('restaurant', 'dress_code', 'Kıyafet Kodu', 'select', 'Casual,Smart Casual,Formal', false, true, 30)
ON CONFLICT (category_code, field_code) DO UPDATE SET
  label = EXCLUDED.label,
  kind = EXCLUDED.kind,
  choices = EXCLUDED.choices,
  required = EXCLUDED.required,
  active = EXCLUDED.active,
  position = EXCLUDED.position;
