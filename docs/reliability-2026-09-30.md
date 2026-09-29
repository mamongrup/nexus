# NEXUS güvenilirlik düzeltmeleri — 30 Eylül 2026

Bu paket, 15 Eylül 2026 paketinin kapsamadığı güvenlik ve doğruluk düzeltmelerini
içerir. Kapsam değişikliklerinin özeti migration 180 ile birlikte aşağıdadır.

## Kapatılan yetki açığı: tedarikçi moderasyonsuz yayınlayabiliyordu

`catalog.guard_supplier_publication_status()` yalnızca tedarikçinin kategori için
**onaylı onboarding başvurusu** olup olmadığını denetliyordu. Platform moderasyonuna
tabi olup olmadığına bakmıyordu. Bu yüzden doğrudan `status` güncellemesi,
`moderation_status` hâlâ `draft` olan bir ilanı yayınlayabiliyor ve 176 ile gelen iki
katmanlı durum makinesi (tedarikçi gönderir → platform onaylar → yayınlanır) atlanıyordu.

Doğrulama: `scripts/smoke.ps1` "supplier cannot publish before approval" adımı, ilk
düzeltmelerden sonra geçiyordu; ancak bu yalnızca fixture'ın medya/SEO alanları eksik
olduğu için farklı bir tetikleyicinin hata vermesi sayesindeydi. Sözleşmeye uygun bir
ilan gönderildiğinde yayınlama **200** ile başarılı oluyordu.

Migration 180 iki koşulu birden zorunlu kılar: kategori onayı **ve**
`moderation_status = 'approved'`. Kapsam değişmez — koruma yalnızca ilanın sahibi
tedarikçi kuruluşu olduğunda çalışır, platform yayınları etkilenmez, ve
`catalog.review_listing()` onayı iki alanı aynı UPDATE içinde yazdığı için gerçek bir
onay yine korumadan geçer.

### Mevcut veri düzeltmesi

Migration öncesi veritabanında platform moderasyonu hiç uygulanmadan yayına alınmış
**5 ilan** vardı (`status='published'`, `moderation_status='draft'`). Bunlar sözleşmeye
aykırıydı ve kamuya açık katalogdaydı. Migration 180 bu kayıtları `draft` durumuna
çekti ve `events.audit` tablosuna `property.unapproved_withdrawn` kaydı yazdı. Onay
verildiğinde yeniden yayınlanabilirler.

## Kalan düzeltmeler

- **`catalog.transition_listing_status` çalışmıyordu.** 176 ile eklenen fonksiyon
  platform aktörünü belirlemek için `core.organizations.platform_role` sütununu
  okuyordu; bu sütun tabloda yok. Fonksiyon her çağrıda `42703: column
  o.platform_role does not exist` ile çöküyordu. Doğrulandı: geçici bir tedarikçi
  kuruluşu ve ilanıyla, içine `EXCEPTION WHEN OTHERS` konulmuş bir `DO` bloğunda
  çağrıldığında hata yakalandı.
  Migration 181 fonksiyonun platform kontrolünü `onboarding.operator()` üzerine
  taşıdı; bu, `catalog.review_listing()` ve `catalog.admin_publish()` fonksiyonlarının
  zaten kullandığı ve çalışan tanımdır. Üç fonksiyon artık aynı yetki kuralını paylaşır.
  `test/listing_status_transition.sql` gönderim, tedarikçi onay reddi, platform onayı ve
  askıya alma geçişlerini doğrular.
- **Askıya alınmış ilan geri alınamıyordu.** 176 `catalog.review_listing()` için
  `draft` kararını hiç tanımlamamıştı; platform bir ilanı askıya aldıktan sonra
  onaylı veya taslak duruma geri getiremiyordu. Migration 182 `draft` kararını ekliyor
  ve yalnızca `moderation_status='suspended'` iken kabul ediyor. Onaylı veya taslak
  bir ilanın durumu keyfî değiştirilemez. `test/review_listing_decisions.sql`
  taslak ve onaylı ilanlar için `invalid_state`, askıya alınmış ilan için `ok`
  döndüğünü doğrular.
- **Tedarikçi başvuru verisi kanonik kategorilerle uyumsuzdu.** `onboarding.applications`
  içinde kanonik 17 kategoriden `visa` için onaylı başvuru yoktu; buna karşılık emekli
  `spa` ve `package` kodları onaylı başvurularda bulunuyordu. Migration 183 `visa`
  başvurusunu ekliyor ve emekli kodları silmek yerine `status='deleted'` yaparak
  denetim izini koruyor. Doğrulama: 17 kanonik kategorinin tamamı onaylı başvuruya
  sahip, emekli kodlar silinmiş durumda. Migration, uygulandıktan sonra bu koşulu
  `DO` bloğu içinde kendisi denetler.
