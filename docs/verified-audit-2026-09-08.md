# PDF ile kod karşılaştırması — 8 Eylül 2026

Sonuç: PDF projesi tamamlanmış değildir. Menü, katalog kaydı, genel işlem düğmesi veya başarı mesajı çalışan modül kanıtı değildir. Bu rapor üretim onayı değildir.

Kaynak: NEXUS_TravelTech_Master_Plan.pdf, özellikle sayfa 6 Supplier OS ve sayfa 7 Agency OS / Marketplace. Mevcut kaynak kod, migration 001–062 ve yerel PostgreSQL testleri incelendi. Alan adlarının canlı dağıtımı doğrulanmadı.

| PDF kapsamı | Kanıt / mevcut durum | Tamamlanması gereken |
|---|---|---|
| NEXUS kurumsal site / CMS | site.gleam, CMS taslak-yayın testleri | Çok dilli gerçek sayfa sunumu ve tüm içerik türlerinin uçtan uca kontrolü |
| rezervasyonyap.com.tr / reservationinturkey.com | marketplace_view.gleam ortak arama ve detay ekranı | Site/kanal ayrımı, kategoriye uygun satış, gerçek ortak rezervasyon çekirdeğine bağlantı ve dağıtım |
| Tedarikçi sitesi / white label | Katalogda ürün bulunması yeterli değil | Alan adı, tema, tenant içerik yönlendirmesi ve satış bağlantısı |
| Business / Organization | Organizasyon, kullanıcı, rol ve başvuru altyapısı | Şube/marka/belge yaşam döngüsü uçtan uca kontrolü |
| Listing Factory | Kategori alanları, CRUD, kalite raporu | URL/medya import, sahiplik doğrulama, AI çıkarımı ve görsel inceleme |
| Inventory / Availability | Günlük envanter ve opsiyon testleri; PMS üniteleri | Koltuk, masa, filo, kabin ve zaman dilimi modellerinin gerçek operasyonları |
| Pricing / Contracts | commercial_engine ve fiyat motoru testi | Bütün kategorilerin fiyat birimleri, kurallar ve sözleşme iş akışları |
| Reservations | Mevcut çekirdekte opsiyon, stok, onay, iptal testleri | Yeni genel pazaryeri formunun çekirdeğe bağlanması, değişiklik/voucher/no-show |
| Operations | Oda durumu değiştirme gerçek DB işlemi | Bakım, görev atama, kaynak planlama ve kategoriye özgü operasyonlar |
| CRM / Reputation / Marketing | Katalog ve genel işlem düğmesi tam modül değil | Profil, segment, sadakat, kampanya, yorum ve yanıt yaşam döngüleri |
| Payments | Ayar altyapısı gerçek tahsilat kanıtı değil | ParamPOS pazaryeri / acente normal hesap için transport, imza, callback, mutabakat, iade |
| Finance | Çift taraflı muhasebe ve dengeli fiş testi mevcut | Gerçek ödeme/rezervasyon bağları, cari, vergi, nakit akışı ve kapanış senaryoları |
| Distribution | OTA ekranı var, gerçek eşitleme yok | Yetkili sağlayıcı adaptörleri, hata/yeniden deneme, webhook, eşleştirme |
| Reports / BI | Digital twin ve bazı rapor altyapısı | Kaynak veriden doğrulanmış kategori/kanal/kâr raporları |
| AI Workforce | Kuyruk/yetki/yönetişim altyapısı | Gerçek model çağrıları, maliyet/token ölçümü, araç yürütümü ve değerlendirmeler |
| 6 dil / 6 para birimi | preferences.js seçimleri localStorage'a kaydediyor | İçeriği gerçekten değiştiren locale çözümleme, çeviri ve fiyat kur dönüşümü |
| İletişim e-postası | Mesaj kaydı ve yönetici kutusu var | SMTP/API teslimatı ve teslimat hatası takibi; kayıt e-posta gönderimi değildir |

## Bu denetimde giderilen hatalar

- 058 migration kodu dış servis çağrısı olmadan EGM kodu, WhatsApp teslimatı ve GİB onayı üretiyordu. 061 bunu kaldırır; işlemler artık yan etki yaratmadan hata verir.
- Genel modül düğmesi yalnızca başarı telemetry kaydı yazıyordu. Gerçek iş yürütmediği için sahte başarı engellendi.
- Yeni pazaryeri rezervasyon fonksiyonu rezervasyon kaydı oluşturmadan PNR döndürüyor, oda durumunu değiştiriyordu. Bu yol artık açıkça rezervasyonun oluşturulmadığını döndürür. Test edilmiş mevcut rezervasyon çekirdeği korunmuştur.
- Yönetici ilan okuma/yayınlama fonksiyonlarına yetki kontrolü eklendi; uygulama çağrıları oturum kapsamında çalışır.
- PMS değişikliği ve ilan modülü okumasına firma, rol, etkin modül ataması kontrolü eklendi. Altı operasyon tablosunda RLS ve doğrudan yazma kısıtlaması uygulandı.
- Panelde entegrasyonların doğrulanmadığı belirtildi. Eski simülasyon kayıtları silinmedi; kanıt olarak kullanılmamalıdır.

## Doğrulama

scripts/test.ps1: 6 Gleam testi ve 8 SQL test dosyası geçti. Yeni testler sahte gönderim/PNR üretimini, anonim yönetici erişimini, atanmış/atanmamış/durdurulmuş PMS yetkisini, farklı firma ve viewer sınırlarını kapsar. Fixture işlemleri geri alınır. Sunucu yeniden başlatıldı; /v1/health database=ready döndürüyor.

Bu testler bütün PDF gereksinimlerinin uygulandığı anlamına gelmez. Yukarıdaki eksikler açık kalmaktadır.
