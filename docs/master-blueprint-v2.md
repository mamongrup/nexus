# NEXUS TravelTech
## v2 | Karar, ürün ve uygulama blueprint'i

**Tedarikçiden acenteye, rezervasyondan hakedişe tek güvenilir ticaret akışı.**

7 Eylül 2026 • Türkçe • Hazırlık ve tasarım belgesi

Bu çalışma, sunulan 21 sayfalık NEXUS TravelTech Master Plan v1'in tamamının incelenmesi ve seçilmiş resmî kaynakların yeniden kontrolü üzerine hazırlanmıştır. Belgedeki önceki kararlar değerlendirme girdisidir; doğrulanmış müşteri talebi, mevcut yazılım yeteneği veya otomatik uygulama yetkisi sayılmamıştır.

**Ana öneri:** Büyük platform vizyonunu koru; ilk ürünü dar ve uçtan uca çalışır kur. Villa/tatil evi tedarikçisi ile acentenin teklif, opsiyon, tahsilat, rezervasyon ve hakediş döngüsünü çöz. Aynı çekirdekten B2C ve tedarikçi sitesi üret. Otel, deneyim ve ulaşım motorlarını ancak bu döngü kanıtlandıktan sonra genişlet.

**Bu pakette:** v1 değerlendirmesi, ürün sınırları, ticari model, tüm kategori portföyü, Supplier OS ve Agency OS ekranları, listing, fiyat, opsiyon, ödeme, ledger, PostgreSQL veri sözlüğü, API taslağı, AI organizasyonu, güvenlik, SEO, connectivity, aşamalı roadmap ve kabul testleri bulunur.

**Belgenin statüsü:** Karar almaya ve sprint planlamaya hazır tasarım önerisi. Çalışan yazılım, üretime uygulanabilir migration, eksiksiz OpenAPI dosyası veya hukuki/mali onay değildir. Kritik çekirdeğin kolon ve sözleşme ayrıntıları verilmiştir; sonraki kategori motorları kapsam haritası düzeyindedir.

**Kullanıcının netleştirdiği çalışma modeli:** Geliştirme ekibi yok; kullanıcı ve Codex birlikte çalışacak. Önceden ayrılmış sabit bütçe yok; oluşan gerçek giderler izlenecek. Mevcut kod ve tedarikçi sözleşmeleri henüz paylaşılmadı. Türkiye ve villa/tatil evi başlangıcı tasarım varsayımıdır; mevcut işe göre doğrulanacaktır. Bu sürüm, kullanıcının bu açıklamasına göre ekip ve takvim varsayımları düzeltilerek hazırlanmıştır.

---

## 01 | Yönetici kararı

V1 iyi bir vizyon envanteri; henüz yatırım ve geliştirme sırasını belirleyen bir uygulama şartnamesi değil. Sorun fikir eksikliği değil, aynı anda çok fazla iş modelinin ve envanter davranışının açılması. İlk başarı ölçüsü modül sayısı değil, güvenle tamamlanan ve kârlılığı görülen rezervasyondur.

### Korunacak beş temel

- Supplier OS, Agency OS ve marketplace'in ortak ticaret çekirdeği.
- PostgreSQL, sürümlü fiyat/politika snapshot'ı, çift taraflı kayıt ve denetlenebilir işlemler.
- Ürün içeriği, satılabilir teklif ve müsaitliğin ayrı modellenmesi.
- Sağlayıcı adaptörleri, API sözleşmeleri ve işlem idempotency'si.
- AI'nin yetkilendirilmiş araçlar üzerinden çalışması ve insan müdahalesi.

### Değiştirilecek beş temel

- Kullanıcı + Codex kapasitesine göre tek rezervasyon yolculuğunu tamamlayan küçük dikey teslimatlar.
- Başlangıçta mikroservis yerine modüler monolit; olaylar için transactional outbox.
- Tek genel inventory tablosu yerine ortak sözleşme ve kategoriye özel kapasite motorları.
- Tek ortak mali defter görünümü yerine tüzel kişilik bazında ayrılmış ledger book'ları.
- İlk günden otonom AI yönetimi yerine öneri, kontrollü işlem ve ölçülmüş yetki artışı.

### İlk ürünün vaadi

“Doğru ürün, güncel fiyat, açık opsiyon süresi ve izlenebilir ödeme.” Tedarikçi fiyatını ve takvimini bir kez yönetir; acente kime ne borçlandığını görür; müşteri hangi tutarı hangi koşullarda ödediğini bilir. Her satışın mali ve operasyonel durumu aynı işlem kimliğiyle takip edilir.

**Rekabet tezi:** AI ve birleşik OS söylemi tek başına savunulabilir avantaj değildir. Mews'in 2026 duyurusu da birleşik veri, finans ve AI yönünü anlatmaktadır [R10]. NEXUS'un önerilen avantajı, belirli bir bölgede kaliteli tedarik yoğunluğu, güvenilir müsaitlik ve düşük operasyon yüküyle tekrar rezervasyon üretmesidir. Bu bir stratejik hipotezdir; pilotla sınanmalıdır.

---

## 02 | V1 değerlendirmesi ve düzeltme kaydı

| V1 alanı / sayfa | Değerlendirme | V2 kararı |
|---|---|---|
| Ortak çekirdek, s. 5-6 | Doğru yön; dağıtım sınırı belirsiz | Tek kod tabanı, açık modül sahipliği, DB transaction sınırları |
| Gleam / Lustre, s. 1 | Dil ile arayüz katmanı karışmış | Gleam dil; Lustre UI; sunucu ve DB araçları ayrıca seçilir |
| Kategoriler, s. 4, 20 | Geniş ve yararlı portföy | Pazarlama kategorisi kodsuz; yeni rezervasyon davranışı kod ve test ister |
| Fiyat kuralları, s. 8 | Snapshot güçlü; hesaplama tabanı eksik | Komisyon, net fiyat ve markup ayrı sözleşme tipleri |
| Opsiyon, s. 8 | Ticari akış var; yarış koşulu tanımsız | Talep kapasite tutmaz; onay ve tahsis aynı transaction |
| Finans, s. 9 | Doğru nesneler; hukuki roller belirsiz | Satıcı, tahsil eden, fatura kesen, hakediş alıcısı ayrı |
| Çoklu dil / SEO, s. 10 | Dil kodsuz URL mümkün | Site çapında rota tekilliği, hreflang, sabit slug ve yayın kapısı |
| Connectivity, s. 10-11 | Adaptör yönü doğru | Supply dağıtımı ve demand tedariği ayrılır; erişim kapıları eklenir |
| AI, s. 11-12, 21 | Yetki sınırları iyi başlangıç | Araç sözleşmesi, onay hash'i, bütçe, tekrar güvenliği ve kill switch |
| Tenant, s. 14 | organization_id tek başına yetersiz | Owner tenant, işlem tarafları ve alan bazlı görünürlük ayrılır |
| Roadmap, s. 16 | Fazlar ilk geliri gereksiz geciktirebilir | Kullanıcı + Codex için tarih değil çalışan çıktı ve kabul kapısı |
| “Undo”, s. 20-21 | Finans ve dış işlemlerde yanıltıcı | İçerikte sürüm geri alma; finans ve rezervasyonda telafi işlemi |

**Önemli nüans:** Merkezi veritabanı, dış kanallardaki çift rezervasyonu tek başına önlemez. Dış sistemin gecikmesi, mapping hatası veya başka satış kanalı aynı stoğu tüketebilir. Garanti yalnızca NEXUS'un otorite olduğu envanter ve atomik tahsis sınırı için verilir.

**Sunum düzeltmesi:** V1'de bazı mimari kutular ve oklar okunmayı zorlaştırıyor. Bu sürüm, mimariyi karar ve işlem sınırlarıyla açıklar; geniş özellik listesini faz ve bağımlılıklarla ilişkilendirir.

---

## 03 | İlk pazar, dağıtım ve gelir modeli

### Başlangıç hipotezi

İlk dikey villa/tatil evi olsun. Birim/gece envanteri, acente opsiyonu ve doğrudan satış aynı örnekte denenebilir. İlk bölge mevcut tedarik ilişkilerinin en yoğun olduğu yerden seçilir; Fethiye/Kalkan gibi bir bölge yalnızca adaydır. Mevcut iş ağı bilinmediği için kesin şehir kararı verilmez.

İlk kontrollü pilot hedef önerisi: 1 tedarikçi, 3-5 doğrulanmış ve takvimi sahiplenilmiş birim, 1 acente. Sonraki doğrulama hedefi 5 tedarikçi ve 3 acentedir. İlk tedarikçi/acente gerçek takvim ve teklif akışını kullanmayı kabul etmezse kapsamdan önce değer önerisi revize edilir. Sayılar pazar verisi değil, kullanıcı + Codex çalışma kapasitesine uygun deney tasarımıdır.

| Paket | İlk ücretlendirme yaklaşımı | Sınır |
|---|---|---|
| Supplier Starter | Temel panel ve standart alt alan adı; satış bazlı gelir | AI kullanım kotası, standart destek |
| Supplier Pro | Aylık abonelik; özel alan adı, toplu işlem, rapor | Özel tasarım ayrı hizmet |
| Agency | Başlangıçta düşük giriş bariyeri; kontrat bazlı işlem geliri | Markup ve NEXUS hizmet bedeli ayrı gösterilir |
| API / white-label | Kurulum + kullanım / minimum hacim | Pilot sonrası; SLA ve erişim sözleşmeli |

Komisyon yüzdeleri bu aşamada ilan edilmez. Tedarikçi maliyeti, acente payı, PSP bedeli, destek ve iptal maliyeti ölçülmeden “en düşük komisyon” vaadi sürdürülebilir değildir. Ücretsiz site, edinim aracıdır; sınırsız depolama, çeviri ve özel destek taahhüdü değildir.

### Pazara giriş sırası

