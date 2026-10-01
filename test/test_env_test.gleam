//// nexus_test_env + support köprüsünün kendi-kendini-test eden paketi.
////
//// with_lock / with_env2 / unique_username safdır: her koşumda ve CI'da
//// (DB'siz) çalışır. DB gerektiren with_unique_session / create_unique_admin
//// testleri veritabanı erişilemezse [SKIP] ile atlanır; REQUIRE_TEST_DB=true
//// iken gürültülü kırılır (scripts/test.ps1 bu değişkeni açar). Sessiz yeşil
//// yalnızca CI'ın DB'siz birim modunda kabul edilir.

import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import nexus/database
import pog
import support.{
  create_unique_admin, env_set, env_unset, unique_username, with_env2, with_lock,
  with_unique_session,
}
import wisp

pub fn with_lock_returns_body_result_test() {
  with_lock("selftest_lock", "selftest_owner", fn() { 41 + 1 })
  |> should.equal(42)
}

pub fn with_env2_sets_and_restores_test() {
  with_env2("selftest_env", [#("NEXUS_TEST_ENV_PROBE", env_set("1"))], fn() {
    envoy.get("NEXUS_TEST_ENV_PROBE") |> should.equal(Ok("1"))
  })
  // Kapanışın DIŞINDA: env eski (yok) değerine döndü.
  envoy.get("NEXUS_TEST_ENV_PROBE") |> should.be_error
}

pub fn with_env2_restores_previous_value_and_returns_result_test() {
  envoy.set("NEXUS_TEST_ENV_PROBE2", "onceki")
  let result =
    with_env2("selftest_env2", [#("NEXUS_TEST_ENV_PROBE2", env_unset())], fn() {
      envoy.get("NEXUS_TEST_ENV_PROBE2") |> should.be_error
      "govde-sonucu"
    })
  // Kapanışın DIŞINDA: önceki değer geri geldi.
  envoy.get("NEXUS_TEST_ENV_PROBE2") |> should.equal(Ok("onceki"))
  result |> should.equal("govde-sonucu")
  envoy.unset("NEXUS_TEST_ENV_PROBE2")
}

pub fn unique_username_format_test() {
  let email = unique_username("selftest")
  email |> string.starts_with("parallel-") |> should.be_true
  email |> string.ends_with("@nexus.local") |> should.be_true
  email |> string.contains("selftest") |> should.be_true
  // İki çağrı çakışmamalı: paralel testler aynı hesaba dokunamaz.
  unique_username("selftest") |> should.not_equal(email)
}

fn database_required() -> String {
  "platform veritabani gereklidir: REQUIRE_TEST_DB=true iken DB erisilemez (scripts/test.ps1 kapisi)"
}

/// Fixture owner yetkisi ister (nexus_app auth.users tablosuna yazamaz);
/// platform DB testleri de PGOWNER ile koşar (scripts/test.ps1 → psql -U
/// $env:PGOWNER). Bağlantı kurulamazsa [SKIP] basar ve Error döndürür.
fn test_db() -> Result(pog.Connection, Nil) {
  let host = envoy.get("PGHOST") |> result.unwrap("127.0.0.1")
  let port =
    envoy.get("PGPORT")
    |> result.try(int.parse)
    |> result.unwrap(5433)
  let db_name = envoy.get("PGDATABASE") |> result.unwrap("nexustraveltech")
  let user = envoy.get("PGOWNER") |> result.unwrap("nexus_owner")
  let password =
    envoy.get("PGOWNER_PASSWORD")
    |> result.lazy_or(fn() { envoy.get("PGPASSWORD") })
    |> result.unwrap("")
  let pool_name = process.new_name("nexus_test_env_db")
  let config =
    pog.default_config(pool_name)
    |> pog.host(host)
    |> pog.port(port)
    |> pog.database(db_name)
    |> pog.user(user)
    |> pog.password(option.Some(password))
    |> pog.pool_size(2)
  case pog.start(config) {
    Error(_) -> {
      io.println("[SKIP] DB entegrasyon testi: pool başlatılamadı")
      Error(Nil)
    }
    Ok(_) -> {
      let db = pog.named_connection(pool_name)
      case pog.query("SELECT 1") |> pog.execute(db) {
        Ok(_) -> Ok(db)
        Error(_) -> {
          io.println("[SKIP] DB entegrasyon testi: veritabanı erişilemez")
          Error(Nil)
        }
      }
    }
  }
}

/// DB erişilemezken REQUIRE_TEST_DB=true ise gürültülü kırılır; değişken
/// yoksa [SKIP] (platform CI'sı DB'siz birim modu — .github/workflows/test.yml).
fn skip_gate() -> Nil {
  case envoy.get("REQUIRE_TEST_DB") {
    Ok(_) -> panic as database_required()
    Error(Nil) -> Nil
  }
}

pub fn with_unique_session_creates_and_closes_session_test() {
  case test_db() {
    Error(Nil) -> skip_gate()
    Ok(db) -> {
      let session_token =
        with_unique_session(db, "selftestsession", fn(_email, session_token) {
          database.session(db, session_token) |> should.be_ok
          session_token
        })
      // Kapanışın DIŞINDA: blok sonunda oturum kapatılmış olmalı.
      database.session(db, session_token) |> should.be_error
      Nil
    }
  }
}

pub fn create_unique_admin_is_idempotent_and_logins_test() {
  case test_db() {
    Error(Nil) -> skip_gate()
    Ok(db) -> {
      let email = unique_username("adminfixture")
      create_unique_admin(db, email)
      // İkinci çağrı aynı emaille çakmamalı (idempotent upsert).
      create_unique_admin(db, email)
      let token = wisp.random_string(48)
      database.login(db, email, "admin123456", token) |> should.be_true
      let _ = database.logout(db, token)
      Nil
    }
  }
}
