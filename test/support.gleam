//// Shared parallel-safe test helpers — Gleam bridge to the
//// `nexus_test_env` Erlang module (src/nexus/erl/nexus_test_env.erl).
////
//// Env tests (SECRET_KEY_BASE*, NEXUS_CONFIG_KEY, CSP_REPORT_ONLY) run under
//// a named lock with panic-safe restore; session tests use unique users.
//// This keeps gleeunit's process-global state (OS env + shared account
//// counters in auth.users) from leaking between parallel tests.
////
//// Contract and decision table: docs/testing-parallel-safe-helpers.md
//// Acente muadili: acente projesindeki test/support.gleam ile birebir aynı
//// sözleşme (AGENTS.md sözleşme eşitliği).

import nexus/database
import pog
import wisp

@external(erlang, "nexus_test_env", "with_lock")
pub fn with_lock(name: a, owner: b, body: fn() -> c) -> c

@external(erlang, "nexus_test_env", "with_env")
pub fn with_env2(
  name: a,
  updates: List(#(String, EnvUpdate)),
  body: fn() -> c,
) -> c

pub type EnvUpdate {
  EnvSet(String)
  EnvUnset
}

pub fn env_set(value: String) -> EnvUpdate {
  EnvSet(value)
}

pub fn env_unset() -> EnvUpdate {
  EnvUnset
}

/// Test başına benzersiz admin hesabı e-postası (paralel sayaç yarışlarını
/// önler): parallel-<tag>-<rand>@nexus.local. auth.users email'i GLOBAL
/// UNIQUE'tir; benzersiz hesap hem email çakışmasını hem failed_attempts
/// yarışını önler.
@external(erlang, "nexus_test_env", "unique_username")
pub fn unique_username(tag: String) -> String

/// Sabit test organizasyonu: unique kullanıcıların tenant_id'si buna bağlıdır.
const fixture_tenant_id = "00000000-0000-0000-0000-000000000001"

/// Test için benzersiz platform hesabı yaratır (idempotent upsert). Fixture
/// owner yetkisi ister: nexus_app auth.users tablosuna yazamaz; platform DB
/// testleri de PGOWNER ile koşar (scripts/test.ps1).
pub fn create_unique_admin(db: pog.Connection, email: String) -> Nil {
  // `|>` `<>`'dan öncelikli olduğu için SQL, boruya girmeden önce tek
  // ifadeye bağlanmalı; aksi halde `<> fixture_tenant_id |> pog.query()` gibi
  // bir ifade boruya gömülür.
  let org_sql =
    "insert into core.organizations(id, legal_name) values ('"
    <> fixture_tenant_id
    <> "', 'NEXUS Test Organization') on conflict (id) do update set legal_name = excluded.legal_name"
  let _ = org_sql |> pog.query() |> pog.execute(db)

  let user_sql =
    "insert into auth.users(tenant_id, email, display_name, role, password_hash) values ('"
    <> fixture_tenant_id
    <> "', $1, 'Parallel Test Admin', 'owner', crypt('admin123456', gen_salt('bf'))) on conflict (email) do update set display_name = excluded.display_name, role = excluded.role, password_hash = excluded.password_hash, failed_attempts = 0, locked_until = null"
  user_sql
  |> pog.query()
  |> pog.parameter(pog.text(email))
  |> pog.execute(db)
  |> fn(_) { Nil }
}

/// Benzersiz kullanıcı yaratan + oturum açan ve blok sonunda oturumu kapatan
/// yardımcı. Paralel güvenli oturum testlerinin ortak deseni. Giriş, platform
/// sözleşmesi olan auth.login DB fonksiyonu üzerinden yapılır
/// (nexus/database.login).
pub fn with_unique_session(
  db: pog.Connection,
  tag: String,
  body: fn(String, String) -> a,
) -> a {
  let email = unique_username(tag)
  create_unique_admin(db, email)
  let session_token = wisp.random_string(48)
  let assert True = database.login(db, email, "admin123456", session_token)
  let result = body(email, session_token)
  // Logout başarısızlığı sessiz kalmaz: sözleşme "blok sonunda oturum kapalı"dır.
  let assert Ok(_) = database.logout(db, session_token)
  result
}