- **Kategori varsayılanı emekli bir koddu.** `POST /admin/listings` kategori
  verilmediğinde `"villa"` yazıyordu. `villa` AGENTS.md'ye göre bağımsız bir ana
  kategori değil (`holiday_home` alt türü) ve `onboarding.categories` içinde pasif
  durumdadır. Tedarikçi onay tetikleyicisi bu kodu reddettiği için kategori seçmeden
  oluşturulan her ilan kaydedilemiyordu (422). Handler artık dosyada zaten var olan
  `category_or_default` yardımcısını kullanıyor; aynı yardımcı fiyat, takvim ve
  müsaitlik komutlarında da kullanılıyordu.
- **Kanal fiyat ucu sahte veri yayımlıyordu.** `GET /api/metasearch/google-hotel-ads.xml`
  sabit kodlanmış fiyat, donmuş zaman damgası ve geçersiz bir tarih penceresiyle 200
  dönüyordu. Artık doğrulanmış tedarikçi fiyatı yayınlanana kadar 503 döner.
- **Hız sınırı başlıkla atlatılabiliyordu.** İstemci kimliği `X-Forwarded-For`'dan
  alınıyordu; başlığı değiştirmek sayacı sıfırlıyordu. Kimlik artık socket peer
  adresinden gelir, yönlendirme başlıkları yalnızca `TRUSTED_PROXY_CIDRS` içindeki
  proxy'lerden geldiğinde ve zincir en dış hoptan içe doğru okunur.
- **Şifreleme anahtarı API kimlik bilgisiydi.** `NEXUS_CONFIG_KEY` acente API
  çağrılarında bearer token olarak kabul ediliyordu; bu, tüm gizli ayarları şifreleyen
  AES-256-GCM ana anahtarıdır. Kimlik doğrulama artık `NEXUS_API_KEY` ile yapılır ve
  sır karşılaştırması sabit zamanlıdır.
- **Bilinen zayıf parolalar.** `admin@nexus.local`, `supplier@nexus.local`,
  `agency@nexus.local` ve `kalite-denetim@nexus.local` hesapları `password123` kullanıyordu;
  48 karakterlik rastgele değerlere döndürüldü. `scripts/rotate-weak-passwords.ps1`
  kalıcı araç olarak eklendi ve zayıf parola kalırsa hata verip durur.
- **CSP karışmış içerik.** `img-src` ve `media-src` içinden `http:` kaynakları kaldırıldı.
- **Acente callback gövdesi** elle string birleştirme yerine JSON encoder ile kuruluyor.
- **PowerShell 5.1 uyumu.** `setup.ps1` içindeki `RandomNumberGenerator::GetBytes(int)`
  yalnızca .NET Core'da bulunduğu için Windows'un kendi PowerShell'inde setup hiç
  çalışmıyordu. Tüm komutlar için `.cmd` sarmalayıcıları eklendi; işletim sistemi yürütme
  ilkesi değiştirilmeden çalışır.
- **Yayın görünürlük sözleşmesi yalnızca yazma tarafında uygulanıyordu.** 180 iki
  katmanlı durum makinesini yazma tarafında zorladı, ancak vitrini, acente kataloğunu
  ve rezervasyon talebini okuyan fonksiyonlar 004/063 döneminden kalma yalnızca
  `status='published'` filtresini kullanıyordu. Bunun iki somut sonucu vardı:
  30 günden eski (bayat) ilanlar hâlâ vitrinde ve acente kataloğunda görünüyordu —
  `catalog.published()` bu kuralı doğru tanımlıyordu ama hiçbir okuma yolundan
  çağrılmıyordu; ve moderasyonu olmayan bir kayıt doğrudan rezervasyon talebine
  dönüşebiliyordu, çünkü yazma koruması yalnızca `kind='supplier'` kuruluşlarını
  denetliyor.

  Migration 184 altı okuma yolunu tek sözleşmeye hizalar: `partners.agency_catalog()`,
  `booking.request_option()`, `catalog.marketplace_listings()`,
  `catalog.marketplace_listing_detail()`, `catalog.marketplace_listings_v2()` ve
  `catalog.marketplace_listings_for_agency()`. Yayınlanabilir ilan artık
  `status='published' AND moderation_status='approved'` olmalı **ve** son 30 gün içinde
  tedarikçi tarafından teyit edilmiş olmalıdır. Bu, `catalog.published()` ile aynı
  tanımdır. Kapsam değişmez: yalnızca okuma, hiçbir mevcut veri değiştirilmez ve
  hiçbir ilan yayından kaldırılmaz.
