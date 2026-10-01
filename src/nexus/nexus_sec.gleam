//// Güvenlik politikaları — saf fonksiyonlar.
////
//// CSP başlık stratejisi ve SECRET_KEY_BASE sır dönemi (era) çözümlemesi
//// burada saf olarak modellenir; router bu modülü çağırır. Saf olmanın
//// nedeni CI'ın `gleam test` adımının veritabanı olmadan koşmasıdır:
//// politika kararları yan etkisiz fonksiyonlar olarak test edilir, DB'ye
//// dokunan uçlar (rapor kaydı, çerez damgası) ayrı tutulur.

import gleam/list
import gleam/string

/// Sıkılaştırılmış CSP politikası. `report-uri` ihlalleri /api/csp-report
/// ucuna gönderir; enforcing modda da rapor akışı sinyal olarak kalır.
/// Kademeli geçiş: önce CSP_REPORT_ONLY=true ile raporla, ihlal akışı
/// sakinleşince enforcing moda al (bkz. docs/security-deployment-checklist).
pub const csp_policy = "default-src 'self'; img-src 'self' data: https:; media-src 'self' data: https: blob:; frame-src 'self' https://www.youtube.com https://www.youtube-nocookie.com https://player.vimeo.com; style-src 'self' 'unsafe-inline'; font-src 'self' data: https:; form-action 'self'; frame-ancestors 'none'; base-uri 'none'; report-uri /api/csp-report"

/// Kime hangi CSP başlığı gitmeli? Report-only kipte sıkılaştırılmış
/// politika yalnızca raporlama başlığıyla gider (enforcing başlık yok);
/// sayfalar etkilenmez, ihlaller toplanır. Enforcing kipte başlık
/// uygulanır ve rapor akışı sinyal olarak sürer.
pub fn csp_headers(report_only: Bool) -> List(#(String, String)) {
  case report_only {
    True -> [#("content-security-policy-report-only", csp_policy)]
    False -> [#("content-security-policy", csp_policy)]
  }
}

/// `CSP_REPORT_ONLY` env değerinin kip karşılığı. Yalnızca birebir "true"
/// etkin sayılır (=="1" gibi near-miss yazımlar yanlışlıkla kıp açmaz).
pub fn report_only_mode(env_value: String) -> Bool {
  case env_value {
    "true" -> True
    _ -> False
  }
}

/// Sır dönemleri: current (SECRET_KEY_BASE) ve previous
/// (SECRET_KEY_BASE_PREVIOUS, rotasyon penceresi).
pub type SecretEra {
  Current
  Previous
}

/// current imzası geçerliyse hiçbir zaman pencere açılmaz; yalnızca current
/// geçersizken previous tanınıyorsa previous kabul edilir. İkisi de
/// geçersizse istek anonim akar (Error) — pencere asla oturum üretmez. Saf hali: çerez doğrulama sonuçları parametredir.
pub fn resolve_secret_era(
  current_valid: Bool,
  previous_valid: Bool,
) -> Result(SecretEra, Nil) {
  case current_valid, previous_valid {
    True, _ -> Ok(Current)
    False, True -> Ok(Previous)
    _, _ -> Error(Nil)
  }
}

/// Previous-era kabulünden sonra çerez yeniden damgalanmalı mı? Login
/// (303 -> /admin) ve logout (303 -> /login) yanıtlarının kendi
/// nexus_session set-cookie yönergesi kazanır: damga login'in fresh
/// token'ını eski token'la ezemez ve logout'un silme (max_age=0)
/// yönergesi diriltilemez.
pub fn should_restamp(status: Int, location: String) -> Bool {
  let location = string.trim(location)
  case status == 303 && { location == "/login" || location == "/admin" } {
    True -> False
    False -> True
  }
}

/// Başlık listesini cevaba uygular (sırayla).
pub fn apply_headers(
  set_header: fn(a, String, String) -> a,
  res: a,
  headers: List(#(String, String)),
) -> a {
  list.fold(headers, res, fn(acc, pair) {
    let #(name, value) = pair
    set_header(acc, name, value)
  })
}
