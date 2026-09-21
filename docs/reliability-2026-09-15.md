# NEXUS güvenilirlik düzeltmeleri — 15 Eylül 2026

## Uygulanan kapsam

- 103 migration: KBS, OTA, WhatsApp, e-fatura ve genel modül çalıştırma uçları gerçek sağlayıcı adaptörü bulunmadığında SQLSTATE 55000 ile, veri yazmadan durur. UUID ve metin sarmalayıcıları test edilir.
- Eski pazaryeri rezervasyon fonksiyonları PNR veya onay üretmez. HTTP satış ucu veritabanına yazmadan 503 döndürür. Rezervasyon kutusu kaldırılmıştır; durum mesajı tr/en/de/ru/zh/fr dillerinde sunulur.
- Gerçek fiyat kaynağı bulunmayan rakip fiyat kıyaslaması ve KBS/WhatsApp garantisi ilan detayından kaldırılmıştır.
- 104 migration: muhasebe fişi rezervasyonun bağlı teklifinden alınan dondurulmuş tutarlarla oluşur. Sabit %88/%3 dağılım kaldırılmıştır. Vergi ayrı satıra yazılır. Eksik, negatif, kesirli, toplamı uyuşmayan veya dövizi farklı snapshot kabul edilmez.
- 105 migration: yerel check-in ve folio işlemleri devam eder; KBS, KABİS/U-ETDS ve WhatsApp kayıtları dış sağlayıcı doğrulaması olmadan `pending` kalır. Sahte TC, dispatch kodu, teslimat veya doğrulama durumu üretilmez.
- 106 migration: dış işlemler için idempotent kuyruk, claim, retry ve terminal durum sözleşmesi eklendi. `provider_reference` yalnız gerçek sağlayıcı yanıtı geldiğinde doldurulmalıdır.
- 107 migration: worker için `SKIP LOCKED` ile tekil claim ve tenant kapsamlı operasyon durum listesi eklendi. Aynı işlem eşzamanlı iki worker tarafından alınamaz.
- 108 migration: yalnızca başarısız işlemler için, en fazla 10 denemeli ve artan beklemeli retry politikası eklendi. Başarılı veya iptal edilmiş işlem yeniden kuyruğa alınamaz.
- 109 migration: NEXUS–Acente için dokuz alanlı, sürümlü `marketplace_listings_v2` sözleşmesi eklendi. Feed artık sağlayıcının gerçek medya JSON'unu taşır; stokta olmayan görsel uydurulmaz.
- 110 migration: CNY (Çin Yuanı) ortak para birimi ve `zh` yereli eklendi; varsayılan para birimi ve ödeme ayarlarının seçeneklerine dahil edildi.
- Muhasebe işlemi aktif kullanıcı ve kendi işletmesi için owner/general_manager/accounting/finance_manager yetkisi ister. Rezervasyon kilidi aynı satışın iki kez muhasebeleştirilmesini önler.
- Önceki kayıtlar yeniden yazılmamıştır. Eski muhasebe dağılımları veya sağlayıcı onayı gibi görünen kayıtlar ayrıca incelenmelidir.

## Doğrulama

 scripts/test.ps1: 13 Gleam testi ve 19 SQL test dosyası başarılı.
Yeni testler: booking_status_test.gleam, external_operation_existing_listing.sql, frozen_quote_ledger.sql, operational_provider_truth.sql, external_operation_queue.sql, external_operation_worker.sql, external_operation_retry.sql, marketplace_feed_v2.sql.
SQL testleri geçici kayıtlarla transaction içinde çalışır ve rollback yapar.
Veritabanı migration öncesi .local altında pg_dump custom formatıyla yedeklenmiştir.

## Henüz tamamlanmayan kritik işler

1. Gerçek pazaryeri satışını mevcut booking/inventory çekirdeğine bağlama: kanal kimliği, tekrar istek anahtarı, dondurulmuş teklif, stok kilidi, doğrulanmış ödeme ve iptal/iade.
2. Yeni normal rezervasyon tekliflerinde ticari dağılım snapshot'ını üretme. Snapshot olmayan eski rezervasyonlar otomatik muhasebeleştirilemez; oran uydurulmaz.
3. Tüm modüllerde sağlayıcı yanıtı denetimi: özellikle 083 ulaşım/KABİS, 084 hızlı giriş/misafir mesajları ve daha sonraki fonksiyonlar. Mevcut testlerdeki “verified” ifadesi dış sağlayıcı doğrulaması değildir.
4. İşletme ve rol yetkilerinin tüm SECURITY DEFINER fonksiyonlarında tekrar doğrulanması; özellikle kullanıcı yönetimi ve bağlam alanları.
5. NEXUS–acente API sözleşmesi: doğrudan DB bağlantısı yerine sürümlü API, cursor, silinme/yayından kalkma olayları, retry ve hata kuyruğu.
6. Yayın kalite kapısı: tr/en/de/ru/zh/fr içerik, semantik HTML, tesis/oda görselleri, yapılandırılmış kurallar. AR ilave dil olabilir, ZH yerine geçmez.
7. ParamPOS, OTA, KBS ve mesaj sağlayıcılarının ayrı sandbox kabul testleri. Ayar ekranı veya kuyruk kaydı işlem başarısı sayılmaz.
8. Git başlangıç geçmişi ve uzak depo, yedekten geri yükleme tatbikatı, CI içinde PostgreSQL testleri, ortam/dağıtım ayırımı.

## Ürün geliştirme sırası

Önce bir villa için tedarikçi → NEXUS → iki pazaryeri ve acente → rezervasyon → stok → muhasebe → iptal zincirini tamamlayın.
Sonra otel oda tipleri, fiyat planları, kontenjan, minimum konaklama ve kanal yönetimini derinleştirin.
Operasyon merkezinde geciken eşitleme, süresi biten opsiyon, tutarsız ödeme ve eksik içerik için sorumlu kişi, tekrar deneme ve denetlenebilir işlem geçmişi sunun.
Performans hedefleri ölçümle belirlensin; yük ve eşzamanlı son-stok testleri olmadan üstünlük veya sıfır çifte rezervasyon iddiası verilmesin.

Bu paket gerçek ödeme veya dış sağlayıcı entegrasyonu teslimatı değildir; yanlış başarı üretimini engelleyen ve finans doğruluğunu artıran ilk düzeltme paketidir.
