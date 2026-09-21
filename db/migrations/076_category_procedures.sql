-- 076_category_procedures.sql
-- Comprehensive category-specific listing creation procedures, regulatory guidelines, and field encoding fixes

-- 1. Create table for category procedures
CREATE TABLE IF NOT EXISTS onboarding.category_procedures (
  category_code text PRIMARY KEY REFERENCES onboarding.categories(code) ON DELETE CASCADE,
  procedure_title text NOT NULL,
  legal_basis text NOT NULL,
  badge_text text NOT NULL DEFAULT 'Yasal Prosedür & Zorunluluk',
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  guidelines text NOT NULL DEFAULT '',
  required_documents text NOT NULL DEFAULT '',
  operational_rules text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Clean up category descriptions
UPDATE onboarding.categories SET 
  name = 'Villa / Tatil Evi',
  description = 'Müstakil villa, lüks konut, dağ evi ve turizm amaçlı tatil konutu'
WHERE code = 'villa';

UPDATE onboarding.categories SET 
  name = 'Otel / Konaklama Tesisi',
  description = 'Yıldızlı otel, butik otel, tatil köyü, apart ve pansiyon konaklama tesisi'
WHERE code = 'hotel';

UPDATE onboarding.categories SET 
  name = 'Yat / Marina',
  description = 'Lüks gulet, motoryat, katamaran, yelkenli ve mavi tur kiralama'
WHERE code = 'yacht';

UPDATE onboarding.categories SET 
  name = 'Araç kiralama',
  description = 'Binek araç grubu, VIP filo, elektrikli otomobil, teslim ve iade kiralama'
WHERE code = 'car';

UPDATE onboarding.categories SET 
  name = 'Tur / Deneyim',
  description = 'Günübirlik ve konaklamalı tur, profesyonel rehberli gezi ve özel seyahat'
WHERE code = 'tour';

UPDATE onboarding.categories SET 
  name = 'Transfer / Ulaşım',
  description = 'Havalimanı karşılama, VIP şoförlü transfer, şehirlerarası ve liman ulaşımı'
WHERE code = 'transfer';

UPDATE onboarding.categories SET 
  name = 'Aktivite / Deneyim',
  description = 'Yamaç paraşütü, dalış, rafting, safariler ve adrenalin/doğa aktiviteleri'
WHERE code = 'activity';

UPDATE onboarding.categories SET 
  name = 'Restoran / Gastronomi',
  description = 'Şef tadım menüsü, fine dining, masa rezervasyonu ve gastronomi deneyimleri'
WHERE code = 'restaurant';

UPDATE onboarding.categories SET 
  name = 'Uçak / Bilet',
  description = 'Tarifeli havayolu uçak bileti, charter uçuşlar ve kabin sınıfı rezervasyonları'
WHERE code = 'flight';

UPDATE onboarding.categories SET 
  name = 'Kruvaziyer',
  description = 'Uluslararası gemi seyahati, kabin kategorileri ve liman rotalı turlar'
WHERE code = 'cruise';

UPDATE onboarding.categories SET 
  name = 'SPA / Spor',
  description = 'Termal sağlık, geleneksel Türk hamamı, profesyonel masaj ve detoks terapileri'
WHERE code = 'spa';

UPDATE onboarding.categories SET 
  name = 'Plaj / Şezlong',
  description = 'Özel plaj kulübü (Beach Club), iskele, şezlong, daybed ve VIP loca alanları'
WHERE code = 'beach';

UPDATE onboarding.categories SET 
  name = 'Feribot',
  description = 'Adalar ve uluslararası hatlar deniz otobüsü, feribot, yolcu ve araç bileti'
WHERE code = 'ferry';

UPDATE onboarding.categories SET 
  name = 'Otobüs',
  description = 'Şehirlerarası karayolu yolcu taşımacılığı, 2+1 konforlu otobüs seferleri'
WHERE code = 'bus';

UPDATE onboarding.categories SET 
  name = 'Etkinlik / Bilet',
  description = 'Açık hava konseri, müzik festivali, tiyatro, sahne sanatları ve spor bileti'
WHERE code = 'event';

UPDATE onboarding.categories SET 
  name = 'Sinema',
  description = 'Vizyon filmleri, IMAX/3D salon seansı ve numaralı koltuk rezervasyonu'
WHERE code = 'cinema';

UPDATE onboarding.categories SET 
  name = 'Paket / Dinamik Paket',
  description = 'Uçak + Otel + Transfer kombine tatil paketi ve kişiye özel seyahat programı'
WHERE code = 'package';

UPDATE onboarding.categories SET 
  name = 'Hac / Umre',
  description = 'Kutsal topraklar Hac, Umre, Kudüs ziyaret programları ve rehberli ibadet turları'
WHERE code = 'pilgrimage';

-- 3. Fix corrupted UTF-8 encodings in category_fields
UPDATE onboarding.category_fields SET label = 'Kabin Sınıfı' WHERE category_code = 'flight' AND field_code = 'cabin_class';
UPDATE onboarding.category_fields SET label = 'Bagaj Hakkı (kg)' WHERE category_code = 'flight' AND field_code = 'baggage_kg';
UPDATE onboarding.category_fields SET label = 'İade Edilebilir Bilet' WHERE category_code = 'flight' AND field_code = 'refundable';
UPDATE onboarding.category_fields SET label = 'Tesis Olanakları' WHERE category_code = 'hotel' AND field_code = 'amenities';
UPDATE onboarding.category_fields SET label = 'Süre (Gün)' WHERE category_code = 'package' AND field_code = 'duration_days';
UPDATE onboarding.category_fields SET label = 'Uçak Bileti Dahil' WHERE category_code = 'package' AND field_code = 'includes_flight';
UPDATE onboarding.category_fields SET label = 'Transfer Dahil' WHERE category_code = 'package' AND field_code = 'includes_transfer';
UPDATE onboarding.category_fields SET label = 'Pansiyon Tipi', choices = 'Her Şey Dahil,Ultra Her Şey Dahil,Oda Kahvaltı,Yarım Pansiyon' WHERE category_code = 'package' AND field_code = 'meal_plan';
UPDATE onboarding.category_fields SET label = 'Program Türü', choices = 'Hac,Umre,Kudüs & Umre,Ramazan Umresi' WHERE category_code = 'pilgrimage' AND field_code = 'program_type';
UPDATE onboarding.category_fields SET label = 'Mutfak Türü' WHERE category_code = 'restaurant' AND field_code = 'cuisine_type';
UPDATE onboarding.category_fields SET label = 'Masa Kapasitesi' WHERE category_code = 'restaurant' AND field_code = 'seating_capacity';
UPDATE onboarding.category_fields SET label = 'Kıyafet Kodu' WHERE category_code = 'restaurant' AND field_code = 'dress_code';
UPDATE onboarding.category_fields SET label = 'Bakım / Terapi Türü' WHERE category_code = 'spa' AND field_code = 'treatment_type';
UPDATE onboarding.category_fields SET label = 'Seans Süresi (Dakika)' WHERE category_code = 'spa' AND field_code = 'duration_minutes';
UPDATE onboarding.category_fields SET label = 'Terapist Tercihi', choices = 'Farketmez,Kadın,Erkek' WHERE category_code = 'spa' AND field_code = 'therapist_gender';
UPDATE onboarding.category_fields SET label = 'Süre' WHERE category_code = 'tour' AND field_code = 'duration';
UPDATE onboarding.category_fields SET label = 'Araç Sınıfı' WHERE category_code = 'transfer' AND field_code = 'vehicle_class';
UPDATE onboarding.category_fields SET label = 'Yatak Odası' WHERE category_code = 'villa' AND field_code = 'bedrooms';
UPDATE onboarding.category_fields SET label = 'Banyo Sayısı' WHERE category_code = 'villa' AND field_code = 'bathrooms';
UPDATE onboarding.category_fields SET label = 'Kabin Sayısı' WHERE category_code = 'yacht' AND field_code = 'cabin_count';
UPDATE onboarding.category_fields SET label = 'Mürettebat Dahil' WHERE category_code = 'yacht' AND field_code = 'crew_included';
UPDATE onboarding.category_fields SET label = 'Kalkış Marinası' WHERE category_code = 'yacht' AND field_code = 'departure_marina';

-- Fix requirements labels
UPDATE onboarding.requirements SET label = 'Bagaj ve sınıf kuralları' WHERE category_code = 'flight' AND code = 'baggage';
UPDATE onboarding.requirements SET label = 'Taşıyıcı / bağlantı sağlayıcı' WHERE category_code = 'flight' AND code = 'provider';
UPDATE onboarding.requirements SET label = 'Paket bileşenleri' WHERE category_code = 'package' AND code = 'components';
UPDATE onboarding.requirements SET label = 'Vize ve konaklama şartları' WHERE category_code = 'pilgrimage' AND code = 'visa';
UPDATE onboarding.requirements SET label = 'İşyeri / uzmanlık belgesi' WHERE category_code = 'spa' AND code = 'license';
UPDATE onboarding.requirements SET label = 'Tekne ruhsatı ve denize elverişlilik' WHERE category_code = 'yacht' AND code = 'license';

-- 4. Seed Comprehensive Category Procedures
INSERT INTO onboarding.category_procedures (
  category_code, procedure_title, legal_basis, badge_text, steps, guidelines, required_documents, operational_rules
) VALUES
(
  'villa',
  'Müstakil Konut ve Lüks Villa İlan Kayıt Prosedürü',
  'Kültür ve Turizm Bakanlığı 7464 Sayılı Konutların Turizm Amaçlı Kiralanması Kanunu & 1774 Sayılı Kimlik Bildirme Kanunu (AKBS)',
  'Yasal İzin ve AKBS Zorunlu',
  '[
    {"step": 1, "title": "Bakanlık İzin Belgesi & Plaket Doğrulaması", "desc": "Kültür ve Turizm Bakanlığı Turizm Amaçlı Konut İzin Belgesi numarası ve konut girişine asılan karekodlu plaket numarası sisteme girilmelidir."},
    {"step": 2, "title": "Tesis Güvenlik ve Yangın Standartları", "desc": "Konutta duman dedektörü, yangın söndürme tüpü, ilk yardım çantası ve acil durum tahliye krokisi tam bulunmalıdır."},
    {"step": 3, "title": "Oda, Yatak ve Yaşam Alanı Tanımı", "desc": "Her yatak odasının yatak tipi (çift/tek), ebeveyn banyosu, jakuzi, klima ve bebek yatağı olanakları eksiksiz listelenmelidir."},
    {"step": 4, "title": "Havuz Güvenliği ve Periyodik Bakım", "desc": "Havuzun korunaklılık (muhafazakar) durumu, ısıtmalı havuz opsiyonu ve periyodik klor/pH bakım saatleri misafirlere ilan edilmelidir."},
    {"step": 5, "title": "Depozito, İptal ve Giriş Protokolü", "desc": "Girişte alınacak hasar depozitosu tutarı, iade süresi, check-in (16:00) / check-out (10:00) saatleri ve KBS kimlik bildirim süreci girilmelidir."}
  ]'::jsonb,
  'İlanda beyan edilen misafir kapasitesinin üzerinde konaklama kesinlikle yasaktır. 1774 sayılı kanun uyarınca tesise giriş yapan her yetişkin misafirin TC kimlik veya pasaport bilgisi emniyet sistemine (AKBS) giriş gününde iletilmelidir.',
  '1. Turizm Amaçlı Konut İzin Belgesi\n2. DASK ve Yangın Sigortası Poliçesi\n3. Tapu veya Kira Alt Sözleşmesi\n4. EGM AKBS Tesis Kodu Belgesi',
  '• Giriş saati en erken 16:00, çıkış saati en geç 10:00 olarak uygulanır.\n• Evcil hayvan ve parti/etkinlik kuralları ilanda açıkça belirtilmelidir.\n• Hasar depozitosu çıkışta yapılan fiziki kontrolden sonra en geç 24 saat içinde iade edilir.'
),
(
  'hotel',
  'Otel, Resort ve Butik Tesis İlan Kayıt Prosedürü',
  '2634 Sayılı Turizmi Teşvik Kanunu, Turizm Tesislerinin Niteliklerine İlişkin Yönetmelik & AKBS Emniyet Bildirimi',
  'İşletme Belgesi & PMS Uyumlu',
  '[
    {"step": 1, "title": "Turizm İşletme / Belediye Ruhsatı Tescili", "desc": "Kültür ve Turizm Bakanlığı yıldız derecelendirme belgesi veya belediye işyeri açma ruhsatı resmi sicili kaydedilmelidir."},
    {"step": 2, "title": "Oda Tipi Envanteri ve PMS Oda Numaralandırması", "desc": "Standart, Deluxe, Suit ve Aile Odası envanterleri PMS oda kodları ve kat planları ile eşleştirilmelidir."},
    {"step": 3, "title": "Pansiyon Konsepti ve Yeme-İçme Standartları", "desc": "Oda-Kahvaltı, Yarım Pansiyon veya Her Şey Dahil konsept servis saatleri, alakart restoran ve açık büfe detayları tanımlanmalıdır."},
    {"step": 4, "title": "7/24 Resepsiyon ve AKBS Otomasyonu", "desc": "Resepsiyon entegrasyonu, temassız check-in olanakları ve emniyet kimlik bildirim altyapısının faal olduğu doğrulanmalıdır."},
    {"step": 5, "title": "Fiyatlandırma, No-Show ve Garanti Kart Politikası", "desc": "Sezonluk oda fiyatları, çocuk yaş indirim dilimleri, ücretsiz iptal süreleri ve no-show tahsilat prosedürü ilan edilmelidir."}
  ]'::jsonb,
  'Konaklama vergisi (%2) ve KDV (%10) yasal mevzuata uygun hesaplanarak faturalandırılmalıdır. Tesis genel alanlarında kamera güvenlik sistemi ve yangın alarm istasyonu faal olmalıdır.',
  '1. Kültür ve Turizm Bakanlığı İşletme Belgesi\n2. İtfaiye Yangın Uygunluk Raporu\n3. İl Sağlık Müdürlüğü Havuz ve Su Hijyen Raporu\n4. Vergi Levhası ve İmza Sirküleri',
  '• Ön büro 7/24 kesintisiz hizmet vermekle yükümlüdür.\n• Odaya giriş 14:00, odadan ayrılış 12:00 olarak uygulanır.\n• Odalarda günlük temizlik ve 2 günde bir nevresim değişimi standarttır.'
),
(
  'yacht',
  'Ticari Yat, Gulet ve Katamaran Mavi Yolculuk İlan Prosedürü',
  'Deniz Turizmi Yönetmeliği, Ulaştırma ve Altyapı Bakanlığı Gemi ve Su Araçları Denetim Yönetmeliği & Liman Başkanlığı Transitlog Mevzuatı',
  'Denize Elverişlilik & P&I Sigortası',
  '[
    {"step": 1, "title": "Denize Elverişlilik ve Ticari Yat Belgesi", "desc": "Liman Başkanlığı onaylı geçerli Denize Elverişlilik Belgesi, tonaj kaydı ve P&I (Personel ve Üçüncü Şahıs) Sigortası kaydedilmelidir."},
    {"step": 2, "title": "Mürettebat ve Personel Kadro Beyanı", "desc": "Kaptan, başçarkçı, aşçı ve gemici yeterlilik belgeleri ile gemi adamı cüzdanları sisteme işlenmelidir."},
    {"step": 3, "title": "Kabin Tipleri ve Yaşam Alanı Donanımı", "desc": "Master, double ve twin kabin düzeni, klima çalışma saatleri, su yapıcı (Watermaker) ve jeneratör kapasiteleri listelenmelidir."},
    {"step": 4, "title": "Marina, Rota ve Seyir Planı", "desc": "Kalkış ve dönüş marinası (Bodrum, Göcek, Fethiye vb.), haftalık rota planı ve liman bağlama koşulları açıklanmalıdır."},
    {"step": 5, "title": "Yakıt, Kumanya ve APA (Gelişmiş Provizyon) Prosedürü", "desc": "Fiyata dahil olan seyir yakıtı saati, kumanya temini, aşçı menü hazırlığı ve transitlog masrafları netleştirilmelidir."}
  ]'::jsonb,
  'Kapasite aşımı denizcilik kanunlarına göre ağır para cezası ve seferden men nedenidir. Seyir öncesinde Liman Başkanlığına onaylatılmış Transitlog yolcu listesi eksiksiz emniyet bildirimine bağlanmalıdır.',
  '1. Denize Elverişlilik Belgesi\n2. Ticari Yat İşletme Belgesi\n3. P&I ve Tekne-Makine Sigorta Poliçesi\n4. Mürettebat Donatım Asgari Emniyet Belgesi',
  '• Kiralama genelde Cumartesi 16:00 giriş - Cumartesi 09:30 çıkış esasıyla yapılır.\n• Rota hava muhalefeti halinde kaptanın yetkisiyle güvenlik gerekçesiyle değiştirilebilir.\n• Su sporları kullanımında can yeleği takılması uluslararası denizcilik kuralıdır.'
),
(
  'car',
  'Filo ve Araç Kiralama (Rent-a-Car) İlan Prosedürü',
  'Emniyet Genel Müdürlüğü KABİS (Kiralık Araç Bildirim Sistemi), Karayolu Taşıma Yönetmeliği & Ticaret Bakanlığı Motorlu Araç Ticareti Yönetmeliği',
  'KABİS Entegrasyonu & Rent-a-Car Kasko',
  '[
    {"step": 1, "title": "Rent-a-Car Kasko ve Ruhsat Doğrulaması", "desc": "Kiralama amaçlı kullanıma uygun genişletilmiş Rent-a-Car Kasko poliçesi ve araç ruhsat bilgileri sisteme girilmelidir."},
    {"step": 2, "title": "KABİS Emniyet Bildirim Entegrasyonu", "desc": "Aracın kiralanması anında Emniyet Genel Müdürlüğü KABİS sistemine sözleşme ve sürücü aktarımı protokolü onaylanmalıdır."},
    {"step": 3, "title": "Sürücü Yaşı ve Ehliyet Yılı Şartları", "desc": "Araç segmentine göre asgari yaş (Ekonomik: 21, Premium: 25, Lüks: 28) ve asgari ehliyet yılı (en az 2-3 yıl) tanımlanmalıdır."},
    {"step": 4, "title": "Provizyon, Depozito ve Kredi Kartı Şartı", "desc": "Sürücü adına düzenlenmiş kredi kartından çekilecek provizyon tutarı ve trafik cezası kontrol süresi (en geç 25 gün) belirtilmelidir."},
    {"step": 5, "title": "Kilometre Limiti ve Yakıt Politikası", "desc": "Günlük/aylık kilometre sınırı, km aşım bedeli ve aynı seviyede yakıt iade (Same-to-Same) kuralı girilmelidir."}
  ]'::jsonb,
  'Tüm araçlarda periyodik muayene, yetkili servis bakımı ve mevsimine uygun lastik (kış/yaz) donanımı eksiksiz olmalıdır. Alkollü veya uyuşturucu etkisinde araç kullanımı kasko kapsamı dışındadır.',
  '1. Rent-a-Car Kasko ve Trafik Sigortası Poliçesi\n2. KABİS Yetki ve Şifre Belgesi\n3. Araç Tescil Belgesi (Ruhsat)\n4. Şirket Faaliyet Belgesi',
  '• Araç tesliminde detaylı kaporta ve kilometre ekspertiz tutanağı düzenlenir.\n• Ek sürücü talebi mutlaka kiralama sözleşmesine eklenmelidir.\n• HGS/OGS geçiş ücretleri dönüşte provizyondan otomatik mahsup edilir.'
),
(
  'tour',
  'Tur, Gezi ve Seyahat Deneyimi İlan Prosedürü',
  '1618 Sayılı Seyahat Acentaları ve Seyahat Acentaları Birliği Kanunu (TÜRSAB) & Zorunlu Paket Tur Sigortası Yönetmeliği',
  'TÜRSAB A Grubu & Lisanslı Rehber',
  '[
    {"step": 1, "title": "TÜRSAB İşletme Belgesi Tescili", "desc": "Turu organize eden seyahat acentasının TÜRSAB A Grubu işletme sicil numarası ve acenta unvanı doğrulanmalıdır."},
    {"step": 2, "title": "Kokartlı Profesyonel Rehber Görevlendirmesi", "desc": "TUREB ruhsatnameli, çalışma kartı vizeli profesyonel turist rehberi ataması yapılmalıdır."},
    {"step": 3, "title": "Zorunlu Seyahat Sigortası Kapsamı", "desc": "Tura katılan tüm misafirleri kapsayan zorunlu seyahat kaza ve sağlık sigortası poliçe şartları girilmelidir."},
    {"step": 4, "title": "Güzergâh, Saatler ve Dahil/Hariç Hizmetler", "desc": "Kalkış noktaları, ziyaret edilecek müze/ören yerleri, öğle yemeği ve ekstra harcamalar şeffafça listelenmelidir."},
    {"step": 5, "title": "Hava Koşulları ve Katılım İptal Şartları", "desc": "Asgari yolcu sayısı, hava muhalefeti durumunda tur erteleme hakları ve misafir cayma baremleri tanımlanmalıdır."}
  ]'::jsonb,
  'Kaçak tur ve belgesiz rehberlik faaliyetleri yasal suç teşkil eder. Müze ve ören yeri girişlerinde Kültür Bakanlığı kurallarına ve milli park düzenlemelerine tam uyulmalıdır.',
  '1. TÜRSAB A Grubu Seyahat Acentası Belgesi\n2. Profesyonel Turist Rehberi Çalışma Kartı\n3. Tur Lideri ve Araç Görevlendirme Formu\n4. Zorunlu Paket Tur Sigortası',
  '• Tur hareket saatinden 15 dakika önce buluşma noktasında olunması rica edilir.\n• Müze Kart ve kimlik kartları katılımcıların yanında bulunmalıdır.\n• Tur güzergâhında güvenlik gerekçesiyle rehber inisiyatifiyle sıra değişikliği yapılabilir.'
),
(
  'transfer',
  'Havalimanı ve Şehirlerarası Özel VIP Transfer İlan Prosedürü',
  'Karayolu Taşıma Kanunu ve Yönetmeliği (D2 / B2 Belgesi), Ulaştırma Bakanlığı U-ETDS Sistemi & TÜRSAB Transfer Yönetmeliği',
  'D2 Taşıma Yetkisi & U-ETDS Uyumlu',
  '[
    {"step": 1, "title": "D2 / B2 Taşıma Yetki Belgesi Doğrulaması", "desc": "Ulaştırma ve Altyapı Bakanlığı tarafından tanzim edilmiş geçerli D2 yetki belgesi ve araç plaka listesi sisteme kaydedilmelidir."},
    {"step": 2, "title": "Sürücü SRC ve Psikoteknik Raporu", "desc": "Transfer şoförlerinin SRC-1/2 mesleki yeterlilik belgesi, adli sicil kaydı ve psikoteknik onayları girilmelidir."},
    {"step": 3, "title": "U-ETDS Yolcu Bildirim Entegrasyonu", "desc": "Transfer hareketinden önce taşınacak yolcuların kimlik ve varış bilgilerinin Bakanlık U-ETDS sistemine aktarımı taahhüt edilmelidir."},
    {"step": 4, "title": "Meet & Greet (Havalimanı Karşılama) Standartları", "desc": "Terminal kapısında isim levhasıyla karşılama, uçuş takip otomasyonu ve 60 dakikalık ücretsiz rötar beklemesi kuralı girilmelidir."},
    {"step": 5, "title": "Araç Donanımı ve Bagaj Kapasite Tanımı", "desc": "VIP Vito/Transporter, sedan veya minibüs tipi araçların koltuk sayısı, bagaj adedi ve bebek koltuğu opsiyonu belirtilmelidir."}
  ]'::jsonb,
  'Korsan taşımacılık cezalarına karşı araçta taşıt kartı, yolcu isim listesi ve sözleşme nüshası hazır bulundurulmalıdır. Tüm koltuklar için koltuk ferdi kaza sigortası zorunludur.',
  '1. Ulaştırma Bakanlığı D2 Taşıma Yetki Belgesi\n2. Taşıt Kartı ve Araç Ruhsatı\n3. Şoför SRC ve Psikoteknik Belgeleri\n4. Zorunlu Karayolu Taşımacılık Mali Sorumluluk Sigortası',
  '• Uçuş rötarlarında ek ücret talep edilmeksizin iniş saati takip edilir.\n• Araç içerisinde sigara ve tütün ürünleri kullanımı kesinlikle yasaktır.\n• Çocuk koltuğu talepleri transferden en az 12 saat önce bildirilmelidir.'
),
(
  'activity',
  'Aktivite, Macera ve Doğa Sporları İlan Prosedürü',
  'Turizm Amaçlı Sportif Faaliyet Yönetmeliği, İlgili Spor Federasyonları Talimatları & 3. Şahıs Mali Sorumluluk Sigortası',
  'Sportif İzin & Lisanslı Pilot/Eğitmen',
  '[
    {"step": 1, "title": "Sportif Turizm İzin Kurulu Onayı", "desc": "Valilik / Kaymakamlık Sportif Turizm İzin Kurulu onay belgesi ve parkur uygunluk tescili girilmelidir."},
    {"step": 2, "title": "Sertifikalı Pilot ve Eğitmen Kadrosu", "desc": "Yamaç paraşütü pilotu (T2), rafting rehberi veya dalış eğitmeni (CMAS/PADI) federasyon lisansları doğrulanmalıdır."},
    {"step": 3, "title": "Güvenlik Ekipmanları ve CE Test Raporları", "desc": "Kask, harness, can yeleği, karabina ve iplerin periyodik bakım tarihleri ve CE güvenlik testleri onaylanmalıdır."},
    {"step": 4, "title": "Sağlık Beyanı ve Katılımcı Kısıtlamaları", "desc": "Kalp, astım, hamilelik ve boy/kilo (azami 105 kg vb.) katılım şartları ayrıntılı tanımlanmalıdır."},
    {"step": 5, "title": "Kaza Sigortası ve Hava Koşulları Protokolü", "desc": "Tüm katılımcıları kapsayan ekstrem spor ferdi kaza poliçesi ve hava muhalefetinde tam iade/erteleme kuralı girilmelidir."}
  ]'::jsonb,
  'Katılımcılara aktivite öncesinde güvenlik brifingi verilmesi ve ıslak imzalı risk/sağlık beyanı formunun alınması mecburidir. Hava durumu uygun değilse hiçbir uçuş veya su aktivitesi icra edilemez.',
  '1. Sportif Turizm İzin Belgesi\n2. Pilot / Eğitmen Federasyon Lisansı\n3. Ekipman Güvenlik ve Periyodik Muayene Formu\n4. Üçüncü Şahıs Mali Mesuliyet Sigorta Poliçesi',
  '• Aktivite alanında alkollü veya uyuşturucu etkisi altında katılım yasaktır.\n• Uygun spor ayakkabı ve giysi giyilmesi katılımcı sorumluluğundadır.\n• Profesyonel video ve fotoğraf çekimleri aktivite paketine göre opsiyonel olarak sunulabilir.'
),
(
  'restaurant',
  'Restoran, Şef Masası ve Gastronomi İlan Prosedürü',
  'İşyeri Açma ve Çalışma Ruhsatlarına İlişkin Yönetmelik & Tarım ve Orman Bakanlığı Gıda Hijyen Yönetmeliği',
  'Gıda Güvenliği & Masa Rezervasyon',
  '[
    {"step": 1, "title": "İşyeri Açma Ruhsatı ve Hijyen Belgesi", "desc": "Belediye işyeri açma ve çalışma ruhsatı ile mutfak hijyen denetim onayları sisteme girilmelidir."},
    {"step": 2, "title": "Menü Tipi, Tadım Programı ve Alerjenler", "desc": "Alakart menü, şef tadım menüsü (Tasting Menu), vegan/vejetaryen opsiyonlar ve alerjen listesi girilmelidir."},
    {"step": 3, "title": "Masa/Bölüm Planı ve Oturma Kapasitesi", "desc": "Ana salon, bahçe, deniz kenarı, şef masası veya VIP loca oturum düzenleri belirlenmelidir."},
    {"step": 4, "title": "Ön Provizyon ve Rezervasyon Garanti Politikası", "desc": "Yoğun saatler ve özel günlerde (yılbaşı, sevgililer günü vb.) kişi başı teminat tutarı ve son iptal saati girilmelidir."},
    {"step": 5, "title": "Kıyafet Kodu (Dress Code) ve Mekan Kuralları", "desc": "Casual, Smart Casual veya Formal kıyafet zorunluluğu ve çocuk misafir kabul saatleri açıklanmalıdır."}
  ]'::jsonb,
  'Tüm gıda maddeleri Tarım Bakanlığı standartlarında saklanmalı ve hazırlanmalıdır. Menü fiyatları mevzuata uygun şekilde masalarda ve girişte şeffaf olarak sergilenmelidir.',
  '1. İşyeri Açma ve Çalışma Ruhsatı\n2. Gıda Hijyen ve Güvenlik Sertifikası\n3. Vergi Levhası ve Alkol Ruhsatı (TAPDK)',
  '• Rezervasyon saati 15 dakikadan fazla geciktiğinde masa bekleme kuralı işletilir.\n• Dışarıdan yiyecek ve içecek kabul edilmez.\n• Özel diyet ve alerjen durumları rezervasyon sırasında belirtilmelidir.'
),
(
  'flight',
  'Tarifeli ve Charter Uçuş Biletleme İlan Prosedürü',
  'Sivil Havacılık Genel Müdürlüğü (SHGM) Yolcu Hakları Yönetmeliği (SHY-YOLCU) & IATA Uluslararası Biletleme Kuralları',
  'IATA & SHGM Akredite',
  '[
    {"step": 1, "title": "IATA ve Havayolu Biletleme Yetkisi", "desc": "IATA üyelik tescili veya ilgili havayolu şirketi doğrudan biletleme yetki kodu sisteme tanımlanmalıdır."},
    {"step": 2, "title": "Kabin Sınıfları ve Koltuk Özellikleri", "desc": "Economy, Premium Economy, Business ve First Class sınıf hakları, koltuk aralığı ve ikram servisi girilmelidir."},
    {"step": 3, "title": "Bagaj ve El Bagajı Kuralları", "desc": "Kabin bagajı ölçü/ağırlık limitleri (8 kg) ve kayıtlı kargo bagajı hakları (15-30 kg) belirtilmelidir."},
    {"step": 4, "title": "Bilet Değişiklik ve İptal Baremleri", "desc": "Uçuştan önce iptal, açığa alma, isim düzeltme ve no-show cezai kesintileri şeffafça gösterilmelidir."},
    {"step": 5, "title": "PNR ve E-Bilet İletim Otomasyonu", "desc": "Bilet onaylandığında 6 haneli PNR ve 13 haneli bilet numarasının misafire SMS ve e-posta ile anlık iletimi sağlanmalıdır."}
  ]'::jsonb,
  'Uçuş saatleri havayolu inisiyatifiyle değişebilir. SHY-YOLCU yönetmeliği uyarınca 2 saati aşan rötarlarda yolculara ikram, 8 saati aşan rötarlarda otel konaklaması sağlanması kanuni zorunluluktur.',
  '1. IATA Acentelik Belgesi / Havayolu Yetki Sözleşmesi\n2. SHGM Seyahat Acentası Biletleme Yetki Onayı\n3. Şirket İmza Sirküleri',
  '• İç hatlarda uçuştan en az 60 dk, dış hatlarda en az 120 dk önce kontuarda olunmalıdır.\n• Geçerli kimlik kartı veya süresi dolmamış pasaport ibrazı zorunludur.\n• Evcil hayvan kabin taşımacılığı önceden havayolundan onaylanmalıdır.'
),
(
  'cruise',
  'Uluslararası Kruvaziyer ve Gemi Turları İlan Prosedürü',
  'Uluslararası Denizde Can Emniyeti Sözleşmesi (SOLAS), IMO Kılavuzları & Seyahat Acentaları Mevzuatı',
  'SOLAS & IMO Standartları',
  '[
    {"step": 1, "title": "Kruvaziyer Şirketi Satış Acenteliği", "desc": "Kruvaziyer hattı (MSC, Costa, Celestyal vb.) resmi satış temsilciliği veya acente sözleşmesi kaydedilmelidir."},
    {"step": 2, "title": "Kabin Tipleri ve Güverte Konumu", "desc": "İç Kabin, Dış Kabin (Pencereli), Balkonlu Kabin ve Suit kategorileri metrekare ve kat bilgileriyle tanımlanmalıdır."},
    {"step": 3, "title": "Liman Vergileri ve Bahşiş Kapsamı", "desc": "Paket ücrete dahil olan/olmayan liman vergileri, servis bahşişleri ve içecek paketleri detaylandırılmalıdır."},
    {"step": 4, "title": "Pasaport ve Vize Protokolü", "desc": "Rotadaki ülkeler için asgari 6 ay geçerli pasaport ve Schengen/Amerikan vizesi şartları misafire bildirilmelidir."},
    {"step": 5, "title": "Gemi İçi Güvenlik Tatbikatı Katılımı", "desc": "Uluslararası SOLAS kuralları gereği seyre çıkmadan önce zorunlu can filikası tatbikatına katılım kuralı açıklanmalıdır."}
  ]'::jsonb,
  'Kruvaziyer gemilerinde pasaport kontrolü liman yetkilileri ve gemi resepsiyonu tarafından müştereken yürütülür. Hamileliğin 24. haftasını aşmış yolcular denizcilik kuralları gereği kabul edilemez.',
  '1. Kruvaziyer Şirketi Temsilcilik Belgesi\n2. TÜRSAB Seyahat Acentası İşletme Belgesi\n3. Uluslararası Paket Tur Sigortası',
  '• Gemi kalkış saatinden en az 3 saat önce liman biniş terminalinde olunmalıdır.\n• Tüm harcamalar gemi kartı (Cruise Card) üzerinden nakitsiz yürütülür.\n• Akşam yemeklerinde ana restoranda şık kıyafet kuralları geçerlidir.'
),
(
  'spa',
  'SPA, Termal Sağlık ve Masaj Terapisi İlan Prosedürü',
  'Sağlık Bakanlığı Kaplıcalar ve Termal Tesisler Yönetmeliği & Masaj Salonları Standartları',
  'Uzman Terapist & Sağlık Kontrolü',
  '[
    {"step": 1, "title": "İşletme İzin Belgesi ve Tesis Onayı", "desc": "Belediye ve İl Sağlık Müdürlüğü onaylı işletme ruhsatı ile hijyen denetim belgeleri girilmelidir."},
    {"step": 2, "title": "Sertifikalı Masör ve Terapist Kadrosu", "desc": "Terapistlerin MEB veya uluslararası federasyon onaylı masaj/uzmanlık diplomaları sisteme işlenmelidir."},
    {"step": 3, "title": "Terapi Seans Süreleri ve Paket Detayı", "desc": "Klasik, Medikal, Bali, Kese-Köpük seans süreleri (45/60/90 dk) ve kullanılan organik yağlar listelenmelidir."},
    {"step": 4, "title": "Terapist Tercihi ve Mahremiyet Esasları", "desc": "Kadın/erkek terapist seçeneği, tekli oda veya çiftler için VIP Suit oda olanakları tanımlanmalıdır."},
    {"step": 5, "title": "Tıbbi Beyan Formu ve İptal Süreci", "desc": "Kalp rahatsızlığı, tansiyon, hamilelik ve ameliyat geçmişi sorgulayan sağlık formu doldurulması kuralı konulmalıdır."}
  ]'::jsonb,
  'Tesis genelinde tek kullanımlık peştamal, terlik ve havlu hijyeni zorunludur. Tıbbi teşhis veya tedavi amacı taşımayan rahatlatıcı ve dinlendirici wellness hizmeti sunulmalıdır.',
  '1. Sıhhi Müessese İşletme Ruhsatı\n2. Terapist Ustalık / MEB Sertifikaları\n3. Tesis Hijyen ve Dezenfeksiyon Karnesi',
  '• Seans başlangıcından en az 15 dakika önce tesiste hazır bulunulmalıdır.\n• Randevu iptalleri en geç 4 saat öncesine kadar ücretsizdir.\n• Islak alanlarda (Sauna, Buhar Odası, Hamam) güvenlik uyarılarına uyulmalıdır.'
),
(
  'beach',
  'Plaj Alanı, Şezlong ve VIP Loca İlan Prosedürü',
  'Kıyı Kanunu Uygulama Yönetmeliği & Belediye Kıyı Tesisleri İşletme Yönergesi',
  'Kıyı İzni & Cankurtaran Güvencesi',
  '[
    {"step": 1, "title": "Kıyı Kullanım ve Plaj İşletme İzni", "desc": "Resmi kıyı tahsis/işletme izin belgesi ve Çevre Bakanlığı deniz suyu analiz raporları kaydedilmelidir."},
    {"step": 2, "title": "TSSF Sertifikalı Cankurtaran Güvencesi", "desc": "Türkiye Sualtı Sporları Federasyonu (TSSF) belgeli gümüş/bronz cankurtaran görevlendirmesi teyit edilmelidir."},
    {"step": 3, "title": "Ünite Tipleri ve Konum Haritası", "desc": "Ön sıra şezlong, iskele daybed, çim alan veya VIP özel cabana/loca kapasiteleri net planlanmalıdır."},
    {"step": 4, "title": "Giriş Saatleri ve Minimum Harcama (Minimum Spend)", "desc": "Giriş saati aralığı (09:00 - 19:00), şezlong dahil hizmetler ve kişi başı harcama limiti şartları açıklanmalıdır."},
    {"step": 5, "title": "Plaj Tesisleri ve Güvenlik Kuralları", "desc": "Duş, soyunma kabini, emanet kasası, vale otopark olanakları ve evcil hayvan/yaş kuralları girilmelidir."}
  ]'::jsonb,
  'Cankurtaran gözetim saatleri (09:00 - 18:30) haricinde denize girmek misafirin kendi sorumluluğundadır. Denizde emniyet şamandıraları ve güvenlik dubaları çekili bulunmalıdır.',
  '1. Kıyı Tesisleri İşletme İzin Belgesi\n2. TSSF Cankurtaran Lisansları\n3. Deniz Suyu Hijyen Analiz Raporu',
  '• Rezervasyonlar saat 11:30''a kadar geçerlidir; gecikmelerde bekleme listesi devreye girer.\n• Dışarıdan yiyecek ve içecek getirilmesi tesis kuralları gereği yasaktır.\n• Deniz taşıtlarının yüzme alanına 200 metreden fazla yaklaşması yasaktır.'
),
(
  'ferry',
  'Deniz Otobüsü ve Feribot Seferi İlan Prosedürü',
  'Denizyolu ile Yapılacak Düzenli Seferler Yönetmeliği & Liman Başkanlığı Sefer İzinleri',
  'Liman İzni & Yolcu Güvenliği',
  '[
    {"step": 1, "title": "Liman Başkanlığı Sefer İzin Tescili", "desc": "Kalkış ve varış liman başkanlıklarınca onaylanmış resmi hat ve sefer çizelgesi kaydedilmelidir."},
    {"step": 2, "title": "Yolcu ve Araç Yükleme Kapasitesi", "desc": "Yaya yolcu koltuk sayısı, motosiklet, binek araç ve hafif ticari araç kapasiteleri girilmelidir."},
    {"step": 3, "title": "Terminal, Biniş Kapısı ve Check-in Süreleri", "desc": "Araçlı yolcular için kalkıştan 45 dk, yayalar için 20 dk önce biniş kapısında olma kuralı belirtilmelidir."},
    {"step": 4, "title": "Araç Tipi Kısıtlamaları ve Yükseklik", "desc": "LPG/CNG''li araç kuralları, tavan bagajı ve azami yükseklik sınırları (azami 2.10 metre) tanımlanmalıdır."},
    {"step": 5, "title": "Hava Muhalefeti ve Sefer İptal Güvencesi", "desc": "Fırtına ve deniz koşulları nedeniyle iptal edilen seferlerde kesintisiz ücret iadesi şartı onaylanmalıdır."}
  ]'::jsonb,
  'Yolcu ve araç manifestoları gemi hareketinden önce liman otomasyonuna aktarılmalıdır. Can yelekleri tüm yolcu kapasitesini kapsayacak adette kolay erişilebilir dolaplarda olmalıdır.',
  '1. Sefer İzin Belgesi ve Hat Tescili\n2. Gemi Denize Elverişlilik Belgesi\n3. Yolcu ve Taşıt Sigorta Poliçesi',
  '• Binişlerde fotoğraflı kimlik kartı veya pasaport ibrazı mecburidir.\n• Gemi seyre başladıktan sonra araç güvertesine inmek can güvenliği açısından yasaktır.\n• Evcil hayvanlar taşıma kafesinde veya belirlenen açık güvertede seyahat edebilir.'
),
(
  'bus',
  'Şehirlerarası Karayolu Otobüs Seferi İlan Prosedürü',
  'Karayolu Taşıma Kanunu ve Yönetmeliği (B1 / D1 Yetki Belgesi) & Ulaştırma Bakanlığı U-ETDS Sistemi',
  'D1 Yetki Belgesi & 2+1 Konfor',
  '[
    {"step": 1, "title": "B1 / D1 Taşıma Yetki Belgesi Doğrulaması", "desc": "Ulaştırma Bakanlığı onaylı karayolu tarifeli yolcu taşıma yetki belgesi ve firma sicili sisteme girilmelidir."},
    {"step": 2, "title": "Otobüs Tipi ve Koltuk Yerleşim Düzeni", "desc": "2+1 Tekli Koltuk veya 2+2 standart oturum planı, koltuk arkası multimedya ekranı ve 220V priz durumu belirtilmelidir."},
    {"step": 3, "title": "U-ETDS Yolcu ve PNR Bildirim Akışı", "desc": "Kesilen her biletin TC kimlik, cinsiyet ve koltuk numarasının anlık olarak U-ETDS sistemine iletimi zorunludur."},
    {"step": 4, "title": "Otogar Peron ve Durak Zaman Çizelgesi", "desc": "Kalkış otogarı peron numarası, güzergahtaki mola tesisleri ve tahmini varış süresi listelenmelidir."},
    {"step": 5, "title": "Bagaj Hakkı ve İade/Açığa Alma Koşulları", "desc": "Bilet başına 30 kg ücretsiz bagaj hakkı ve sefere 12 saat kalaya kadar kesintisiz iade kuralı girilmelidir."}
  ]'::jsonb,
  'Kaptan şoförlerin yasal takograf sürüş sürelerine (azami 4.5 saat kesintisiz, 9 saat günlük) ve dinlenme molalarına titizlikle uyulması kanuni gerekliliktir.',
  '1. Ulaştırma Bakanlığı D1 Yetki Belgesi\n2. Araç Zorunlu Koltuk Ferdi Kaza Sigortası\n3. Karayolu Motorlu Taşıt Mali Sorumluluk Sigortası\n4. Kaptan SRC ve Psikoteknik Belgeleri',
  '• Sefer kalkış saatinden 20 dakika önce otogar peronunda hazır bulunulmalıdır.\n• Bagaj tesliminde numaralı bagaj fişi alınması ve muhafaza edilmesi gerekir.\n• Otobüs içinde sesli müzik dinlenmesi ve koridorda ayakta durulması yasaktır.'
),
(
  'event',
  'Konser, Festival ve Sahne Sanatları İlan Prosedürü',
  'Fikir ve Sanat Eserleri Kanunu (Telif Hakları), Mülki İdare Etkinlik İzinleri & Biletleme ve Katma Değer Vergisi Mevzuatı',
  'Mülki İdare İzni & Barkodlu Bilet',
  '[
    {"step": 1, "title": "Valilik / Kaymakamlık Etkinlik İzin Tescili", "desc": "İlgili mülki idare amirliğinden alınmış resmi etkinlik izin yazısı ve mekân tahsis sözleşmesi girilmelidir."},
    {"step": 2, "title": "Kategori ve Numaralı/Ayakta Krokisi", "desc": "Sahne önü (Golden Circle), VIP Loca, Tribün ve Genel Giriş ayakta kapasiteleri net krokilerle tanımlanmalıdır."},
    {"step": 3, "title": "Yaş Sınırı ve Güvenlik Protokolü", "desc": "18 yaş sınırı, ebeveyn refakati kuralı, emniyet özel güvenlik görevlendirmesi ve ambulans noktaları belirtilmelidir."},
    {"step": 4, "title": "Kapı Açılış ve Bilet Kontrol Sistemi", "desc": "Kapı açılış saati, turnike QR/Barkod okuma sistemi ve biletsiz/sahte bilet koruması tanımlanmalıdır."},
    {"step": 5, "title": "Mücbir Sebep ve Etkinlik İptal Prosedürü", "desc": "Hava muhalefeti veya sanatçı rahatsızlığı hallerinde erteleme tarihi veya bilet bedeli iade şartları girilmelidir."}
  ]'::jsonb,
  'Etkinlik alanına profesyonel ses/görüntü kayıt cihazı, kesici delici alet ve dışarıdan yiyecek-içecek sokulması güvenlik sebebiyle yasaktır. Girişte kimlik doğrulaması zorunludur.',
  '1. Mülki İdare Etkinlik İzin Yazısı\n2. Mekân Tahsis ve Güvenlik Sözleşmesi\n3. Telif Hakları Meslek Birlikleri (MESAM/MSG) İzin Belgesi',
  '• Biletler tek kişiliktir ve barkod okutulduktan sonra alandan çıkan katılımcı tekrar içeri alınmaz.\n• Etkinlik alanında desibel sınırları mevzuata uygun tutulur; işitme hassasiyeti olanlar uyarılır.\n• Satılan biletlerin iptali ancak etkinliğin iptal edilmesi durumunda mümkündür.'
),
(
  'cinema',
  'Sinema Salonu ve Seans Rezervasyon İlan Prosedürü',
  '5224 Sayılı Sinema Filmlerinin Değerlendirilmesi ve Sınıflandırılması Hakkında Kanun & Belediye Sinema Salon Ruhsatı',
  'Bakanlık Yaş Sınıflandırması',
  '[
    {"step": 1, "title": "Sinema İşletme Ruhsatı ve Yangın Raporu", "desc": "Belediye sinema işletme ruhsatı, acil çıkış tahliye sistemi ve itfaiye yangın uygunluk raporu girilmelidir."},
    {"step": 2, "title": "Kültür Bakanlığı Yaş ve İçerik İşaretleri", "desc": "Filmin Bakanlık onaylı yaş sınıfı (Genel İzleyici, 6+, 10+, 13+, 16+, 18+) ve şiddet/korku piktogramları belirtilmelidir."},
    {"step": 3, "title": "Salon ve Ses/Görüntü Teknolojisi", "desc": "Salon numarası, 2D/3D projeksiyon türü, Dolby Atmos ses sistemi ve koltuk düzeni krokisi sisteme işlenmelidir."},
    {"step": 4, "title": "Seans Saatleri ve Reklam Süresi Tanımı", "desc": "Seans başlangıç saati, film net süresi ve 10 dakikalık ara süresi şeffaf şekilde listelenmelidir."},
    {"step": 5, "title": "İptal ve Seans Değişikliği Koşulları", "desc": "Seans başlamadan en geç 60 dakika öncesine kadar online bilet iptal ve kupona çevirme kuralı girilmelidir."}
  ]'::jsonb,
  'Yaş sınıflandırması gereği yaş sınırına uymayan misafirlerin velileriyle dahi salona girişi kanunen yasaktır. Salon içerisinde kamera veya telefonla kayıt yapılması telif hakları ihlalidir.',
  '1. Belediye Sinema Salonu Açma Ruhsatı\n2. İtfaiye Yangın Tahliye Uygunluk Raporu\n3. Eser Sınıflandırma ve Dağıtımcı Belgesi',
  '• Numaralı biletlerde seçilen koltuğa oturulması zorunludur.\n• 3D gözlükler seans girişinde temin edilir ve çıkışta teslim edilir.\n• Seans başladıktan 15 dakika sonra salona misafir kabul edilmez.'
),
(
  'package',
  'Uçak + Otel + Transfer Dinamik Tatil Paketi Prosedürü',
  'Paket Tur Sözleşmeleri Yönetmeliği, 1618 Sayılı Kanun & TÜRSAB Paket Tur Zorunlu Sigorta Standartları',
  'Kapsamlı Güvence & Tek Fiyat',
  '[
    {"step": 1, "title": "Paket Tur Düzenleme Yetki Belgesi", "desc": "TÜRSAB A Grubu seyahat acentası paket tur teminat sözleşmesi ve acenta lisansı doğrulanmalıdır."},
    {"step": 2, "title": "Bileşenlerin Anlık Senkronizasyonu", "desc": "Uçak bileti (PNR), otel oda blokajı ve VIP transfer aracının eşzamanlı anlık onay mekanizması kurulmalıdır."},
    {"step": 3, "title": "Şeffaf Tek Fiyat ve Dahil Olan Hizmetler", "desc": "Uçak vergileri, konaklama vergisi, transfer bedeli ve otel yeme-içme konsepti dahil net tutar ilan edilmelidir."},
    {"step": 4, "title": "Paket Tur Bilgilendirme ve Sözleşme Formu", "desc": "Seyahat başlangıcından önce misafire iletilecek 16 maddelik standart Paket Tur Sözleşmesi bağlanmalıdır."},
    {"step": 5, "title": "Kombine İptal ve Değişiklik Baremleri", "desc": "Havayolu bilet kuralları ve otel ceza sürelerinin harmanlandığı şeffaf paket tur iptal cetveli sunulmalıdır."}
  ]'::jsonb,
  'Paket tur sözleşmesinde yer alan herhangi bir bileşenin acenta tarafından değiştirilmesi halinde emsal veya daha üst kalitede alternatif sağlanması zorunludur. Paket tur sigortası tüm katılımcılara sunulmalıdır.',
  '1. TÜRSAB A Grubu Seyahat Acentası Belgesi\n2. Zorunlu Paket Tur Sigorta Poliçesi\n3. Havayolu ve Otel Tedarikçi Sözleşmeleri',
  '• Paket turun tüm voucher belgeleri (Uçak, Otel, Transfer) tek dijital seyahat cüzdanında teslim edilir.\n• Uçuş saatlerindeki havayolu kaynaklı değişikliklerde transfer aracı otomatik revize edilir.\n• İptal taleplerinde havayolu iade edilemeyen bilet kısıtlamaları saklıdır.'
),
(
  'pilgrimage',
  'Hac, Umre ve Kutsal Topraklar Ziyaret İlan Prosedürü',
  'Diyanet İşleri Başkanlığı Hac ve Umre Seyahatleri ile İlgili İşlerin Yürütülmesine Dair Karar & Suudi Arabistan Hac ve Umre Bakanlığı Mevzuatı',
  'Diyanet Yetki Belgeli & Nusuk Entegrasyonu',
  '[
    {"step": 1, "title": "Diyanet İşleri Başkanlığı Acenta İzin Belgesi", "desc": "Diyanet İşleri Başkanlığı Hac ve Umre Komisyonunca tanzim edilmiş cari yıl seyahat düzenleme yetki belgesi girilmelidir."},
    {"step": 2, "title": "Suudi Arabistan Nusuk ve E-Vize Protokolü", "desc": "Nusuk platformu onaylı umre vizesi, Mekke/Medine ibadet randevuları ve sağlık sigortası altyapısı tanımlanmalıdır."},
    {"step": 3, "title": "Mekke ve Medine Otel Yürüme Mesafeleri", "desc": "Otellerin Harem-i Şerif ve Mescid-i Nebevi avlusuna olan mesafeleri (yürüme mesafesi veya servisli) metre bazında net girilmelidir."},
    {"step": 4, "title": "Din Görevlisi, İrşat ve Rehberlik Kadrosu", "desc": "Kafileye eşlik edecek tecrübeli hoca, Diyanet lisanslı din görevlisi ve grup rehberi bilgileri listelenmelidir."},
    {"step": 5, "title": "Kutsal Mekânlar Ziyaret ve İkram Programı", "desc": "Sevr Dağı, Hira Mağarası, Arafat, Müzdelife, Mina, Uhud ve Kuba Mescidi ziyaretleri ile sabah/akşam yemekleri planlanmalıdır."}
  ]'::jsonb,
  'Kutsal topraklara seyahat edecek misafirlerin Suudi Arabistan Krallığı tarafından zorunlu kılınan aşı (Menenjit vb.) ve sağlık kartlarını tamamlaması mecburidir. Diyanet denetim kurallarına eksiksiz uyulmalıdır.',
  '1. Diyanet İşleri Başkanlığı Hac/Umre Yetki Belgesi\n2. Suudi Arabistan Hac Bakanlığı Acente Sözleşmesi\n3. Uluslararası Kapsamlı Seyahat ve Sağlık Sigortası\n4. Diyanet Din Görevlisi Görevlendirme Onayı',
  '• İbadet programı gereği Mekke ve Medine otel giriş-çıkış saatleri kafile uçuşlarına göre koordine edilir.\n• İhram kuralları ve mikat sınırları konusunda rehber hocalar tarafından bilgilendirme yapılır.\n• Zemzem suyu ve kutsal emanetler bagaj kuralları havayolu standartlarına göre uygulanır.'
)
ON CONFLICT (category_code) DO UPDATE SET
  procedure_title = EXCLUDED.procedure_title,
  legal_basis = EXCLUDED.legal_basis,
  badge_text = EXCLUDED.badge_text,
  steps = EXCLUDED.steps,
  guidelines = EXCLUDED.guidelines,
  required_documents = EXCLUDED.required_documents,
  operational_rules = EXCLUDED.operational_rules,
  created_at = now();