1. Tedarikçi takvimi ve fiyatı doğrulanır; acente gerçek teklif üretir.
2. Tedarikçi kendi kitlesini standart siteye getirir; ilk rezervasyonlar gözlemlenir.
3. Aynı katalogdan B2C marketplace açılır; ücretli trafik kontrollü başlatılır.
4. Bölgesel arz ve dönüşüm kanıtlanınca ikinci bölge veya kategori eklenir.

Her kohortta 30/60/90 gün tedarikçi aktivasyonu, acente tekrarı ve rezervasyon katkısı izlenir. Trafik ve ilan sayısı tek başına büyüme başarısı sayılmaz.

---

## 04 | Tam ürün evreni ve açılış sırası

Ortak yapı: **Catalog → Offer → Order → Reservation → Fulfillment → Finance**. Kategoriler aynı ticari omurgayı kullanır, fakat aynı kapasite algoritmasını kullanmak zorunda değildir.

| Dalga | Kategoriler | Envanter / özel gereksinim |
|---|---|---|
| A: ilk pilot | Villa, tatil evi | Tek birim/gece, minimum konaklama, giriş-çıkış, temizlik aralığı |
| B: kanıt sonrası | Otel | Oda tipi/gece havuzu, yetişkin/çocuk, rate plan, CTA/CTD, allotment |
| B | Tur, aktivite | Kalkış/slot kapasitesi, kişi tipleri, rehber, minimum katılım |
| B | Transfer | Zaman penceresi, rota, araç sınıfı, bagaj, uçuş gecikmesi |
| C | Araç | Birim/grup, teslim-iade aralığı, sigorta, kilometre, depozito |
| C | Yat | Charter aralığı, mürettebat kaynağı, marina, hazırlık süresi |
| C | Restoran/masa | Masa kombinasyonu, servis süresi, kişi sayısı, no-show |
| C | SPA/spor, şezlong | Eşzamanlı personel/oda/ekipman veya yatak/slot |
| D: partnerli | Uçak | Provider offer/order, fiyat yenileme, biletleme, void/refund, ancillary |
| D | Cruise | Sefer/kabin/fare, yolcu kuralları, ödeme takvimi |
| D | Etkinlik, sinema | Seans/koltuk; tekil koltuk tahsisi ve barkod kullanım kontrolü |
| D | Otobüs, feribot | Sefer, durak segmentleri, koltuk; feribotta araç kapasitesi |
| D | Hac/Umre | Grup tahsisi, yetkili sağlayıcı, belge ve ülke/ürün koşulları |
| D | Paket tur, dinamik paket | Bileşen rezervasyonları, kısmi başarısızlık, ayrı iptal kuralları |

Dalga, kesin tarih değildir. Her yeni motor için ücret ödemeye hazır müşteri, operasyon sahibi, tedarik erişimi ve başarısızlık telafisi gerekir. Uçak ve dinamik paket, konaklamanın basit alt türü olarak uygulanmaz.

**Kodsuz genişleme sınırı:** “Havuzlu villa” gibi kategori/özellik eklemek metadata ile yapılabilir. “Koltuk 12A'yı tut”, “şoför ile aracı aynı anda ayır”, “uçuşu biletle” yeni davranıştır; kod, durum makinesi ve kabul testi gerektirir. Ortak çekirdek bu eklemeleri taşımalı, bütün domainleri tek JSONB nesnesine sıkıştırmamalıdır.

---

## 05 | İlk sürümün teslim sınırı

### İlk pilotta zorunlu

Şirket/kullanıcı/rol, doğrulanmış tedarikçi, villa listing, takvim ve sezon fiyatı; acente arama ve teklif; kontratlı markup; opsiyon talebi/onayı/sona ermesi; ödeme linki veya hosted checkout; rezervasyon ve voucher; iptal/iade talebi; tüzel kişilik bazlı işlem defteri ve günlük mutabakat; insan görev kuyruğu; audit ve destek ekranı.

İlk pilot tek ürünlü order ile çalışır. Order ve booking_item modeli çok bileşene hazırdır; müşteriye “otel + uçuş + transfer aynı anda garantili” vaadi verilmez. Bölünmüş ödeme ve taksit ancak PSP/sözleşme doğrulaması sonrası açılır. Acente kredisi başlangıçta kapalı, onaylı havale veya ön ödeme açık olur.

### Dil ve para birimi taahhüdü

Veri modeli ve arayüz altyapısı ilk günden 6+ dili ve para birimini destekler. Önerilen dil seti TR, EN, DE, RU, AR, FR; para birimi seti TRY, EUR, USD, GBP, CHF, AED. Kesin set müşteri dağılımıyla seçilir. Kapalı pilot TR/EN ile başlayabilir; genel çok dilli açılışta altı dilin kritik akışları insan kontrolünden geçmelidir. AR için RTL zorunludur.

Altı para biriminde gösterim, altısında tahsilat ve hakediş desteği demek değildir. Tahsilat yalnızca PSP'nin sözleşmeyle ve testle doğrulanan para birimlerinde açılır; kullanıcıya ödeyeceği gerçek para birimi checkout öncesinde gösterilir.

### İlk sürüm dışında

Tam PMS/POS/ERP, stok/satın alma/bordro, uçuş biletleme, cruise, dinamik paket, reklam ağı, kurumsal seyahat, gerçek zamanlı tüm kanal yönetimi, sınırsız tema editörü ve otonom AI GM. Bunlar vizyondan silinmez; ayrı yatırım kapısına alınır.

**Pilot çıkış ölçütü:** Uçtan uca rezervasyon, tahsilat, iptal ve mutabakat işlemleri çalışır; P0 güvenlik/finans testleri geçer; kritik destek sahibi bellidir. Sadece güzel listing ekranı veya çalışan arama pilot için yeterli değildir.

---

## 06 | Mimari ve teknoloji kararı

Gleam bir programlama dilidir; Erlang çalışma ortamını kullanabilir ve JavaScript'e derlenebilir [R1]. Lustre, Gleam ile UI ve sunucu tarafında HTML üretimi sağlayan bir kütüphanedir [R2]. Dolayısıyla “Gleam back office / Lustre frontend” tek başına teknoloji mimarisi değildir.

### Önerilen başlangıç

- Backend: Gleam/BEAM modüler monolit. HTTP, PostgreSQL sürücüsü, migration, iş kuyruğu ve gözlemlenebilirlik paketleri kısa teknik denemeyle sabitlenir.
- UI: Supplier/Agency/HQ için Lustre; B2C ve tedarikçi sitesinde sunucuda render edilen içerik, etkileşimli arama ve checkout.
- Veri: yönetilen PostgreSQL; nesne deposu ve CDN. Arama başlangıçta PostgreSQL full-text/trigram; gerekli coğrafi sorgular için doğrulanmış PostGIS desteği.
- Arka plan: ayrı worker process/deployment; kalıcı job tablosu, lease ve retry. BEAM process belleği tek başına iş kuyruğu veya rezervasyon kaydı değildir.
- Ölçek: başlangıçta Kafka, Kubernetes, ayrı event store veya çok sayıda mikroservis zorunlu tutulmaz. Yük ve ekip sahipliği gösterdiğinde ayrıştırılır.

### Bağlantı diyagramı

```text
B2C + Supplier site + Agency + Supplier + HQ
                     |
           Auth / API / Policy
                     |
 Catalog - Pricing - Inventory - Booking - Finance
                     |
       PostgreSQL transaction + Outbox
                     |
       Jobs / Adapters / Notification
              |                 |
        PSP & providers    Search & AI tools
```

**İlk teknik kapı:** Gerçek DB transaction ve RLS context'i; eşzamanlı hold; PSP sandbox callback; SSR ürün sayfası; RTL form; trace; deploy ve restore denemesi. Sabit süre taahhüdü yerine bu çıktılar aranır. Kullanıcı + Codex bu yığında güvenle ilerleyemiyorsa mimari korunup mevcut projeyle uyumlu bir yığın seçilir. Dil tercihi, teslim riskinden bağımsız bir bağlılık değildir. Çalışan sistem varsa önce modül bazlı koruma/uyarlama analizi yapılır; toplu yeniden yazım varsayılmaz.

---

## 07 | Domain ve veri sahipliği

| Modül | Sahip olduğu doğruluk | Dışarı verdiği sonuç |
|---|---|---|
| Identity / Partners | Üyelik, rol, kontrat ve paylaşım | Yetki kararı, kontrat sürümü |
| Catalog / Content | Ürün gerçekleri, çeviri, medya | Yayına uygun listing |
| Pricing | Hesaplama ve ticari politika | Süreli, immutable quote |
| Inventory | NEXUS otoriteli tahsis | Hold ve kesin tahsis |
| Booking | Sipariş ve hizmet durumu | Reservation, voucher, iptal |
| Payment | PSP ödeme denemeleri | Doğrulanmış ödeme durumu |
| Finance | Defter ve hakediş | Mutabakat, settlement |
| Connectivity | Mapping, dış referans ve teslim | Provider status / sync |
| AI / Workflow | Görev, öneri, onay ve yürütme | Domain API üzerinden eylem |

**Product:** Kalıcı hizmet tanımı. **Listing:** Bir site/kanalda yayımlanan sunum. **Offer/quote:** Belirli tarih, kişi, para birimi ve kontrat için süreli fiyat. **Order:** Alıcının ticari sepet/sipariş üst nesnesi. **Reservation:** Tedarikçinin hizmet taahhüdü. **Allocation:** Bu taahhüdün kapasite karşılığı. Aynı ürün birçok listing ve offer üretir; ürünün üzerine tek “fiyat” yazılmaz.

### Çok şirketli işlem

tenant_id kaydın özel çalışma alanını, seller_org_id hukuki satıcıyı, supplier_org_id hizmet sağlayıcıyı, agency_org_id aracıyı ve collector_org_id tahsil eden tarafı gösterir. Bunların hepsinin aynı olması gerekmez. Sözleşme ilişkisi, tüm veriyi görme izni değildir.