- **Acente ürün kataloğu hiç görünmüyordu.** `/admin` rotası, acente oturumu için
  NEXUS'e özel `partners.directory()` fonksiyonunu çağırıyordu; o fonksiyon yalnızca
  `auth.workspace()='nexus'` iken satır döndürdüğü için acente her zaman boş tablo
  görüyor ve bağlı olduğu tedarikçilerin ürünlerine hiç ulaşamıyordu. Rota artık
  acente için `partners.agency_catalog()` okuyor; görünüm tarafı zaten bu satır
  biçimini destekliyordu.

## Güncellenen test ve araçlar

- `scripts/smoke.ps1` tek katmanlı yayın akışını varsayıyordu ve sözleşme 1.2.0
  gettikten sonra çalışmıyordu. Test artık gerçek iki katmanlı akışı doğruluyor:
  tedarikçi gönderimi, platform onayı, askıya alma, tazelik teyidi, sürüm çakışması ve
  yetki reddi adımlarıyla birlikte 26 kontrol.
  Yanlışlıkla geçen bir kontrolü önlemek için fixture artık ortak sözleşmenin istediği
  medya, açıklama, SEO ve kategori alanlarını eksiksiz gönderiyor.
- `test/supplier_publication_moderation_guard.sql` yeni korumayı kapsıyor: onaysız
  yayınlama reddediliyor, onaylı ilan yayınlanabiliyor ve kategori onayı geri
  çekildiğinde yeniden yayınlanamıyor.
- `test/listing_status_transition.sql` migration 181 düzeltmesini kapsıyor.
- `test/review_listing_decisions.sql` migration 182'nin askıya alınmış ilanı taslağa
  döndürme kararını ve bu kararın diğer durumlara sızmamasını kapsıyor.
- `test/publication_visibility_contract.sql` migration 184'ü kapsıyor: taslak ilan
  hiçbir vitrinde görünmüyor; yayınlanmış, moderasyonu onaylı ve taze ilan altı okuma
  yolunun hepsinde görünüyor; bayat ilan ve moderasyonsuz yayınlanmış ilan hiçbirinde
  görünmüyor ve rezervasyon opsiyonu talebi alamıyor.
- Yayınlanan tedarikçi ilanı ekleyen altı SQL test fixture'ı, sözleşmeye uygun olması
  için `moderation_status='approved'` ve `last_confirmed_at=now()` ile güncellendi; gerçek
  `catalog.review_listing()` onayı bu iki alanı birlikte yazar.
- `scripts/reservation-smoke.ps1` iki katmanlı moderasyonu kapsıyor: tedarikçi
  gönderimi, platform onayı, tazelik teyidi, askıya alma ve taslağa geri alma ile
  birlikte 45 kontrol. Fixture'a onaylı `onboarding.applications` kaydı ve sözleşmeye
  uygun ilan alanları eklendi.
- `scripts/rotate-weak-passwords.ps1` ve `.cmd` eklendi.

## Doğrulama

- `gleam build`: uyarısız.
- `gleam test`: 24 test, 0 hata.
- `scripts/test.ps1`: format kontrolü + 21 `db/tests` + 10 `test/*.sql` dosyası başarılı.
- `scripts/smoke.ps1`: 26 kontrol başarılı.
- `scripts/reservation-smoke.ps1`: 45 kontrol başarılı.
- Canlı kontroller: hız sınırı atlatması kapalı (15 denemede 429), yeni parola ile
  giriş 303 ve `/admin` 200, eski parola 401, kanal fiyat ucu 503.
- Sözleşme eşitliği: 17 kategori, 78 filtre maddesi, 17 modül uyumlu.

## Hâlâ açık işler

15 Eylül 2026 paketindeki sekiz madde geçerlidir. Bu pakete ek olarak:

1. Yayın kalite kapısı eksik: çok dilli içerik, semantik HTML ve görsel doğrulaması
   hâlâ uygulanmıyor (15 Eylül listesinin 6. maddesi).
2. `catalog.published()` hâlâ hiçbir okuma yolundan çağrılmıyor; aynı sözleşme 184
  ile her okuma fonksiyonuna elle yazıldı. Ortak bir `catalog.is_publishable()`
   yardımcısına taşınması, bir sonraki alanın unutulma riskini kaldırır.