-- 5. Helper function to fetch category procedure
CREATE OR REPLACE FUNCTION onboarding.get_category_procedure(p_category text)
RETURNS TABLE(
  procedure_title text,
  legal_basis text,
  badge_text text,
  steps jsonb,
  guidelines text,
  required_documents text,
  operational_rules text
) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT 
    p.procedure_title,
    p.legal_basis,
    p.badge_text,
    p.steps,
    p.guidelines,
    p.required_documents,
    p.operational_rules
  FROM onboarding.category_procedures p
  WHERE p.category_code = p_category
  LIMIT 1;
$$;

-- 6. Helper function to fetch all category procedures
CREATE OR REPLACE FUNCTION onboarding.all_category_procedures()
RETURNS TABLE(
  category_code text,
  category_name text,
  procedure_title text,
  legal_basis text,
  badge_text text,
  steps_count int,
  guidelines text
) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT 
    c.code,
    c.name,
    coalesce(p.procedure_title, c.name || ' İlan Ekleme Prosedürü'),
    coalesce(p.legal_basis, 'İlgili Sektörel Mevzuat ve Standartlar'),
    coalesce(p.badge_text, 'Yasal Prosedür'),
    coalesce(jsonb_array_length(p.steps), 0),
    coalesce(p.guidelines, '')
  FROM onboarding.categories c
  LEFT JOIN onboarding.category_procedures p ON p.category_code = c.code
  WHERE c.active
  ORDER BY c.name;
$$;

-- 7. Grants
GRANT USAGE ON SCHEMA onboarding TO nexus_app;
GRANT SELECT ON onboarding.category_procedures TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.get_category_procedure(text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.all_category_procedures() TO nexus_app;
