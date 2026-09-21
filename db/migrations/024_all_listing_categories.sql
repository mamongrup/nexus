INSERT INTO onboarding.categories(code,name) VALUES
 ('yacht','Yat / Marina'),('spa','SPA / Spor'),('flight','Uçak / Bilet'),('pilgrimage','Hac / Umre'),('package','Paket / Dinamik Paket')
 ON CONFLICT (code) DO NOTHING;
INSERT INTO onboarding.requirements(category_code,code,label,kind,required,position) VALUES
 ('yacht','license','Tekne ruhsatı','document',true,10),('yacht','capacity','Yolcu kapasitesi','number',true,20),('yacht','route','Marina ve rota','text',true,30),
 ('spa','license','İşyeri / uzmanlık belgesi','document',true,10),('spa','services','Hizmet ve ekipman listesi','text',true,20),('spa','capacity','Slot kapasitesi','number',true,30),
 ('flight','provider','Taşıyıcı / bağlantı sağlayıcı','text',true,10),('flight','baggage','Bagaj ve sınıf kuralları','text',true,20),
 ('pilgrimage','authorization','Yetki belgesi','document',true,10),('pilgrimage','visa','Vize ve konaklama şartları','text',true,20),
 ('package','components','Paket bileşenleri','text',true,10),('package','capacity','Paket kapasitesi','number',true,20)
 ON CONFLICT (category_code,code) DO NOTHING;
