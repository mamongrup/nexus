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
- Yayınlanan tedarikçi ilanı ekleyen altı SQL test fixture'ı, sözleşmeye uygun olması
  için `moderation_status='approved'` ile güncellendi.
- `scripts/rotate-weak-passwords.ps1` ve `.cmd` eklendi.

## Doğrulama

- `gleam build`: uyarısız.
- `gleam test`: 24 test, 0 hata.
- `scripts/test.ps1`: format kontrolü + 21 `db/tests` + 9 `test/*.sql` dosyası başarılı.
- `scripts/smoke.ps1`: 26 kontrol başarılı.
- Canlı kontroller: hız sınırı atlatması kapalı (15 denemede 429), yeni parola ile
  giriş 303 ve `/admin` 200, eski parola 401, kanal fiyat ucu 503.
- Sözleşme eşitliği: 17 kategori, 78 filtre maddesi, 17 modül uyumlu.

## Hâlâ açık işler

15 Eylül 2026 paketindeki sekiz madde geçerlidir. Bu pakete ek olarak:

1. Askıya alınmış ilanı (`suspended`) taslağa döndürme geçişi veritabanında tanımlı,
   ancak HTTP rotası yalnızca `approved`, `changes_requested` ve `suspended`
   kararlarını kabul ediyor. Platform bu geçişi arayüzden yapamıyor.
2. Tedarikçi başvuru verisinde kanonik 17 kategoriden `visa` eksik; `spa` ve `package`
   gibi emekli kodlar hâlâ onaylı başvurularda bulunuyor.
3. `scripts/reservation-smoke.ps1` iki katmanlı moderasyon akışını kapsamıyor.
4. Yayın kalite kapısı eksik: çok dilli içerik, semantik HTML ve görsel doğrulaması
   hâlâ uygulanmıyor (15 Eylül listesinin 6. maddesi).
