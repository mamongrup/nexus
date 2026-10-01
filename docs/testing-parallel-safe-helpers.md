# Paralel güvenli test yardımcıları — platform rehberi (NEXUS)

gleeunit testleri **aynı VM'de paralel süreçlerde** koşar. Süreç-genel durumu
(OS env, paylaşılan DB hesapları) mutasyona uğratan her test, koşumlar arasında
kanıtlanmış şekilde sızar: bir testin bıraktığı `SECRET_KEY_BASE` sonraki
testin farklı bir dünyada çalışmasına, iki paralel testin aynı hesabın
`failed_attempts` sayaçlarında yarışması lockout kesinliğini bozar. Bu
rehberdeki üç yardımcı bu iki tehlike sınıfını kapatır.

Platformun mevcut test bölünmesi: `gleam test` **saf birim testleri** koşar
(CI'da Postgres servis edilmez — [test.yml](../.github/workflows/test.yml));
DB testleri **sıralı** psql zinciridir ([scripts/test.ps1](../scripts/test.ps1),
`PGOWNER` rolüyle). Gleam tarafında env'e veya ortak hesap durumuna dokunacak
her yeni test bu üçlüyü kullanmak zorundadır.

Sözleşme eşitliği: üçlü, acente projesindeki muadiliyle **birebir aynıdır**
(AGENTS.md tedarikçi sözleşme eşitliği ilkesi) — aynı yardımcı adları, aynı
anlamlar, aynı `unique_username` biçimi. Acente tarafındaki rehber:
`acente/docs/testing-parallel-safe-helpers.md`.

Uygulama: [src/nexus/erl/nexus_test_env.erl](../src/nexus/erl/nexus_test_env.erl)
— Gleam tarafındaki pub bağları paylaşılan
[test/support.gleam](../test/support.gleam) modülündedir. Test dosyanıza
bağlamak için:

```gleam
import support.{create_unique_admin, env_set, env_unset, unique_username, with_env2, with_lock, with_unique_session}
```

## Yardımcılar

### `with_lock(name, owner, body)` — adlandırılmış kilit

Erlang `global:set_lock` ile serileştirir; gövde panik atsa bile kilit
`after` bloğunda serbest kalır ve **gövdenin sonucunu döndürür** (ezmez).

```gleam
with_lock("lockout_kesinligi", "lockout_owner", fn() {
  // Bu bölge aynı anda yalnız bir testte koşar.
  kesinlik_gerektiren_adimlar()
})
```

Ne zaman: iki test aynı anda dokunamaz — hesap-çapraz sayaçlar
(`auth.users.failed_attempts`: 4 deneme → 15 dakika kilidi), tek-of
kaynaklar, sıra-duyarlı kurulumlar.

### `with_env2(name, updates, body)` — kilitli, panik-güvenli env kapsamı

`updates: List(#(String, EnvUpdate))` içindeki değişkenlerin eski değerlerini
kaydeder, `body` bitince (panik dahil) **hepsini eski haline döndürür**.
`EnvUnset` değişkeni kaldırır; pencereyi kapatmak için `env_unset()`,
açmak/set etmek için `env_set(v)` kullanılır.

```gleam
with_env2("secret_rotation_window", [
  #("SECRET_KEY_BASE_PREVIOUS", env_set(old_secret)),
  #("SECRET_KEY_BASE", env_set(simulate.default_secret_key_base)),
], fn() { pencere_acikken_davranis(db) })
```

Ne zaman: `SECRET_KEY_BASE`, `SECRET_KEY_BASE_PREVIOUS`, `NEXUS_CONFIG_KEY`,
`CSP_REPORT_ONLY` gibi süreç-genel env'e dokunan her test. İki env testi aynı
anda koşamaz; kilit adı test alanını tanımlar (ör. `"secret_rotation_window"`).

### `with_unique_session(db, tag, body)` — benzersiz hesap + oturum

`parallel-<tag>-<rastgele>@nexus.local` e-postasıyla platform hesabını upsert
eder (`create_unique_admin`), sözleşme fonksiyonu `auth.login` üzerinden
(`nexus/database.login`) oturum açar, `body(email, session_token)`'ı koşar ve
blok sonunda **`database.logout` yapar**. Şifre her zaman `admin123456`.

```gleam
with_unique_session(db, "controlpanel", fn(email, session_token) {
  ... simulate.cookie(...) |> router.handle(db, origin) ...
})
```

Ne zaman: oturumlu istek gerektiren her DB testi. `auth.users.email`
**GLOBAL UNIQUE**'tir; benzersiz hesap hem email çakışmasını hem
`failed_attempts` yarışını önler.

Dikkat: fixture **owner yetkisi ister** — `nexus_app` `auth.users` tablosuna
yazamaz; platform DB testleri de `PGOWNER` ile koşar (`scripts/test.ps1`).
Benzersiz kullanıcılar sabit test organizasyonuna
(`00000000-0000-0000-0000-000000000001`) bağlanır.

### `unique_username(tag)` + `create_unique_admin(db, email)` — login-akışı testleri için

`with_unique_session` oturumu **önceden** açtığı için login akışının
kendisini test edenler bunu kullanamaz; onlar hesabı kendi açar, formu/servisi
kendi dener:

```gleam
let email = unique_username("loginsuccess")
create_unique_admin(db, email)
// ... login POST bu e-posta ile ...
```

## Karar tablosu

| Test... | Kullanım |
|---|---|
| Oturumlu istek yapıyor | `with_unique_session(db, "etiket", fn(email, token) { ... })` |
| Login/lockout akışını doğruluyor | `unique_username` + `create_unique_admin` (gerekirse `with_lock`) |
| OS env'e dokunuyor | `with_env2` (kilit adı: test alanı) |
| Hesap-çapraz kesinlik / serileştirme | `with_lock` |
| Hiçbiri — saf hesaplama | Yardımcı gerekmez |

## Kritik tuzak: "restore sonrası" davranış kapsam İÇİNDE test edilemez

`with_env2(..., fn() { ... })` kapanışına koyduğunuz her şey **env hâlâ
değiştirilmişken** koşar. "Env eski değerine döndükten sonra X davranışı"
iddiası kapanışın **dışına** yazılmalıdır — gövde bunu döndürür:

```gleam
// 1-3: pencere açıkken davranış (kapanış içinde).
let session_token =
  with_env2("secret_rotation_window", [...], fn() { pencere_govdesi(db) })

// 4: pencere kapandı (restore edildi) — kapanışın DIŞINDA.
eski_tarayici(session_token) |> router.handle(db, origin) |> should_status(403)
```

Bu hata acente tarafında derlenmiş artefakttan yakalanmıştı: adım 4 kapanış
içindeyken test "pencere kapalıyken 403" bekleyip 303 alıyordu.

## DB entegrasyon testleri ve `REQUIRE_TEST_DB`

Üçlünün DB bacağı (`with_unique_session`, `create_unique_admin`) kendi-kendini
[test/test_env_test.gleam](../test/test_env_test.gleam) paketiyle doğrulanır.
Kapı kuralı:

- `REQUIRE_TEST_DB=true` → DB erişilemezse test **gürültülü kırılır**.
  [scripts/test.ps1](../scripts/test.ps1) bu değişkeni açar; platformun tam
  kapısında DB garantidir.
- Değişken yok (CI: `test.yml` DB'siz `gleam test`) → DB testleri `[SKIP]`
  mesajıyla atlanır. Sessiz yeşil yalnızca CI'ın DB'siz birim modunda
  kabul edilir; DB'yi CI'a eklerken (postgres service + `REQUIRE_TEST_DB=true`)
  atlama ortadan kalkar.

Platformda bugün paylaşılan fixture hesabı yoktur (SQL DB testleri kendi
kapsamlı verisini yaratır). Paylaşılan bir hesap fixture'ı eklenirse, acente
tarafındaki paylaşılan-hesap statik kontrolü de
(`scripts/check-test-shared-admin.ps1` muadili) birlikte eklenmelidir;
benzersiz kullanıcı kuralı o noktaya kadar tek korumadır.

## Yeni test şablonları

### 1) Env-duyarlı platform testi

```gleam
pub fn feature_reads_env_test() {
  with_env2("feature_env_alani", [#("MY_FLAG", env_set("on"))], fn() {
    davranis_on_modunda(db)
  })
  // Kapanışın dışında: MY_FLAG eski haline döndü.
  davranis_normal_modunda(db)
}
```

### 2) Oturumlu uç testi (en yaygın)

```gleam
pub fn admin_something_requires_session_test() {
  case test_db() {
    Error(Nil) -> skip_gate()
    Ok(db) -> {
      with_unique_session(db, "somethingshort", fn(_email, session_token) {
        let resp =
          simulate.browser_request(http.Get, "/admin/something")
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> router.handle(db, origin)
        resp.status |> should.equal(200)
      })
    }
  }
}
```

### 3) Login-akışı testi (benzersiz hesap, oturum yardımcısız)

```gleam
pub fn login_flow_test() {
  case test_db() {
    Error(Nil) -> skip_gate()
    Ok(db) -> {
      let email = unique_username("loginflow")
      create_unique_admin(db, email)
      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([#("email", email), #("password", "admin123456")])
        |> router.handle(db, origin)
      resp.status |> should.equal(303)
    }
  }
}
```

## Kabul kontrol listesi

- [ ] Test süreç-genel durum mutasyona uğratıyor mu? → üç yardımcıdan biri zorunlu.
- [ ] Paylaşılan bir hesap fixture'ı ekleniyorsa gerekçe var mı?
  (Varsayılan: yok; benzersiz kullanıcı kuralı zorunlu.) Paylaşılan hesap
  geliyorsa acente muadilindeki statik kontrol de eklenir.
- [ ] "Env restore edildi" iddiası `with_env2` kapanışının **dışında** mı?
- [ ] Bloklar `body` sonucunu döndürüyor mu (sonuç ezme yok)?
- [ ] DB gerektiren test `REQUIRE_TEST_DB` kapısına bağlı mı? (test.ps1'de
  gürültülü, CI'da `[SKIP]`.)
- [ ] Üçlüde yapılan her değişiklik acente muadiliyle karşılaştırıldı mı?
  (Sözleşme eşitliği — tek taraflı farklılaştırma yasaktır.)
