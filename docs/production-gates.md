# Üretim öncesi kapılar

Güncelleme: Aşağıdaki S0 başlangıç listesi tarihçedir. Takvim/opsiyon, ödenmemiş rezervasyon ve şifreli yönetici ayarları artık uygulanmıştır. Güncel çalışan kapsam ve açık işler `implementation-status.md` içindedir. Gerçek ödeme, finans ve canlıya çıkış kapıları hâlâ açıktır.

Bu teslimat S0, yerel geliştirilebilir temeldir. APP_ENV=development zorunlu, HTTP ve PostgreSQL yalnız loopback'e bağlıdır. Geliştirme kaydı ile canlı turizm ürünü yayın onayı aynı şey değildir.

Çalışan kapsam: yönetici oturumu, üç rolün sunucu kontrolü, ilan taslağı oluşturma, owner tarafından yayın/yayından alma, Lustre SSR katalog, arama, DB sağlık kontrolü, RLS, optimistic version kontrolü, audit/outbox.

Sonraki paketler:

1. Listing'in product/listing_version/translation olarak ayrılması; doğrulama belgeleri, medya ve sürümlü edit/onay. Mevcut catalog.properties S0 veri modelidir, kalıcı nihai şema değildir. Veri taşıma yeni migration ile yapılır.
2. Tarih bazlı rate plan, resource, atomik hold ve allocation_day; 100 paralel son-stok testi ve expiry/payment yarışı. Şimdiki inventory/booking tabloları yalnız schema başlangıcıdır; satış komutu yoktur.
3. Quote snapshot, kontratlı fiyat, PSP sandbox, idempotency ve telafi. Ödeme bilgisi/anahtarı şu an yoktur; gerçek tahsilat yapılmaz.
4. Book/account modeli, dengeli posting procedure, reversal ve mutabakat. finance tablosu olması ledger motorunun tamamlandığı anlamına gelmez. Runtime'a finans yazma yetkisi verilmedi.
5. MFA, kullanıcı/rol yönetimi, giriş hız limiti, parola sıfırlama, session housekeeping, audit retention, görev retry/dead-letter ve operasyon sorumlusu.
6. TLS, proxy güven sınırı, cookie Secure, farklı origin konfigürasyonu, CSP/CSRF tekrar doğrulaması; secret manager; ayrı ortamlar; güncel PostgreSQL patch seviyesi; yedek/restore ve CI.
7. Dil çevirileri, AR RTL ve altı dil uçtan uca QA. Şu an altı locale kayıtlı, arayüz Türkçedir. Altı döviz başlangıç fiyatında seçilebilir; canlı FX/tahsilat değildir.

Tüm bu işler master blueprint'teki kabul kapılarıyla açılır. Üretim guard'ını kaldırmak tek başına canlıya çıkış hazırlığı değildir.
