# Rakip taraması ve NEXUS öncelikleri — 7 Eylül 2026

Bu tarama yalnızca resmi ürün ve geliştirici dokümantasyonlarına dayanır. Amaç, NEXUS'un kopyalaması gereken ekranları değil, pilot müşteriye değer yaratacak kabiliyetleri belirlemektir.

## Pazar karşılaştırması

| Rakip | Resmi olarak öne çıkan yetenek | NEXUS için anlamı |
|---|---|---|
| [SiteMinder Channel Manager](https://www.siteminder.com/channel-manager/) | 450+ kanal, gerçek zamanlı envanter, PMS/RMS bağlantıları, merkezi rezervasyon ve ödeme akışı | Bağlantı katmanında idempotency, hata kuyruğu, acknowledgement ve sağlık göstergeleri ilk sınıf özellik olmalı. |
| [Cloudbeds Channel Manager](https://www.cloudbeds.com/channel-manager/) ve [Cloudbeds Platform](https://www.cloudbeds.com/hospitality-platform/) | PMS, kanal yöneticisi, booking engine, ödeme, açık API, dijital check-in ve konuk iletişimi | NEXUS'un modül ataması güçlü; ancak her modülün API sözleşmesi, yetkisi ve iş akışı da görünür olmalı. |
| [Mews Platform](https://www.mews.com/en-gb/products) | Bulut PMS, embedded payments, gelir yönetimi, konuk zekâsı ve mobil POS | Rezervasyon ve finans olaylarını tek bir ledger/outbox akışında tutmak; mobil uyum ve self-service akışını erken eklemek gerekir. |
| [HotelRunner Reservations API](https://developers.hotelrunner.com/custom-apps/xml-api/reservations) | Rezervasyon/iptal push-pull, acknowledgement ve kontrollü polling kuralları | Tedarikçi entegrasyonlarında sözleşme testleri, tekrar güvenliği, rate limit ve bağlantı logları zorunlu olmalı. |

## NEXUS'un farklılaşma alanı

NEXUS'un en güçlü birleşimi; T.C. kimlik ve belge doğrulama akışı, kategoriye göre ilan gereksinimleri, tedarikçiye atanmış modüller, merkezî Nexus operasyonu ve acente çalışma alanıdır. Bu akış rakiplerin genel PMS özelliklerinden daha yerel ve daha kontrollü bir tedarikçi onboarding deneyimi sağlar.

## Öncelikli geliştirme sırası

1. **Pilot güveni:** ParamPOS ödeme/geri dönüş/iade ve pazaryeri hakediş adaptörü; imzalı callback, idempotency ve mutabakat ekranı.
2. **Dağıtım güveni:** Tedarikçi bağlantı adaptörleri, rezervasyon acknowledgement, retry/backoff, outbox ve bağlantı sağlık ekranı. Onaylanan ilanların kendi acente sitelerine yayınlanması bu katmandan geçmeli.
3. **Gelir ve operasyon:** komisyon/markup, iptal politikası, ledger posting, günlük mutabakat, doluluk/pace ve temel gelir raporları.
4. **Konuk deneyimi:** mobil uyum, dijital check-in, WhatsApp/e-posta olayları ve self-service rezervasyon değişikliği.
5. **AI yönetimi:** çeviri işçisinin gerçek sağlayıcı adaptörleri, araç izinleri, bütçe limiti, insan onayı ve tüm kararların audit kaydı.
6. **Kapsam genişletme:** PMS/POS/ERP'nin tamamını ilk sürümde yeniden yazmak yerine villa, otel, tur, transfer, yat, restoran, SPA, uçak, hac/umre ve paket tur modüllerini ortak ürün/rezervasyon sözleşmeleri üzerinden aşamalı açmak.

## Rakiplerden alınacak teknik kabul kriterleri

- Her dış çağrı correlation id, idempotency key, timeout, retry ve son hata nedeni ile saklanır.
- Her rezervasyon ve ödeme olayı append-only audit/outbox kaydı üretir.
- Envanter, fiyat ve rezervasyon değişiklikleri için gerçek zamanlı webhook; webhook yoksa sağlayıcının rate limitine uyan polling uygulanır.
- Modül, departman, tedarikçi ve acente yetkileri tenant sınırları ile test edilir.
- Yönetici paneli entegrasyon sağlığını, bekleyen işleri ve insan onayı bekleyen kararları tek ekranda gösterir.

Bu belge, ürün kararlarını yönlendiren bir çalışma notudur; rakiplerin tüm özelliklerinin kısa sürede kopyalanması hedeflenmez.