Acente kendi müşteri satışı ve kendisine açılmış net fiyatı görür. Tedarikçi hizmet için gereken misafir bilgisi ve kendi hakedişini görür. Başka acentelerin marjını göremez. HQ destek erişimi süreli, gerekçeli ve audit'li olur. Genel marketplace okuması özel ürün tablolarından değil yayınlanmış alanları içeren projection'dan yapılır.

**Pilot sahiplik kararı:** Ortak ticaret ağının product, quote, hold, order ve reservation kayıtları operatör workspace'inde aynı tenant altında tutulur; supplier_org_id/agency_org_id gerçek tarafları ayırır. Özel CRM ve şirket belgeleri şirket tenant'ında kalır. Ağa alınan ürün açık paylaşım/projection ile oluşur. Ortak ağda tenant kontrolüne ek olarak taraf ve alan yetkisi zorunludur; operatör tenant'ını bilmek erişim vermez. Böylece quote-hold arasındaki bileşik FK'lar çelişmez.

**Yazma sınırı:** Modüller birbirinin tablolarını rastgele güncellemez. Aynı veritabanı transaction'ına ihtiyaç varsa tek use-case service koordinasyonu kullanılır. Olaylar sonradan bildirim ve projection üretir; kapasite kararının yerine geçmez.

---

## 08 | Listing Factory ve Supplier OS

### Listing yaşam döngüsü

```text
draft -> validating -> review_required -> approved -> published
                         |                 |
                      rejected         suspended -> review_required
```

Yayınlanmış kaydı değiştirmek yeni draft version üretir. Onaylanan sürüm atomik olarak yayına geçer; canlı sayfaya yarım çeviri veya onaysız politika sızmaz. Takvim/fiyat güncellemesi içerik onayından ayrı iş akışıdır.

URL import kaynak hakkı, robots/erişim koşulları ve içerik lisansıyla sınırlıdır. Kaynak URL, alınma zamanı, alan bazında kaynak ve tedarikçi doğrulaması saklanır. AI eksik havuz ölçüsünü, resmi izin numarasını, fiyatı veya müsaitliği tahmin ederek gerçek alanına yazamaz. İçeriğe gömülü talimatlar veri kabul edilir; AI araç yetkisini değiştiremez.

### Supplier menüsü ve ekran sözleşmesi

| Menü / sayfa | Temel alanlar ve eylem | Başarı koşulu |
|---|---|---|
| İşletmem | Firma, yetkili, belgeler, ekip | Doğrulama kararı ve kapsamı kayıtlı |
| İlanlar / sihirbaz | Konum, kapasite, özellik, kurallar, medya | Eksik ticari alanlar yayın öncesi kapanır |
| Takvim | Tarih, stok, blok, opsiyon, rezervasyon | Toplu işlem önizlemesi ve conflict raporu |
| Fiyatlar | Sezon, min. gece, ek ücret, iptal | Örnek tarih için açıklamalı hesap |
| Opsiyonlar | İsteyen acente, süre, tahsis | Onay aynı anda kapasite ayırır |
| Rezervasyonlar | Misafir, hizmet, ödeme, voucher | Durum geçişi rol ve gerekçeyle |
| Finans | Beklenen/alınan ödeme, kesinti, hakediş | PSP ve ledger farkı görünür |
| Sitem / AI / Destek | Tema, yayın, görevler, talepler | Tenant ve site yetkisi doğrulanır |

**Villa çekirdek alanları:** Hizmet adresi ve koordinat, yatak odası/banyo/yatak dağılımı, kişi kapasitesi, havuz özellikleri, erişilebilirlik beyanı, ev kuralları, giriş/çıkış saati, temizlik/depozito, minimum gece, iptal koşulu, medya kullanım hakkı ve gerekli doğrulama belgeleri. Hassas kesin adresin kamusal görünürlüğü ayrı politika olur.

Kalite skoru önerilen yayın eşiğini destekler; belge eksikliği veya çelişkili ticari bilgi yüksek puanla geçilemez. Kaydetme autosave, version conflict, boş durum ve hata açıklaması içerir.

---

## 09 | Agency OS, B2C ve site deneyimi

| Agency menüsü | Ekran içeriği | Yetki / kontrol |
|---|---|---|
| Arama | Tarih, kişi/çocuk yaşı, ürün, bölge, para birimi | Sadece satışa izinli kontratlar |
| Teklifler | Alternatifler, net maliyet, markup, geçerlilik | Müşteriye net maliyet sızmaz |
| Opsiyonlar | Talep, son süre, kalan süre, uzatma | Supplier onayı ve kapasite tekrar kontrolü |
| Rezervasyonlar | Hizmet ve ödeme durumları ayrı | İptal bedeli önizlemeden iptal yok |
| Müşteriler | Booker ve traveler ayrı, izin kayıtları | En az gerekli kişisel veri |
| Finans | Alacak, borç, marj, mutabakat | Yalnızca kendi book/projection'ı |
| Ekip / Ayarlar | Rol, markup limiti, bildirim | Finans ve kullanıcı yönetimi ayrılır |

### Lustre sayfa planı

Panel rotaları: /app/supplier/listings, /calendar, /options, /reservations, /finance; /app/agency/search, /quotes, /options, /bookings, /customers; /app/hq/approvals, /payments, /reconciliation, /incidents. Bunlar uygulama rotalarıdır; SEO dil kodu kararıyla karıştırılmaz.

Her işlem sayfasında loading, empty, error, unauthorized, stale-version ve success durumları tasarlanır. Ortak bileşenler: money display, date/party picker, server-time countdown, quote breakdown, status timeline, approval diff, audit drawer. Mobil görünüm, klavye kullanımı, alan etiketi, hata odağı ve RTL test edilir.

### B2C müşteri akışı

Arama → ürün detayı → canlı fiyat doğrulama → misafir ve sözleşme → ödeme → rezervasyon durumu → voucher. Arama sonucu “başlangıç fiyatı” ise açıkça etiketlenir. Fiyat değişirse müşteri yeniden kabul eder. Ödeme başarılı fakat hizmet teyitsizse ekran “rezervasyon onaylandı” demez; takip referansı ve destek yolu verir.

Tedarikçi sitesi aynı kataloğun site/channel kurallı görünümüdür. Ayrı stok ve ödeme kodu oluşmaz. Başlangıçta tek erişilebilir tema, sabit bloklar, SSL ve alt alan adı; özel alan adı doğrulaması tenant eşlemesine bağlıdır. Tema HTML/JS'sinin keyfî yüklenmesi kapalıdır.

**İlk prototip senaryosu:** Acente 3 gecelik villa teklifi oluşturur, %8 markup ekler, opsiyon ister; tedarikçi 30 dakika verir; ödeme sonrası iki tarafta farklı yetkilerle aynı rezervasyon referansı görünür.

---

## 10 | Fiyat, komisyon ve markup sözleşmesi

İki temel model ayrı seçilir: **commissionable gross** (brüt fiyattan komisyon ayrılır) ve **net rate** (tedarikçi netine markup eklenir). Bir kontratta hangi modelin geçerli olduğu zorunlu alandır. “%10” tek başına yeterli değildir: hangi taban, hangi kalem, hangi tarihte, vergi dahil mi, kime ait sorularının cevabı gerekir.

### Deterministik hesaplama

1. Ürün/tarih/kişi için konaklama veya hizmet tabanı hesaplanır.
2. Dahil ve hariç vergi, zorunlu ücret, ekstra ve indirim ayrıştırılır.
3. Geçerli kontrat sürümü ve komisyona uygun kalemler seçilir.
4. NEXUS payı ve acente markup'ı izin verilen tabana uygulanır.
5. Her kalem minor unit'e belirlenmiş yuvarlama yöntemiyle çevrilir; toplam kalemlerden üretilir.
6. Müşteriye satılan tutar, taraf hakedişleri, FX ve politika sürümleri quote snapshot'ına yazılır.

| Vergisiz örnek A: brüt komisyon | Tutar |
|---|---|
| Tedarikçinin komisyona esas satış tutarı | 10.000 TRY |
| Tedarikçi komisyonu %12 | 1.200 TRY |
| Tedarikçi net hakedişi | 8.800 TRY |
| Acente ek markup %5 × 10.000 | 500 TRY |
| Müşteri toplamı | 10.500 TRY |
| Dağılım kontrolü | 8.800 + 1.200 + 500 = 10.500 |

Örnek B: net fiyat 8.800, NEXUS markup %10 × 8.800 = 880; acente markup %5 × 9.680 = 484; müşteri 10.164 TRY. Bu iki örnek aynı iş modeli değildir. Vergiler, PSP maliyeti ve gerçek ticari oranlar örnek dışında tutulmuştur; kimin taşıdığı kontratta yazılır.

**Kural çakışması:** rule_type içinde explicit priority, specificity ve yürürlük aralığı kullanılır; eşit öncelikli çelişki sessizce seçilmez, yayın reddedilir. Birleşebilen kurallar stack_group ile tanımlanır. Kontrat sınırı, minimum katkı ve yasaklı taraf politikası daha üst güvenlik katmanıdır. Sezonlar yerel hizmet tarihine göre değerlendirilir.

**Quote değişmezliği:** amount, currency, rate_version, contract_version, cancellation_version, tax_basis, rounding_policy, expires_at ve hash saklanır. Yeni fiyat eski rezervasyonu değiştirmez. Tarih değişikliği yeni quote ve fark işlemi üretir.

---

## 11 | Opsiyon motoru ve kapasite doğruluğu

Opsiyon talebi ile gerçek hold farklı nesnelerdir. Talep oluşturmak stoğu azaltmaz. Supplier onayı ancak kapasite aynı transaction içinde ayrılabiliyorsa “approved” olur. Bekleyen iki acenteye aynı son birim için kesin opsiyon verilmez.

```text
REQUEST: pending -> approved | rejected | withdrawn | expired
HOLD:    active  -> consumed | released | expired
BOOKING: pending -> confirmed -> fulfilled
                    |    |
                    | cancel_pending -> cancelled
                    + review_required (istisna takibi)
```

### Villa/gece algoritması

