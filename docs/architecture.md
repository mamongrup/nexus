# NEXUS S0 mimarisi

Gleam 1.18.1 + Erlang, Wisp 2.2.2, Mist 6.0.3, Lustre 5.7.1, Pog 4.1.0, gleam_stdlib 1.0.5, gleam_json 3.1.0. Hex kararlı sürümleri 7 Eylül 2026 tarihinde sorgulandı; çözülmüş sürümler manifest.toml içinde kilitlidir. PostgreSQL mevcut Laragon ikilisi 18.2'dir, sunucunun en güncel patch sürümü olduğu iddia edilmez.

Ön yüz `src/nexus/view.gleam` içinde gerçek Lustre Element ağacıdır; sunucuda HTML'ye render edilir (SSR). Formlar HTTP ile Gleam komutlarına gider. Ayrı React/PHP katmanı ve sahte HTML panel yoktur. İlk aşamada JavaScript SPA/hydration eklenmedi.

Akış: router -> oturum/CSRF/rol -> domain validation -> Pog transaction -> PostgreSQL RLS -> audit/outbox trigger -> Lustre görünümü.

Özel ilan sorguları tek transaction içinde `SET LOCAL` eşdeğeri `set_config(...,true)` ile doğrulanmış session tenant/actor context'i kurar. Connection pool context'i başka isteğe taşınmaz. Public katalog yalnız SECURITY DEFINER `catalog.published()` projection'ını kullanır. Fonksiyonlar sabit search_path ile çalışır ve PUBLIC execution iptal edilmiştir.

App rolü `nexus_app`: superuser, owner, BYPASSRLS, CREATE ROLE/DB değildir. Auth tablolarını okuyamaz; oturum/login fonksiyonlarını çağırabilir. Tenant GUC'si tek başına saldırganın erişebildiği bir API değildir: server login sonucundan gelir. Yeni çok şirketli ağ ilişkileri açıldığında taraf/alan yetkisi ayrıca geliştirilecek.

Parola pgcrypto bcrypt cost 12 ile hash edilir. Başlangıç parolası yalnız yerel .env'dedir. Session token DB'de SHA-256 hash, tarayıcıda imzalı HttpOnly/Lax cookie; sekiz saat expiry ve logout revoke. Form token'ı imzalı cookieyle eşleşir ve Origin doğrulanır. Bilinen hesapta beş başarısız denemeden sonra 15 dakika kilit vardır. Internet için ayrıca IP/global rate limit gerekir.

Para bigint minor units; uygulama iki basamaklı ondalığı integer olarak parse eder. Altı seçilebilir para biriminin hepsi iki basamaklıdır. Quote veya döviz dönüşümü henüz yoktur.

Mevcut Laragon PostgreSQL kümesi locale hatası verdiğinden ona dokunulmadı. NEXUS kümesi `C:/laragon/data/nexustraveltech-postgresql`, 127.0.0.1:5433, UTF8/C locale, SCRAM-SHA-256. Apache'nin proje kökündeki kaynakları sunması .htaccess ile engellidir; NEXUS kendi loopback HTTP sunucusunda çalışır.

Resmî kaynaklar: https://gleam.run/ • https://hex.pm/packages/wisp • https://hex.pm/packages/mist • https://hex.pm/packages/lustre • https://hex.pm/packages/pog
