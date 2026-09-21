-- Canonical category contract v1.0.0 shared with the agency application.
ALTER TABLE onboarding.categories
  ADD COLUMN IF NOT EXISTS contract_version text NOT NULL DEFAULT '1.0.0',
  ADD COLUMN IF NOT EXISTS position int NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS core.contract_versions (
  contract_name text PRIMARY KEY,
  version text NOT NULL,
  activated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO core.contract_versions(contract_name,version)
VALUES ('nexus.catalog.categories','1.0.0')
ON CONFLICT(contract_name) DO UPDATE
SET version=excluded.version,activated_at=now();

INSERT INTO onboarding.categories(code,name,description,active,contract_version,position) VALUES
 ('hotel','Otel','Otel, tatil köyü, apart ve diğer konaklama tesisleri',true,'1.0.0',1),
 ('villa','Villa','Villa, tatil evi ve özel konut',true,'1.0.0',2),
 ('yacht','Yat','Yat, gulet, katamaran ve marina ürünleri',true,'1.0.0',3),
 ('tour','Tur','Günübirlik veya çok günlük turlar',true,'1.0.0',4),
 ('activity','Aktivite','Aktivite, deneyim ve rehberli etkinlik',true,'1.0.0',5),
 ('flight','Uçuş','Uçuş ve hava yolu bilet ürünleri',true,'1.0.0',6),
 ('car','Araç','Araç kiralama ve araç hizmetleri',true,'1.0.0',7),
 ('cruise','Kruvaziyer','Kruvaziyer, gemi, rota ve kabin ürünleri',true,'1.0.0',8),
 ('pilgrimage','Hac & Umre','Hac ve umre organizasyonları',true,'1.0.0',9),
 ('visa','Vize','Vize başvuru ve danışmanlık hizmetleri',true,'1.0.0',10),
 ('ferry','Feribot','Feribot ve deniz otobüsü seferleri',true,'1.0.0',11),
 ('transfer','Transfer','Havalimanı, şehir içi ve özel transfer',true,'1.0.0',12),
 ('beach','Şezlong','Plaj, şezlong, loca ve zaman dilimi ürünleri',true,'1.0.0',13),
 ('cinema','Sinema','Film, salon, seans ve koltuk ürünleri',true,'1.0.0',14),
 ('event','Etkinlik','Konser, tiyatro, festival ve etkinlik biletleri',true,'1.0.0',15),
 ('restaurant','Restoran','Restoran, masa ve gastronomi ürünleri',true,'1.0.0',16),
 ('bus','Otobüs','Otobüs hattı, sefer ve koltuk ürünleri',true,'1.0.0',17)
ON CONFLICT(code) DO UPDATE SET
 name=excluded.name,
 description=excluded.description,
 active=true,
 contract_version=excluded.contract_version,
 position=excluded.position;

UPDATE onboarding.categories
SET active=false,contract_version='1.0.0',position=0
WHERE code NOT IN (
 'hotel','villa','yacht','tour','activity','flight','car','cruise',
 'pilgrimage','visa','ferry','transfer','beach','cinema','event',
 'restaurant','bus'
);

INSERT INTO onboarding.requirements(category_code,code,label,kind,required,position) VALUES
 ('visa','business_document','Faaliyet / yetki belgesi','document',true,10),
 ('visa','authorization','Vize danışmanlığı yetki belgesi','document',true,20),
 ('bus','business_document','Faaliyet / yetki belgesi','document',true,10),
 ('bus','transport_license','Taşımacılık yetki belgesi','document',true,20),
 ('bus','insurance','Zorunlu taşıma ve sorumluluk sigortası','document',true,30)
ON CONFLICT(category_code,code) DO UPDATE SET
 label=excluded.label,kind=excluded.kind,required=excluded.required,position=excluded.position;