Önce ilgili resource ve [check_in, check_out) aralığındaki tüm gece satırları deterministik sırada kilitlenir. Eksik gece satırı varsa işlem başarısız olur; “satır yok, stok var” varsayılmaz. Süresi dolmuş aktif tahsisler aynı kilit düzeniyle serbest bırakılır. Her gece için capacity - blocked - held - sold ≥ istenen miktar kontrol edilir. Hold, gece tahsisleri, sayaçlar, audit ve outbox tek commit ile yazılır. PostgreSQL satır kilitleri bu eşzamanlılık tasarımının temel aracıdır [R4].

Kapasite kontrolünde Redis veya arama indeksi karar vermez. DB kilidi beklerken süre aşımı olursa kontrollü retry veya 409 conflict döner. Bütün yazıcılar aynı resource/gün kilit sırasını izler. Süre kararı transaction başlangıcından kalan saat yerine kilit sonrası DB saatiyle alınır.

### Politika önerileri

- Kısa checkout hold başlangıç değeri 10 dakika; B2B opsiyon supplier tanımlı süre ve maksimum uzatma adedi taşır. Bunlar pilotta ayarlanır.
- Uzatma yeni fiyatı otomatik garanti etmez; quote geçerliliği ayrı kontrol edilir.
- Acente başına açık opsiyon ve tutulan stok limiti stok kilitleme suistimalini sınırlar.
- Başka kanalın otorite olduğu stokta provider hold desteği yoksa “kesin opsiyon” sunulmaz; talep statüsü gösterilir.
- Süre dolumu worker'ı gecikse de API kontrolü süresi dolmuş hold'u tüketemez.

**İptal ve tarih değişimi:** Eski tahsis onay alınmadan serbest bırakılmaz. NEXUS içi değişimde yeni tahsis ve eski tahsis bırakma atomik yürür; dış sağlayıcıda saga ve telafi gerekir.

---

## 12 | Ödeme ve rezervasyon orkestrasyonu

Ödeme durumu, rezervasyon durumu ve hizmet durumu ayrı tutulur. Frontend dönüş URL'si ödeme kanıtı değildir. İmzalı webhook veya PSP sorgusuyla tutar, para birimi, işlem ve merchant eşleşmesi doğrulanır. Param pazaryeri dokümanı ve FAQ'sı, POS'tan ayrı hakediş akışının incelenmesi gerektiğini gösterir; tam sayfa erişimi bu kontrolde sınırlı kalmıştır [R7].

| Olay | Karar | Müşteriye durum |
|---|---|---|
| Geçerli hold + doğrulanmış ödeme | Hold consume ve booking confirm tek DB transaction | Onaylandı |
| Ödeme geldi, hold süresi doldu | Aynı üründe tekrar kapasite ve quote kontrolü | İşleniyor; otomatik onay vaadi yok |
| Yeniden kapasite alınamıyor | İade/void talebi, istisna görevi | Ödeme alındı, hizmet teyit edilemedi |
| PSP timeout | unknown; reference ile sorgula | Tekrar ödeme istenmeden kontrol |
| Yinelenen webhook | Daha önce işlenen sonuç dön | İkinci tahsilat/kayıt yok |
| Dış provider timeout | provider_unknown; retrieve/reconcile | Sonuç bekleniyor |

### Önerilen ilk ödeme modeli

Lisanslı PSP üzerinden hosted checkout; kart bilgisi NEXUS veritabanı veya loguna girmez. Satıcı/alt üye onboarding'i ve ödeme/hakediş sözleşmesi netleştirilir. NEXUS Payment Engine bir işlem orkestratörüdür; lisanslı ödeme kuruluşu olma iddiası değildir. İş modelinin ödeme mevzuatı kapsamı ayrıca doğrulanır [R13].

PSP authorization/capture destekliyorsa kısa hold ve teyit sonrası capture denenir. Desteklemiyorsa tahsilat sonrası teyit başarısızlığında iade akışı zorunludur. Bu yeteneklerin Param'da ilgili sözleşme için var olduğu varsayılmaz. Altı döviz, kısmi iade, taksit, split, gecikmeli ödeme ve chargeback yetenekleri sağlayıcı matrisiyle doğrulanır.

### Havale ve bakiye

Dekont yüklemek “ödendi” yapmaz; banka/PSP hareketi veya yetkili finans kullanıcısının doğrulaması gerekir. Kapora, kalan tutar ve son ödeme tarihi schedule satırlarıdır. Kaporanın hangi hizmet taahhüdünü doğurduğu sözleşmede tanımlanır. Acente kredi limiti açılırsa kullanılabilir limit de hold gibi atomik rezerve edilir.

**Idempotency:** Her ticari komut tenant + operation + key kapsamında tekilleşir; request hash farklıysa 409 döner. Belirsiz dış işlem yeni anahtarla körlemesine tekrarlanmaz. Aynı rezervasyonun ikinci PSP denemesi ancak önceki denemenin sonucu kontrol edilerek açılır.

---

## 13 | Ledger, hakediş ve katkı ekonomisi

Tek motor üzerinde **ayrı ledger book'ları** kullanılır: her book bir tüzel kişiliğe aittir. NEXUS, supplier ve acente aynı defterin serbest filtrelenmiş kullanıcıları değildir. Ticari taraflar ortak transaction referansıyla ilişkilendirilir; başka şirketin hesap satırları paylaşılmaz. İlk sürüm operasyonel alt defterdir, yasal muhasebe yazılımının otomatik yerine geçmez.

### Vergisiz, NEXUS tahsilatlı örnek A

| Olay | Borç | Alacak |
|---|---|---|
| 10.500 tahsilat doğrulandı | PSP clearing 10.500 | Supplier payable 8.800; agency payable 500; ertelenmiş platform bedeli 1.200 |
| Platform hizmeti kazanıldı | Ertelenmiş platform bedeli 1.200 | Platform geliri 1.200 |
| PSP 250 masraf düşüp 10.250 aktardı | Banka 10.250; PSP gideri 250 | PSP clearing 10.500 |
| Supplier ve acenteye ödeme | Supplier payable 8.800; agency payable 500 | Banka 9.300 |

Her satır grubunda toplam borç ve alacak eşittir. Gelirin hangi anda kazanıldığı, kesintiler ve fatura sorumluluğu sözleşme/mali politika ile belirlenir; örnek muhasebe görüşü değildir. PSP doğrudan taraflara dağıtıyorsa banka bacakları gerçek fon akışına göre farklı posting template kullanır.

**Değişmezler:** Her journal book ve currency bazında dengeli; amount_minor pozitif; aynı business event yalnızca bir kez post edilir; posted kayıt güncellenmez/silinmez. İade, chargeback veya düzeltme reversal/new-entry ile yapılır. Bir satır CHECK'i çok satırlı dengeyi garanti edemez: posting procedure ve commit öncesi denge doğrulaması gerekir.

### Mutabakat ve hakediş

Günlük üçlü eşleştirme: booking/payment ↔ PSP hareketi ↔ banka/settlement raporu. Farklar amount, currency, fee, missing, duplicate ve timing olarak ayrılır; sahibi ve yaşlandırması vardır. Payout'a uygunluk: hizmet/milestone, iptal durumu, mutabakat ve rezerv/chargeback koşulları. Payout emri ile gerçekleşen ödeme ayrı statülerdir.

**Örnek birim ekonomi:** 1.200 platform geliri - 250 PSP - 100 destek - 20 AI - 80 beklenen iade/chargeback maliyeti = 750 TRY katkı. 600 TRY edinim maliyeti sonrası 150 TRY kalır. Bunlar senaryo sayılarıdır; piyasa maliyeti veya fiyat teklifi değildir. GMV, gelir ve nakit birbirine karıştırılmaz.

---

## 14 | PostgreSQL tasarım standardı

Kolon sözlüğü sonraki üç sayfada çekirdek kapsam için verilmiştir. Notasyon: PK birincil anahtar, FK yabancı anahtar, UQ tekil, NN boş olamaz; “?” nullable. uuid kimlikler uygulamada güvenli üretilir. İşlem zamanı timestamptz/UTC; gece envanteri date ve property IANA timezone ile tanımlanır. Konaklama çıkış günü satılmaz.

### Şema ve tenant ilkeleri

identity, partners, catalog, content, pricing, inventory, booking, payment, finance, workflow, integration şemaları önerilir. Özel tablolarda tenant_id NN; çocuk kayıtlarında (tenant_id,parent_id) bileşik FK ile tenant uyumu zorlanır. Yerel tabloların global currency/country referansları hariç, yalnız UUID FK yeterli sayılmaz.

Uygulama DB rolü tablo sahibi/superuser/BYPASSRLS değildir. Tenant özel tablolarda RLS default-deny; USING ve WITH CHECK; migration sahibi ayrı. PostgreSQL'de owner ve ayrıcalıklı rollerin bypass davranışı nedeniyle RLS tek başına eksiksiz güvenlik değildir [R3]. Her transaction'da güvenilir kimlikten SET LOCAL tenant context kurulur; pool dönüşünde oturum durumu sızmaz. İstemci tenant header'ı tek başına yetki kaynağı değildir.

Cross-tenant erişim: booking_parties ve field-level projection aracılığıyla açık okuma izni; partner ilişkisi tüm satırlara yazma hakkı vermez. Destek ve worker DB rolleri kendi görev kapsamlarıyla ayrılır.

### Para, sürüm ve arama

Money bigint minor units + currency FK. JPY gibi sıfır, üç ondalıklı para birimleri ve API'de JavaScript sayı sınırı dikkate alınır; amount_minor JSON string olarak taşınabilir. FX numeric(24,12); parite yönü, kaynak ve zaman snapshot olur. Floating point para hesabında kullanılmaz.

Fiyat/iptal politikaları immutable version tabloları; JSONB yalnız snapshot, esnek açıklayıcı özellik ve dış payload içindir. Kimlik, kapasite, tutar ve ilişki kolonlaşır. Yoğun JSONB alanına gerekçesiz GIN index eklenmez. Operasyonel listelerde (tenant_id,status,created_at,id) index ve cursor pagination kullanılır.

