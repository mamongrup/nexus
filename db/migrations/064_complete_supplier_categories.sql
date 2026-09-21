INSERT INTO onboarding.categories(code,name,description) VALUES
 ('activity','Aktivite / Deneyim','Süreli aktivite, biletli deneyim ve rehberli etkinlik'),
 ('car','Araç kiralama','Araç grubu, filo, teslim ve iade ürünü'),
 ('cruise','Kruvaziyer','Gemi, sefer, rota ve kabin ürünü'),
 ('event','Etkinlik / Bilet','Mekân, tarih, bölüm ve bilet türü'),
 ('cinema','Sinema','Film, salon, seans ve koltuk ürünü'),
 ('bus','Otobüs','Hat, sefer ve koltuk ürünü'),
 ('ferry','Feribot','Hat, sefer, yolcu ve araç kapasitesi'),
 ('beach','Plaj / Şezlong','Plaj alanı, gün ve zaman dilimi ürünü')
ON CONFLICT(code) DO UPDATE SET name=excluded.name,description=excluded.description,active=true;

INSERT INTO onboarding.category_fields(category_code,field_code,label,kind,choices,required,position) VALUES
 ('activity','activity_type','Aktivite türü','text','',true,10),('activity','duration_minutes','Süre (dakika)','number','',true,20),('activity','minimum_age','Asgari yaş','number','',false,30),('activity','safety_rules','Güvenlik kuralları','text','',true,40),('activity','slot_capacity','Seans kapasitesi','number','',true,50),
 ('car','vehicle_group','Araç grubu','text','',true,10),('car','transmission','Vites','select','Otomatik,Manuel',true,20),('car','fuel','Yakıt','text','',true,30),('car','mileage_policy','Kilometre politikası','text','',true,40),('car','insurance','Sigorta kapsamı','text','',true,50),
 ('cruise','cruise_line','Kruvaziyer şirketi','text','',true,10),('cruise','ship','Gemi','text','',true,20),('cruise','itinerary','Rota','text','',true,30),('cruise','cabin_category','Kabin kategorisi','text','',true,40),('cruise','departure','Hareket tarihi/limanı','text','',true,50),
 ('event','venue','Mekân','text','',true,10),('event','organizer','Organizatör','text','',true,20),('event','event_datetime','Etkinlik tarihi ve saati','text','',true,30),('event','ticket_type','Bilet türü','text','',true,40),('event','section_capacity','Bölüm kapasitesi','number','',true,50),
 ('cinema','film','Film','text','',true,10),('cinema','hall','Salon','text','',true,20),('cinema','session','Seans','text','',true,30),('cinema','seat_type','Koltuk türü','text','',true,40),
 ('bus','route','Hat / rota','text','',true,10),('bus','departure','Hareket yeri ve saati','text','',true,20),('bus','arrival','Varış yeri ve saati','text','',true,30),('bus','seat_capacity','Koltuk kapasitesi','number','',true,40),
 ('ferry','route','Hat / rota','text','',true,10),('ferry','departure','Hareket yeri ve saati','text','',true,20),('ferry','passenger_capacity','Yolcu kapasitesi','number','',true,30),('ferry','vehicle_capacity','Araç kapasitesi','number','',false,40),
 ('beach','area','Plaj / alan','text','',true,10),('beach','unit_type','Ünite türü','select','Şezlong,Loca,Daybed,Şemsiye',true,20),('beach','slot','Zaman dilimi','text','',true,30),('beach','capacity','Kapasite','number','',true,40)
ON CONFLICT(category_code,field_code) DO UPDATE SET label=excluded.label,kind=excluded.kind,choices=excluded.choices,required=excluded.required,active=true,position=excluded.position;

INSERT INTO onboarding.requirements(category_code,code,label,kind,required,position)
SELECT c.code,'business_document','Faaliyet / yetki belgesi','document',true,10 FROM onboarding.categories c
WHERE NOT EXISTS(SELECT FROM onboarding.requirements r WHERE r.category_code=c.code AND r.kind='document')
ON CONFLICT(category_code,code) DO NOTHING;
INSERT INTO onboarding.requirements(category_code,code,label,kind,required,position)
SELECT c.code,'liability_document','Sigorta veya sorumluluk belgesi','document',true,20 FROM onboarding.categories c
WHERE c.code IN ('activity','car','cruise','event','bus','ferry','beach')
ON CONFLICT(category_code,code) DO NOTHING;
