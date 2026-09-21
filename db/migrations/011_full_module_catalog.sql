INSERT INTO cms.pages(slug,title,summary,body) VALUES
 ('modul-kbs','KBS Kimlik Bildirimi','Konaklama bildirim süreçlerini tek akışta yönetin.','Yetkili sağlayıcı bağlantısı, bildirim kuyruğu, gönderim sonucu ve insan kontrolü için çalışma alanı.'),
 ('modul-mobile-checkin','Mobil Kimlik Okur & Check-in','Check-in adımlarını mobil operasyonla yönetin.','Kimlik okuma sağlayıcısı ve check-in durumu için yetkili cihaz akışı.'),
 ('modul-housekeeping','Kat Hizmetleri','Oda durumunu ve görevleri ekiplerle eşleştirin.','Temizlik, bakım, hazır oda ve görev önceliklerini izleyin.'),
 ('modul-crm','Sadakat ve CRM Yönetimi','Misafir ilişkisini ve tekrar satışı yönetin.','Segment, izin, iletişim geçmişi ve sadakat akışları.'),
 ('modul-whatsapp','WhatsApp API & Bildirimler','Operasyon bildirimlerini doğru kanala taşıyın.','Şablon onayı, opt-in, gönderim durumu ve teslim takibi.'),
 ('modul-table','Masa & Online Rezervasyon','Masa planı ve rezervasyon talepleri.','Masa kombinasyonu, servis süresi ve no-show politikası.'),
 ('modul-menu','Akıllı Dijital Menü','QR menü ve içerik yönetimi.','Çok dilli ürün, alerjen ve fiyat yayını.'),
 ('modul-spa','SPA ve Spor Salonu Yönetimi','Personel, oda, ekipman ve slot kapasitesi.','Eşzamanlı kapasite ve randevu akışı.'),
 ('modul-banket','Satış ve Banket Yönetimi','Etkinlik, salon ve banket operasyonu.','Teklif, kapasite, menü ve hizmet kalemleri.'),
 ('modul-einvoice','e-Fatura, e-Arşiv, e-İrsaliye','Belge süreçlerine hazırlık.','Yetkili e-belge sağlayıcısı adaptörü ve belge durumu.'),
 ('modul-stock','Stok, Reçete ve Maliyet','Malzeme ve maliyet görünürlüğü.','Stok hareketi, reçete ve maliyet snapshot.'),
 ('modul-purchase','Satın Alma Programı','Tedarik ve satın alma talepleri.','Talep, teklif, sipariş ve teslim alma akışı.'),
 ('modul-bank','Banka Entegrasyonları','Mutabakat için banka hareketleri.','Banka sağlayıcısı bağlantısı ve insan kontrollü eşleştirme.'),
 ('modul-payroll','Personel, Bordro & QR PDKS','Personel operasyonu ve vardiya.','Rol, vardiya, puantaj ve yetkili dış sistem adaptörü.'),
 ('modul-marine','Marina & Yat İşletim Sistemi','Yat, marina ve charter yönetimi.','Tekne, marina, mürettebat ve hazırlık aralığı.'),
 ('modul-tga','TGA Turizm Tanıtım Entegrasyonu','Tanıtım ve içerik bağlantıları.','Yetkili tanıtım kanalı bağlantısı ve içerik onayı.'),
 ('modul-hotspot','Hotspot & 5651 Loglama','Ağ erişimi ve loglama operasyonu.','Yetkili ağ sağlayıcısı adaptörü ve saklama politikası.'),
 ('modul-cloud','Cloud Sunucu & Yedekleme','Operasyon altyapısı ve geri dönüş.','Yedek, restore provası ve gözlemlenebilirlik.'),
 ('modul-flight','Uçak ve Biletleme','Teklif, PNR, biletleme ve iade.','Provider offer/order, fiyat yenileme, biletleme, void/refund ve ek hizmetler.'),
 ('modul-cruise','Cruise Yönetimi','Cruise ürün ve kabin akışı.','Kabin, sefer, yolcu ve sağlayıcı sözleşmesi.'),
 ('modul-hajj','Hac / Umre','Yetkili grup ve belge süreci.','Grup tahsisi, belge ve ülke/ürün koşulları.'),
 ('modul-package','Paket Tur ve Dinamik Paket','Bileşenli ürün yönetimi.','Bileşen rezervasyonu, kısmi başarısızlık ve ayrı iptal kuralları.')
 ON CONFLICT(slug) DO NOTHING;
INSERT INTO onboarding.product_modules(code,family,name,slug,description,page_slug) VALUES
 ('kbs','hotel','KBS Kimlik Bildirimi','modul-kbs','Konaklama bildirim akışı.','modul-kbs'),('mobile-checkin','hotel','Mobil Kimlik Okur & Check-in','modul-mobile-checkin','Mobil check-in.','modul-mobile-checkin'),('housekeeping','hotel','Kat Hizmetleri (Housekeeping)','modul-housekeeping','Oda görevleri.','modul-housekeeping'),('crm','hotel','Sadakat ve CRM Yönetimi','modul-crm','Misafir ilişkileri.','modul-crm'),('whatsapp','hotel','WhatsApp API & Bildirimler','modul-whatsapp','Bildirim ve iletişim.','modul-whatsapp'),
 ('table-reservation','pos','Masa & Online Rezervasyon','modul-table','Masa rezervasyonu.','modul-table'),('digital-menu','pos','Akıllı Dijital Menü (QR Menü)','modul-menu','QR menü.','modul-menu'),('spa-sport','pos','SPA ve Spor Salonu Yönetimi','modul-spa','Slot ve kaynak yönetimi.','modul-spa'),('banquet','pos','Satış ve Banket Yönetimi','modul-banket','Etkinlik ve banket.','modul-banket'),
 ('einvoice','erp','e-Fatura, e-Arşiv, e-İrsaliye','modul-einvoice','E-belge süreçleri.','modul-einvoice'),('stock-cost','erp','Stok, Reçete ve Maliyet','modul-stock','Stok ve maliyet.','modul-stock'),('purchasing','erp','Satın Alma Programı','modul-purchase','Satın alma.','modul-purchase'),('banking','erp','Banka Entegrasyonları','modul-bank','Banka hareketleri.','modul-bank'),('payroll','erp','Personel, Bordro & QR PDKS','modul-payroll','Personel operasyonu.','modul-payroll'),
 ('marine','other','Marina & Yat İşletim Sistemi','modul-marine','Yat ve marina.','modul-marine'),('tga','other','TGA Turizm Tanıtım Entegrasyonu','modul-tga','Tanıtım bağlantısı.','modul-tga'),('hotspot','other','Hotspot & 5651 Loglama','modul-hotspot','Ağ ve log.','modul-hotspot'),('cloud-backup','other','Cloud Sunucu & Yedekleme','modul-cloud','Altyapı ve yedek.','modul-cloud'),('flight','other','Uçak ve Biletleme','modul-flight','Uçuş ve bilet.','modul-flight'),('cruise','other','Cruise Yönetimi','modul-cruise','Cruise ürünleri.','modul-cruise'),('hajj-umrah','other','Hac / Umre','modul-hajj','Yetkili grup süreci.','modul-hajj'),('package-tour','other','Paket Tur ve Dinamik Paket','modul-package','Bileşenli paket.','modul-package')
 ON CONFLICT(code) DO NOTHING;