Audit DB yetkileriyle append-only tutulur; ayrı depoya periyodik salt okunur kopya ve hash doğrulaması eklenir. “Immutable” burada uygulama yetkileri ve kayıt politikasıyla sağlanır; DB yöneticisinin fiziksel müdahalesini sihirli biçimde engellemez.

---

## 15 | Çekirdek veri sözlüğü: kimlik ve katalog

Bu sayfalardaki tablolar tasarım sözleşmesidir; production migration yerine geçmez. Listelenen zorunlu alanlar NN, “?” işaretliler nullable'dır. Özel tablolarda ortak alanlar: id uuid PK, tenant_id uuid FK organization, created_at timestamptz, updated_at timestamptz, version bigint CHECK > 0 ve UQ(tenant_id,id). Global tablolar ayrıca belirtilir.

| Tablo | Özgül kolonlar | Ana constraint / index |
|---|---|---|
| organization (global) | id uuid PK, legal_name text, country_code char(2), timezone text, status text | status allowlist; kimlik doğrulama ayrı |
| app_user (global) | id uuid PK, auth_subject text, email text? | UQ(auth_subject); kimlik sağlayıcı referansı |
| membership | user_id uuid FK app_user, role_code text, status text | UQ(tenant_id,user_id,role_code) |
| partner_relationship | counterparty_org_id uuid FK, status text, valid_from timestamptz, valid_to timestamptz? | CHECK self partner değil; (tenant,status) |
| contract_version | relationship_id uuid FK, revision int, model text, terms jsonb, effective_from date, effective_to date? | UQ(tenant,relationship,revision); yayın sonrası immutable |
| product | supplier_org_id uuid FK, type_code text, status text, source_ref text? | (tenant,type,status); supplier yetkisi |
| property | product_id uuid FK, timezone text, country_code char(2), locality text, address_private text, latitude numeric?, longitude numeric? | UQ(tenant,product); koordinat aralığı |
| resource | product_id uuid FK, kind text, name text, capacity int, active boolean | capacity > 0; (tenant,product,active) |
| listing_version | product_id uuid FK, revision int, state text, facts jsonb, source_url text?, approved_by uuid? | UQ(tenant,product,revision); approved için actor |
| translation | listing_version_id uuid FK, locale text, title text, description text, review_state text, source_hash text | UQ(tenant,listing_version,locale) |
| media_asset | storage_key text, checksum text, rights_ref text?, scan_status text, mime text, size_bytes bigint | UQ(tenant,storage_key); size > 0 |
| site_route | site_id uuid FK site, locale text, path text, target_version_id uuid FK, state text | UQ(site_id,path); güncel rota çakışamaz |
| site | hostname text, owner_org_id uuid FK, theme_version text, status text | UQ(hostname); sahiplik doğrulaması |

**FK kuralı:** Yukarıdaki tenant içi FK'lar fiilen (tenant_id, ilgili_id) → (tenant_id,id) şeklinde uygulanır. organization/app_user gibi global hedeflerde tekli FK geçerlidir. Global currency/code tabloları rol kapsamında salt okunur olur.

**Ayrı genişletmeler:** category/attribute_definition, product_attribute, media_link, route_redirect, role/permission ve publication_channel tabloları bu sözlüğün devamıdır; ilk sprintte gerçek form ihtiyaçlarına göre kolonlaştırılır. Route redirect hedefi döngüye izin vermez, eski URL yeni canonical'a tek adımda gider.

---

## 16 | Çekirdek veri sözlüğü: fiyat ve rezervasyon

Önceki sayfanın ortak kolon standardı geçerlidir. Bileşik PK kullanılan inventory_day ve allocation_day için ayrıca id zorunlu değildir. Tarih aralığı [check_in,check_out); tüm miktarlar pozitif tam sayıdır.

| Tablo | Özgül kolonlar | Constraint / index |
|---|---|---|
| rate_plan | product_id uuid FK, name text, currency char(3) FK, cancellation_version_id uuid FK | (tenant,product) |
| rate_version | rate_plan_id uuid FK, revision int, start_date date, end_date date, amount_minor bigint, min_nights int | start < end; amount ≥ 0; min_nights > 0; UQ(plan,revision) tenant ile |
| quote | product_id uuid FK, agency_org_id uuid?, contract_version_id uuid FK, currency char(3), total_minor bigint, expires_at timestamptz, snapshot jsonb, snapshot_hash text | total ≥ 0; (tenant,expires_at); immutable |
| inventory_day | tenant_id, resource_id uuid FK, service_date date, capacity int, blocked int, held int, sold int | PK(tenant,resource,date); tüm sayaçlar ≥ 0; blocked+held+sold ≤ capacity |
| option_request | quote_id uuid FK, requested_by uuid FK, desired_expiry timestamptz, state text, decision_reason text? | (tenant,state,created_at) |
| hold | quote_id uuid FK, option_request_id uuid?, expires_at timestamptz, state text | state allowlist; active için (tenant,expires_at) partial index |
| allocation_day | tenant_id, hold_id uuid FK, resource_id uuid FK, service_date date, quantity int, state text | PK(tenant,hold,resource,date); inventory_day bileşik FK |
| customer_order | buyer_org_id uuid?, booker_ref uuid?, currency char(3), total_minor bigint, state text | total ≥ 0; (tenant,state,created_at,id) |
| reservation | order_id uuid FK, quote_id uuid FK, hold_id uuid FK, supplier_org_id uuid FK, state text, confirmed_at timestamptz? | UQ(tenant,hold_id); confirmed için timestamp |
| booking_item | reservation_id uuid FK, product_id uuid FK, start_date date, end_date date, quantity int, snapshot jsonb | start < end; quantity > 0; (tenant,reservation) |
| booking_party | reservation_id uuid FK, org_id uuid FK, role text, visibility_policy text | UQ(tenant,reservation,org,role) |
| cancellation | reservation_id uuid FK, requested_by uuid FK, reason text, fee_minor bigint, state text, policy_snapshot jsonb | fee ≥ 0; bir aktif cancellation için partial UQ |

**Sayaç tutarlılığı:** allocation_day tahsisin kaynağı, inventory_day sayaçları atomik güncellenen operasyonel görünümüdür. Bütün tahsis komutları tek procedure/use-case yolundan geçer. Periyodik karşılaştırma fark bulursa satış durdurulur ve incident açılır; kör otomatik düzeltme yapılmaz.

**Snapshot sınırı:** Misafir kimlik belgesi ve gereksiz PII immutable quote içine gömülmez. traveler/participant ayrı korumalı tabloda; quote ticari kararın yeniden açıklanması için yeterli alanları taşır. Oda/gece havuzu ve slot envanteri sonraki motorlarda farklı tablolarla uygulanır.

---

## 17 | Çekirdek veri sözlüğü: finans ve yürütme

| Tablo | Özgül kolonlar | Constraint / index |
|---|---|---|
| payment_intent | order_id uuid FK, collector_org_id uuid FK, currency char(3), amount_minor bigint, state text | amount > 0; (tenant,order,state) |
| payment_attempt | intent_id uuid FK, provider text, merchant_ref text, external_ref text?, state text, amount_minor bigint | UQ(provider,merchant_ref,external_ref) external_ref doluyken |
| webhook_inbox | provider text, merchant_ref text, event_ref text, payload_hash text, verified_at timestamptz?, processed_at timestamptz? | UQ(provider,merchant_ref,event_ref); payload kontrollü saklanır |
| refund | attempt_id uuid FK, amount_minor bigint, reason text, state text, external_ref text? | amount > 0; toplam iade capture'ı aşamaz, kilitli komut kontrolü |
| ledger_book | legal_org_id uuid FK, name text, functional_currency char(3) | book sahibine scoped erişim |
| account | book_id uuid FK, code text, currency char(3), kind text | UQ(tenant,book,code,currency); kind allowlist |
| journal | book_id uuid FK, business_event_id uuid, currency char(3), effective_at timestamptz, state text, reversal_of uuid? | UQ(tenant,book,business_event_id); posted immutable |
| journal_line | journal_id uuid FK, book_id uuid FK, account_id uuid FK, side char(1), amount_minor bigint | amount > 0; side D/C; book ve currency uyumu |
| settlement | book_id uuid FK, payee_org_id uuid FK, currency char(3), amount_minor bigint, state text, due_at timestamptz | (tenant,state,due_at); kalemler settlement_item ile |
| payout | settlement_id uuid FK, provider_ref text?, amount_minor bigint, state text | UQ external ref scoped; settlement kilidi |
| idempotency_record | operation text, key text, request_hash text, state text, response_ref text?, expires_at timestamptz | UQ(tenant,operation,key); uzun işte in_progress |
| outbox_event | aggregate_type text, aggregate_id uuid, aggregate_version bigint, event_type text, payload jsonb, published_at timestamptz? | unpublished partial index; event id unique |
| ai_action | tool text, input_hash text, resource_version bigint, policy_version text, state text, budget_minor bigint | (tenant,state,created_at); execution_key UQ |
| approval | action_id uuid FK, approver_id uuid FK, decision text, approved_hash text, expires_at timestamptz | aynı kişi kritik işlemi önerip onaylayamaz |

**Çok satırlı invariants:** Journal dengesi, toplam iade sınırı ve settlement'a kalemlerin bir kez dahil edilmesi sadece basit CHECK ile çözülemez. Kilitli posting/refund komutu, unique iş referansı ve transaction sonu doğrulaması birlikte gerekir. FX journal'ı her para biriminde clearing hesaplarıyla dengelenir; kur farkı açık kayıt olur.

**Ek yürütme tabloları:** job, job_attempt, audit_event, reconciliation_case, payment_schedule, ai_run, tool_call, provider_mapping ve consumer_inbox. Worker lease_expiry ve attempt_count saklar; transaction dışı dış servis çağrısı tamamlanınca sonuç idempotent kaydedilir. Bu alanların kesin tipleri API ve provider sözleşmesiyle tamamlanır.

