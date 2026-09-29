# NEXUS TravelTech · Yerel geliştirme

## Güvenilirlik güncellemeleri

- 30 Eylül 2026: [güvenilirlik raporu](docs/reliability-2026-09-30.md). Tedarikçinin
  moderasyon onayı olmadan ilan yayınlamasını engelleyen koruma, bozuk durum geçiş
  fonksiyonu düzeltmesi ve `smoke.ps1` in 1.2.0 sözleşmesine uyarlanması.
- 15 Eylül 2026: [güvenilirlik raporu](docs/reliability-2026-09-15.md).
  Doğrulanmış sağlayıcı cevabı olmayan işlemlerin 503 döndürmesi ve hakediş kayıtlarının
  dondurulmuş tutarlara bağlanması.

Doğrulanmış satış bağlantısı tamamlanana kadar pazaryeri rezervasyonu 503 döndürür.
103 ve 104 migration'ları gerçek dış işlem olmadan başarı kaydını engeller ve muhasebe fişini dondurulmuş teklif tutarlarına bağlar.

Master blueprint'e bağlı Gleam + Lustre + PostgreSQL başlangıcı. Proje: `C:\laragon\www\Nexustraveltech`.

## Aç

- Yönetici: http://127.0.0.1:8081/admin
- Ön yüz: http://127.0.0.1:8081/
- Sağlık: http://127.0.0.1:8081/v1/health
- Ayarlar: http://127.0.0.1:8081/admin/settings

Hesap: `admin@nexus.local`. Rastgele başlangıç parolası proje kökündeki `.env` dosyasında `ADMIN_PASSWORD` satırındadır. Bu dosya Git tarafından dışlanır; paylaşılmamalıdır. `.env.example` gerçek parola içermez.

PowerShell 7 ile proje klasöründe:

```powershell
./scripts/start.ps1  # Arka planda başlat; pencere açmaz.
./scripts/dev.ps1    # Alternatif: terminalde çalıştır, Ctrl+C ile durdur.
```

PowerShell 7 kurulu değilse veya imza yürütme ilkesi betikleri engelliyorsa aynı
komutların `.cmd` sarmalayıcıları vardır. Bunlar işletim sistemi ayarına dokunmadan
yalnızca bu proje çağrısı için yürütme ilkesini geçici olarak atlar:

```cmd
scripts\start.cmd
scripts\dev.cmd
```

İki komut aynı anda kullanılmaz. Sunucu zaten çalışıyorsa `start.ps1` sağlık kontrolü yapıp mevcut adresi döndürür. Loglar `.local/server.log` ve `.local/server-error.log` altındadır. PostgreSQL ayrı bir süreçtir; Laragon'un diğer PostgreSQL veri klasörünü değiştirmez.

## Kurulum ve doğrulama

```powershell
./scripts/setup.ps1    # Parolalar, bağımsız DB kümesi, migration, ilk yönetici
./scripts/migrate.ps1  # Yalnız yeni migration'lar; checksum kontrolü
./scripts/test.ps1     # Format + Gleam testleri + DB izolasyon testleri
./scripts/smoke.ps1    # Çalışan sunucuda giriş/ilan/yayın/güvenlik testleri
./scripts/reservation-smoke.ps1 # Üç şirket, ayar yetkileri ve rezervasyon HTTP testi
./scripts/rotate-weak-passwords.ps1 # Bilinen zayıf parolaları döndürür, kalan varsa durur
```

