//// nexus_sec politika birim testleri — DB'siz, CI'da koşar.
////
//// CSP başlık kipi, sır dönemi çözümlemesi ve yeniden damgalama kararı
//// saf fonksiyonlar olarak burada doğrulanır. Uçtan uca (DB + canlı
//// sunucu) doğrulama scripts/security-smoke.ps1 ve test/*.sql'dedir;
//// çünkü platform CI'ının gleam test adımı veritabanısız koşar.

import gleam/list
import gleam/string
import nexus/nexus_sec

// --- CSP başlık stratejisi --------------------------------------------------

pub fn csp_report_only_mode_sends_only_report_header_test() {
  let headers = nexus_sec.csp_headers(True)
  assert list.length(headers) == 1
  let assert [#(name, value)] = headers
  assert name == "content-security-policy-report-only"
  assert string.contains(value, "default-src 'self'")
  // Rapor-only başlığı da ihlalleri /api/csp-report'a göndermelidir.
  assert string.contains(value, "report-uri /api/csp-report")
}

pub fn csp_enforcing_mode_sends_enforcing_header_test() {
  let headers = nexus_sec.csp_headers(False)
  assert list.length(headers) == 1
  let assert [#(name, value)] = headers
  assert name == "content-security-policy"
  assert !string.contains(name, "report-only")
  assert string.contains(value, "report-uri /api/csp-report")
}

pub fn csp_policy_keeps_hardening_directives_test() {
  assert string.contains(nexus_sec.csp_policy, "frame-ancestors 'none'")
  assert string.contains(nexus_sec.csp_policy, "base-uri 'none'")
  assert string.contains(nexus_sec.csp_policy, "form-action 'self'")
  assert string.contains(nexus_sec.csp_policy, "object-src") == False
}

pub fn report_only_mode_accepts_only_exact_true_test() {
  assert nexus_sec.report_only_mode("true")
  assert !nexus_sec.report_only_mode("")
  assert !nexus_sec.report_only_mode("1")
  // Near-miss yazımlar kipi açmamalı: sessiz gevşeme yerine net durum.
  assert !nexus_sec.report_only_mode("TRUE")
  assert !nexus_sec.report_only_mode("True")
  assert !nexus_sec.report_only_mode("false")
  assert !nexus_sec.report_only_mode(" true")
}

// --- Sır dönemi (era) çözümlemesi -------------------------------------------

pub fn current_era_wins_even_when_previous_is_valid_test() {
  // current geçerliyken pencere asla açılmaz: previous varlığı davranışı
  // değiştiremez, aksi hâlde pencere kalıcı bir gevşeme olur.
  assert nexus_sec.resolve_secret_era(True, True) == Ok(nexus_sec.Current)
  assert nexus_sec.resolve_secret_era(True, False) == Ok(nexus_sec.Current)
}

pub fn previous_era_only_accepted_without_current_test() {
  assert nexus_sec.resolve_secret_era(False, True) == Ok(nexus_sec.Previous)
}

pub fn both_eras_invalid_leaves_request_anonymous_test() {
  // Pencere oturum üretmez; her iki imza da geçersizse istek anonim akar.
  assert nexus_sec.resolve_secret_era(False, False) == Error(Nil)
}

// --- Yeniden damgalama kararı -----------------------------------------------

pub fn login_and_logout_responses_are_not_restamped_test() {
  // Login (303 -> /admin) kendi fresh çerezini yazar; damga onu ezemez.
  assert !nexus_sec.should_restamp(303, "/admin")
  // Logout (303 -> /login) çerez silme (max_age=0) yönergesi taşır;
  // diriltme silmeyi geri alamaz.
  assert !nexus_sec.should_restamp(303, "/login")
}

pub fn ordinary_responses_are_restamped_test() {
  assert nexus_sec.should_restamp(200, "")
  assert nexus_sec.should_restamp(303, "/admin/listings")
  assert nexus_sec.should_restamp(404, "")
  // Konum boşsa 303 bile damgalanmalı: bilinmeyen yönlendirme fresh çerez
  // taşımıyor sayılır.
  assert nexus_sec.should_restamp(303, "")
}
