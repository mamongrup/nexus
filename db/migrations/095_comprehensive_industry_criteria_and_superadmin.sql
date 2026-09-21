-- 095_comprehensive_industry_criteria_and_superadmin.sql
-- Sektörel Kriter Standartları: ETS Tur, Tatilbudur, Tatil Sepeti, Rezervasyonyap.com.tr, Airbnb ve Booking.com
-- Süper Admin'in yönettiği dinamik ilan kriter havuzu ve kategori şemaları

CREATE OR REPLACE FUNCTION onboarding.seed_industry_criteria_presets()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
  -- =========================================================================
  -- 1. OTEL (HOTEL) - ETS, Tatilbudur, Tatil Sepeti & Booking.com Benchmark
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('hotel', 'property_type', 'Tesis Türü', 'select', 'Otel,Butik Otel,Tatil Köyü / Resort,Termal & Spa Oteli,Şehir / İş Oteli,Apart Otel,Pansiyon,Dağ Oteli', true, true, 5),
    ('hotel', 'star_rating', 'Yıldız Derecesi', 'select', '5 Yıldızlı,4 Yıldızlı,3 Yıldızlı,Butik / Özel Belgeli,Yıldızsız Konaklama', true, true, 10),
    ('hotel', 'meal_plan', 'Pansiyon & Konsept Türü', 'select', 'Ultra Her Şey Dahil (UAI),Her Şey Dahil (AI),Tam Pansiyon Plus,Yarım Pansiyon (HB),Oda Kahvaltı (BB),Sadece Oda (RO),Alkolsüz Her Şey Dahil (Helal Konsept)', true, true, 15),
    ('hotel', 'beach_distance', 'Denize & Plaja Mesafe', 'select', 'Denize Sıfır,50 - 100 Metre,100 - 300 Metre,300 - 500 Metre,500 Metre Üzeri / Özel Servisli,Denize Mesafeli (Şehir/Doğa)', true, true, 20),
    ('hotel', 'beach_features', 'Plaj Tipi ve Özellikleri', 'select', 'Özel Plaj (Mavi Bayraklı Kum),Kum & Çakıl Karışık Plaj,Ahşap Güneşlenme İskelesi,Platform / Kayalık Plaj,Özel Pavilyon / Loca Hizmeti,Halk Plajına Yakın', false, true, 25),
    ('hotel', 'pool_types', 'Havuz & Su Eğlencesi Olanakları', 'select', 'Açık Yüzme Havuzu + Aquapark (Kaydıraklı),Kapalı Isıtmalı Havuz,Sonsuzluk (Infinity) Havuzu,Termal / Şifalı Su Havuzu,Açık ve Kapalı Havuzlar,Çocuk Havuzlu', false, true, 30),
    ('hotel', 'concept_themes', 'Öne Çıkan Konsept & Tema', 'select', 'Aile ve Çocuk Dostu Otel,Balayı Oteli (Özel İkramlı),Yetişkin Oteli (Adult Only +16),Spa & Termal Sağlık Oteli,Doğa ve Dağ Tatili,Deniz & Güneş Resort', false, true, 35),
    ('hotel', 'spa_wellness', 'Spa, Hamam & Sağlık Olanakları', 'select', 'Tam Donanımlı Spa (Hamam, Sauna, Masaj, Buhar Odası),Türk Hamamı & Sauna Mevcut,Sadece Masaj Odası,Termal Kür Merkezi,Fitness / Spor Salonu Mevcut,Spa Bulunmuyor', false, true, 40),
    ('hotel', 'room_type_detail', 'Oda Kategorisi', 'select', 'Standart Oda,Deluxe Oda,Aile Odası (Bağlantılı),Junior Suit,Jakuzili Balayı Suiti,Deniz Manzaralı Oda,Doğa Manzaralı Oda', true, true, 45),
    ('hotel', 'bed_setup', 'Yatak Kombinasyonu', 'select', '1 Çift Kişilik (French/Double) Yatak,2 Tek Kişilik (Twin) Yatak,1 Çift + 1 Tek Kişilik Yatak,Aile Odası (2 Çift + 1 Tek Kişilik),King Size Yatak', true, true, 50),
    ('hotel', 'room_size_sqm', 'Oda Büyüklüğü (m²)', 'number', '', false, true, 55),
    ('hotel', 'room_amenities', 'Oda İçi Donanım & Konfor', 'text', '', false, true, 60),
    ('hotel', 'child_policy', 'Çocuk ve Bebek Politikası', 'select', '0-6 Yaş 1. Çocuk Ücretsiz,0-12 Yaş 1. Çocuk Ücretsiz,Mini Club ve Çocuk Animasyonu Var,Bebek Dostu (Mama Sandalyesi, Yatak, Isıtıcı),Adult Only (+16 Yaş Sınırı)', true, true, 65),
    ('hotel', 'dining_options', 'Yeme & İçme Olanakları', 'select', 'Ana Açık Büfe Restoran + A La Carte Restoranlar,Ana Restoran Açık Büfe,A La Carte Restoran,Snack Bar & Pastane,24 Saat Oda Servisi', false, true, 70),
    ('hotel', 'pet_policy', 'Evcil Hayvan Politikası', 'select', 'Evcil Hayvan Kabul Edilmez,Küçük Irk Evcil Hayvan Kabul Edilir (max 5 kg),Kedi ve Köpek Kabul Edilir (Ücretsiz),Kedi ve Köpek Kabul Edilir (Ücretli)', false, true, 75),
    ('hotel', 'accessible_features', 'Engelli ve Erişilebilirlik Durumu', 'select', 'Tekerlekli Sandalye Rampası & Engelli Odası Mevcut,Asansör ve Düz Ayak Giriş Mevcut,Engelliye Uygun Değildir', false, true, 80),
    ('hotel', 'cancellation_policy', 'İptal ve İade Şartları', 'select', 'Girişe 3 Gün Kalana Kadar %100 Kesintisiz İptal,Girişe 7 Gün Kalana Kadar Ücretsiz İptal,Girişe 14 Gün Kalana Kadar Ücretsiz İptal,İadesiz İndirimli Fiyat (Non-Refundable)', true, true, 85),
    ('hotel', 'reception_hours', 'Resepsiyon Hizmeti', 'select', '7/24 Kesintisiz Resepsiyon & Güvenlik,08:00 - 00:00 Saatleri Arası Açık,Esnek / Anahtarlık Teslimi', true, true, 90),
    ('hotel', 'ministry_license_no', 'Turizm İşletme Belge No (Bakanlık Ruhsatı)', 'text', '', true, true, 95),
    ('hotel', 'tax_included', 'Vergi ve Harç Durumu', 'select', 'KDV ve %2 Konaklama Vergisi Fiyata Dahildir,Vergiler Girişte İlave Olarak Tahsil Edilir', true, true, 100)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 2. TATİL EVİ & VİLLA (VILLA) - Airbnb & Booking.com Benchmark
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('villa', 'place_type', 'Konaklama Mülk Türü', 'select', 'Müstakil Lüks Villa,Muhafazakar Korunaklı Villa,Geleneksel Taş Konak,Dağ Evi & Chalet,Doğa İçi Ahşap Bungalov,Tiny House (Küçük Ev),Glamping & Kubbe Çadır,Rezidans Daire,Apart Daire', true, true, 5),
    ('villa', 'bedrooms', 'Yatak Odası Sayısı', 'number', '', true, true, 10),
    ('villa', 'bathrooms', 'Banyo Sayısı', 'number', '', true, true, 15),
    ('villa', 'total_beds', 'Toplam Yatak Sayısı', 'number', '', true, true, 20),
    ('villa', 'max_guests', 'Maksimum Misafir Kapasitesi', 'number', '', true, true, 25),
    ('villa', 'pool_type', 'Havuz Türü ve İzolasyonu', 'select', 'Tam Korunaklı (Dışarıdan Görünmeyen Muhafazakar Havuz),Özel Açık Yüzme Havuzu,Özel Isıtmalı ve Jakuzili Havuz,Kapalı Isıtmalı İç Havuz,Ortak Kullanım Havuz,Havuz Bulunmuyor', true, true, 30),
    ('villa', 'indoor_luxury', 'İç Mekan ve Lüks Özellikler', 'select', 'Yatak Odasında Jakuzi Mevcut,Salon Şöminesi (Odunlu/Bioethanol),Sauna ve Türk Hamamı Mevcut,Jakuzi + Şömine + Yerden Isıtma,Klima (Tüm Odalarda Bağımsız)', false, true, 35),
    ('villa', 'outdoor_features', 'Bahçe ve Dış Mekan Olanakları', 'select', 'Geniş Çim Bahçe + Taş Barbekü / Mangal,Veranda + Kamelya + Hamak,Özel Çocuk Oyun Parkı + Salıncak,Ateş Çukuru & Oturma Alanı,Deniz veya Doğa Manzaralı Teras', false, true, 40),
    ('villa', 'kitchen_equipment', 'Mutfak Donanımı ve Gereçleri', 'select', 'Tam Donanımlı Ankastre (Bulaşık Makinesi, Fırın, Mikrodalga, Filtre Kahve),Temel Mutfak Donanımı Mevcut,Bulaşık Makinesi ve Fırın Mevcut,Kapsül Kahve Makinesi & Tost Makinesi', false, true, 45),
    ('villa', 'connectivity_work', 'İnternet ve Çalışma İmkânı', 'select', 'Yüksek Hızlı Fiber Wi-Fi (50+ Mbps) & Çalışma Masası,Standart Wi-Fi Bağlantısı,Wi-Fi ve Akıllı TV (Netflix/Youtube),İnternet Bağlantısı Bulunmuyor', false, true, 50),
    ('villa', 'checkin_method', 'Giriş Yöntemi (Check-In)', 'select', 'Akıllı Şifreli Kilit (Self Check-in / Temassız),Keybox (Şifreli Anahtar Kutusu),Karşılama Görevlisi ile Yüz Yüze Giriş', true, true, 55),
    ('villa', 'checkin_window', 'Giriş Saati Aralığı', 'select', '16:00 ve Sonrası,15:00 ve Sonrası,14:00 ve Sonrası,7/24 Esnek Giriş', true, true, 60),
    ('villa', 'checkout_window', 'Çıkış Saati Sınırı', 'select', 'En geç 10:00,En geç 11:00,En geç 12:00', true, true, 65),
    ('villa', 'house_rules', 'Ev Kuralları ve İzinler', 'select', 'Parti ve Etkinlik Yasaktır (Sessizlik Kuralları),Aile ve Çift Konaklamasına Uygundur,Sadece Belirlenen Kişi Sayısı Konaklayabilir,Sigara Yalnızca Dış Alanda İçilebilir', true, true, 70),
    ('villa', 'safety_features', 'Güvenlik Donanımı', 'select', 'Dış Alan Güvenlik Kamerası + Duman Dedektörü + İlk Yardım,Alarm Sistemi + Yangın Söndürme Tüpü,Duman Dedektörü ve İlk Yardım Çantası', false, true, 75),
    ('villa', 'cleaning_fee_minor', 'Temizlik Ücreti Durumu', 'select', 'Tüm Konaklamalarda Fiyata Dahil,7 Gece Altı Konaklamalarda Ek Temizlik Ücreti Alınır,Sabit Giriş Temizlik Ücreti Uygulanır', false, true, 80),
    ('villa', 'deposit_minor', 'Hasar Depozitosu Politikası', 'select', 'Girişte Nakit Alınır Çıkışta Kontrol Edilip İade Edilir,Kredi Kartı Provizyon Blokesi Alınır,Depozito Talep Edilmez', false, true, 85),
    ('villa', 'ministry_permit_no', '7464 Sayılı İzin Belgesi No (Bakanlık Tescili)', 'text', '', true, true, 90),
    ('villa', 'qrcode_plaque_no', 'Karekodlu Konut Giriş Plaket Numarası', 'text', '', true, true, 95)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 3. TUR VE GEZİ (TOUR) - Tatil Sepeti, ETS, Tatilbudur & Acente2 Benchmark
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('tour', 'tour_type', 'Tur Kategorisi ve Konsepti', 'select', 'Kültür Turu,Mavi Yolculuk & Tekne Turu,Doğa ve Trekking Yürüyüşü,Gurme & Gastronomi Turu,Günübirlik Hafta Sonu Gezisi,Fotoğraf & Macera Safari Turu,İnanç & Tarih Gezisi,Yurt Dışı Paket Tur', true, true, 5),
    ('tour', 'duration_text', 'Tur Süresi ve Konaklama', 'select', 'Günübirlik (Gidiş-Dönüş),1 Gece 2 Gün Otel Konaklamalı,2 Gece 3 Gün Otel Konaklamalı,3 Gece 4 Gün Otel Konaklamalı,4 Gece 5 Gün Otel Konaklamalı,7 Gece 8 Gün Tam Hafta Turu', true, true, 10),
    ('tour', 'transportation_mode', 'Ulaşım Aracı ve Konfor', 'select', 'Lüks Turizm Otobüsü (Travego / Tourismo),Tarifeli Uçak Bileti Dahil,VIP Mercedes Sprinter / Minibüs,Hızlı Tren (YHT) Ulaşımlı,Özel Gezi Teknesi ile Ulaşım,Kendi Aracıyla Katılım (Buluşmalı)', true, true, 15),
    ('tour', 'departure_point', 'Kalkış / Buluşma Noktaları', 'text', '', true, true, 20),
    ('tour', 'hotel_pickup', 'Otelden Alma (Pickup) Hizmeti', 'select', 'Belirlenen Durak Noktalarından Kalkış,Otelden Çift Yönlü Ücretsiz Transfer Dahil,Havalimanı Karşılama ve Transfer Dahil', true, true, 25),
    ('tour', 'guide_languages', 'Rehberlik Hizmeti ve Dilleri', 'select', 'Profesyonel Kokartlı Bakanlık Rehberi (Türkçe),Çok Dilli Rehber (Türkçe & İngilizce),Bölge Uzmanı Yerel Rehber,Audio Guide (Kulaklık Sistemi Dahil)', true, true, 30),
    ('tour', 'included_services', 'Fiyata Dahil Olan Hizmetler', 'text', '', false, true, 35),
    ('tour', 'excluded_services', 'Fiyata Dahil Olmayan Hizmetler', 'text', '', false, true, 40),
    ('tour', 'museum_entrance', 'Müze ve Örenyeri Girişleri', 'select', 'Tüm Müze ve Örenyeri Giriş Biletleri Dahildir,Müze Kart Geçerlidir / Misafire Aittir,Milli Park ve Özel Girişler Dahildir', false, true, 45),
    ('tour', 'included_meals', 'Fiyata Dahil Yemekler', 'select', 'Tüm Sabah Kahvaltıları ve Akşam Yemekleri Dahil,Sadece Sabah Kahvaltıları Dahil,Öğle Yemekleri Dahil,Tüm Öğünler Dahil (Tam Pansiyon Tur),Yemekler Ekstradır', false, true, 50),
    ('tour', 'difficulty_level', 'Fiziksel Zorluk Seviyesi', 'select', 'Kolay (Her Yaşa ve Aileye Uygun),Orta (Hafif Yokuş ve Şehir Yürüyüşleri),Zor (Uzun Parkur / Efor Gerektiren Doğa Yürüyüşü)', true, true, 55),
    ('tour', 'guaranteed_departure', 'Kesin Hareket Garantisi', 'select', 'Kesin Hareketli (Kontenjana Bakılmaksızın Kalkar),Minimum 15 Kişi ile Kesinleşir,Minimum 25 Kişi ile Kesinleşir', false, true, 60),
    ('tour', 'cancellation_hours', 'İptal ve İade Penceresi', 'select', 'Kalkışa 72 Saate Kadar %100 Kesintisiz İade,Kalkışa 7 Gün Kalana Kadar İptal Güvencesi,Kalkışa 15 Gün Kalana Kadar Kesintisiz İptal,Son 72 Saatte İptal Edilemez', true, true, 65),
    ('tour', 'tursab_licence_no', 'TÜRSAB Belge Numarası (A Grubu Acente Ruhsatı)', 'text', '', true, true, 70)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 4. AKTİVİTE & MACERA (ACTIVITY) - Rezervasyonyap, Airbnb Exp & GetYourGuide
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('activity', 'activity_category', 'Aktivite ve Macera Türü', 'select', 'Kapadokya Sıcak Hava Balonu,Yamaç Paraşütü (Tandem Paragliding),Köprülü Kanyon Rafting,Tüplü Dalış (Scuba Diving),ATV / Quad Safari,Jeep / Buggy Safari,Zipline ve Macera Parkuru,At Safari / Binicilik,Kitesurf & Rüzgar Sörfü,Jet Ski & Su Sporları,Tuz Gölü / Doğa Keşfi', true, true, 5),
    ('activity', 'duration_minutes', 'Deneyim Süresi (Dakika)', 'number', '', true, true, 10),
    ('activity', 'hotel_transfer', 'Otel Transfer Hizmeti', 'select', 'Otelden Çift Yönlü Ücretsiz Transfer Dahildir,Belirlenen Buluşma Noktasından Başlar,İsteğe Bağlı Ek Ücretli Transfer', true, true, 15),
    ('activity', 'equipment_included', 'Güvenlik ve Ekipman Durumu', 'select', 'Tüm Güvenlik ve Teknik Ekipmanlar Fiyata Dahildir (Kask, Yelek vb.),Temel Ekipman Dahil / Özel Ekipman Kiralama Opsiyonel,Özel Kıyafet / Ekipman Gerekmemektedir', true, true, 20),
    ('activity', 'photo_video_service', 'Fotoğraf & 4K Video Çekimi', 'select', 'GoPro 4K Aksiyon Videosu ve Fotoğraflar Fiyata Dahildir,Drone ile Özel Çekim Dahildir,Fotoğraf ve Video Paketi İsteğe Bağlı Ek Ücretlidir,Çekim Hizmeti Bulunmuyor', false, true, 25),
    ('activity', 'minimum_age', 'Asgari Yaş Sınırı', 'number', '', false, true, 30),
    ('activity', 'weight_restrictions', 'Ağırlık ve Kilo Sınırı', 'select', 'Maksimum 105 kg Ağırlık Sınırı,Minimum 30 kg / Maksimum 110 kg,Maksimum 120 kg Ağırlık Sınırı,Herhangi Bir Kilo Sınırı Yoktur', false, true, 35),
    ('activity', 'health_requirements', 'Sağlık ve Katılım Kriterleri', 'select', 'Hamileler, Kalp / Tansiyon ve Panik Atak Hastaları Katılamaz,Yüzme Bilme Şartı Aranmaz (Can Yeleği Mecburidir),Her Yaşa ve Fiziksel Kondisyona Uygundur,Temel Düzey Yüzme Bilgisi Gereklidir', true, true, 40),
    ('activity', 'insurance_coverage', 'Sigorta Kapsamı', 'select', 'Tam Kapsamlı Ferdi Kaza & Ekstrem Sporlar Sigortası Dahildir,Üçüncü Şahıs Mali Mesuliyet Sigortası Dahildir,Bakanlık Onaylı Standart Turizm Sigortası', true, true, 45),
    ('activity', 'weather_policy', 'Hava Koşulları ve İptal Güvencesi', 'select', 'Hava Muhalefetinde %100 Kesintisiz İade veya Bir Sonraki Güne Erteleme,Hava Şartlarında Erteleme Hakkı,Uçuş İptalinde 24 Saat İçinde Tam İade', true, true, 50),
    ('activity', 'instructor_certifications', 'Eğitmen ve Pilot Lisansı', 'select', 'THK ve SHGM Onaylı Ticari Tandem Pilotu,PADI / CMAS Bröveli Profesyonel Dalış Eğitmeni,Uluslararası Nehir Federasyonu (IRF) Onaylı Rafting Rehberi,Lisanslı Safari Eğitmeni', true, true, 55),
    ('activity', 'slot_capacity', 'Seans Kontenjan Kapasitesi', 'number', '', true, true, 60),
    ('activity', 'safety_rules', 'Güvenlik Kuralları ve Katılım Protokolü', 'text', '', true, true, 65)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 5. ETKİNLİK & FESTİVAL (EVENT) - Biletix, Passo & Airbnb Experiences
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('event', 'event_category', 'Etkinlik ve Organizasyon Türü', 'select', 'Canlı Müzik Konseri,Açık Hava Festivali,Tiyatro ve Sahne Gösterisi,Stand-Up Komedi,Sanat & Gastronomi Workshop Atölyesi,Doğa Kampı ve Outdoor Buluşması,Spor Müsabakası & Turnuva', true, true, 5),
    ('event', 'venue', 'Mekân ve Salon Bilgisi', 'text', '', true, true, 10),
    ('event', 'organizer', 'Organizatör / Etkinlik Sahibi', 'text', '', true, true, 15),
    ('event', 'event_datetime', 'Etkinlik Tarihi ve Başlama Saati', 'text', '', true, true, 20),
    ('event', 'doors_open_time', 'Kapı Açılış Saati', 'select', 'Etkinlikten 2 Saat Önce Kapılar Açılır,Etkinlikten 1 Saat Önce Kapılar Açılır,Etkinlikten 30 Dakika Önce Kapılar Açılır,Belirlenen Saatte Açılır', false, true, 25),
    ('event', 'seating_type', 'Oturma Düzeni ve Bilet Kategorisi', 'select', 'Numaralı Koltuk Düzeni,VIP Sahne Önü Bistro Masalar,Ayakta Genel Giriş,Kategori 1 / Kategori 2 Tribün,Özel Loca / Balkon Oturumu', true, true, 30),
    ('event', 'age_limit', 'Yaş Sınırı Kuralı', 'select', 'Genel İzleyici Kitlesi (+0),+6 Yaş ve Üzeri Katılabilir,+12 Yaş ve Üzeri Katılabilir,+18 Yaş Sınırı Vardır (Alkol Satış Alanı)', true, true, 35),
    ('event', 'venue_facilities', 'Mekân Olanakları ve Hizmetler', 'select', 'Yeme-İçme Alanları (Food Court) ve Bar Mevcut,Ücretsiz Otopark ve Vale Hizmeti Mevcut,Vestiyer ve Emanet Dolabı Mevcut,Engelli Rampası ve Özel İzleme Alanı Mevcut', false, true, 40),
    ('event', 'ticket_policy', 'Bilet Giriş ve İptal Şartları', 'select', 'QR Kod / Mobil E-Bilet ile Hızlı Giriş (Çıktı Gerekmez),Etkinlik İptalinde Otomatik %100 Para İadesi,Bilet Başkasına Devredilebilir / İsim Değişikliği Mümkündür', true, true, 45),
    ('event', 'recording_rules', 'Kamera ve Kayıt Politikası', 'select', 'Kişisel Cep Telefonu Çekimi Serbesttir,Profesyonel Kamera ve Ses Kayıt Cihazı Kesinlikle Yasaktır,Her Türlü Kayıt Yasaktır', false, true, 50),
    ('event', 'section_capacity', 'Bölüm / Salon Kapasitesi', 'number', '', true, true, 55)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 6. YAT, TEKNE & GULET (YACHT) - Yatvitrini, Viravira & Tatil Sepeti
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('yacht', 'boat_type', 'Tekne & Yat Türü', 'select', 'Lüks Ahşap Gulet (Mavi Yolculuk),Motor Yat,Katamaran,Yelkenli (Monohull),Sürat Teknesi (Günübirlik)', true, true, 5),
    ('yacht', 'boat_length_m', 'Tekne Boyu (Metre)', 'number', '', true, true, 10),
    ('yacht', 'cabin_count', 'Kabin Sayısı', 'number', '', true, true, 15),
    ('yacht', 'crew_included', 'Mürettebat Durumu', 'select', 'Kaptan ve Aşçı Dahildir,Kaptan + Aşçı + Gemici + Hostes Dahildir,Sadece Kaptan Dahildir,Mürettebatsız (Bareboat Kiralama)', true, true, 20),
    ('yacht', 'departure_marina', 'Kalkış Marinası / Liman', 'text', '', true, true, 25),
    ('yacht', 'fuel_policy', 'Yakıt Durumu', 'select', 'Günde 3-4 Saat Seyir Yakıtı Fiyata Dahildir,Yakıt Tüketildiği Kadar Misafire Aittir,Klima Yakıtı Dahildir', true, true, 30),
    ('yacht', 'watersports_gear', 'Su Sporları ve Ekipmanlar', 'select', 'Paddleboard (SUP) + Kano + Şnorkel & Palet Takımları Dahil,Su Kayağı & Ringo Mevcut (Çekici Bot ile),Seabob & Elektrikli Sörf Tahtası Mevcut,Sadece Temel Şnorkel Takımları', false, true, 35),
    ('yacht', 'cruising_routes', 'Öne Çıkan Seyir Rotaları', 'select', 'Göcek Koyları & Fethiye Körfezi,Bodrum & Gökova Körfezi,Marmaris & Hisarönü - Datça,Kaş - Kalkan - Kekova Batık Şehir', false, true, 40)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 7. PLAJ & BEACH CLUB (BEACH) - Tatilbudur & Beach Club Benchmark
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('beach', 'beach_type', 'Plaj ve Kıyı Yapısı', 'select', 'Özel Güneşlenme İskelesi & Platform,İnce Beyaz Kum Plaj,Çakıl ve Berrak Deniz,Doğal Lagün & Çim Güneşlenme Alanı', true, true, 5),
    ('beach', 'sunbed_concept', 'Şezlong, Loca ve Şemsiye Hizmeti', 'select', 'Standart Şezlong + Havlu + Şemsiye Girişe Dahil,Özel VIP Loca / Pavilyon Hizmeti (Meyve & Şampanya İkramlı),Ön Sıra Deniz Kenarı Minder Hizmeti', true, true, 10),
    ('beach', 'food_spend_credit', 'Harcama Limiti (Minimum Spend)', 'select', 'Harcama Limiti Yoktur (Giriş Ücreti Karşılığı Kullanım),Giriş Ücreti Karşılığı 1 Alkolsüz/Alkollü İçecek İkramı,Minimum Harcama Tutarı (Spend Limit) Uygulanır', true, true, 15),
    ('beach', 'music_vibe', 'Müzik ve Eğlence Konsepti', 'select', 'Canlı DJ Performansı & Happy Hour Partileri,Chill-Out / Lounge Sakin Müzik,Akustik Canlı Müzik,Sessiz ve Sakin Dinlenme Alanı (Müziksiz Bölüm)', false, true, 20),
    ('beach', 'water_sports', 'Plaj İçi Su Sporları İmkânı', 'select', 'Jetski, Flyboard, Parasailing ve Ringo Mevcut,Paddleboard (SUP) ve Kano Kiralama Mevcut,Su Sporları Bulunmuyor', false, true, 25)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  -- =========================================================================
  -- 8. ARAÇ KİRALAMA & TRANSFER (CAR & TRANSFER) - RentSyst, Yolcu360, Rentalcars
  -- =========================================================================
  INSERT INTO onboarding.category_fields(category_code, field_code, label, kind, choices, required, active, position) VALUES
    ('car', 'transmission', 'Vites Türü', 'select', 'Otomatik Vites,Manuel Vites,Yarı Otomatik (Tiptronic)', true, true, 5),
    ('car', 'fuel_type', 'Yakıt Türü', 'select', 'Dizel,Benzin,Hibrit (Benzin + Elektrik),%100 Elektrikli (EV)', true, true, 10),
    ('car', 'vehicle_class', 'Araç Sınıfı & Segmenti', 'select', 'Ekonomik (B Segment),Orta Sınıf (C Segment),Lüks Sedan (Mercedes C/E, BMW 3/5),SUV / Crossover (4x4),Geniş Aile & VIP Minibüs (Mercedes Vito / 8+1)', true, true, 15),
    ('car', 'mileage_policy', 'Kilometre Sınırı', 'select', 'Sınırsız Kilometre,Günlük 250 km Sınırı,Günlük 350 km Sınırı,Haftalık 2000 km Paketi', true, true, 20),
    ('car', 'insurance_coverage', 'Kasko ve Güvence Paketi', 'select', 'Muafiyetsiz Tam Kasko (CDW) Dahildir,Standart Trafik ve Kasko (Muafiyetli),Mini Hasar Sigortası + Lastik-Cam-Far (LCF) Dahildir', true, true, 25),
    ('car', 'kabis_verification', 'EGM KABİS ve Kimlik Bildirimi', 'select', 'KABİS Emniyet Bildirimi İçin Kimlik / Ehliyet Zorunludur (Sistem Entegre),Yabancı Pasaport ve Uluslararası Ehliyet ile Teslim', true, true, 30),
    ('car', 'delivery_method', 'Teslimat Şekli', 'select', 'Havalimanı Ofisinden Teslim / İade,Adrese / Otele Vale ile Teslimat,Şehir İçi Merkez Ofis Teslimatı', true, true, 35)
  ON CONFLICT (category_code, field_code) DO UPDATE SET
    label = EXCLUDED.label, kind = EXCLUDED.kind, choices = EXCLUDED.choices, required = EXCLUDED.required, active = EXCLUDED.active, position = EXCLUDED.position;

  RETURN 'ok';
END;
$$;

-- Run preset seed right away
SELECT onboarding.seed_industry_criteria_presets();

-- Operator reset function callable from Super Admin API / UI
CREATE OR REPLACE FUNCTION onboarding.reset_standard_criteria()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
  IF NOT onboarding.operator() THEN
    RETURN 'forbidden';
  END IF;
  RETURN onboarding.seed_industry_criteria_presets();
END;
$$;

GRANT EXECUTE ON FUNCTION onboarding.seed_industry_criteria_presets(), onboarding.reset_standard_criteria() TO nexus_app;