Her komutun `scripts\` altında `.cmd` karşılığı vardır (`scripts\test.cmd` gibi).

Setup tekrar çalıştırılabilir; mevcut yöneticinin parolasını ve verilerini sıfırlamaz. Smoke testi GUID isimli kendi geçici ilanını oluşturur, doğrular ve yalnız o kayıt ile olaylarını temizler. DB izolasyon testleri transaction rollback kullanır.

## PostgreSQL bağlantısı

| Alan | Değer |
|---|---|
| Sunucu | 127.0.0.1 |
| Port | 5433 |
| Veritabanı | nexustraveltech |
| Uygulama rolü | nexus_app |
| Migration / yönetim rolü | nexus_owner |
| Parolalar | .env: PGPASSWORD / PGOWNER_PASSWORD |
| Veri klasörü | C:/laragon/data/nexustraveltech-postgresql |
| PostgreSQL ikilisi | Laragon'da kurulu 18.2 |

Küme UTF8, C locale ve SCRAM-SHA-256 kullanır; yalnız 127.0.0.1 dinler. Proje şemaları `core`, `auth`, `catalog`, `inventory`, `booking`, `finance`, `events`, `system`.

## Çalışan akış

Giriş → Genel bakış → Yeni ilan → Taslak kaydet → Yayınla → Ön yüzde görüntüle/ara → Yayından kaldır. Başlık/konum/kapasite/başlangıç fiyatı PostgreSQL'de saklanır. Yayın güncellemesi sürüm kontrolü, audit ve transactional outbox üretir. Ön yüz yalnız yayınlanmış ürünleri okur. Başlangıçta sahte ilan veya finans rakamı yoktur.

Gleam backend Wisp/Mist ile çalışır. Ön yüz ve panel gerçek Lustre bileşenleriyle SSR HTML üretir; formlar sunucudaki komutlara gönderilir. JavaScript SPA değildir. 6 para birimi ve 6 dil sözlüğü kayıtlıdır; mevcut arayüz Türkçedir, FX/çok dilli sayfa motoru henüz yoktur.

## Dosya haritası

- `src/nexustraveltech.gleam`: uygulama ve PostgreSQL havuzu.
- `src/nexus/router.gleam`: HTTP, oturum, rol, CSRF ve güvenlik başlıkları.
- `src/nexus/domain.gleam`: doğrulama ve integer para işlemleri.
- `src/nexus/database.gleam`: parametreli sorgular, scoped transaction.
- `src/nexus/view.gleam`: Lustre giriş/panel/katalog.
- `priv/static/app.css`: duyarlı arayüz.
- `db/migrations`: sürümlü şema; uygulandıktan sonra değiştirilmez.
- `docs/master-blueprint-v2.md`: onaylanan çalışma vizyonu.
- `docs/architecture.md`: kararlar ve kilitli paket sürümleri.
- `docs/production-gates.md`: sonraki paketler ve canlıya geçiş koşulları.

## Ağ ve kimlik doğrulama sınırları

- Hız sınırı ve denetim kaydı istemci kimliği olarak **socket peer adresini** kullanır. `X-Forwarded-For` ve `CF-Connecting-IP` yalnızca eşleşen peer `TRUSTED_PROXY_CIDRS` içindeyse okunur ve zincir en dış hoptan içe doğru ilk güvenilmeyen adrese açılır. `TRUSTED_PROXY_CIDRS` boşsa hiçbir yönlendirme başlığına güvenilmez.
- Platform seviyesindeki acente API çağrıları `NEXUS_API_KEY` ile doğrulanır. `NEXUS_CONFIG_KEY` kimlik doğrulaması için kabul edilmez; o anahtar yalnızca şifreli ayarların ana anahtarıdır. Sır karşılaştırması sabit zamanlıdır.
- `APP_PUBLIC_HOST` yalnızca `APP_ENV=production` iken zorunludur; eksikse uygulama açılışta açık hata verir.

## Kapsam sınırı

Takvim, tarih bazlı fiyat, opsiyon talebi/onayı, ödenmemiş kesin rezervasyon ve iptal artık uygulanmıştır. NEXUS yöneticisi pazaryeri POS/AI/e-posta/depolama ayarlarını, her acente yöneticisi kendi standart POS bilgilerini yönetir. Gizli ayarlar AES-256-GCM ile şirket/alan bağlamına bağlı şifrelenir; ekrana geri verilmez. NEXUS_CONFIG_KEY ayrı yedeklenmelidir.

Gerçek ParamPOS tahsilatı, pazaryeri dağıtımı, ledger posting, AI çalışanları ve tüm kategoriler henüz tamamlanmadı. Ayar girilmesi bu servisleri etkinleştirmez. Güncel ve doğrulanmış kapsam `docs/implementation-status.md` dosyasındadır. APP_ENV=development kontrolü aktiftir.

Kanal fiyat akışı da bu sınırın içindedir: `GET /api/metasearch/google-hotel-ads.xml` doğrulanmış tedarikçi fiyatı yayınlanana kadar **503** döndürür. Sabit kodlanmış fiyat, geçerlilik penceresi veya zaman damgasıyla 200 üretmez; aksi hâlde kanal uydurma müsaitliği doğrulanmış sayardı.

Kaynakların Apache ile yanlışlıkla sunulmaması için proje kökünde `.htaccess` erişimi kapatır. Bu uygulama PHP değildir; `nexustraveltech.test` otomatik Laragon virtual host'u yerine yukarıdaki Gleam sunucu adresi kullanılır.

Windows'ta Gleam `priv` sembolik bağlantı ister. `scripts/prepare-build.ps1`, Developer Mode gerektirmeyen proje içi directory junction'ları hazırlar. İşletim sistemi güvenlik ayarları değiştirilmez.

Üretim paketi denemesi: `gleam export erlang-shipment`. Bu paket oluşsa bile canlı operasyon kapıları ayrıca tamamlanmalıdır.
