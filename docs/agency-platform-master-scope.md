# NEXUS Acente Platformu — Ana Ürün Kapsamı

Bu belge, bağımsız çalışabilen ve isteğe bağlı olarak NEXUS kataloğuna bağlanan kapsamlı acente ürününün ana kapsamıdır.

## Ürün modeli

- Her acente kendi markası, alan adı, logosu, içerikleri ve ayarlarıyla ayrı bir tenant olarak çalışır.
- Acente kendi ilanlarını manuel ekleyebilir veya tedarikçi/API bağlantılarından ürün alabilir.
- NEXUS bağlantısı açılıp kapatılabilir; bağlantı kapalıyken acentenin kendi kataloğu çalışmaya devam eder.
- Yönetici, alt acente, tedarikçi, personel ve müşteri ayrı üyelik tipleridir.
- Yönetici rolleri ve izinleri tenant sınırları içinde uygulanır.

## Kategori motoru

Tatil evi, yat, kara/hava/deniz aracı, transfer, feribot, otel, otobüs, uçak, günlük tur, paket tur, gemi turu, aktivite ve blog kategorileri aynı ilan çekirdeği üzerinde kategoriye özel alan şemalarıyla çalışır.

Her kategori destekler:

- medya galerisi, sıralama, kırpma ve WebP/AVIF türevleri;
- açıklama, özellik, kural, konum, fiyat, müsaitlik, yorum ve iptal politikası;
- dönemsel fiyat, yetişkin/çocuk/bebek fiyatı, komisyon, markup ve ön ödeme;
- kampanya, kupon, paket ve ilgili ürün önerileri;
- manuel kayıt ve yetkili API kaynağı;
- ilan kodu, SEO alanları, filtrelenebilir listeleme ve özel landing page.

## Ticari ve rezervasyon çekirdeği

- Arama yerel okuma modelinden sonuç verir; dış API çağrısı arama isteğini bloklamaz.
- İlan adı, ilan kodu, bölge, kategori, alt kategori, kapasite, tarih ve fiyat araması indeksli olur.
- Sepet, opsiyon, teklif, rezervasyon, ödeme, iptal, iade, voucher ve hakediş durumları ayrı state machine olarak tutulur.
- ParamPOS ödeme tokenizasyonu ve doğrulanmış callback ile bağlanır; kart verisi tutulmaz.
- Cüzdan, hediye çeki, kupon, komisyon ve alt acente payları çift taraflı finans kayıtlarıyla izlenir.

## CMS, pazarlama ve müşteri deneyimi

- Sınırsız dil ve para birimi; kur kaynağı, yüzde düzeltme ve yayınlama geçmişi.
- Header, footer, mega menü, popup, banner, blog, bölge, kategori ve özel filtre sayfası yönetimi.
- SEO başlığı/açıklaması/etiketi, canonical, hreflang, sitemap, robots, 301, 404, breadcrumb, JSON-LD ve Google Analytics.
- Şablonlu sosyal medya paylaşımı; içerik yayınında otomatik paylaşım kuyruğu.
- E-posta, SMS, WhatsApp, canlı destek, favoriler, karşılaştırma, son gezilenler ve sepet hatırlatma.
- Üye doğrulama, profil, rezervasyon geçmişi, cüzdan, hediye çeki ve bildirim merkezi.

## AI işletim sistemi

- AI Worker → Manager → Director → AI GM hiyerarşisi.
- İçerik, çeviri, SEO, medya etiketleme, sosyal paylaşım, fiyat önerisi, talep tahmini, müşteri destek ve anomali tespiti çalışanları.
- Her görev için tenant sınırı, bütçe, günlük kota, tekrar sayısı, araç izinleri ve insan onayı.
- Otonom işlem yalnızca düşük riskli görevlerde; yayın, ödeme, fiyat ve dış sistem işlemleri onaylı.
- Prompt/model sürümü, maliyet, sonuç, hata ve insan kararı audit kaydına girer.

## Uygulama sırası

1. Acente tenant, kullanıcı/rol ve ayar çekirdeği.
2. Kategori şeması, ilan, medya ve hızlı arama modeli.
3. Takvim, fiyat, kampanya, sepet, teklif ve rezervasyon state machine.
4. NEXUS bağlantısı ve sağlayıcı adapter sözleşmesi.
5. Ödeme, cüzdan, komisyon, voucher ve bildirim kuyruğu.
6. CMS, SEO, pazarlama ve müşteri üyelik alanları.
7. AI worker işletim döngüsü ve performans/raporlama.
8. Mobil uygulama API'si ve operasyonel sertleştirme.

## Performans kabulü

- Arama ve rezervasyon sorguları dış sağlayıcı yanıtını beklemez.
- Liste araması ve ilan kodu araması indeksli okuma modelinden döner.
- Müsaitlik doğrulaması rezervasyon adımında atomik kilit ile yapılır.
- Kritik sorgular veri hacmiyle EXPLAIN ANALYZE ve yük testiyle doğrulanır.
