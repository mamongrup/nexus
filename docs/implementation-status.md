# Uygulama durumu — 7 Eylül 2026

Master blueprint tamamen uygulanmış değildir. Bu dosya çalışan kapsamı ve açık işleri ayırır.

## Doğrulanan yerel kapsam

- Ön yüz NEXUS programını tanıtan kurumsal sitedir; konaklama satış kataloğu değildir.
- NEXUS program yönetimi `/admin`, ayrı site içerik yönetimi `/admin/site`.
- CMS: sayfa oluşturma, başlık/açıklama/metin, taslak önizleme, owner yayını/yayından alma, sürüm kontrolü ve audit. Yeni sayfalar yayınlanınca site navigasyonuna eklenir.
- Kurumsal modül kataloğu: otel, POS, ERP, villa, tur, transfer, yat/marina, restoran, SPA, uçak, hac/umre, paket tur ve altyapı modülleri; NEXUS tarafından tedarikçiye atanabilir ve tedarikçi panelinden görülebilir.
- Departman kataloğu: NEXUS ve tedarikçi için ayrı pazarlama, sosyal medya, AI, muhasebe, SEO, çeviri ve holding/operasyon departmanları; tenant kapsamlı atama ve dizin ekranı.
- CMS çeviri kuyruğu: TR/EN/DE/RU/AR/FR ve TRY/EUR/USD/GBP/CHF/AED seçenekleri; içerik başına tüm dillere çeviri işi kuyruğa alınabilir.
- Çeviri worker sözleşmesi: iş claim, tamamla, hata ve kontrollü retry fonksiyonları; aynı işin iki worker tarafından alınmasını engelleyen `SKIP LOCKED` akışı.
- Tedarikçi AI yönlendirmesi: DeepSeek dahil sağlayıcı seçimi ve görsel, yazı, içerik, SEO alanları için ayrı provider seçimi; aynı provider birden fazla alanda kullanılabilir.
- Tedarikçi çalışma zamanı görünümü: tedarikçi yalnızca kendi AI provider yönlendirmesini okuyabilir; token hiçbir runtime sorgusundan dönmez.
- İlan kategori doğrulamaları: yat/marina, SPA/spor, uçak/bilet, hac/umre ve paket/dinamik paket kategorileri onboarding ve belge gereksinimlerine bağlandı.
- İlan metadata temeli: kategori, SEO alanları, olanaklar, medya ve AI taslakları `catalog.properties` üzerinde tenant kontrollü saklanıyor.
- Yönetici kontrollü kategori alanları: NEXUS tarafından tanımlanan alan kodu, tip, seçenekler, zorunluluk ve sıra bilgisi tedarikçi ilan formuna şema olarak sunuluyor.

## 16 Eylül 2026 doğrulanan eklentiler

- Acente bağlantı isteği akışı: acente panelindeki istek NEXUS'a imzalı anahtarla iletilir; NEXUS sahibi isteği onaylamadan katalog aktarımı açılmaz.
- Acente kapsam politikası: NEXUS sahibi izin verilen kategori listesini ve acente başına ilan üst sınırını belirler; acente feed'i yalnızca yayınlanmış ve izinli kayıtları alır.
- Acente senkronizasyonu: yazma hataları artık sessizce yutulmaz; işlenen ilan sayısı loglanır ve tenant kimliği boşsa senkronizasyon kapalı kalır.
- Dış sağlayıcı doğruluğu: KABİS/U-ETDS/WhatsApp gibi gerçek sağlayıcı cevabı gerektiren işlemler `pending` kalır; testler sahte başarı üretmediğini doğrular.

- Gleam/Wisp/Mist sunucu, Lustre SSR, PostgreSQL, oturum ve CSRF kontrolleri.
- Tedarikçi ilan oluşturma/yayınlama, tarih bazlı fiyat, atomik opsiyon.
- NEXUS partner bağlantısı → acente talebi → tedarikçi onayı → acente kesin rezervasyonu → ödenmemiş rezervasyonun tedarikçi tarafından iptali.
- Tekrar rezervasyon ve iptal güvenliği, donmuş toplam fiyat, opsiyon süresi ve stok iadesi.
- NEXUS sahibi için 36 sistem ayarı; acente sahibi için 7 ayrı POS ayarı.
- NEXUS ParamPOS pazaryeri hesabı, acente ParamPOS standart hesabı ayrı şirket kapsamında saklanır.
- AES-256-GCM ile gizli ayar şifrelemesi; anahtar ve şirket/alan bağlamı doğrulaması; ekranda geri göstermeme; içeriksiz audit; sürüm çakışması kontrolü.

## Henüz tamamlanmayanlar

- ParamPOS ödeme isteği, sağlayıcı doğrulaması, callback, tahsilat/iade, pazaryeri alt üye/hakediş akışı. Ayar kaydı tahsilatı etkinleştirmez.
- Ticari komisyon/markup, iptal politikası/cezası, ledger posting ve mutabakat.
- Diğer ürün kategorilerinin stok ve satış motorları, medya, SEO, canlı döviz ve gerçek AI sağlayıcı adaptörü.
- AI worker/manager/director/GM çalıştırma, tool yetkileri, bütçe uygulanması ve insan onayı.
- SMTP/S3/tedarikçi bağlantısı: ayar alanları var; servis adaptörleri yok.
- MFA, parola sıfırlama, yedek/restore tatbikatı, CI, TLS/deployment, yük ve yarış testlerinin tamamı.

## Kontroller

- `scripts/test.ps1`: Gleam testleri ve rollback kullanan üç SQL test paketi.
- `scripts/smoke.ps1`: ilan/giriş/CSRF HTTP testi.
- `scripts/reservation-smoke.ps1`: geçici üç şirketle ayar güvenliği ve rezervasyon HTTP testi; verilerini temizler.

## Ayar anahtarı

NEXUS_CONFIG_KEY sunucunun `.env` dosyasındadır; yönetici paneline gönderilmez. Veritabanı yedeği ile bu anahtar ayrı ve güvenli şekilde yedeklenmelidir. Anahtar kaybında şifreli değerler çözülemez. Script, şifreli kayıtlar mevcutken otomatik yeni anahtar üretmez. Anahtar rotasyonu henüz uygulanmadı.

## ParamPOS kaynakları

- https://dev.param.com.tr/tr/api/ortak-odeme-iframe
- https://posws.param.com.tr/turkpos.ws/service_turkpos_prod.asmx?op=TP_Modal_Payment
- https://posws.param.com.tr/turkpos.ws/service_turkpos_prod.asmx?op=TP_Islem_Sorgulama4
- https://dev.param.com.tr/tr/pazaryeri

Kullanıcı canlı hesabının ve HTTPS alan adının hazır olduğunu belirtti. Bilgiler yönetici ekranından girilecek; şu ana kadar canlı bağlantı veya tahsilat doğrulanmadı.