---

## 18 | API komutları ve olay sözleşmeleri

Prefix /v1. İş bağlamı token'dan çözülür. GET listeleri cursor/limit, alan bazlı yetki ve filtre allowlist kullanır. POST ticari komutlarda Idempotency-Key; mevcut kaydı değiştiren işlemlerde If-Match/version zorunludur. Para alanları currency + amount_minor string çiftidir.

| Endpoint | Amaç / başlıca sonuç |
|---|---|
| POST /listings; POST /imports | Draft oluştur / kontrollü import job başlat |
| PATCH /listings/{id}; POST /listings/{id}/submit | Sürümlü düzenle / incelemeye gönder |
| POST /listings/{id}/publish | Yetkili sürümü yayınla |
| GET /availability; POST /inventory/blocks | Takvim sorgula / kapasite blokla |
| POST /rate-versions; POST /quotes | Fiyat sürümü / immutable teklif |
| POST /option-requests | Talep oluştur; stok garantisi yok |
| POST /option-requests/{id}/approve | Kapasite ayırıp hold döndür |
| POST /option-requests/{id}/reject | Gerekçeli ret |
| POST /holds; POST /holds/{id}/extend | Checkout hold / yetkili uzatma |
| POST /holds/{id}/release | Hold serbest bırak |
| POST /orders; GET /orders/{id} | Order aç / yetkili görünüm |
| POST /payment-intents | PSP checkout başlat, booking onaylamaz |
| GET /reservations/{id} | Hizmet/ödeme durumunu ayrı oku |
| POST /reservations/{id}/cancel-preview | Geçerli iptal bedeli snapshot'ı |
| POST /reservations/{id}/cancellations | İptal komutu / async işlem |
| POST /refunds; GET /settlements | Yetkili iade / hakediş görünümü |
| POST /webhooks/{provider} | Kimliği doğrulanmış inbox alımı |
| GET /approvals; POST /approvals/{id}/decide | İnsan kontrolü |
| GET /jobs/{id}; GET /audit-events | İş takibi / yetkili denetim |

### Hold oluşturma örneği

İstek: {quote_id, resource_id, check_in, check_out, quantity}. Yanıt 201: {hold_id, state:"active", expires_at, server_now, version}. Yetki 403; kapasite/fiyat/sürüm çakışması 409; geçersiz alan 422; asenkron dış teyit 202 + job_id. Hata gövdesi: code, message, retryable, correlation_id, field_errors. İç SQL/PSP sırrı yanıtlanmaz.

Olay zarfı: event_id, type, schema_version, aggregate_id, aggregate_version, tenant_id, occurred_at, correlation_id, causation_id, actor_ref, payload. Örnekler: hold.created, hold.expired, payment.verified, reservation.confirmed, refund.completed, journal.posted. DB state ve outbox aynı commit'te; teslim en az bir kez, consumer inbox ile tekilleştirme. “Exactly once” ağ garantisi verilmez. Sırasız olayda sürüm kontrolü ve authoritative reread yapılır.

---

## 19 | Connectivity: iki ayrı ağ

**Supply dağıtımı:** Tedarikçinin içerik, fiyat ve rezervasyonlarını dış satış kanalına bağlamak. **Demand tedariği:** Dış sağlayıcının ürününü NEXUS'ta aramak ve satmak. Booking.com kendi portalında Connectivity ile Demand API'yi ayrı tanımlar [R5]. Connectivity erişimi, tüm Booking.com envanterini yeniden satma hakkı değildir.

| Adaptör yeteneği | Sözleşmede açık değer |
|---|---|
| search / quote | Destek, timeout, cache TTL, fiyat geçerliliği |
| hold | Gerçek hold var/yok; süre ve referans |
| book / retrieve | Idempotency desteği, sorgu anahtarı, unknown çözümü |
| modify / cancel / refund | Her biri ayrı destek ve kısıt |
| push / pull | Webhook, polling, acknowledgement, sıra |
| financial | Tahsil eden taraf, currency, hakediş ve rapor |

### Entegrasyon kabul kapısı

Partner erişimi ve sözleşme → sandbox → mapping → contract tests → hata/telafi testleri → gerekiyorsa sertifikasyon → sınırlı canlı grup. Booking.com canlıya geçiş gereklilikleri API'ye göre sertifikasyon veya self-assessment içerebilir [R6]. HotelRunner rezervasyon dokümanı push/pull ve teslim onayı akışlarını anlatır [R8]; bu nedenle tek “webhook bağlandı” testi yeterli değildir.

Canonical model dış alanları kaybetmez: raw provider reference, mapping_version ve desteklenmeyen alanlar namespaced extensions içinde tutulur. Ancak provider payload iç çekirdeğin şeması olmaz. Hata retry politikası işleme göre ayrılır: arama güvenle yinelenebilir; booking timeout'u sorgusuz yeniden siparişe dönüşmez.

**Envanter otoritesi:** Her resource için NEXUS, channel manager veya dış provider'dan hangisinin yetkili olduğu bellidir. iCal bir blok senkronizasyon yardımcısıdır; anlık hold/fiyat dağıtım garantisi sayılmaz. Stop-sell, stale availability ve mapping bozulması için görünür operasyon kuyruğu gerekir.

**Failover sınırı:** Başka sağlayıcıya yönlenmek aynı sözleşme, fiyat ve iptal şartını garanti etmez. Belirsiz bir booking başka provider'da otomatik yeniden alınmaz. Müşteri teyidi ve telafi politikası gerekir. OpenTable dokümanının içeriği bu incelemede okunamadı; dining yetenekleri veya erişim koşulları doğrulanmış kabul edilmedi [R16].

---

## 20 | Altı dil, döviz ve SEO mimarisi

### Dil kodsuz URL kararı korunuyor

/tr/ veya /en/ zorunlu değildir; her dilde ayrı, kararlı URL gerekir. Örnek tasarım: /villa/deniz-manzarali-lale-evi ve /villas/sea-view-lale-house. Site çapında (site_id,path) unique; aynı özel ad iki dilde çakışırsa locale'e uygun kategori veya sabit kısa içerik kimliği eklenir. Başlık değişince slug otomatik değişmez; editör kontrollü değişimde 301 kaydı tutulur.

Google dokümanı hreflang ile dil/bölge alternatiflerinin bildirilebildiğini açıklar [R11]. Tasarım: her çeviri kendi canonical'ına gider; karşılıklı hreflang ve uygun x-default; sitemap yalnız yayımlanmış, erişilebilir URL'leri içerir. İngilizce sayfa Türkçe sayfaya canonical edilmez. Cookie/IP otomatik yönlendirmesi taranabilir tek içerik yolu olmaz.

İki marka alan adı aynı içerik havuzunu kullanabilir, fakat aynı dilde eşdeğer sayfa çoğaltımı bilinçli yönetilir: tek indekslenecek ana URL veya gerçekten farklı pazar içeriği. reservationinturkey.com'un müşteri odağı ve marka sahipliği doğrulanmadan URL/domain taşınmaz. Filtre kombinasyonları sınırsız indekslenmez; destinasyon landing sayfaları editoryal kalite kapısından geçer.

### Çeviri ve içerik modeli

Kaynak sürümü, locale, terim sözlüğü, çeviri sürümü ve insan review_state. Fiyat, sözleşme, iptal ve güvenlik metni otomatik çeviriyle kontrolsüz yayımlanmaz. Kaynak değişince çeviri “stale” olur. Arama sorgusu diline göre sözlük ve normalizasyon; Arapça RTL; Türkçe I/İ dönüşümü test edilir. AI SEO tıklanma garantisi veya doğrulanmamış özellik üretmez.

### Döviz modeli

display_currency, charge_currency, settlement_currency ve book functional_currency ayrıdır. Gösterim yaklaşık ise etiketlenir; checkout'ta gerçek charge amount ve currency sabitlenir. Snapshot FX oranı, parite yönü, kaynak, timestamp ve geçerlilik taşır. Kur eskirse yeniden quote; müşteri onayı gerekir. İade, orijinal tahsilat para birimi ve PSP işlemiyle bağlanır; bankanın döviz etkisinin aynen geri döneceği vaat edilmez.

**SEO kabulü:** JavaScript kapalı ürün içeriği okunur; 404 gerçek 404, kalıcı redirect 301, canonical ve hreflang doğru, çevirisi eksik URL index'e açık değil. Schema.org alanları sayfada görünen doğrulanmış bilgilerle uyumludur.

---

## 21 | AI Worker → Manager → Director → GM

Hiyerarşi ürünün görev ve karar görünümüdür; her rolün ayrı sürekli model çağrısı olması gerekmez. Süre sonlandırma, muhasebe post etme ve kapasite kontrolü deterministik kodda kalır. AI belirsiz girdiyi işler, öneri üretir ve yetkili araç çağrısı önerir.

| Rol | Sorumluluk | Başlangıç yetkisi |
|---|---|---|
| Worker | Alan çıkarma, çeviri, açıklama, tutarsızlık bulma | Draft yaz; yayın ve fiyat öner |
| Manager | Kuyruk, SLA, görev önceliği, kalite kontrol | Görev ata; insan onayı iste |
| Director | Ticari/operasyonel hedefleri birlikte değerlendir | Sınırlı senaryo ve bütçe önerisi |
| AI GM | Haftalık risk/fırsat, aksiyon sahibi ve etki | Yönetim önerisi; kritik icra yok |
| İnsan yönetici | Sözleşme, mali yetki, istisna ve politika | Nihai yetki ve sorumluluk |

### Eylem hattı

```text
Kaynak -> Worker önerisi -> Şema doğrulama -> Policy
        -> İnsan onayı (gerekiyorsa) -> Domain command
        -> Sonuç doğrulama -> Audit + Evaluation
```

Tool allowlist: extract_listing, propose_translation, validate_listing, explain_quote, propose_price_change, request_hold, draft_customer_message, flag_reconciliation_case. Araç girdisinde tenant context istemciden/AI'den güvenilmez; sunucu kimliğinden gelir. Tool sonucu typed ve minimum veri olur. AI doğrudan SQL, ödeme paneli şifresi veya sınırsız HTTP aracı almaz.

**Onay sözleşmesi:** actor, tool, target, amount/currency, input_hash, resource_version, policy_version ve expires_at bağlanır. İnsan farklı veriye onay verdiyse yürütme durur. Onay ekranı değişiklik öncesi/sonrası, mali etki, kaynak ve geri dönüş/telafi yolunu gösterir. Kill switch yeni işlemleri durdurur; PSP'ye gönderilmiş işlemi iptal etmiş gibi davranmaz.

**Yetki yükseltme:** Önce shadow, sonra recommend, sonra düşük riskli auto. Pilot değerlendirme seti önerisi 200 temsilî iş + 50 saldırı/istisna; kritik ticari gerçek uydurma ve tenant sızıntısı için sıfır tolerans test kapısı. Bu örneklem üretimde sıfır hata garantisi değildir. Kabul oranı, yanlış otomasyon, override, maliyet ve insan süresi birlikte ölçülür.

---

## 22 | AI araçları ve insan kontrol merkezi

| Worker | Girdi → çıktı | Yasak / kontrol |
|---|---|---|
| Listing Importer | İzinli URL/dosya → alan önerileri ve kaynak | Ticari gerçeği uyduramaz; SSRF ve dosya taraması |
| Translation | Kaynak sürümü → taslak çeviri | Kritik şartlar review gerektirir |
| Listing QA | Draft → eksik/çelişki listesi | Skor belge zorunluluğunu geçersiz kılamaz |
| Price Analyst | Fiyat snapshot → öneri ve açıklama | Fiyatı kendi başına değiştirmez |
| Option Assistant | Bekleyen talepler → önerilen öncelik | Tahsisi inventory motoru yapar |
| Finance Analyst | Maskeli hareketler → fark sınıflandırma | Journal/payout doğrudan yazamaz |
| Sales Assistant | Yetkili quote → mesaj taslağı | Limit dışı indirim ve izinsiz gönderim yok |
| Operations Analyst | Incident → olası neden / task | Provider sonucu belirsizken failover booking yok |

### HQ kontrol merkezi

Tek kuyrukta risk, yaş, son tarih, taraflar ve beklenen etki. Filtreler: onay bekleyen, finans farkı, ödeme belirsiz, provider belirsiz, yayın kontrolü, müşteri şikâyeti. Eylemler: incele, düzenle, onayla, reddet, insana ata, otomasyonu durdur. Her kritik eylem rol, gerekçe ve son durumu yeniden doğrular.

### AI yürütme güvenliği

Job başına max_steps, max_tool_calls, token/cost_budget, deadline ve tenant günlük kota. Model sağlayıcı timeout'unda görev güvenle askıya alınır; checkout AI'ye bağımlı olmaz. Harici belge ve ilan metni prompt injection taşıyabilir; untrusted content olarak ayrılır. URL import private IP/metadata adreslerini, redirect kaçışını ve zararlı dosyaları engelleyen fetch servisi üzerinden yapılır.

Model sürümü, prompt sürümü, tool schema sürümü, policy sürümü ve outcome saklanır; gereksiz kişisel veri ve iç model düşünce kaydı tutulmaz. Tenant belleği ve vektör araması erişim filtrelerini taşır; cache key de tenant/izin sürümü içerir. Kaynak gösteremeyen öneri ticari veri değişikliğine dönüşmez.

**İnsan-only başlangıç alanları:** Banka hesabı/yararlanıcı değişikliği, kritik yetki açma, kontrat kabulü, payout serbest bırakma ve ilk pilot iadeleri. Düşük riskli içerik işlemleri ancak pilot sonuçlarından sonra auto olabilir. İnsan onayı tüm müşteriler için tek yöneticiye yığılmaz; görev devri, SLA, ikinci onay ve vekâlet kapsamı modellenir.

---

## 23 | Güvenlik, operasyon ve dayanıklılık

### Canlıya çıkış için ürünle ilgili kontroller

MFA ve finans yetki ayrımı; role + resource + field yetkilendirme; RLS negatif testleri; secrets manager; TLS; şifreli yedek; imzalı kısa süreli dosya erişimi; webhook doğrulama/replay kontrolü; audit; rate limit; hassas log maskeleme. Supplier evrakları, traveler verisi ve herkese açık listing medyası aynı erişim sınıfı değildir.

Hukuki doğrulama çıktısı bir karar kaydı olmalı: hangi taraf satıcı/aracı/tahsil eden, hangi ürün için hangi belge gerekiyor, fatura kimin, saklama ve silme süreleri ne, hangi veri hangi ülkede işleniyor. Türkiye ödeme modeli TCMB kapsamıyla; yurt dışı cloud/AI aktarımı KVKK mekanizmalarıyla kontrol edilir [R13, R14]. Genel bir “KVKK uyumlu” etiketi yerine veri envanteri ve gerçek sözleşme akışı gerekir. Bu belge uygulanacak hukuki sonucu kesinleştirmez.

| Hedef | Pilot önerisi | Nasıl doğrulanır? |
|---|---|---|
| Booking API erişilebilirlik | Aylık %99,9 hedef | Kritik yol synthetic ölçümü; provider etkisi ayrı |
| İç quote gecikmesi | p95 < 800 ms | Hedef veri seti ve 20 eşzamanlı kullanıcı |
| Outbox gecikmesi | p95 < 30 saniye | En eski bekleyen olay alarmı |
| RPO / RTO | ≤15 dakika / ≤4 saat | Restore tatbikatı; elde edilen sonuç kaydı |
| Para mutabakatı | Günlük; farkın sahibi aynı iş günü | Açık fark yaşlandırma ve finans imzası |

Bunlar taahhüt değil ilk ölçüm hedefleridir; trafik, sağlayıcı ve operasyon bütçesiyle revize edilir. Kritik ödeme/tenant olayı on-call sorumlusuna gider. Runbook: satış durdurma, provider belirsizlik sorgusu, refund takibi, restore, veri sızıntısı müdahalesi ve müşteriye iletişim sahibi.

**Yayın stratejisi:** CI'da migration lint/deneme, domain ve contract tests; staging; feature flag; küçük tenant grubu; geri alma. Şema değişimi expand-contract; yeni kolon doldurulmadan eski okuma silinmez. Yedek almak kadar geri yükleme ve veri bütünlüğü testi zorunludur. Mutabakat veya tenant izolasyonu bozulduysa yeni kategori/özellik yayını durur.

---

## 24 | Sen + Codex: uygulanabilir çalışma planı

Kullanıcının kararı: ekip yok, sabit bütçe yok; birlikte geliştirme ve gerçekleşen giderleri izleme. Bu nedenle çok kişilik ekip takvimi kaldırıldı. İşler küçük, bağımlılık sıralı ve her biri gösterilebilir paketler halinde yürür. Geniş platform tek hamlede teslim sözüne dönüşmez.

| Aşama | Birlikte üreteceğimiz çıktı | Sonraki aşamanın şartı |
|---|---|---|
| S0 | Mevcut kod/veri inceleme; ilk gerçek villa örneği; ticari rol | Koruma/yeniden kurma kararı ve gerçek kullanım |
| S1 | Yerelde çalışan giriş, ilan, takvim, fiyat ve quote | Sen örnek verinin ve hesabın doğruluğunu görürsün |
| S2 | Aynı uygulamada supplier + agency opsiyonu ve rezervasyon | Eşzamanlılık testleri ve rol ayrımı geçer |
| S3 | PSP sandbox, ledger, iptal/iade ve mutabakat | Başarı kadar hata/telafi akışı da çalışır |
| S4 | 1 supplier, 3-5 birim, 1 agency ile kontrollü canlı | Sözleşme, destek sahibi, yedek ve kritik testler hazır |
| S5 | Basit supplier sitesi + B2C; altı dil; AI içerik taslakları | Gerçek kullanım ve işletilebilir maliyet |
| S6 | 5 supplier/3 agency; sonra otel veya deneyim | Kârlı tekrar kullanım ve düşük destek yükü |

**Sen:** Tedarikçi ilişkileri, ürün bilgisi, fiyat/kontrat kararı, hesap sahipliği, gerçek kullanıcı testi, canlı müşteri desteği ve mali onaylar. **Codex:** Analiz, kod, migration taslağı, UI, otomasyon, test, hata düzeltme ve kurulum belgeleri; mevcut araç ve erişim izinleri içinde. Codex'in bir oturumdaki çalışması sürekli 7/24 operasyon hizmeti sayılmaz. Hizmet kesintisi alarmı sana ulaşmalıdır.

### Giderleri nasıl yöneteceğiz?

Gerçek gider defteri: geliştirme aracı/model kullanımı + sunucu/DB/depolama + alan adı + e-posta/SMS + PSP işlem bedeli + gerekiyorsa dış uzman kontrolü. Geliştirme aracı kullanımıyla gelecekte ürünün AI API tüketimi ayrı izlenir. Yerel geliştirmeyle başlayıp ücretli servisi ihtiyaç oluştuğunda seçeriz. Fiyatlar seçildiği gün resmî sayfalardan doğrulanır; bu belge TL tutarı uydurmaz.

“Sabit bütçe yok”, sınırsız otomatik harcama izni değildir. Yeni ücretli hizmet seçildiğinde ücret modeli görünür olur. Ürün AI'sında tenant/job kotaları ve aylık kullanım uyarıları konur. İlk pilotta pahalı arama kümesi, mikroservis filosu, özel tema fabrikası ve tam ERP açılmaz. Takvim için ilk iki çalışan paket tamamlanınca gerçek ilerleme hızından tahmin üretilir.

---

## 25 | KPI, kabul testleri ve lansman kararı

### Ölçüm sözleşmesi

| KPI | Tanım | İlk değerlendirme |
|---|---|---|
| Aktive supplier | Doğrulanmış, yayınlı, gelecek 90 gün takvimi sahiplenilmiş | Haftalık kohort |
| Quote → booking | Onaylı booking / süresi sonuçlanmış quote | B2B/B2C ayrı; test kayıtları hariç |
| Opsiyon dönüşümü | Consumed hold / approved hold | Tedarikçi ve acente bazında |
| Gerçekleşen GMV | Dönem politikasıyla fulfilled brüt satış | Booked GMV ayrıca raporlanır |
| Platform net gelir | Kazanılmış ücret - ters kayıt/iadeler | GMV ile karıştırılmaz |
| Katkı | Net gelir - PSP - değişken destek/AI/risk/edinim | Rezervasyon ve kanal bazında |
| AI net fayda | Tasarruf edilen insan süresi - review/onarım süresi | Maliyet ve yanlış işlemle birlikte |

### P0 test paketi

- Aynı son villa/geceye 100 paralel hold: yalnızca bir başarılı tahsis; sayaçlar tutarlı.
- Ödeme ile expiry aynı anda: kapasite iki kez satılmaz; ödeme sonucu izlenir; gerekirse iade işi oluşur.
- Aynı webhook 20 kez ve farklı sırada: tek mali etki; geçmiş başarılı durum geriye düşmez.
- PSP/booking timeout: unknown statüsü; ikinci kör tahsilat/rezervasyon yok.
- Tenant A kullanıcısı B'nin API, export, arama, dosya ve AI belleğine erişemez.
- Kısmi iadeler toplamı capture tutarını aşamaz; posted journal dengeli ve tekildir.
- Onay sonrası tutar veya kaynak sürümü değişirse AI eylemi çalışmaz.
- Restore sonrası tahsis, ledger ve outbox tutarlılığı kontrol edilir.
- Çıkış günü, saat dilimi, minimum gece, çocuk yaşı, sıfır/üç ondalıklı para ve yuvarlama testleri geçer.
- Altı dilin checkout/iptal metni, AR RTL, canonical/hreflang ve ekran okuyucu akışı doğrulanır.

**Önerilen genel lansman kapısı:** Kontrollü küçük pilotun ardından en az 30 gerçek rezervasyonun tahsilat/teyit mutabakatı ve en az 10 gerçekleşmiş hizmet; ayrıca sandbox'ta başarısızlık senaryoları. Örneklem iş hacmine göre uyarlanır, güvenilirlik garantisi değildir. Açık P0, açıklanamayan finans farkı, tenant sızıntısı veya sahipsiz canlı destek varken genel açılış yapılmaz. Sen ticari/canlı kullanım kararını verirsin; Codex teknik test kanıtını sunar. Gerekli uzman görüşü ayrı iş kalemidir.

---

## 26 | İlk sprint backlog'u ve karar defteri

| ID | İş / teslimat | Sahip | Bitti sayılma koşulu |
|---|---|---|---|
| NX-001 | 1 supplier + 1 agency gerçek akış kaydı | Sen | Mevcut akış, ürün ve ilk kullanım isteği yazılı |
| NX-002 | Satıcı/tahsil eden/fatura matrisi | Sen + Codex | İlk işlem tipi ve PSP görüşme soruları net |
| NX-003 | Mevcut kod ve veri envanteri | Codex | Korunacak modüller ve migration riski listeli |
| NX-004 | Tenant ve rol threat model | Codex | Supplier/agency/HQ alan görünürlüğü matrisi |
| NX-005 | Quote hesaplama örnekleri | Codex + sen | Brüt/net, vergi, iade, FX için golden fixtures |
| NX-006 | Inventory proof | Codex | 100 paralel hold ve expiry testi geçer |
| NX-007 | PSP sandbox proof | Codex; hesap sende | Başarı, timeout, duplicate, iade izi gösterilir |
| NX-008 | Lustre/SSR akış prototipi | Codex; kullanım testi sende | Listing → quote → hold → sonuç; RTL örneği |
| NX-009 | OpenAPI ve migration başlangıcı | Codex | Şema/API aynı invariant'ları taşır |
| NX-010 | CI, trace, restore denemesi | Codex; hesap sende | Staging kurulumu yeniden üretilebilir |

### Kesinleştirilecek kararlar

D-01 İlk kategori/bölge: varsayılan villa/tatil evi; mevcut tedarik ağıyla doğrula. D-02 Çalışma modeli kesin: sen + Codex; yığını teknik denemeden sonra kilitle. D-03 Ticari rol: marketplace aracılığı mı, net alıp satış mı; her kanalda açık. D-04 Tahsilat: merchant ve alt üye modelini PSP ile doğrula. D-05 Dil/para seti: gerçek müşteri talebi ve ödeme yeteneğiyle doğrula. D-06 Partner: sertifikasyon ve erişim koşulunu kodlamadan önce al. D-07 Mevcut yazılım: veri kaybetmeyen aşamalı geçiş planı çıkar.

### Sonraki teknik paketin sınırı

Bu blueprint kabul edilen kararlarla v2.1 uygulama paketine dönüşür: çalıştırılıp test edilmiş migration'lar, RLS politikaları ve seed; makine doğrulanmış OpenAPI; Gleam modül/typed domain tasarımları; Lustre wireframe ve component states; provider contract test fixtures; job/tool JSON şemaları ve eval setleri. Bugünkü taslağın hiçbir tablo veya endpoint'i çalıştırılmış yazılım diye sunulmaz.

**Yönetim önerisi:** Kaynakları ilk güvenilir ticaret döngüsüne ayır. Her iki haftada çalışan akış göster; her ay gerçek katkı ve operasyon yükünü ölç. Vizyonun genişliği mimaride yaşasın, aynı anda açılan ürün sayısında değil.

---

## 27 | Kaynaklar ve doğrulama notları

Kontrol tarihi: 7 Eylül 2026. Kaynaklar teknik kabiliyet veya ürünün kendi beyanı için kullanıldı; bağımsız performans, pazar liderliği, fiyat ya da NEXUS'a erişim garantisi olarak kullanılmadı. Bu belgedeki roadmap, sayısal pilot eşikleri ve mimari kararlar özgün öneridir.

- **Girdi:** NEXUS_TravelTech_Master_Plan.pdf, kullanıcı tarafından sağlanan v1, 21 sayfa. Tam metni incelendi; değerlendirme tablosu kaynak sayfalara işaret eder.
- **[R1] Gleam:** Dil, BEAM/Erlang ortamı ve JavaScript hedefi. [Resmî site](https://gleam.run/).
- **[R2] Lustre:** UI ve server-side HTML yetenekleri. [Resmî dokümantasyon](https://lustre.hexdocs.pm/).
- **[R3] PostgreSQL RLS:** Policy, default-deny ve bypass sınırları. [Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html).
- **[R4] PostgreSQL locking:** Satır kilitleri ve eşzamanlılık. [Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html).
- **[R5] Booking.com:** Supply Connectivity ve Demand ayrımı. [API portalı](https://developers.booking.com/) ve [Demand başlangıç](https://developers.booking.com/demand/docs).
- **[R6] Booking.com:** API bazlı canlıya geçiş ve sertifikasyon. [Going Live](https://developers.booking.com/connectivity/docs/going_live).
- **[R7] Param:** Pazaryeri ve hakediş inceleme girdisi. [Pazaryeri](https://dev.param.com.tr/tr/pazaryeri) ve [SSS](https://dev.param.com.tr/tr/sik-sorulan-sorular). Arama sonucundaki resmî açıklamalar görüldü; tam sayfa açılışı hata verdi. Kesin method/ödeme yeteneği teyit edilmedi.
- **[R8] HotelRunner:** Rezervasyon push/pull ve acknowledgement. [Reservation API](https://developers.hotelrunner.com/custom-apps/xml-api/reservations).
- **[R9] Tourplan:** Teklif, fiyat kuralları, operasyon ve finans bütünlüğü. [DMC solution](https://www.tourplan.com/solutions/destination-management-company-solution/). Çıkarım: kontratlı fiyat motoru ve acente akışı birlikte tasarlanmalı.
- **[R10] Mews:** 27 Mayıs 2026 tarihli OS duyurusu. [Resmî basın açıklaması](https://www.mews.com/en/press/mews-operating-system-unfold-2026). Pazarlama beyanıdır; performans iddiaları NEXUS'a taşınmadı.
- **[R11] Google:** Dil alternatifleri ve hreflang. [Localized versions](https://developers.google.com/search/docs/specialty/international/localized-versions).
- **[R12] ElektraWeb:** Ürün kapsamı için incelenen resmî sayfa. [Resmî site](https://elektraweb.com/). Ayrıntılı API/entegrasyon desteği bu çalışmada doğrulanmadı.
- **[R13] TCMB:** Ödeme hizmetleri düzenleme çerçevesi. [Genel bakış](https://www.tcmb.gov.tr/wps/wcm/connect/TR/TCMB%20TR/Main%20Menu/Temel%20Faaliyetler/Odeme%20Hizmetleri/Genel%20Bakis).
- **[R14] KVKK:** Yurt dışı aktarım standart sözleşme mekanizmaları. [Resmî duyuru ve belgeler](https://www.kvkk.gov.tr/Icerik/7938/Standart-Sozlesmeler-ve-Baglayici-Sirket-Kurallarina-Iliskin-Dokumanlar-Hakkinda-Kamuoyu-Duyurusu).
- **[R15] HotelRunner:** PMS, satış ve otomasyon ürün ailesi. [Resmî site](https://hotelrunner.com/). Arama üzerinden ürün kapsamı görüldü; rezervasyon davranışında R8 esas alındı.
- **[R16] OpenTable:** [Doküman portalı](https://docs.opentable.com/). Portal açıldı, içerik alınamadı. Özellik ve ticari erişim iddiası için kullanılmadı.

**Okuma anahtarı:** “Kaynak” dış doğrulamayı, “öneri” tasarım kararını, “varsayım” eksik iş bilgisini, “kapı” ilerlemeden önce kanıtlanacak koşulu gösterir. Bu ayrım, v2'yi uygulanabilir tutarken belirsizliği gizlememek içindir.
