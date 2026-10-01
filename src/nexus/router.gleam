import envoy
import gleam/bit_array
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/http/response as http_response
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import lustre/element.{text}
import nexus/accounting_view
import nexus/agency_callback
import nexus/ai_generator
import nexus/ai_governance
import nexus/ai_hub_view
import nexus/booking_status
import nexus/calendar
import nexus/calendar_view
import nexus/campaigns_view
import nexus/category_admin
import nexus/checkin_view
import nexus/commercial_engine
import nexus/connection_requests_view
import nexus/contact_inbox
import nexus/contract
import nexus/crm_view
import nexus/database as db
import nexus/departments_view
import nexus/digital_twin
import nexus/domain
import nexus/einvoice_view
import nexus/finance_os
import nexus/fleet_view
import nexus/housekeeping_view
import nexus/hr_view
import nexus/listing_modules_view
import nexus/marketplace_view
import nexus/modules_view
import nexus/nexus_sec
import nexus/onboarding_view
import nexus/partners_view
import nexus/platform_control_view
import nexus/quality_view
import nexus/rateshopper_view
import nexus/settings
import nexus/site
import nexus/social_media_view
import nexus/storage
import nexus/supplier_performance_view
import nexus/tours_view
import nexus/users_view
import nexus/view
import pog
import simplifile
import wisp
import wisp/internal

pub fn handle(
  req: wisp.Request,
  conn: pog.Connection,
  origin: String,
  peer: String,
) -> wisp.Response {
  let allowed_host = case envoy.get("APP_ENV") {
    Ok("production") -> {
      let public_host = envoy.get("APP_PUBLIC_HOST") |> result.unwrap("")
      req.host == public_host
    }
    _ -> req.host == "127.0.0.1" || req.host == "localhost"
  }
  case allowed_host {
    False -> wisp.response(403) |> wisp.string_body("Forbidden host")
    True -> {
      use <- wisp.rescue_crashes
      use <- wisp.serve_static(req, under: "/static", from: "priv/static")
      let csrf =
        wisp.get_cookie(req, "nexus_csrf", wisp.Signed)
        |> result.unwrap(wisp.random_string(32))
      // CSP ihlal raporları ana dispatch'e girmez: kendi hız limiti ve
      // kapısı vardır, tarayıcı oturumu/CSRF gerektirmez.
      let response = case csp_report_request(req) {
        True -> handle_csp_report(req, conn, peer)
        False ->
          // SECRET_KEY_BASE rotasyon penceresi (çift sırlı doğrulama):
          // previous-era tanımlıysa ve oturum çerezi yalnız eski sır altında
          // doğrulanıyorsa istek previous bağlantıyla işlenir ve yanıt
          // current-era sır ile yeniden damgalanır; kullanıcı zorunlu
          // çıkışa düşmez. Pencere kapalıyken davranış değişmez.
          case rotate_secret(req) {
            Ok(#(migrated_req, session_token)) ->
              route(migrated_req, conn, csrf, origin, peer)
              |> wisp.set_cookie(
                migrated_req,
                "nexus_csrf",
                csrf,
                wisp.Signed,
                28_800,
              )
              |> restamp_session_cookie(
                with_secret(migrated_req, current_app_secret()),
                session_token,
              )
            Error(req) ->
              route(req, conn, csrf, origin, peer)
              |> wisp.set_cookie(req, "nexus_csrf", csrf, wisp.Signed, 28_800)
          }
      }
      response
      |> wisp.set_header("cache-control", "no-store")
      |> wisp.set_header("x-content-type-options", "nosniff")
      |> wisp.set_header("x-frame-options", "DENY")
      |> wisp.set_header("referrer-policy", "same-origin")
      |> fn(res) {
        nexus_sec.apply_headers(
          wisp.set_header,
          res,
          nexus_sec.csp_headers(csp_report_only()),
        )
      }
    }
  }
}

fn html(body: String) {
  wisp.ok() |> wisp.html_body(body)
}

// ---------------------------------------------------------------------------
// CSP ihlal raporlama (POST /api/csp-report).
//
// CSP_REPORT_ONLY kademeli geçişinde ihlalleri toplar; enforcing modda da
// rapor akışı sinyal olarak sürer. Kayıt hedefi nexus.security_events
// (db/migrations/186); günlük özet scripts/daily-csp-report.ps1.
// ---------------------------------------------------------------------------

fn csp_report_request(req: wisp.Request) -> Bool {
  case req.method, wisp.path_segments(req) {
    http.Post, ["api", "csp-report"] -> True
    _, _ -> False
  }
}

fn handle_csp_report(
  req: wisp.Request,
  conn: pog.Connection,
  peer: String,
) -> wisp.Response {
  // Abuselere karşı: istemci başına dakikada 20 rapor.
  case
    rate_limited("csp-report:" <> request_client_id(req, peer), 20, 60_000.0)
  {
    True ->
      wisp.response(429)
      |> wisp.set_header("retry-after", "60")
      |> wisp.string_body("")
    False ->
      case request.get_header(req, "content-type") {
        Ok("application/csp-report" <> _) ->
          case wisp.read_body_bits(req) {
            Error(_) -> wisp.response(400) |> wisp.string_body("")
            Ok(bits) -> {
              let size = bit_array.byte_size(bits)
              // 16 KB üstü rapor zaten bozuk/suistimal; kaydetmeden reddet.
              case size > 16_384 {
                True -> wisp.response(413) |> wisp.string_body("")
                False -> {
                  let _ = record_csp_violation(conn, req, peer, bits)
                  wisp.response(204) |> wisp.string_body("")
                }
              }
            }
          }
        // Diğer içerik tipleri kabul edilmez (report-uri spec'i JSON
        // gövdeyi application/csp-report ile gönderir).
        _ -> wisp.response(415) |> wisp.string_body("")
      }
  }
}

fn record_csp_violation(
  conn: pog.Connection,
  req: wisp.Request,
  peer: String,
  bits: BitArray,
) -> Nil {
  let body_text = bit_array.to_string(bits) |> result.unwrap("")
  let _ =
    "select nexus.record_security_event($1, $2, $3, $4, $5, $6, $7, $8::jsonb)"
    |> pog.query()
    |> pog.parameter(pog.text(request_id(req)))
    |> pog.parameter(pog.text(request_client_id(req, peer)))
    |> pog.parameter(pog.text(http.method_to_string(req.method)))
    |> pog.parameter(pog.text("csp-report"))
    |> pog.parameter(pog.text("csp_violation"))
    |> pog.parameter(pog.text("info"))
    |> pog.parameter(pog.text("observed"))
    |> pog.parameter(pog.text(body_text))
    |> pog.execute(conn)
  Nil
}

fn request_id(req: wisp.Request) -> String {
  let supplied =
    request.get_header(req, "x-request-id")
    |> result.unwrap("")
    |> string.trim
    |> string.slice(0, 128)
  case supplied {
    "" -> "req-" <> wisp.random_string(24)
    value -> value
  }
}

// ---------------------------------------------------------------------------
// SECRET_KEY_BASE rotasyon penceresi (çift sırlı doğrulama).
//
// Rotasyon, eski sır altında imzalanmış nexus_session çerezlerinin tümünü
// geçersiz kılardı: kullanıcılar bir sonraki istekte anonim kalır ve zorunlu
// çıkış yapardı. Bu pencere eski imzayı tanıyıp isteği current-era
// bağlantıyla işler ve yanıt çerezini yeni sır ile yeniden damgalar.
// Dönem kararı nexus_sec.resolve_secret_era saf fonksiyonundadır.
//
// Kapsam notu: pencere yalnızca oturum çerezini kurtarır; sırrın tümden
// sızdığı bir acil durumda sadece rotasyon yetmez — previous sırrı hiç
// tanımlamadan rotasyon yapın ve tüm oturum jetonlarını iptal edin.
//
fn with_secret(req: wisp.Request, secret: String) -> wisp.Request {
  request.Request(
    ..req,
    body: internal.Connection(..req.body, secret_key_base: secret),
  )
}

fn current_app_secret() -> String {
  envoy.get("SECRET_KEY_BASE") |> result.unwrap("")
}

fn previous_app_secret() -> Result(String, Nil) {
  case envoy.get("SECRET_KEY_BASE_PREVIOUS") {
    Ok(previous) if previous != "" -> Ok(previous)
    _ -> Error(Nil)
  }
}

fn csp_report_only() -> Bool {
  nexus_sec.report_only_mode(envoy.get("CSP_REPORT_ONLY") |> result.unwrap(""))
}

/// current-era imzası geçerliyse pencere açılmaz; yalnızca current geçersizken
/// previous tanınıyorsa previous-era çerezi kabul edilir. Dönen istek previous
/// bağlantısıyla taşınır; yanıt restamp_session_cookie ile current sır ile
/// yeniden damgalanmalıdır.
fn rotate_secret(
  req: wisp.Request,
) -> Result(#(wisp.Request, String), wisp.Request) {
  let current_valid =
    wisp.get_cookie(req, "nexus_session", wisp.Signed) |> result.is_ok
  case previous_app_secret() {
    Error(_) -> Error(req)
    Ok(previous) -> {
      let previous_valid =
        wisp.get_cookie(
          with_secret(req, previous),
          "nexus_session",
          wisp.Signed,
        )
        |> result.is_ok
      case nexus_sec.resolve_secret_era(current_valid, previous_valid) {
        Ok(nexus_sec.Previous) ->
          case
            wisp.get_cookie(
              with_secret(req, previous),
              "nexus_session",
              wisp.Signed,
            )
          {
            Ok(session_token) ->
              Ok(#(with_secret(req, previous), session_token))
            Error(_) -> Error(req)
          }
        _ -> Error(req)
      }
    }
  }
}

/// Previous-era kabulünden sonra nexus_session çerezini current sır ile
/// yeniden damgalar. Login (303 -> /admin) ve logout (303 -> /login)
/// yanıtları atlanır: login kendi fresh çerezini yazar; logout'un çerez
/// silme (max_age=0) yönergesi diriltilemez. Karar nexus_sec.should_restamp.
fn restamp_session_cookie(
  res: wisp.Response,
  req: wisp.Request,
  session_token: String,
) -> wisp.Response {
  let location = case http_response.get_header(res, "location") {
    Ok(value) -> value
    Error(_) -> ""
  }
  case nexus_sec.should_restamp(res.status, location) {
    False -> res
    True ->
      wisp.set_cookie(
        res,
        req,
        "nexus_session",
        session_token,
        wisp.Signed,
        28_800,
      )
  }
}

const security_rate_limit_cache_key = "nexus:security_rate_limits"

@external(erlang, "persistent_term", "get")
fn cache_get(key: String, default: a) -> a

@external(erlang, "persistent_term", "put")
fn cache_put(key: String, value: a) -> Nil

@external(erlang, "nexus_net", "ip_in_cidrs")
fn ip_in_cidrs_ffi(ip: String, cidrs: List(String)) -> Bool

/// The identity used for rate limiting and audit records.
///
/// The socket peer is the only address a client cannot choose, so it is
/// authoritative. `X-Forwarded-For` and `CF-Connecting-IP` are attacker
/// controlled and are consulted only when the immediate peer is a proxy this
/// deployment listed in `TRUSTED_PROXY_CIDRS`. With that variable unset no
/// forwarding header is ever believed, which closes header spoofing.
fn request_client_id(req: wisp.Request, peer: String) -> String {
  case peer {
    "" -> "unknown"
    _ -> {
      let cidrs = trusted_proxy_cidrs()
      case is_trusted_address(peer, cidrs) {
        True -> forwarded_client(req, cidrs) |> fallback(peer)
        False -> peer
      }
    }
  }
}

fn trusted_proxy_cidrs() -> List(String) {
  envoy.get("TRUSTED_PROXY_CIDRS")
  |> result.unwrap("")
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(entry) { entry != "" })
}

fn is_trusted_address(ip: String, cidrs: List(String)) -> Bool {
  case cidrs {
    [] -> False
    _ -> ip_in_cidrs_ffi(ip, cidrs)
  }
}

fn forwarded_client(req: wisp.Request, cidrs: List(String)) -> String {
  let chain =
    request.get_header(req, "x-forwarded-for")
    |> result.unwrap("")
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(entry) { entry != "" })
  case chain {
    [] ->
      request.get_header(req, "cf-connecting-ip")
      |> result.unwrap("")
      |> string.trim
    _ -> rightmost_untrusted(list.reverse(chain), cidrs, "")
  }
}

/// Walk the forwarding chain from the closest hop outwards and return the
/// first address that is not itself a trusted proxy. Taking the first entry
/// instead would let a client prepend a forged address to the header.
fn rightmost_untrusted(
  entries: List(String),
  cidrs: List(String),
  fallback: String,
) -> String {
  case entries {
    [] -> fallback
    [entry, ..rest] ->
      case is_trusted_address(entry, cidrs) {
        True -> rightmost_untrusted(rest, cidrs, fallback)
        False -> entry
      }
  }
}

fn fallback(value: String, default: String) -> String {
  case value == "" {
    True -> default
    False -> value
  }
}

fn rate_limited(key: String, limit: Int, window_ms: Float) -> Bool {
  let now_ms = timestamp.to_unix_seconds(timestamp.system_time()) *. 1000.0
  let cache: dict.Dict(String, #(Float, Int)) =
    cache_get(security_rate_limit_cache_key, dict.new())
  case dict.get(cache, key) {
    Ok(#(window_start, count)) if now_ms -. window_start <. window_ms -> {
      let blocked = count >= limit
      cache_put(
        security_rate_limit_cache_key,
        dict.insert(cache, key, #(window_start, count + 1)),
      )
      blocked
    }
    _ -> {
      cache_put(
        security_rate_limit_cache_key,
        dict.insert(cache, key, #(now_ms, 1)),
      )
      False
    }
  }
}

fn fail() {
  wisp.response(503)
  |> wisp.set_header("content-type", "text/html; charset=utf-8")
  |> wisp.html_body(
    "<!doctype html><html lang=\"tr\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Bağlantı Hatası - NEXUS</title><link rel=\"stylesheet\" href=\"/static/site.css\"><link rel=\"stylesheet\" href=\"/static/admin-modern.css\"></head><body style=\"display:grid;place-items:center;min-height:100vh;background:#f7f9f8;font-family:system-ui,-apple-system,sans-serif;margin:0;padding:20px;\"><div style=\"text-align:center;padding:36px;background:#fff;border-radius:18px;border:1px solid #d9e3df;box-shadow:0 8px 30px rgba(0,0,0,0.06);max-width:440px;width:100%;box-sizing:border-box;\"><h2 style=\"margin:0 0 10px;font-size:1.3rem;color:#1a3832;\">Veritabanına Erişilemiyor</h2><p style=\"color:#6b7f79;font-size:0.92rem;line-height:1.5;margin:0 0 20px;\">Veritabanı servisiyle bağlantı kurulamadı. Lütfen sayfayı yenileyin.</p><a href=\"javascript:location.reload()\" class=\"button primary\" style=\"display:inline-block;padding:10px 22px;border-radius:10px;background:#087f83;color:#fff;text-decoration:none;font-weight:600;font-size:0.9rem;\">Sayfayı Yenile</a></div></body></html>",
  )
}

/// Channel rate feeds must never answer with invented availability.
///
/// A 200 here would let a channel treat placeholder prices and a stale
/// validity window as confirmed supplier inventory, so an unconfigured feed
/// reports itself unavailable instead.
fn channel_feed_unavailable() -> wisp.Response {
  let body =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    <> "<OTA_HotelRateAmountNotifRQError>\n"
    <> "  <Error Code=\"503\">Channel rate feed is unavailable. No verified supplier rates are published.</Error>\n"
    <> "</OTA_HotelRateAmountNotifRQError>"
  wisp.response(503)
  |> wisp.set_header("cache-control", "no-store")
  |> wisp.set_header("content-type", "application/xml; charset=utf-8")
  |> wisp.string_body(body)
}

fn field(fields: List(#(String, String)), key: String) {
  list.key_find(fields, key) |> result.unwrap("")
}

fn category_or_default(category: String) {
  case string.trim(category) {
    "" -> "holiday_home"
    "villa" -> "holiday_home"
    value -> value
  }
}

fn send_agency_connection_approval(
  conn: pog.Connection,
  request_id: String,
  api_key: String,
  callback_key: String,
) -> Result(String, String) {
  case string.trim(callback_key) {
    "" -> Error("NEXUS_API_KEY boş")
    key -> {
      let decoder = {
        use agency_id <- decode.field(0, decode.string)
        use agency_endpoint <- decode.field(1, decode.string)
        decode.success(#(agency_id, agency_endpoint))
      }
      case
        pog.query(
          "select agency_id::text, agency_endpoint from partners.connection_requests where id::text=$1 limit 1",
        )
        |> pog.parameter(pog.text(request_id))
        |> pog.returning(decoder)
        |> pog.execute(conn)
      {
        Error(_) -> Error("bağlantı isteği okunamadı")
        Ok(result) ->
          case list.first(result.rows) {
            Error(_) -> Error("bağlantı isteği bulunamadı")
            Ok(#(agency_id, agency_endpoint)) ->
              agency_callback.post_connection_approved(
                agency_endpoint,
                agency_id,
                api_key,
                key,
              )
          }
      }
    }
  }
}

fn record_agency_connection_callback(
  conn: pog.Connection,
  request_id: String,
  status: String,
  error: String,
) -> Nil {
  let _ =
    pog.query(
      "insert into partners.agency_connection_callbacks(
         request_id,agency_id,agency_endpoint,status,attempts,last_error,
         last_attempt_at,next_attempt_at,updated_at
       )
       select id,agency_id,agency_endpoint,$2,1,left($3,2000),now(),
              case when $2='sent' then null else now()+interval '15 minutes' end,
              now()
         from partners.connection_requests
        where id::text=$1
       on conflict(request_id) do update set
         agency_id=excluded.agency_id,
         agency_endpoint=excluded.agency_endpoint,
         status=excluded.status,
         attempts=partners.agency_connection_callbacks.attempts+1,
         last_error=excluded.last_error,
         last_attempt_at=now(),
         next_attempt_at=case when excluded.status='sent' then null else now()+interval '15 minutes' end,
         updated_at=now()",
    )
    |> pog.parameter(pog.text(request_id))
    |> pog.parameter(pog.text(status))
    |> pog.parameter(pog.text(error))
    |> pog.execute(conn)
  Nil
}

fn retry_agency_connection_callback(
  conn: pog.Connection,
  s: domain.Session,
  request_id: String,
) -> String {
  let callback_key = envoy.get("NEXUS_API_KEY") |> result.unwrap("")
  let api_key =
    calendar.command(
      conn,
      s,
      "select partners.issue_agency_api_key(r.agency_id,'default')
         from partners.connection_requests r
        where r.id::text=$1 and r.status='approved'
        limit 1",
      [pog.text(request_id)],
    )
    |> result.unwrap("failed")
  case string.starts_with(api_key, "nx_") {
    False -> api_key
    True ->
      case
        send_agency_connection_approval(conn, request_id, api_key, callback_key)
      {
        Ok(_) -> {
          record_agency_connection_callback(conn, request_id, "sent", "")
          "agency_callback_sent"
        }
        Error(reason) -> {
          record_agency_connection_callback(conn, request_id, "failed", reason)
          "agency_callback_failed:" <> reason
        }
      }
  }
}

@external(erlang, "nexus_secrets", "secure_compare")
fn secure_compare_ffi(presented: String, expected: String) -> Bool

/// Compares a presented credential against the expected secret without letting
/// response timing reveal how many leading characters matched.
fn secret_matches(presented: String, expected: String) -> Bool {
  case expected {
    "" -> False
    _ ->
      secure_compare_ffi(presented, expected)
      || secure_compare_ffi(presented, "Bearer " <> expected)
  }
}

/// Form CSRF token comparison. The token is compared in constant time so the
/// response duration does not leak how many characters of the expected token
/// an attacker guessed; lengths always differ for wrong guesses, which
/// secure_compare already rejects without early exit on content.
fn csrf_matches(presented: String, expected: String) -> Bool {
  secure_compare_ffi(presented, expected)
}

fn secure_form_csrf(values: List(#(String, String)), csrf: String) -> Bool {
  csrf_matches(field(values, "csrf"), csrf)
}

/// Authorise a platform level agency request with the dedicated integration key.
///
/// `NEXUS_CONFIG_KEY` is deliberately not accepted here. It is the AES-256-GCM
/// master key that protects every sealed setting, so using it as a network
/// credential would tie data at rest and authentication to the same secret.
/// Integration callers must present `NEXUS_API_KEY`.
fn agency_request_key_ok(req: wisp.Request, peer: String) -> Bool {
  let api_key = envoy.get("NEXUS_API_KEY") |> result.unwrap("")
  let auth_hdr = request.get_header(req, "authorization") |> result.unwrap("")
  let api_hdr = request.get_header(req, "x-nexus-api-key") |> result.unwrap("")
  let ok = secret_matches(auth_hdr, api_key) || secret_matches(api_hdr, api_key)
  case ok {
    True -> True
    False -> {
      // The attempt is always recorded so repeated bad keys stay visible. The
      // request is denied either way: this check authorises, it does not
      // throttle, so the limiter must not be able to turn into a bypass.
      let key =
        "agency-request-key:"
        <> request_client_id(req, peer)
        <> ":"
        <> string.slice(auth_hdr <> api_hdr, 0, 64)
      rate_limited(key, 30, 300_000.0)
      False
    }
  }
}

fn bearer_value(value: String) -> String {
  let trimmed = string.trim(value)
  case string.starts_with(trimmed, "Bearer ") {
    True -> string.drop_start(trimmed, 7) |> string.trim
    False -> trimmed
  }
}

fn request_api_key(req: wisp.Request) -> String {
  let auth_hdr = request.get_header(req, "authorization") |> result.unwrap("")
  let api_hdr = request.get_header(req, "x-nexus-api-key") |> result.unwrap("")
  case bearer_value(api_hdr) {
    "" -> bearer_value(auth_hdr)
    key -> key
  }
}

fn agency_api_key_required(conn: pog.Connection, agency_id: String) -> Bool {
  case
    pog.query("select partners.agency_api_key_required($1)")
    |> pog.parameter(pog.text(agency_id))
    |> pog.returning(decode.field(0, decode.bool, decode.success))
    |> pog.execute(conn)
  {
    Ok(res) -> list.first(res.rows) |> result.unwrap(False)
    Error(_) -> True
  }
}

fn agency_api_key_ok(
  conn: pog.Connection,
  agency_id: String,
  key: String,
) -> Bool {
  case
    pog.query("select partners.agency_api_key_ok($1,$2)")
    |> pog.parameter(pog.text(agency_id))
    |> pog.parameter(pog.text(key))
    |> pog.returning(decode.field(0, decode.bool, decode.success))
    |> pog.execute(conn)
  {
    Ok(res) -> list.first(res.rows) |> result.unwrap(False)
    Error(_) -> False
  }
}

fn agency_request_authorized(
  req: wisp.Request,
  conn: pog.Connection,
  agency_id: String,
  peer: String,
) -> Bool {
  case string.trim(agency_id) {
    "" -> False
    _ -> {
      let key = request_api_key(req)
      case agency_api_key_required(conn, agency_id) {
        True -> agency_api_key_ok(conn, agency_id, key)
        False -> agency_request_key_ok(req, peer)
      }
    }
  }
}

fn agency_id_from_json_payload(body: String) -> String {
  json.parse(
    from: body,
    using: decode.field("agency_id", decode.string, decode.success),
  )
  |> result.unwrap("")
}

fn single_string_decoder() {
  use value <- decode.field(0, decode.string)
  decode.success(value)
}

fn file_extension(name: String) -> String {
  string.split(name, ".") |> list.last |> result.unwrap("") |> string.lowercase
}

fn clean_base64(raw: String) -> String {
  case string.split_once(raw, "base64,") {
    Ok(#(_, b64)) -> b64
    Error(_) -> raw
  }
  |> string.replace("\r", "")
  |> string.replace("\n", "")
  |> string.replace(" ", "")
  |> string.trim
}

fn build_media_json(hero: String, gallery: String) -> String {
  let hero_trimmed = string.trim(hero)
  let hero_items = case hero_trimmed {
    "" -> []
    h -> [h]
  }
  let gallery_items =
    string.split(gallery, "\n")
    |> list.flat_map(fn(line) { string.split(line, ",") })
    |> list.map(string.trim)
    |> list.filter(fn(s) { s != "" && s != hero_trimmed })

  json.array(list.append(hero_items, gallery_items), of: json.string)
  |> json.to_string
}

fn document_download(conn: pog.Connection, s: domain.Session, token: String) {
  case
    calendar.rows_with(
      conn,
      s,
      "select * from onboarding.download_document($1)",
      [pog.text(token)],
    )
  {
    Ok([[stored, original]]) ->
      wisp.ok()
      |> wisp.file_download(named: original, from: ".local/uploads/" <> stored)
      |> wisp.set_header("x-content-type-options", "nosniff")
    _ -> wisp.response(404)
  }
}

fn authorized_form(
  req: wisp.Request,
  csrf: String,
  origin: String,
  run: fn(List(#(String, String))) -> wisp.Response,
) {
  use form <- wisp.require_form(req)
  case
    secure_form_csrf(form.values, csrf)
    && request.get_header(req, "origin") == Ok(origin)
  {
    True -> run(form.values)
    False ->
      wisp.response(403)
      |> wisp.set_header("content-type", "text/plain; charset=utf-8")
      |> wisp.string_body("Güvenlik doğrulaması başarısız. Sayfayı yenileyin.")
  }
}

/// GET /v1/secret-rotation-window — rotasyon penceresinin operasyonel
/// görünümü: her sır için ayrı kayıt (SECRET_KEY_BASE + NEXUS_CONFIG_KEY),
/// yasi ayri raporlanır. /health service/database durumunu raporlamaya
/// devam eder; pencere ayrı uçta izlenir ki izleme sistemi ayrı alarm
/// kurabilsin. Bilinen her durum (unknown/open/expired) 200 ile raporlanır
/// — durum bilgi taşıyıcısıdır; fail-closed zorlaması
/// scripts/check-secret-hygiene.ps1 ve production gates'tedir. Sadece DB
/// okunamadığında 503 döner.
fn secret_rotation_window(conn: pog.Connection) -> wisp.Response {
  case db.rotation_window(conn) {
    Ok(rows) ->
      wisp.response(200)
      |> wisp.json_body(
        json.to_string(
          json.object([
            #(
              "secrets",
              json.array(rows, fn(row) {
                let #(secret, state, age, window) = row
                json.object([
                  #("secret", json.string(secret)),
                  #("state", json.string(state)),
                  #("age_hours", json.string(age)),
                  #("window_hours", json.string(window)),
                  #("reminder", json.string(window_reminder(secret, state))),
                ])
              }),
            ),
          ]),
        ),
      )
    Error(_) ->
      wisp.response(503)
      |> wisp.json_body(
        json.to_string(
          json.object([
            #("secrets", json.array([], fn(_row) { json.null() })),
            #("state", json.string("unavailable")),
          ]),
        ),
      )
  }
}

fn window_reminder(secret: String, state: String) -> String {
  case state {
    "open" ->
      case secret {
        "SECRET_KEY_BASE" ->
          "SECRET_KEY_BASE_PREVIOUS must be removed within the window"
        _ -> "Age is informational; no PREVIOUS counterpart for this secret"
      }
    "expired" ->
      case secret {
        "SECRET_KEY_BASE" -> "SECRET_KEY_BASE_PREVIOUS must be removed now"
        _ -> "Rotate NEXUS_CONFIG_KEY and re-encrypt affected settings"
      }
    _ -> "No rotation record: run scripts/record-secret-rotation.ps1"
  }
}

fn route(
  req: wisp.Request,
  conn: pog.Connection,
  csrf: String,
  origin: String,
  peer: String,
) {
  case req.method, wisp.path_segments(req) {
    http.Get, ["v1", "secret-rotation-window"] -> secret_rotation_window(conn)
    http.Get, ["v1", "health"] -> {
      let ok = db.healthy(conn)
      // Rotasyon özeti yalnız DB sağlıyken sorgulanır; okuma hatası
      // /health durumunu değiştirmez (null ile raporlanır).
      let rotation = case ok {
        True -> db.rotation_window(conn)
        False -> Error(Nil)
      }
      wisp.response(case ok {
        True -> 200
        False -> 503
      })
      |> wisp.json_body(
        json.to_string(
          json.object([
            #("service", json.string("nexustraveltech")),
            #(
              "database",
              json.string(case ok {
                True -> "ready"
                False -> "unavailable"
              }),
            ),
            #("environment", json.string("development")),
            #("secret_rotations", case rotation {
              Ok(rows) ->
                json.array(rows, fn(row) {
                  let #(secret, state, age, window) = row
                  json.object([
                    #("secret", json.string(secret)),
                    #("state", json.string(state)),
                    #("age_hours", json.string(age)),
                    #("window_hours", json.string(window)),
                  ])
                })
              Error(_) -> json.null()
            }),
          ]),
        ),
      )
    }
    http.Post, ["v1", "agency", "connection-request"] -> {
      case agency_request_key_ok(req, peer) {
        False ->
          wisp.response(401)
          |> wisp.json_body(
            "{\"ok\":false,\"error\":\"Geçersiz NEXUS bağlantı anahtarı\"}",
          )
        True -> {
          let query = wisp.get_query(req)
          let agency_id = field(query, "agency_id")
          let agency_name = field(query, "agency_name")
          let agency_endpoint = field(query, "agency_endpoint")
          case
            pog.query("select partners.receive_connection_request($1,$2,$3)")
            |> pog.parameter(pog.text(agency_id))
            |> pog.parameter(pog.text(agency_name))
            |> pog.parameter(pog.text(agency_endpoint))
            |> pog.returning(single_string_decoder())
            |> pog.execute(conn)
          {
            Ok(result) ->
              case list.first(result.rows) {
                Ok("invalid_request") ->
                  wisp.response(400)
                  |> wisp.json_body(
                    "{\"ok\":false,\"error\":\"Acente bilgileri geçersiz\"}",
                  )
                Ok("agency_conflict") ->
                  wisp.response(409)
                  |> wisp.json_body(
                    "{\"ok\":false,\"error\":\"Acente kodu başka bir kuruluşa ait\"}",
                  )
                Ok(request_id) ->
                  wisp.ok()
                  |> wisp.json_body(
                    "{\"ok\":true,\"requestId\":\"" <> request_id <> "\"}",
                  )
                Error(_) ->
                  wisp.response(500)
                  |> wisp.json_body(
                    "{\"ok\":false,\"error\":\"İstek kaydedilemedi\"}",
                  )
              }
            Error(_) ->
              wisp.response(500)
              |> wisp.json_body(
                "{\"ok\":false,\"error\":\"İstek kaydedilemedi\"}",
              )
          }
        }
      }
    }
    http.Get, ["api", "v1", "feed", "listings"] ->
      api_feed_listings(req, conn, peer)
    http.Get, ["v1", "feed", "listings"] -> api_feed_listings(req, conn, peer)
    http.Get, ["api", "v1", "contract", "categories"] ->
      api_contract_categories(req, conn)
    http.Get, ["v1", "contract", "categories"] ->
      api_contract_categories(req, conn)
    http.Get, ["api", "v1", "contract", "state"] ->
      api_contract_state(req, conn)
    http.Get, ["v1", "contract", "state"] -> api_contract_state(req, conn)
    http.Get, ["api", "v1", "contract", "filters"] -> api_contract_filters(conn)
    http.Get, ["v1", "contract", "filters"] -> api_contract_filters(conn)
    http.Get, ["api", "v1", "feed", "inventory"] ->
      api_feed_inventory(req, conn, peer)
    http.Get, ["v1", "feed", "inventory"] -> api_feed_inventory(req, conn, peer)
    http.Post, ["api", "v1", "webhooks", "reservations"] ->
      api_webhook_reservations(req, conn, peer)
    http.Post, ["v1", "webhooks", "reservations"] ->
      api_webhook_reservations(req, conn, peer)
    http.Get, [] -> public_site(conn, "home")
    http.Get, ["robots.txt"] ->
      wisp.ok()
      |> wisp.set_header("content-type", "text/plain; charset=utf-8")
      |> wisp.string_body(
        "User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /v1/\nSitemap: "
        <> origin
        <> "/sitemap.xml\n",
      )
    http.Get, ["sitemap.xml"] ->
      wisp.ok()
      |> wisp.set_header("content-type", "application/xml; charset=utf-8")
      |> wisp.string_body(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"><url><loc>"
        <> origin
        <> "/</loc></url><url><loc>"
        <> origin
        <> "/program</loc></url><url><loc>"
        <> origin
        <> "/iletisim</loc></url><url><loc>"
        <> origin
        <> "/hakkimizda</loc></url><url><loc>"
        <> origin
        <> "/blog</loc></url></urlset>",
      )
    http.Get, ["ilanlar"] -> {
      let query_params = wisp.get_query(req)
      let q = list.key_find(query_params, "q") |> result.unwrap("")
      let category =
        list.key_find(query_params, "category") |> result.unwrap("")
      let locality =
        list.key_find(query_params, "locality") |> result.unwrap("")
      case
        site.published(conn),
        db.marketplace_listings(conn, q, category, locality)
      {
        Ok(site_rows), Ok(listings) -> {
          let content =
            marketplace_view.render_catalog(listings, q, category, locality)
          html(site.render_custom_page(
            site_rows,
            "Canlı İlanlar & Rezervasyon",
            "Türkiye'nin en seçkin tatil deneyimleri",
            content,
          ))
        }
        _, _ -> fail()
      }
    }
    http.Get, ["ilan", id] -> {
      let query_params = wisp.get_query(req)
      let feedback = list.key_find(query_params, "msg") |> result.unwrap("")
      case site.published(conn), db.marketplace_listing_detail(conn, id) {
        Ok(site_rows), Ok(prop) -> {
          let lang = list.key_find(query_params, "lang") |> result.unwrap("tr")
          let content =
            marketplace_view.render_detail_locale(prop, feedback, lang)
          html(site.render_custom_page(
            site_rows,
            "İlan Detayı & Rezervasyon",
            "Doğrudan rezervasyon",
            content,
          ))
        }
        _, _ -> fail()
      }
    }
    http.Post, ["ilan", _id, "book"] -> booking_status.handle(req)
    http.Get, ["program"] -> public_site(conn, "program")
    http.Get, ["tedarikci"] -> public_site(conn, "tedarikci")
    http.Get, ["acente"] -> public_site(conn, "acente")
    http.Get, ["hakkimizda"] -> public_site(conn, "hakkimizda")
    http.Get, ["blog"] -> {
      case site.published(conn) {
        Ok(rows) -> html(site.render_blog(rows))
        _ -> fail()
      }
    }
    http.Get, ["blog", slug] -> {
      case site.published(conn) {
        Ok(rows) -> html(site.render_blog_detail(rows, slug))
        _ -> fail()
      }
    }
    http.Get, ["modul-" <> _] -> wisp.redirect("/program")
    http.Get, ["iletisim"] -> {
      case site.published(conn), site.contact(conn) {
        Ok(rows), Ok(values) ->
          case site.render_form(rows, "iletisim", values, csrf) {
            Ok(body) -> html(body)
            Error(_) -> wisp.not_found()
          }
        _, _ -> fail()
      }
    }
    http.Post, ["iletisim"] -> {
      use fields <- authorized_form(req, csrf, origin)
      case
        site.submit_contact(
          conn,
          field(fields, "name"),
          field(fields, "email"),
          field(fields, "message"),
        )
      {
        Ok("queued") ->
          contact_feedback(
            conn,
            csrf,
            200,
            "Mesajınız alındı. NEXUS ekibi mesajınızı yönetim panelinden inceleyebilir.",
            [],
          )
        Ok(_) ->
          contact_feedback(
            conn,
            csrf,
            422,
            "Ad, geçerli e-posta ve 5–5000 karakter uzunluğunda mesaj girin.",
            fields,
          )
        Error(_) -> fail()
      }
    }
    http.Get, ["kayit-ol"] -> wisp.redirect("/login")
    http.Get, ["login"] -> html(view.login(csrf, ""))
    http.Post, ["login"] -> {
      use fields <- authorized_form(req, csrf, origin)
      let token = wisp.random_string(48)
      let email = field(fields, "email")
      case
        rate_limited(
          "login:"
            <> string.lowercase(string.trim(email))
            <> ":"
            <> request_client_id(req, peer),
          12,
          300_000.0,
        )
      {
        True ->
          wisp.response(429)
          |> wisp.html_body(view.login(
            csrf,
            "Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin.",
          ))
        False ->
          case db.login(conn, email, field(fields, "password"), token) {
            True ->
              wisp.redirect("/admin")
              |> wisp.set_cookie(
                req,
                "nexus_session",
                token,
                wisp.Signed,
                28_800,
              )
            False ->
              wisp.response(401)
              |> wisp.html_body(view.login(
                csrf,
                "Giriş yapılamadı. Bilgilerini kontrol et; çok sayıda denemede hesap kısa süreli kilitlenir.",
              ))
          }
      }
    }
    _, ["admin", ..] | _, ["logout"] -> admin(req, conn, csrf, origin)
    http.Get, ["checkin", res_id] -> checkin_page(conn, res_id, "")
    http.Post, ["checkin", res_id] -> {
      use form <- wisp.require_form(req)
      let name = field(form.values, "name")
      let tc = field(form.values, "tc")
      let phone = field(form.values, "phone")
      let email = field(form.values, "email")
      let eta = field(form.values, "eta")
      let requests = field(form.values, "requests")
      let sig = field(form.values, "sig")
      case
        pog.query(
          "select booking.submit_online_checkin($1,$2,$3,$4,$5,$6,$7,$8)",
        )
        |> pog.parameter(pog.text(res_id))
        |> pog.parameter(pog.text(name))
        |> pog.parameter(pog.text(tc))
        |> pog.parameter(pog.text(phone))
        |> pog.parameter(pog.text(email))
        |> pog.parameter(pog.text(eta))
        |> pog.parameter(pog.text(requests))
        |> pog.parameter(pog.text(sig))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(conn)
      {
        Ok(_) ->
          checkin_page(
            conn,
            res_id,
            "Online Check-In başarıyla kaydedildi! Kapı şifreniz oluşturuldu.",
          )
        Error(_) ->
          checkin_page(
            conn,
            res_id,
            "Hata: Bilgiler kaydedilemedi, lütfen tekrar deneyin.",
          )
      }
    }
    // This feed used to answer 200 with a canned document: frozen timestamp,
    // a hardcoded validity window and invented prices that no listing produced.
    // A channel scraping it would ingest fabricated rates as confirmed
    // availability, so the route now reports unavailable until real supplier
    // rates are published, matching how every other unverified channel behaves.
    http.Get, ["api", "metasearch", "google-hotel-ads.xml"] ->
      channel_feed_unavailable()
    http.Get, [slug] -> public_site(conn, slug)
    _, _ -> wisp.not_found()
  }
}

fn category_filters_json(conn: pog.Connection, s: domain.Session) {
  let _ = s
  let sql =
    "select coalesce(json_agg(json_build_object('id', g.id::text, 'category', g.category_code, 'key', g.group_key, 'title', g.title, 'helpText', coalesce(g.help_text, ''), 'displayType', g.display_type, 'multiple', g.multiple, 'active', g.active, 'sortOrder', g.position, 'items', coalesce((select json_agg(json_build_object('id', i.id::text, 'key', i.item_key, 'title', i.title, 'helpText', coalesce(i.help_text, ''), 'contractFieldKey', coalesce(i.contract_field_code, ''), 'contractValue', coalesce(i.contract_value, ''), 'active', i.active, 'sortOrder', i.position) order by i.position, i.title) from onboarding.category_filter_items i where i.group_id = g.id and i.active), '[]'::json)) order by g.category_code, g.position, g.title), '[]'::json)::text from onboarding.category_filter_groups g where g.active"
  case
    sql
    |> pog.query()
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(conn)
  {
    Ok(result) -> {
      let body =
        result.rows
        |> list.first
        |> result.unwrap("[]")
      wisp.ok()
      |> wisp.json_body(body)
    }
    Error(_) ->
      wisp.response(500)
      |> wisp.json_body("{\"error\":\"Kategori filtreleri okunamadı\"}")
  }
}

fn api_feed_listings(
  req: wisp.Request,
  conn: pog.Connection,
  peer: String,
) -> wisp.Response {
  let query = wisp.get_query(req)
  let agency_id = field(query, "agency_id")
  case agency_request_authorized(req, conn, agency_id, peer) {
    False ->
      wisp.response(401)
      |> wisp.json_body(
        "{\"ok\":false,\"error\":\"Geçersiz yetkilendirme anahtarı\"}",
      )
    True -> {
      let category = field(query, "category")
      let locality = field(query, "locality")
      let q = field(query, "q")

      let listing_decoder = {
        use id <- decode.field(0, decode.string)
        use title <- decode.field(1, decode.string)
        use loc <- decode.field(2, decode.string)
        use region <- decode.field(3, decode.string)
        use cat <- decode.field(4, decode.string)
        use cap <- decode.field(5, decode.string)
        use prc <- decode.field(6, decode.string)
        use curr <- decode.field(7, decode.string)
        use desc <- decode.field(8, decode.string)
        use short_desc <- decode.field(9, decode.string)
        use imgs <- decode.field(10, decode.string)
        use contract_fields <- decode.field(11, decode.string)
        use price_unit <- decode.field(12, decode.string)
        use availability_mode <- decode.field(13, decode.string)
        use contact_policy <- decode.field(14, decode.string)
        use cancellation_policy <- decode.field(15, decode.string)
        decode.success(#(
          id,
          title,
          loc,
          region,
          cat,
          cap,
          prc,
          curr,
          desc,
          short_desc,
          imgs,
          contract_fields,
          price_unit,
          availability_mode,
          contact_policy,
          cancellation_policy,
        ))
      }

      case agency_id == "" {
        True ->
          wisp.response(400)
          |> wisp.json_body(
            "{\"ok\":false,\"error\":\"agency_id parametresi gereklidir\"}",
          )
        False -> {
          // Feed hem onaylı acente politikasına hem de aktif tedarikçi-acente
          // bağlantısına bağlıdır. Boş sonuç hiçbir zaman genel kataloğa düşmez.
          let rows_res =
            pog.query("select * from catalog.agency_listing_feed($1,$2,$3,$4)")
            |> pog.parameter(pog.text(agency_id))
            |> pog.parameter(pog.text(category))
            |> pog.parameter(pog.text(locality))
            |> pog.parameter(pog.text(q))
            |> pog.returning(listing_decoder)
            |> pog.execute(conn)
            |> result.map(fn(r) { r.rows })

          case rows_res {
            Ok(rows) -> {
              let listings_json =
                "["
                <> {
                  rows
                  |> list.map(fn(row) {
                    let #(
                      id,
                      title,
                      loc,
                      region,
                      cat,
                      cap,
                      prc,
                      curr,
                      desc,
                      short_desc,
                      imgs,
                      contract_fields,
                      price_unit,
                      availability_mode,
                      contact_policy,
                      cancellation_policy,
                    ) = row
                    let clean_imgs = case string.trim(imgs) {
                      "" -> "[]"
                      other -> other
                    }
                    let clean_contract_fields = case
                      string.trim(contract_fields)
                    {
                      "" -> "{}"
                      other -> other
                    }
                    "{\"id\":"
                    <> { json.string(id) |> json.to_string }
                    <> ",\"title\":"
                    <> { json.string(title) |> json.to_string }
                    <> ",\"locality\":"
                    <> { json.string(loc) |> json.to_string }
                    <> ",\"region\":"
                    <> { json.string(region) |> json.to_string }
                    <> ",\"category\":"
                    <> { json.string(cat) |> json.to_string }
                    <> ",\"capacity\":"
                    <> { json.string(cap) |> json.to_string }
                    <> ",\"price\":"
                    <> { json.string(prc) |> json.to_string }
                    <> ",\"currency\":"
                    <> { json.string(curr) |> json.to_string }
                    <> ",\"description\":"
                    <> { json.string(desc) |> json.to_string }
                    <> ",\"shortDescription\":"
                    <> { json.string(short_desc) |> json.to_string }
                    <> ",\"images\":"
                    <> clean_imgs
                    <> ",\"images_json\":"
                    <> { json.string(clean_imgs) |> json.to_string }
                    <> ",\"contractFields\":"
                    <> clean_contract_fields
                    <> ",\"contractFieldsJson\":"
                    <> { json.string(clean_contract_fields) |> json.to_string }
                    <> ",\"priceUnit\":"
                    <> { json.string(price_unit) |> json.to_string }
                    <> ",\"availabilityMode\":"
                    <> { json.string(availability_mode) |> json.to_string }
                    <> ",\"contactPolicy\":"
                    <> { json.string(contact_policy) |> json.to_string }
                    <> ",\"cancellationPolicy\":"
                    <> { json.string(cancellation_policy) |> json.to_string }
                    <> "}"
                  })
                  |> string.join(",")
                }
                <> "]"

              let response_body =
                "{\"ok\":true,"
                <> contract.version_field()
                <> ",\"count\":"
                <> int.to_string(list.length(rows))
                <> ",\"listings\":"
                <> listings_json
                <> "}"

              wisp.ok()
              |> wisp.json_body(response_body)
            }
            Error(_) ->
              wisp.response(500)
              |> wisp.json_body(
                "{\"ok\":false,\"error\":\"İlanlar okunamadı\"}",
              )
          }
        }
      }
    }
  }
}

fn api_contract_state(
  req: wisp.Request,
  conn: pog.Connection,
) -> wisp.Response {
  let _ = req
  let decoder = {
    use key <- decode.field(0, decode.string)
    use val <- decode.field(1, decode.string)
    decode.success(#(key, val))
  }
  case
    pog.query(
      "select data[1], data[2] from onboarding.sync_contract_state() order by data[1]",
    )
    |> pog.returning(decoder)
    |> pog.execute(conn)
  {
    Ok(res) -> {
      let state_json =
        "["
        <> {
          res.rows
          |> list.map(fn(r) {
            let #(k, v) = r
            "{\"key\":"
            <> { json.string(k) |> json.to_string }
            <> ",\"value\":"
            <> { json.string(v) |> json.to_string }
            <> "}"
          })
          |> string.join(",")
        }
        <> "]"

      let body =
        "{\"ok\":true,"
        <> contract.version_field()
        <> ",\"contract_state\":"
        <> state_json
        <> "}"
      wisp.ok()
      |> wisp.json_body(body)
    }
    Error(_) ->
      wisp.response(500)
      |> wisp.json_body(
        "{\"ok\":false,\"error\":\"Sözleşme durumu okunamadı\"}",
      )
  }
}

fn api_contract_categories(
  req: wisp.Request,
  conn: pog.Connection,
) -> wisp.Response {
  let _ = req
  let decoder = {
    use key <- decode.field(0, decode.string)
    use val <- decode.field(1, decode.string)
    decode.success(#(key, val))
  }
  let state_rows =
    pog.query(
      "select data[1], data[2] from onboarding.sync_contract_state() order by data[1]",
    )
    |> pog.returning(decoder)
    |> pog.execute(conn)
    |> result.map(fn(r) { r.rows })
    |> result.unwrap([])

  let state_json =
    "["
    <> {
      state_rows
      |> list.map(fn(r) {
        let #(k, v) = r
        "{\"key\":"
        <> { json.string(k) |> json.to_string }
        <> ",\"value\":"
        <> { json.string(v) |> json.to_string }
        <> "}"
      })
      |> string.join(",")
    }
    <> "]"

  let categories_json =
    "[{\"code\":\"hotel\",\"title\":\"Otel\"},"
    <> "{\"code\":\"holiday_home\",\"title\":\"Tatil Evi\"},"
    <> "{\"code\":\"yacht\",\"title\":\"Yat\"},"
    <> "{\"code\":\"tour\",\"title\":\"Tur\"},"
    <> "{\"code\":\"activity\",\"title\":\"Aktivite\"},"
    <> "{\"code\":\"flight\",\"title\":\"Uçuş\"},"
    <> "{\"code\":\"car\",\"title\":\"Araç\"},"
    <> "{\"code\":\"cruise\",\"title\":\"Kruvaziyer\"},"
    <> "{\"code\":\"pilgrimage\",\"title\":\"Hac & Umre\"},"
    <> "{\"code\":\"visa\",\"title\":\"Vize\"},"
    <> "{\"code\":\"ferry\",\"title\":\"Feribot\"},"
    <> "{\"code\":\"transfer\",\"title\":\"Transfer\"},"
    <> "{\"code\":\"beach\",\"title\":\"Şezlong\"},"
    <> "{\"code\":\"cinema\",\"title\":\"Sinema\"},"
    <> "{\"code\":\"event\",\"title\":\"Etkinlik\"},"
    <> "{\"code\":\"restaurant\",\"title\":\"Restoran\"},"
    <> "{\"code\":\"bus\",\"title\":\"Otobüs\"}]"

  let body =
    "{\"ok\":true,"
    <> contract.version_field()
    <> ",\"categories\":"
    <> categories_json
    <> ",\"contract_state\":"
    <> state_json
    <> "}"

  wisp.ok()
  |> wisp.json_body(body)
}

fn api_contract_filters(conn: pog.Connection) -> wisp.Response {
  let sql =
    "select coalesce(json_agg(json_build_object('id', g.id::text, 'category', g.category_code, 'key', g.group_key, 'title', g.title, 'helpText', coalesce(g.help_text, ''), 'displayType', g.display_type, 'multiple', g.multiple, 'active', g.active, 'sortOrder', g.position, 'items', coalesce((select json_agg(json_build_object('id', i.id::text, 'key', i.item_key, 'title', i.title, 'helpText', coalesce(i.help_text, ''), 'contractFieldKey', coalesce(i.contract_field_code, ''), 'contractValue', coalesce(i.contract_value, ''), 'active', i.active, 'sortOrder', i.position) order by i.position, i.title) from onboarding.category_filter_items i where i.group_id = g.id and i.active), '[]'::json)) order by g.category_code, g.position, g.title), '[]'::json)::text from onboarding.category_filter_groups g where g.active"
  case
    sql
    |> pog.query()
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(conn)
  {
    Ok(result) -> {
      let body =
        result.rows
        |> list.first
        |> result.unwrap("[]")
      wisp.ok()
      |> wisp.json_body("{\"ok\":true,\"groups\":" <> body <> "}")
    }
    Error(_) ->
      wisp.response(500)
      |> wisp.json_body(
        "{\"ok\":false,\"error\":\"Kategori filtreleri okunamadı\"}",
      )
  }
}

fn api_feed_inventory(
  req: wisp.Request,
  conn: pog.Connection,
  peer: String,
) -> wisp.Response {
  let query = wisp.get_query(req)
  let listing_id = field(query, "listing_id")
  let agency_id = field(query, "agency_id")
  case agency_request_authorized(req, conn, agency_id, peer) {
    False ->
      wisp.response(401)
      |> wisp.json_body(
        "{\"ok\":false,\"error\":\"Geçersiz yetkilendirme anahtarı\"}",
      )
    True -> {
      let decoder = {
        use service_date <- decode.field(0, decode.string)
        use status <- decode.field(1, decode.string)
        use price_minor <- decode.field(2, decode.int)
        decode.success(#(service_date, status, price_minor))
      }
      case listing_id != "" && agency_id != "" {
        False ->
          wisp.response(400)
          |> wisp.json_body(
            "{\"ok\":false,\"error\":\"listing_id ve agency_id parametreleri gereklidir\"}",
          )
        True -> {
          case
            pog.query("select * from inventory.agency_inventory_feed($2,$1)")
            |> pog.parameter(pog.text(listing_id))
            |> pog.parameter(pog.text(agency_id))
            |> pog.returning(decoder)
            |> pog.execute(conn)
          {
            Ok(res) -> {
              let days =
                "["
                <> {
                  res.rows
                  |> list.map(fn(r) {
                    let #(d, st, pr) = r
                    "{\"date\":"
                    <> { json.string(d) |> json.to_string }
                    <> ",\"status\":"
                    <> { json.string(st) |> json.to_string }
                    <> ",\"price_minor\":"
                    <> int.to_string(pr)
                    <> "}"
                  })
                  |> string.join(",")
                }
                <> "]"
              let body =
                "{\"ok\":true,\"listing_id\":"
                <> { json.string(listing_id) |> json.to_string }
                <> ",\"inventory\":"
                <> days
                <> "}"
              wisp.ok()
              |> wisp.json_body(body)
            }
            Error(_) ->
              wisp.response(500)
              |> wisp.json_body(
                "{\"ok\":false,\"error\":\"Envanter okunamadı\"}",
              )
          }
        }
      }
    }
  }
}

fn api_webhook_reservations(
  req: wisp.Request,
  conn: pog.Connection,
  peer: String,
) -> wisp.Response {
  use body <- wisp.require_string_body(req)
  case string.trim(body) {
    "" ->
      wisp.response(400)
      |> wisp.json_body("{\"ok\":false,\"error\":\"Boş istek gövdesi\"}")
    json_payload -> {
      let agency_id = agency_id_from_json_payload(json_payload)
      case agency_request_authorized(req, conn, agency_id, peer) {
        False ->
          wisp.response(401)
          |> wisp.json_body(
            "{\"ok\":false,\"error\":\"Geçersiz yetkilendirme anahtarı\"}",
          )
        True -> {
          case
            pog.query(
              "select partners.receive_reservation_webhook_json($1::jsonb)",
            )
            |> pog.parameter(pog.text(json_payload))
            |> pog.returning(single_string_decoder())
            |> pog.execute(conn)
          {
            Ok(res) -> {
              let reply =
                list.first(res.rows)
                |> result.unwrap("{\"ok\":true,\"status\":\"processed\"}")
              wisp.ok()
              |> wisp.json_body(reply)
            }
            Error(_) ->
              wisp.response(500)
              |> wisp.json_body(
                "{\"ok\":false,\"error\":\"Rezervasyon webhook işlenemedi\"}",
              )
          }
        }
      }
    }
  }
}

fn admin(
  req: wisp.Request,
  conn: pog.Connection,
  csrf: String,
  origin: String,
) {
  let token =
    wisp.get_cookie(req, "nexus_session", wisp.Signed) |> result.unwrap("")
  case db.session(conn, token) {
    Error(_) -> wisp.redirect("/login")
    Ok(s) -> {
      let path = wisp.path_segments(req)
      let supplier_only = case path {
        ["admin", "calendar", ..]
        | ["admin", "options", ..]
        | ["admin", "listings", ..] -> True
        _ -> False
      }
      let is_supplier_or_admin =
        s.workspace == "supplier" || s.workspace == "nexus"
      case supplier_only && !is_supplier_or_admin {
        True ->
          wisp.response(403)
          |> wisp.set_header("content-type", "text/html; charset=utf-8")
          |> wisp.html_body(view.shell(
            s,
            csrf,
            "Yetkisiz Erişim",
            view.el("div", "notice", [
              text(
                "Bu bölüm yalnız tedarikçi ve yönetici çalışma alanına açıktır.",
              ),
            ]),
          ))
        False ->
          case req.method, path {
            http.Get, ["admin", "control-center"] ->
              platform_control_page(conn, s, csrf)
            http.Get, ["admin", "category-filters", "data"] ->
              category_filters_json(conn, s)
            http.Post, ["admin", "category-filters", "groups"] -> {
              use f <- authorized_form(req, csrf, origin)
              case
                s.workspace == "nexus"
                && domain.can_access_category_fields(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let category = field(f, "category") |> category_or_default
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "with saved as (insert into onboarding.category_filter_groups(category_code, group_key, title, help_text, display_type, multiple, position, active) values($1, $2, $3, nullif($4,''), $5, $6, $7, true) on conflict(category_code, group_key) do update set title = excluded.title, help_text = excluded.help_text, display_type = excluded.display_type, multiple = excluded.multiple, position = excluded.position, active = true, updated_at = now() returning id) select onboarding.queue_category_filter_translations('group', id, 'tr')::text from saved",
                      [
                        pog.text(category),
                        pog.text(field(f, "group_key")),
                        pog.text(field(f, "title")),
                        pog.text(field(f, "help_text")),
                        pog.text(field(f, "display_type")),
                        pog.bool(field(f, "multiple") == "true"),
                        pog.int(
                          int.parse(field(f, "position"))
                          |> result.unwrap(10),
                        ),
                      ],
                    )
                    |> result.unwrap("failed")
                  category_fields_page(conn, s, csrf, category, case answer {
                    "failed" -> "Filtre grubu kaydedilemedi."
                    _ ->
                      "Filtre grubu kaydedildi ve çeviri kuyruğu güncellendi."
                  })
                }
              }
            }
            http.Post, ["admin", "category-filters", "groups", "deactivate"] -> {
              use f <- authorized_form(req, csrf, origin)
              case
                s.workspace == "nexus"
                && domain.can_access_category_fields(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let category = field(f, "category") |> category_or_default
                  let _ =
                    calendar.command(
                      conn,
                      s,
                      "update onboarding.category_filter_groups set active=false, updated_at=now() where id=$1::uuid",
                      [pog.text(field(f, "group_id"))],
                    )
                  category_fields_page(
                    conn,
                    s,
                    csrf,
                    category,
                    "Filtre grubu pasifleştirildi.",
                  )
                }
              }
            }
            http.Post, ["admin", "category-filters", "items"] -> {
              use f <- authorized_form(req, csrf, origin)
              case
                s.workspace == "nexus"
                && domain.can_access_category_fields(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let category = field(f, "category") |> category_or_default
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "with saved as (insert into onboarding.category_filter_items(group_id, item_key, title, help_text, contract_field_code, contract_value, position, active) values($1::uuid, $2, $3, nullif($4,''), nullif($5,''), nullif($6,''), $7, true) on conflict(group_id, item_key) do update set title = excluded.title, help_text = excluded.help_text, contract_field_code = excluded.contract_field_code, contract_value = excluded.contract_value, position = excluded.position, active = true, updated_at = now() returning id) select onboarding.queue_category_filter_translations('item', id, 'tr')::text from saved",
                      [
                        pog.text(field(f, "group_id")),
                        pog.text(field(f, "item_key")),
                        pog.text(field(f, "title")),
                        pog.text(field(f, "help_text")),
                        pog.text(field(f, "contract_field_code")),
                        pog.text(field(f, "contract_value")),
                        pog.int(
                          int.parse(field(f, "position"))
                          |> result.unwrap(10),
                        ),
                      ],
                    )
                    |> result.unwrap("failed")
                  category_fields_page(conn, s, csrf, category, case answer {
                    "failed" -> "Filtre maddesi kaydedilemedi."
                    _ ->
                      "Filtre maddesi kaydedildi ve çeviri kuyruğu güncellendi."
                  })
                }
              }
            }
            http.Post, ["admin", "category-filters", "items", "deactivate"] -> {
              use f <- authorized_form(req, csrf, origin)
              case
                s.workspace == "nexus"
                && domain.can_access_category_fields(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let category = field(f, "category") |> category_or_default
                  let _ =
                    calendar.command(
                      conn,
                      s,
                      "update onboarding.category_filter_items set active=false, updated_at=now() where id=$1::uuid",
                      [pog.text(field(f, "item_id"))],
                    )
                  category_fields_page(
                    conn,
                    s,
                    csrf,
                    category,
                    "Filtre maddesi pasifleştirildi.",
                  )
                }
              }
            }
            http.Get, ["admin", "category-fields"] ->
              wisp.redirect("/admin/category-fields/villa")
            http.Get, ["admin", "category-fields", category] ->
              category_fields_page(conn, s, csrf, category, "")
            http.Post, ["admin", "category-fields", "sync-presets"] -> {
              use f <- authorized_form(req, csrf, origin)
              case
                s.workspace == "nexus"
                && domain.can_access_category_fields(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let _ =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.reset_standard_criteria()",
                      [],
                    )
                  let cat = field(f, "category")
                  let redirect_cat = case cat {
                    "" -> "hotel"
                    c -> c
                  }
                  category_fields_page(
                    conn,
                    s,
                    csrf,
                    redirect_cat,
                    "Kategori şablonları ve sektörel kriter standartları başarıyla senkronize edildi!",
                  )
                }
              }
            }
            http.Post, ["admin", "category-fields", category] -> {
              use f <- authorized_form(req, csrf, origin)
              case
                s.workspace == "nexus"
                && domain.can_access_category_fields(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let answer =
                    case field(f, "delete") == "true" {
                      True ->
                        calendar.command(
                          conn,
                          s,
                          "select onboarding.category_field_delete($1::uuid)",
                          [pog.text(field(f, "id"))],
                        )
                      False ->
                        calendar.command(
                          conn,
                          s,
                          "select onboarding.category_field_save(nullif($1,'')::uuid,$2,$3,$4,$5,$6,$7,$8,$9)",
                          [
                            pog.text(field(f, "id")),
                            pog.text(category),
                            pog.text(field(f, "code")),
                            pog.text(field(f, "label")),
                            pog.text(field(f, "kind")),
                            pog.text(field(f, "choices")),
                            pog.bool(field(f, "required") == "true"),
                            pog.bool(field(f, "active") == "true"),
                            pog.int(
                              int.parse(field(f, "position"))
                              |> result.unwrap(10),
                            ),
                          ],
                        )
                    }
                    |> result.unwrap("failed")
                  category_fields_page(
                    conn,
                    s,
                    csrf,
                    category,
                    calendar.message(answer),
                  )
                }
              }
            }
            http.Get, ["admin", "departments"] ->
              departments_page(conn, s, csrf, "")
            http.Get, ["admin", "messages"] -> {
              case
                s.workspace == "nexus" && domain.can_access_messages(s.role)
              {
                False -> wisp.response(403)
                True ->
                  case
                    calendar.rows(conn, s, "select * from cms.contact_inbox()")
                  {
                    Ok(rows) -> html(contact_inbox.page(s, csrf, rows))
                    Error(_) -> fail()
                  }
              }
            }
            http.Get, ["admin", "ai"] -> ai_page(conn, s, csrf, "")
            http.Post, ["admin", "ai", "actions", id, "decide"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select ai.decide_action($1,$2,$3)", [
                  pog.text(id),
                  pog.text(field(f, "decision")),
                  pog.text("İnsan onay merkezi kararı"),
                ])
                |> result.unwrap("failed")
              ai_page(conn, s, csrf, calendar.message(answer))
            }
            http.Get, ["admin", "finance"] -> finance_page(conn, s, csrf, "")
            http.Get, ["admin", "supplier-performance"] -> {
              case
                s.workspace == "supplier"
                && domain.can_access_supplier_permission(
                  s.role,
                  "supplier.reports.view",
                )
              {
                False -> wisp.response(403)
                True ->
                  case
                    calendar.rows(
                      conn,
                      s,
                      "select * from onboarding.supplier_performance()",
                    ),
                    calendar.rows(
                      conn,
                      s,
                      "select * from onboarding.supplier_settlement_totals()",
                    )
                  {
                    Ok(metrics), Ok(settlements) ->
                      html(supplier_performance_view.page(
                        s,
                        csrf,
                        metrics,
                        settlements,
                      ))
                    _, _ -> fail()
                  }
              }
            }
            http.Get, ["admin", "pricing"] -> pricing_page(conn, s, csrf, "")
            http.Get, ["admin", "digital-twin"] ->
              digital_twin_page(conn, s, csrf, "")
            http.Post, ["admin", "reservations", id, "post-ledger"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.accounting.manage",
                )
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.payments.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select finance.post_reservation_ledger($1)",
                      [pog.text(id)],
                    )
                    |> result.unwrap("failed")
                  finance_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "departments"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(
                  conn,
                  s,
                  "select organization.assign($1,$2,$3,$4)",
                  [
                    pog.text(s.tenant),
                    pog.text(field(f, "workspace")),
                    pog.text(field(f, "code")),
                    pog.text(field(f, "status")),
                  ],
                )
                |> result.unwrap("failed")
              departments_page(conn, s, csrf, calendar.message(answer))
            }
            http.Get, ["admin", "modules"] -> {
              case s.workspace {
                "supplier" ->
                  case
                    calendar.rows(
                      conn,
                      s,
                      "select * from onboarding.supplier_module_catalog()",
                    )
                  {
                    Ok(rows) ->
                      html(modules_view.supplier_page(s, csrf, rows, ""))
                    Error(_) -> fail()
                  }
                "nexus" -> modules_page(conn, s, csrf, "")
                _ -> wisp.response(403)
              }
            }
            http.Get, ["admin", "modules", "supplier", supplier_id] ->
              supplier_modules_page(conn, s, csrf, supplier_id, "")
            http.Get, ["admin", "modules", "ops", module_code] ->
              module_ops_page(conn, s, csrf, module_code, "")
            http.Post, ["admin", "modules"]
            | http.Post, ["admin", "modules", "assign"]
            -> {
              case domain.can_assign_modules(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.assign_module($1,$2,$3)",
                      [
                        pog.text(field(f, "supplier")),
                        pog.text(field(f, "module")),
                        pog.text(field(f, "status")),
                      ],
                    )
                    |> result.unwrap("failed")
                  let supplier_id = field(f, "supplier")
                  case supplier_id {
                    "" -> modules_page(conn, s, csrf, calendar.message(answer))
                    _ ->
                      supplier_modules_page(
                        conn,
                        s,
                        csrf,
                        supplier_id,
                        calendar.message(answer),
                      )
                  }
                }
              }
            }
            http.Post, ["admin", "modules", "unassign"] -> {
              case domain.can_assign_modules(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.unassign_module($1,$2)",
                      [
                        pog.text(field(f, "supplier")),
                        pog.text(field(f, "module")),
                      ],
                    )
                    |> result.unwrap("failed")
                  let supplier_id = field(f, "supplier")
                  case supplier_id {
                    "" -> modules_page(conn, s, csrf, calendar.message(answer))
                    _ ->
                      supplier_modules_page(
                        conn,
                        s,
                        csrf,
                        supplier_id,
                        calendar.message(answer),
                      )
                  }
                }
              }
            }
            http.Post, ["admin", "modules", "ops", module_code, "sync"] -> {
              use _f <- authorized_form(req, csrf, origin)
              case module_permission_allowed(conn, s, module_code) {
                True -> {
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.trigger_module_action($1,$2,$3)",
                      [
                        pog.text(module_code),
                        pog.text("manual_sync"),
                        pog.text("Operasyonel Konsol Tetiklemesi"),
                      ],
                    )
                    |> result.unwrap("failed")
                  module_ops_page(
                    conn,
                    s,
                    csrf,
                    module_code,
                    calendar.message(answer),
                  )
                }
                False -> wisp.response(403)
              }
            }
            http.Get, ["admin", "applications"] ->
              onboarding_page(conn, s, csrf, "")
            http.Get, ["admin", "onboarding"] ->
              wisp.redirect("/admin/applications")
            http.Get, ["admin", "users"] -> users_page(conn, s, csrf, "")
            http.Post, ["admin", "users"] -> {
              case domain.can_manage_team(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select auth.create_managed_user($1,$2,$3,$4,$5)",
                      [
                        pog.text(field(f, "tenant")),
                        pog.text(field(f, "email")),
                        pog.text(field(f, "name")),
                        pog.text(field(f, "role")),
                        pog.text(field(f, "password")),
                      ],
                    )
                    |> result.unwrap("failed")
                  users_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "users", id] -> {
              case domain.can_manage_team(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select auth.update_managed_user($1,$2,$3,$4)",
                      [
                        pog.text(id),
                        pog.text(field(f, "name")),
                        pog.text(field(f, "role")),
                        pog.bool(field(f, "active") == "true"),
                      ],
                    )
                    |> result.unwrap("failed")
                  users_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "users", id, "password"] -> {
              case domain.can_manage_team(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select auth.reset_managed_password($1,$2)",
                      [pog.text(id), pog.text(field(f, "password"))],
                    )
                    |> result.unwrap("failed")
                  users_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Get, ["admin", "profile"] ->
              html(users_view.profile(s, csrf, ""))
            http.Post, ["admin", "profile"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select auth.update_my_profile($1)", [
                  pog.text(field(f, "name")),
                ])
                |> result.unwrap("failed")
              html(users_view.profile(s, csrf, calendar.message(answer)))
            }
            http.Post, ["admin", "profile", "password"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(
                  conn,
                  s,
                  "select auth.change_my_password($1,$2)",
                  [
                    pog.text(field(f, "current")),
                    pog.text(field(f, "password")),
                  ],
                )
                |> result.unwrap("failed")
              html(users_view.profile(s, csrf, calendar.message(answer)))
            }
            http.Get, ["admin", "application"] ->
              supplier_application_page(conn, s, csrf, "")
            http.Post, ["admin", "application"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(
                  conn,
                  s,
                  "select onboarding.apply($1,$2,$3::jsonb)",
                  [
                    pog.text(field(f, "category")),
                    pog.text(field(f, "legal_name")),
                    pog.text(
                      json.to_string(
                        json.object([
                          #("full_name", json.string(field(f, "full_name"))),
                          #("tc", json.string(field(f, "tc"))),
                        ]),
                      ),
                    ),
                  ],
                )
                |> result.unwrap("failed")
              supplier_application_page(conn, s, csrf, calendar.message(answer))
            }
            http.Post, ["admin", "application", id, "document"] -> {
              use form <- wisp.require_form(wisp.set_max_files_size(
                req,
                10_485_760,
              ))
              case
                secure_form_csrf(form.values, csrf)
                && request.get_header(req, "origin") == Ok(origin)
              {
                False -> wisp.response(403)
                True ->
                  case list.key_find(form.files, "document") {
                    Error(_) ->
                      supplier_application_page(
                        conn,
                        s,
                        csrf,
                        "Lütfen PDF, JPG veya PNG belge seçin.",
                      )
                    Ok(wisp.UploadedFile(file_name: original, path: temporary)) -> {
                      let extension = file_extension(original)
                      case
                        list.contains(["pdf", "jpg", "jpeg", "png"], extension)
                      {
                        False ->
                          supplier_application_page(
                            conn,
                            s,
                            csrf,
                            "Yalnızca PDF, JPG ve PNG dosyaları yüklenebilir.",
                          )
                        True -> {
                          let token = wisp.random_string(32) <> "." <> extension
                          let destination = ".local/uploads/" <> token
                          let saved = case
                            simplifile.create_directory_all(".local/uploads")
                          {
                            Ok(_) ->
                              simplifile.copy_file(
                                at: temporary,
                                to: destination,
                              )
                            Error(e) -> Error(e)
                          }
                          case saved {
                            Error(_) ->
                              supplier_application_page(
                                conn,
                                s,
                                csrf,
                                "Dosya güvenli depoya kaydedilemedi.",
                              )
                            Ok(_) -> {
                              let answer =
                                calendar.command(
                                  conn,
                                  s,
                                  "select onboarding.register_document($1,$2,$3,$4,$5)",
                                  [
                                    pog.text(id),
                                    pog.text(field(form.values, "requirement")),
                                    pog.text("upload:" <> token),
                                    pog.text(original),
                                    pog.text(field(form.values, "expires_on")),
                                  ],
                                )
                                |> result.unwrap("failed")
                              case answer == "ok" {
                                True -> Nil
                                False -> {
                                  let _ =
                                    simplifile.delete_file(at: destination)
                                  Nil
                                }
                              }
                              supplier_application_page(
                                conn,
                                s,
                                csrf,
                                calendar.message(answer),
                              )
                            }
                          }
                        }
                      }
                    }
                  }
              }
            }
            http.Get, ["admin", "documents", token] ->
              document_download(conn, s, token)
            http.Post, ["admin", "applications", "document", id] -> {
              case domain.can_manage_documents(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.review_document($1,$2)",
                      [pog.text(id), pog.text(field(f, "status"))],
                    )
                    |> result.unwrap("failed")
                  onboarding_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "applications", id, "identity"] -> {
              case domain.can_manage_documents(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.identity_result($1,$2,$3,$4)",
                      [
                        pog.text(id),
                        pog.text(field(f, "result")),
                        pog.text("nvi_kps"),
                        pog.text(field(f, "reason")),
                      ],
                    )
                    |> result.unwrap("failed")
                  onboarding_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "applications", id, "decision"] -> {
              case domain.can_manage_documents(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select onboarding.decide($1,$2,$3)",
                      [
                        pog.text(id),
                        pog.text(field(f, "decision")),
                        pog.text(field(f, "reason")),
                      ],
                    )
                    |> result.unwrap("failed")
                  onboarding_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "site"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select cms.create_page($1,$2)", [
                  pog.text(field(f, "slug")),
                  pog.text(field(f, "title")),
                ])
                |> result.unwrap("failed")
              cms_page(conn, s, csrf, calendar.message(answer))
            }
            http.Get, ["admin", "site", slug, "preview"] -> {
              case
                s.workspace == "nexus"
                && list.contains(["owner", "editor"], s.role)
              {
                False -> wisp.response(403)
                True ->
                  case
                    calendar.rows(conn, s, "select * from cms.editor_pages()")
                  {
                    Error(_) -> fail()
                    Ok(rows) -> {
                      let previews =
                        list.filter_map(rows, fn(r) {
                          case r {
                            [id, t, d, b, _, _] -> Ok([id, t, d, b])
                            _ -> Error(Nil)
                          }
                        })
                      case site.render(previews, slug) {
                        Ok(body) -> html(body)
                        Error(_) -> wisp.not_found()
                      }
                    }
                  }
              }
            }
            http.Get, ["admin", "site"] -> cms_page(conn, s, csrf, "")
            http.Get, ["admin", "partners"] ->
              partners_page(conn, s, csrf, False, "")
            http.Get, ["admin", "partners", "connection-requests"] ->
              connection_requests_page(conn, s, csrf, "")
            http.Post,
              ["admin", "partners", "connection-requests", id, "decide"]
            -> {
              use f <- authorized_form(req, csrf, origin)
              let decision = field(f, "decision")
              let answer =
                calendar.command(
                  conn,
                  s,
                  "select partners.decide_connection_request($1,$2,$3,$4,$5)",
                  [
                    pog.text(id),
                    pog.text(decision),
                    pog.text(field(f, "categories")),
                    pog.int(
                      int.parse(field(f, "listing_limit")) |> result.unwrap(100),
                    ),
                    pog.text(field(f, "note")),
                  ],
                )
                |> result.unwrap("failed")
              let message = case
                decision == "approved"
                && string.starts_with(answer, "agency_api_key:")
              {
                False -> calendar.message(answer)
                True -> {
                  let api_key = string.drop_start(answer, 15)
                  let callback_key =
                    envoy.get("NEXUS_API_KEY") |> result.unwrap("")
                  let callback_result =
                    send_agency_connection_approval(
                      conn,
                      id,
                      api_key,
                      callback_key,
                    )
                  case callback_result {
                    Ok(_) -> {
                      record_agency_connection_callback(conn, id, "sent", "")
                      "Bağlantı onaylandı ve API anahtarı acenteye otomatik yazıldı."
                    }
                    Error(reason) -> {
                      record_agency_connection_callback(
                        conn,
                        id,
                        "failed",
                        reason,
                      )
                      calendar.message(answer)
                      <> " Acente callback hatası: "
                      <> reason
                    }
                  }
                }
              }
              connection_requests_page(conn, s, csrf, message)
            }
            http.Post,
              ["admin", "partners", "connection-requests", id, "retry-callback"]
            -> {
              use _f <- authorized_form(req, csrf, origin)
              let answer = retry_agency_connection_callback(conn, s, id)
              connection_requests_page(conn, s, csrf, calendar.message(answer))
            }
            http.Post, ["admin", "site", slug, "save"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select cms.save($1,$2,$3,$4,$5)", [
                  pog.text(slug),
                  pog.text(field(f, "title")),
                  pog.text(field(f, "summary")),
                  pog.text(field(f, "body")),
                  pog.int(int.parse(field(f, "version")) |> result.unwrap(0)),
                ])
                |> result.unwrap("failed")
              cms_page(conn, s, csrf, calendar.message(answer))
            }
            http.Post, ["admin", "site", slug, "publish"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select cms.publish($1,$2,$3)", [
                  pog.text(slug),
                  pog.int(int.parse(field(f, "version")) |> result.unwrap(0)),
                  pog.bool(field(f, "publish") == "true"),
                ])
                |> result.unwrap("failed")
              cms_page(conn, s, csrf, calendar.message(answer))
            }
            http.Post, ["admin", "site", slug, "translate"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select cms.translate_all($1,$2)", [
                  pog.text(slug),
                  pog.text(field(f, "source_locale")),
                ])
                |> result.unwrap("failed")
              cms_page(conn, s, csrf, calendar.message(answer))
            }
            http.Post, ["admin", "site", slug, "delete"] -> {
              use _ <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select cms.delete_page($1)", [
                  pog.text(slug),
                ])
                |> result.unwrap("failed")
              cms_page(conn, s, csrf, calendar.message(answer))
            }
            http.Get, ["admin", "settings"] -> settings_page(conn, s, csrf, "")
            http.Post, ["admin", "settings"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                settings.save(
                  conn,
                  s,
                  field(f, "key"),
                  field(f, "value"),
                  int.parse(field(f, "version")) |> result.unwrap(-1),
                  field(f, "action") == "clear",
                )
              settings_page(conn, s, csrf, calendar.message(answer))
            }
            http.Get, ["admin", "reservations"] ->
              case domain.can_access_reservations(s.role) {
                False -> wisp.response(403)
                True -> reservations_page(conn, s, csrf, "")
              }
            http.Post, ["admin", "requests", id, "confirm"] -> {
              case domain.can_manage_reservations(s.role) {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select booking.confirm_request($1)",
                      [
                        pog.text(id),
                      ],
                    )
                    |> result.unwrap("failed")
                  reservations_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "reservations", id, "cancel"] -> {
              case domain.can_manage_reservations(s.role) {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select booking.cancel_reservation($1)",
                      [pog.text(id)],
                    )
                    |> result.unwrap("failed")
                  reservations_page(conn, s, csrf, calendar.message(answer))
                }
              }
            }
            http.Get, ["admin", "requests"] ->
              partners_page(conn, s, csrf, True, "")
            http.Post, ["admin", "partners"] -> {
              use f <- authorized_form(req, csrf, origin)
              let answer =
                calendar.command(conn, s, "select partners.connect($1,$2,$3)", [
                  pog.text(field(f, "supplier")),
                  pog.text(field(f, "agency")),
                  pog.text(field(f, "status")),
                ])
                |> result.unwrap("failed")
              partners_page(conn, s, csrf, False, calendar.message(answer))
            }
            http.Post, ["admin", "requests"] -> {
              case
                domain.can_manage_reservations(s.role)
                || s.workspace == "agency"
              {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select booking.request_option($1,$2,$3,$4,$5)",
                      [
                        pog.text(field(f, "property")),
                        pog.text(field(f, "start")),
                        pog.text(field(f, "end")),
                        pog.int(
                          int.parse(field(f, "minutes")) |> result.unwrap(0),
                        ),
                        pog.text(field(f, "request_key")),
                      ],
                    )
                    |> result.unwrap("failed")
                  partners_page(conn, s, csrf, True, calendar.message(answer))
                }
              }
            }
            http.Post, ["admin", "requests", id, "decide"] -> {
              case domain.can_manage_reservations(s.role) {
                False -> wisp.response(403)
                True -> {
                  use f <- authorized_form(req, csrf, origin)
                  let answer =
                    calendar.command(
                      conn,
                      s,
                      "select booking.decide_request($1,$2)",
                      [pog.text(id), pog.text(field(f, "decision"))],
                    )
                    |> result.unwrap("failed")
                  partners_page(conn, s, csrf, True, calendar.message(answer))
                }
              }
            }
            http.Get, ["admin", "calendar"] ->
              calendar_page(conn, s, csrf, False, "")
            http.Get, ["admin", "options"] ->
              calendar_page(conn, s, csrf, True, "")
            http.Post, ["admin", "calendar"] -> {
              case
                domain.can_manage_pricing(s.role)
                || domain.can_manage_availability(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  case domain.minor_units(field(fields, "price")) {
                    Error(msg) -> calendar_page(conn, s, csrf, False, msg)
                    Ok(amount) -> {
                      let outcome =
                        calendar.command(
                          conn,
                          s,
                          "select inventory.configure($1,$2,$3,$4,$5)",
                          [
                            pog.text(field(fields, "property")),
                            pog.text(field(fields, "start")),
                            pog.text(field(fields, "end")),
                            pog.int(amount),
                            pog.bool(field(fields, "blocked") == "true"),
                          ],
                        )
                        |> result.unwrap("failed")
                      calendar_page(
                        conn,
                        s,
                        csrf,
                        False,
                        calendar.message(outcome),
                      )
                    }
                  }
                }
              }
            }
            http.Post, ["admin", "options"] -> {
              case
                domain.can_manage_availability(s.role)
                || domain.can_manage_reservations(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let minutes =
                    int.parse(field(fields, "minutes")) |> result.unwrap(0)
                  let outcome =
                    calendar.command(
                      conn,
                      s,
                      "select inventory.create_hold($1,$2,$3,$4,$5)",
                      [
                        pog.text(field(fields, "property")),
                        pog.text(field(fields, "start")),
                        pog.text(field(fields, "end")),
                        pog.int(minutes),
                        pog.text(field(fields, "request_key")),
                      ],
                    )
                    |> result.unwrap("failed")
                  calendar_page(conn, s, csrf, True, calendar.message(outcome))
                }
              }
            }
            http.Post, ["admin", "options", id, "release"] -> {
              case
                domain.can_manage_availability(s.role)
                || domain.can_manage_reservations(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let outcome =
                    calendar.command(
                      conn,
                      s,
                      "select inventory.release_hold($1)",
                      [
                        pog.text(id),
                      ],
                    )
                    |> result.unwrap("failed")
                  calendar_page(conn, s, csrf, True, calendar.message(outcome))
                }
              }
            }
            http.Get, ["admin"] ->
              case s.workspace {
                "nexus" -> html(site.program(s, csrf))
                "agency" -> partners_page(conn, s, csrf, False, "")
                _ ->
                  case domain.default_dashboard(s.role) {
                    "/admin" ->
                      case db.properties(conn, s) {
                        Ok(items) -> html(view.dashboard(s, csrf, items))
                        Error(_) -> fail()
                      }
                    target -> wisp.redirect(target)
                  }
              }
            http.Get, ["admin", "campaigns"] -> {
              case
                domain.can_access_listings(s.role)
                || domain.can_access_social_media(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let f_code =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let message = case f_code {
                    "created" ->
                      "Kampanya başarıyla oluşturuldu ve tüm kanallarda yayına alındı."
                    "toggled" -> "Kampanya durumu başarıyla güncellendi."
                    "deleted" -> "Kampanya sistemden kaldırıldı."
                    _ -> ""
                  }
                  campaigns_page(conn, s, csrf, message)
                }
              }
            }
            http.Post, ["admin", "campaigns"] -> {
              case
                domain.can_access_listings(s.role)
                || domain.can_access_social_media(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let name = field(fields, "name")
                  let ctype = field(fields, "campaign_type")
                  let dtype = field(fields, "discount_type")
                  let dval =
                    int.parse(field(fields, "discount_val"))
                    |> result.unwrap(10)
                  let prop_id = field(fields, "property_id")
                  let cat_code = field(fields, "category_code")
                  let promo_code = field(fields, "promo_code")
                  let min_stay =
                    int.parse(field(fields, "min_stay_nights"))
                    |> result.unwrap(1)
                  let days_adv =
                    int.parse(field(fields, "days_in_advance"))
                    |> result.unwrap(0)
                  let start_d = field(fields, "start_date")
                  let end_d = field(fields, "end_date")
                  let usage_limit =
                    int.parse(field(fields, "usage_limit"))
                    |> result.unwrap(100)
                  let badge = field(fields, "badge_text")

                  case
                    db.create_campaign(
                      conn,
                      s,
                      name,
                      ctype,
                      dtype,
                      dval,
                      prop_id,
                      cat_code,
                      promo_code,
                      min_stay,
                      days_adv,
                      start_d,
                      end_d,
                      usage_limit,
                      badge,
                    )
                  {
                    Ok("ok") -> wisp.redirect("/admin/campaigns?msg=created")
                    Ok(err) -> campaigns_page(conn, s, csrf, "Hata: " <> err)
                    Error(_) ->
                      campaigns_page(
                        conn,
                        s,
                        csrf,
                        "Hata: Kampanya kaydedilirken bir sorun oluştu.",
                      )
                  }
                }
              }
            }
            http.Post, ["admin", "campaigns", id, "toggle"] -> {
              case
                domain.can_access_listings(s.role)
                || domain.can_access_social_media(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let active = field(fields, "active") == "true"
                  let _ = db.toggle_campaign(conn, s, id, active)
                  wisp.redirect("/admin/campaigns?msg=toggled")
                }
              }
            }
            http.Post, ["admin", "campaigns", id, "delete"] -> {
              case
                domain.can_access_listings(s.role)
                || domain.can_access_social_media(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let _ = db.delete_campaign(conn, s, id)
                  wisp.redirect("/admin/campaigns?msg=deleted")
                }
              }
            }
            http.Post, ["admin", "campaigns", "calculate"] -> {
              use fields <- authorized_form(req, csrf, origin)
              let prop_id = field(fields, "property_id")
              let promo = field(fields, "promo_code")
              let in_date = field(fields, "check_in")
              let out_date = field(fields, "check_out")
              let base_price =
                int.parse(field(fields, "base_price")) |> result.unwrap(0)
              case
                db.calculate_booking_discount(
                  conn,
                  prop_id,
                  promo,
                  in_date,
                  out_date,
                  base_price,
                )
              {
                Ok(json_res) ->
                  wisp.ok()
                  |> wisp.set_header(
                    "content-type",
                    "application/json; charset=utf-8",
                  )
                  |> wisp.string_body(json_res)
                Error(_) ->
                  wisp.response(500)
                  |> wisp.string_body("{\"has_discount\":false}")
              }
            }

            // ─── ENTERPRISE EXPANSION MODULES ───────────────────────
            // 1. Muhasebe & Kasa Modülü
            http.Get, ["admin", "accounting"] -> {
              case domain.can_access_accounting(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let f_code =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let message = case f_code {
                    "tx_created" -> "Finansal hareket başarıyla kaydedildi."
                    "tx_deleted" -> "İşlem kaydı silindi."
                    _ -> ""
                  }
                  accounting_page(conn, s, csrf, message)
                }
              }
            }
            http.Post, ["admin", "accounting", "transaction"] -> {
              case domain.can_access_accounting(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let tx_type = case field(fields, "tx_type") {
                    "" -> field(fields, "type")
                    t -> t
                  }
                  let category = field(fields, "category")
                  let title = field(fields, "title")
                  let description = field(fields, "description")
                  let amount = case int.parse(field(fields, "amount")) {
                    Ok(v) -> v * 100
                    Error(_) -> 0
                  }
                  let currency = field(fields, "currency")
                  let payment_method = field(fields, "payment_method")
                  let document_no = case field(fields, "invoice_no") {
                    "" -> field(fields, "document_no")
                    d -> d
                  }
                  case
                    db.add_transaction(
                      conn,
                      s,
                      tx_type,
                      category,
                      title,
                      description,
                      amount,
                      currency,
                      payment_method,
                      document_no,
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/accounting?msg=tx_created")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "accounting", id, "delete"] -> {
              case
                list.contains(
                  ["owner", "general_manager", "accounting"],
                  s.role,
                )
              {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let _ = db.delete_transaction(conn, s, id)
                  wisp.redirect("/admin/accounting?msg=tx_deleted")
                }
              }
            }

            // 2. Sosyal Medya Modülleri
            http.Get, ["admin", "social-media"] -> {
              case domain.can_access_social_media(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let f_code =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let message = case f_code {
                    "post_created" ->
                      "Sosyal medya içeriği başarıyla planlandı/yayınlandı."
                    "post_deleted" -> "Paylaşım kaldırıldı."
                    _ -> ""
                  }
                  social_media_page(conn, s, csrf, message)
                }
              }
            }
            http.Post, ["admin", "social-media", "post"] -> {
              case domain.can_access_social_media(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let platform = field(fields, "platform")
                  let title = field(fields, "title")
                  let caption = field(fields, "caption")
                  let media_url = field(fields, "media_url")
                  let link_url = field(fields, "link_url")
                  let status = case field(fields, "status") {
                    "draft" -> "draft"
                    "scheduled" -> "scheduled"
                    _ -> "published"
                  }
                  case
                    db.create_social_post(
                      conn,
                      s,
                      platform,
                      title,
                      caption,
                      media_url,
                      link_url,
                      status,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect("/admin/social-media?msg=post_created")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "social-media", id, "delete"] -> {
              case domain.can_access_social_media(s.role) {
                False -> wisp.response(403)
                True -> {
                  use _ <- authorized_form(req, csrf, origin)
                  let _ = db.delete_social_post(conn, s, id)
                  wisp.redirect("/admin/social-media?msg=post_deleted")
                }
              }
            }

            // 3. Yapay Zeka Modülleri (AI Hub)
            http.Get, ["admin", "ai-hub"] -> {
              case domain.can_access_ai_hub(s.role) {
                False -> wisp.response(403)
                True -> html(ai_hub_view.page(s, csrf, "", "", ""))
              }
            }
            http.Post, ["admin", "ai-hub", "generate"] -> {
              case domain.can_access_ai_hub(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let tool_type = field(fields, "tool_type")
                  let title = field(fields, "title")
                  let category = field(fields, "category")
                  let locality = field(fields, "locality")
                  let amenities = field(fields, "amenities")
                  let promo_discount = field(fields, "promo_discount")
                  let tone = field(fields, "tone")
                  let guest_name = field(fields, "guest_name")
                  let rating = field(fields, "rating")
                  let comment = field(fields, "comment")
                  let occ_pct =
                    int.parse(field(fields, "occupancy_pct"))
                    |> result.unwrap(70)

                  let #(tool_label, output) = case tool_type {
                    "listing_seo" -> {
                      let #(st, sd) =
                        ai_generator.generate_listing_seo_copy(
                          title,
                          category,
                          locality,
                          amenities,
                        )
                      #(
                        "SEO Başlığı & Açıklama",
                        "Önerilen SEO Başlığı:\n"
                          <> st
                          <> "\n\nÖnerilen Meta Açıklama:\n"
                          <> sd,
                      )
                    }
                    "social_post" -> {
                      let copy =
                        ai_generator.generate_social_post_copy(
                          title,
                          category,
                          promo_discount,
                          tone,
                        )
                      #("Sosyal Medya Gönderi Metni", copy)
                    }
                    "review_reply" -> {
                      let reply =
                        ai_generator.generate_guest_review_reply(
                          guest_name,
                          rating,
                          comment,
                        )
                      #("Misafir Yorum Yanıtı", reply)
                    }
                    "demand_forecast" -> {
                      let #(dl, strat, adj) =
                        ai_generator.generate_demand_forecast(
                          category,
                          locality,
                          occ_pct,
                        )
                      let adj_sign = case adj >= 0 {
                        True -> "+"
                        False -> ""
                      }
                      #(
                        "Talep & Fiyat Stratejisi Analizi",
                        "Talep Seviyesi: "
                          <> dl
                          <> "\n\nÖnerilen Strateji:\n"
                          <> strat
                          <> "\n\nÖnerilen Dinamik Fiyat Revizyonu: "
                          <> adj_sign
                          <> int.to_string(adj)
                          <> "%",
                      )
                    }
                    _ -> #(
                      "Yapay Zeka Aracı",
                      "Seçilen araç için içerik üretilemedi.",
                    )
                  }
                  html(ai_hub_view.page(
                    s,
                    csrf,
                    tool_label,
                    output,
                    "Yapay zeka içeriği başarıyla üretildi!",
                  ))
                }
              }
            }

            // 4. Personel & İK & Bordro
            http.Get, ["admin", "hr"] -> {
              case domain.can_access_hr(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let f_code =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let message = case f_code {
                    "emp_created" ->
                      "Yeni personel kartı başarıyla oluşturuldu."
                    "cand_created" -> "Aday işe alım havuzuna eklendi."
                    "payroll_created" -> "Bordro / avans ödeme kaydı işlendi."
                    _ -> ""
                  }
                  hr_page(conn, s, csrf, message)
                }
              }
            }
            http.Post, ["admin", "hr", "employee"] -> {
              case domain.can_access_hr(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let full_name = field(fields, "full_name")
                  let department = field(fields, "department")
                  let position = field(fields, "position_title")
                  let tc_kimlik = field(fields, "tc_kimlik")
                  let phone = field(fields, "phone")
                  let email = field(fields, "email")
                  let salary = case int.parse(field(fields, "salary")) {
                    Ok(v) -> v * 100
                    Error(_) -> 0
                  }
                  let currency = field(fields, "currency")
                  let start_date = field(fields, "start_date")
                  case
                    db.add_employee(
                      conn,
                      s,
                      full_name,
                      department,
                      position,
                      tc_kimlik,
                      phone,
                      email,
                      salary,
                      currency,
                      start_date,
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/hr?msg=emp_created")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "hr", "candidate"] -> {
              case domain.can_access_hr(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let name = field(fields, "candidate_name")
                  let position = field(fields, "position_applied")
                  let phone = field(fields, "phone")
                  let email = field(fields, "email")
                  let stage = field(fields, "stage")
                  let date = field(fields, "interview_date")
                  let notes = field(fields, "notes")
                  case
                    db.add_candidate(
                      conn,
                      s,
                      name,
                      position,
                      phone,
                      email,
                      stage,
                      date,
                      notes,
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/hr?msg=cand_created")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "hr", "payroll"] -> {
              case domain.can_access_hr(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let emp_id = field(fields, "employee_id")
                  let p_type = field(fields, "payment_type")
                  let amount = case int.parse(field(fields, "amount")) {
                    Ok(v) -> v * 100
                    Error(_) -> 0
                  }
                  let cur = field(fields, "currency")
                  let ref_no = field(fields, "reference_no")
                  case
                    db.add_payroll(conn, s, emp_id, p_type, amount, cur, ref_no)
                  {
                    Ok(_) -> wisp.redirect("/admin/hr?msg=payroll_created")
                    Error(_) -> fail()
                  }
                }
              }
            }

            // 5. Oda Temizliği & Takibi (Housekeeping)
            http.Get, ["admin", "housekeeping"] -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let prop_id =
                    list.key_find(query_params, "prop_id") |> result.unwrap("")
                  let f_code =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let message = case f_code {
                    "status_updated" -> "Oda temizlik durumu güncellendi."
                    "task_assigned" -> "Temizlik görevi başarıyla atandı."
                    "task_updated" -> "Görev durumu güncellendi."
                    "ticket_created" -> "Arıza bildirimi teknik ekibe iletildi."
                    "ticket_resolved" ->
                      "Arıza biletiniz çözüldü olarak kapatıldı."
                    _ -> ""
                  }
                  housekeeping_page(conn, s, csrf, prop_id, message)
                }
              }
            }
            http.Post, ["admin", "housekeeping", "quick_clean"] -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let prop_id = field(fields, "property_id")
                  let room_code = field(fields, "room_code")
                  let _ = db.quick_mark_clean(conn, s, prop_id, room_code)
                  wisp.redirect(
                    "/admin/housekeeping?prop_id="
                    <> prop_id
                    <> "&msg=status_updated",
                  )
                }
              }
            }
            http.Post, ["admin", "housekeeping", "status"] -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let prop_id = field(fields, "property_id")
                  let unit_id = field(fields, "unit_id")
                  let status = field(fields, "status")
                  let _ = db.update_room_clean_status(conn, s, unit_id, status)
                  wisp.redirect(
                    "/admin/housekeeping?prop_id="
                    <> prop_id
                    <> "&msg=status_updated",
                  )
                }
              }
            }
            http.Post, ["admin", "housekeeping", "task"] -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let prop_id = field(fields, "property_id")
                  let room_code = field(fields, "room_code")
                  let staff = field(fields, "assigned_staff")
                  let task_type = field(fields, "task_type")
                  let notes = field(fields, "notes")
                  case
                    db.add_housekeeping_task(
                      conn,
                      s,
                      prop_id,
                      room_code,
                      staff,
                      task_type,
                      notes,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/housekeeping?prop_id="
                        <> prop_id
                        <> "&msg=task_assigned",
                      )
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "housekeeping", "task", id, "status"] -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let prop_id = field(fields, "property_id")
                  let status = field(fields, "status")
                  let _ =
                    db.update_housekeeping_task_status(conn, s, id, status)
                  wisp.redirect(
                    "/admin/housekeeping?prop_id="
                    <> prop_id
                    <> "&msg=task_updated",
                  )
                }
              }
            }
            http.Post, ["admin", "housekeeping", "maintenance"] -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let prop_id = field(fields, "property_id")
                  let room_code = field(fields, "room_code")
                  let title = field(fields, "issue_title")
                  let desc = field(fields, "description")
                  let priority = field(fields, "priority")
                  case
                    db.add_maintenance_ticket(
                      conn,
                      s,
                      prop_id,
                      room_code,
                      title,
                      desc,
                      priority,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/housekeeping?prop_id="
                        <> prop_id
                        <> "&msg=ticket_created",
                      )
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "housekeeping", "maintenance", id, "resolve"]
            -> {
              case domain.can_access_housekeeping(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let prop_id = field(fields, "property_id")
                  let _ = db.resolve_room_ticket(conn, s, id)
                  wisp.redirect(
                    "/admin/housekeeping?prop_id="
                    <> prop_id
                    <> "&msg=ticket_resolved",
                  )
                }
              }
            }

            // ─── 20 INDUSTRY ECOSYSTEM INTEGRATIONS ───────────────────
            // 1. Çok Kanallı CRM & WhatsApp Entegrasyonu
            http.Get, ["admin", "crm"] -> {
              case domain.can_access_crm(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let msg =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let notice = case msg {
                    "guest_ok" ->
                      "Yeni misafir profili CRM portföyüne kaydedildi."
                    "wa_ok" ->
                      "WhatsApp mesajı başarıyla sıraya alındı ve iletildi."
                    _ -> ""
                  }
                  crm_page(conn, s, csrf, notice)
                }
              }
            }
            http.Post, ["admin", "crm", "guest"] -> {
              case domain.can_access_crm(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let name = field(fields, "full_name")
                  let email = field(fields, "email")
                  let phone = field(fields, "phone")
                  let nat = field(fields, "nationality")
                  let tier = field(fields, "vip_tier")
                  let pref = field(fields, "preferences")
                  case
                    calendar.command(
                      conn,
                      s,
                      "select crm.add_guest($1,$2,$3,$4,$5,$6)",
                      [
                        pog.text(name),
                        pog.text(email),
                        pog.text(phone),
                        pog.text(nat),
                        pog.text(tier),
                        pog.text(pref),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/crm?msg=guest_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "crm", "message"] -> {
              case domain.can_access_crm(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let guest = case field(fields, "guest_name") {
                    "" ->
                      case field(fields, "recipient_name") {
                        "" -> "Değerli Misafir"
                        v -> v
                      }
                    v -> v
                  }
                  let phone = case field(fields, "phone") {
                    "" -> field(fields, "recipient_phone")
                    v -> v
                  }
                  let mtype = case field(fields, "msg_type") {
                    "" ->
                      case field(fields, "message_type") {
                        "" -> "pre_arrival"
                        v -> v
                      }
                    v -> v
                  }
                  let message = case field(fields, "message") {
                    "" -> field(fields, "content")
                    v -> v
                  }
                  case
                    calendar.command(
                      conn,
                      s,
                      "select crm.send_whatsapp_message($1,$2,$3,$4)",
                      [
                        pog.text(guest),
                        pog.text(phone),
                        pog.text(mtype),
                        pog.text(message),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/crm?msg=wa_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }

            // 2. Rate Shopper & AI Yield
            http.Get, ["admin", "rate-shopper"] -> {
              case domain.can_access_rate_shopper(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let msg =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let notice = case msg {
                    "rate_ok" -> "Rakip fiyat gözlemi ve AI analizi kaydedildi."
                    _ -> ""
                  }
                  rate_shopper_page(conn, s, csrf, notice)
                }
              }
            }
            http.Post, ["admin", "rate-shopper", "competitor"] -> {
              case domain.can_manage_pricing(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let name = field(fields, "name")
                  let stars =
                    int.parse(field(fields, "stars")) |> result.unwrap(4)
                  let room = field(fields, "room")
                  let channel = field(fields, "channel")
                  let comp_price =
                    int.parse(field(fields, "comp_price")) |> result.unwrap(0)
                  let our_price =
                    int.parse(field(fields, "our_price")) |> result.unwrap(0)
                  let currency = field(fields, "currency")
                  let dt = field(fields, "date")
                  let ai_rec = field(fields, "ai_rec")
                  case
                    calendar.command(
                      conn,
                      s,
                      "select revenue.add_competitor_rate($1,$2,$3,$4,$5,$6,$7,$8,$9)",
                      [
                        pog.text(name),
                        pog.int(stars),
                        pog.text(room),
                        pog.text(channel),
                        pog.int(comp_price),
                        pog.int(our_price),
                        pog.text(currency),
                        pog.text(dt),
                        pog.text(ai_rec),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/rate-shopper?msg=rate_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }

            // 3. Tur Operasyonu & Dinamik Paketleme
            http.Get, ["admin", "tours"] -> {
              case domain.can_access_tours(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let msg =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let notice = case msg {
                    "act_ok" -> "Yeni tur aktivitesi kataloğa eklendi."
                    "pkg_ok" ->
                      "Dinamik paket ve tekil voucher başarıyla oluşturuldu."
                    _ -> ""
                  }
                  tours_page(conn, s, csrf, notice)
                }
              }
            }
            http.Post, ["admin", "tours", "activity"] -> {
              case domain.can_access_tours(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let title = field(fields, "title")
                  let loc = field(fields, "location")
                  let cat = field(fields, "category")
                  let dur =
                    int.parse(field(fields, "duration")) |> result.unwrap(3)
                  let net =
                    int.parse(field(fields, "net_price")) |> result.unwrap(0)
                  let sale =
                    int.parse(field(fields, "sale_price")) |> result.unwrap(0)
                  let cur = field(fields, "currency")
                  let cap =
                    int.parse(field(fields, "capacity")) |> result.unwrap(20)
                  case
                    calendar.command(
                      conn,
                      s,
                      "select tours.add_activity($1,$2,$3,$4,$5,$6,$7,$8)",
                      [
                        pog.text(title),
                        pog.text(loc),
                        pog.text(cat),
                        pog.int(dur),
                        pog.int(net),
                        pog.int(sale),
                        pog.text(cur),
                        pog.int(cap),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/tours?msg=act_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "tours", "package"] -> {
              case domain.can_access_tours(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let guest = field(fields, "guest_name")
                  let hotel = field(fields, "hotel_name")
                  let act = field(fields, "activity_name")
                  let trf = field(fields, "transfer") == "true"
                  let price =
                    int.parse(field(fields, "price")) |> result.unwrap(0)
                  let cur = "EUR"
                  case
                    calendar.command(
                      conn,
                      s,
                      "select tours.create_package($1,$2,$3,$4,$5,$6)",
                      [
                        pog.text(guest),
                        pog.text(hotel),
                        pog.text(act),
                        pog.bool(trf),
                        pog.int(price),
                        pog.text(cur),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/tours?msg=pkg_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }

            // 4. Filo Yönetimi & Rent A Car
            http.Get, ["admin", "fleet"] -> {
              case domain.can_access_fleet(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let msg =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let notice = case msg {
                    "veh_ok" ->
                      "Yeni araç filoya kaydedildi ve KABIS onayına açıldı."
                    "rent_ok" ->
                      "Kiralama sözleşmesi düzenlendi ve KABIS bildirimi yapıldı."
                    _ -> ""
                  }
                  fleet_page(conn, s, csrf, notice)
                }
              }
            }
            http.Post, ["admin", "fleet", "vehicle"] -> {
              case domain.can_access_fleet(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let plate = case field(fields, "plate") {
                    "" -> field(fields, "plate_number")
                    v -> v
                  }
                  let brand = field(fields, "brand")
                  let model = field(fields, "model")
                  let year = case int.parse(field(fields, "year")) {
                    Ok(y) -> y
                    Error(_) ->
                      int.parse(field(fields, "model_year"))
                      |> result.unwrap(2024)
                  }
                  let trans = case field(fields, "trans") {
                    "" ->
                      case field(fields, "transmission") {
                        "" -> "automatic"
                        v -> v
                      }
                    v -> v
                  }
                  let fuel = case field(fields, "fuel") {
                    "" ->
                      case field(fields, "fuel_type") {
                        "" -> "diesel"
                        v -> v
                      }
                    v -> v
                  }
                  let km = case int.parse(field(fields, "km")) {
                    Ok(k) -> k
                    Error(_) ->
                      int.parse(field(fields, "current_km"))
                      |> result.unwrap(0)
                  }
                  let rate = case int.parse(field(fields, "rate")) {
                    Ok(r) -> r
                    Error(_) ->
                      int.parse(field(fields, "daily_rate"))
                      |> result.unwrap(1000)
                  }
                  let cur = "TRY"
                  case
                    calendar.command(
                      conn,
                      s,
                      "select fleet.add_vehicle($1,$2,$3,$4,$5,$6,$7,$8,$9)",
                      [
                        pog.text(plate),
                        pog.text(brand),
                        pog.text(model),
                        pog.int(year),
                        pog.text(trans),
                        pog.text(fuel),
                        pog.int(km),
                        pog.int(rate),
                        pog.text(cur),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/fleet?msg=veh_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "fleet", "rental"] -> {
              case domain.can_access_fleet(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let plate = field(fields, "plate")
                  let driver = field(fields, "driver")
                  let tc = field(fields, "tc")
                  let phone = field(fields, "phone")
                  let start_d = field(fields, "start")
                  let end_d = field(fields, "end")
                  let days =
                    int.parse(field(fields, "days")) |> result.unwrap(1)
                  let amount =
                    int.parse(field(fields, "amount")) |> result.unwrap(0)
                  let deposit =
                    int.parse(field(fields, "deposit")) |> result.unwrap(0)
                  let cur = "TRY"
                  let damage = field(fields, "damage")
                  case
                    calendar.command(
                      conn,
                      s,
                      "select fleet.create_rental($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)",
                      [
                        pog.text(plate),
                        pog.text(driver),
                        pog.text(tc),
                        pog.text(phone),
                        pog.text(start_d),
                        pog.text(end_d),
                        pog.int(days),
                        pog.int(amount),
                        pog.int(deposit),
                        pog.text(cur),
                        pog.text(damage),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/fleet?msg=rent_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }

            // 5. GİB e-Fatura, e-Arşiv & %2 Konaklama Vergisi
            http.Get, ["admin", "einvoice"] -> {
              case domain.can_access_einvoice(s.role) {
                False -> wisp.response(403)
                True -> {
                  let query_params = wisp.get_query(req)
                  let msg =
                    list.key_find(query_params, "msg") |> result.unwrap("")
                  let notice = case msg {
                    "inv_ok" ->
                      "Resmi e-Fatura imzalandı ve GİB portalına iletildi (1200 Başarılı)."
                    _ -> ""
                  }
                  einvoice_page(conn, s, csrf, notice)
                }
              }
            }
            http.Post, ["admin", "einvoice", "issue"] -> {
              case domain.can_access_einvoice(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let itype = case field(fields, "type") {
                    "" ->
                      case field(fields, "invoice_type") {
                        "" -> "e-Arsiv"
                        v -> v
                      }
                    v -> v
                  }
                  let name = case field(fields, "name") {
                    "" ->
                      case field(fields, "customer_title") {
                        "" -> "Müşteri"
                        v -> v
                      }
                    v -> v
                  }
                  let vkn = case field(fields, "vkn") {
                    "" ->
                      case field(fields, "tax_or_tc_number") {
                        "" -> "11111111111"
                        v -> v
                      }
                    v -> v
                  }
                  let tax_off = field(fields, "tax_office")
                  let net = case int.parse(field(fields, "net")) {
                    Ok(n) -> n
                    Error(_) ->
                      int.parse(field(fields, "net_amount"))
                      |> result.unwrap(1000)
                  }
                  let vat =
                    int.parse(field(fields, "vat"))
                    |> result.unwrap(net * 10 / 100)
                  let acc_tax =
                    int.parse(field(fields, "acc_tax"))
                    |> result.unwrap(net * 2 / 100)
                  let total = case int.parse(field(fields, "total")) {
                    Ok(t) if t > 0 -> t
                    _ -> net + vat + acc_tax
                  }
                  let cur = case field(fields, "currency") {
                    "" -> "TRY"
                    v -> v
                  }
                  let prof = case field(fields, "profile") {
                    "" ->
                      case field(fields, "profile_id") {
                        "" -> "EARSIVFATURA"
                        v -> v
                      }
                    v -> v
                  }
                  case
                    calendar.command(
                      conn,
                      s,
                      "select invoicing.issue_invoice($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",
                      [
                        pog.text(itype),
                        pog.text(name),
                        pog.text(vkn),
                        pog.text(tax_off),
                        pog.int(net),
                        pog.int(vat),
                        pog.int(acc_tax),
                        pog.int(total),
                        pog.text(cur),
                        pog.text(prof),
                      ],
                    )
                  {
                    Ok(_) -> wisp.redirect("/admin/einvoice?msg=inv_ok")
                    Error(_) -> fail()
                  }
                }
              }
            }

            http.Get, ["admin", "listings"] ->
              case domain.can_access_listings(s.role) {
                False -> wisp.response(403)
                True ->
                  case db.properties(conn, s) {
                    Ok(items) -> html(view.listings(s, csrf, items))
                    Error(_) -> fail()
                  }
              }
            http.Get, ["admin", "listings", "procedures"] ->
              case s.workspace == "supplier" || s.workspace == "nexus" {
                True -> procedures_page(conn, s, csrf)
                False -> wisp.response(403)
              }
            http.Get, ["admin", "listings", "new"] ->
              case s.workspace == "supplier" || s.workspace == "nexus" {
                True ->
                  listing_form(conn, s, csrf, "", [#("category_code", "hotel")])
                False -> wisp.response(403)
              }
            http.Get, ["admin", "listings", "new", category] ->
              case s.workspace == "supplier" || s.workspace == "nexus" {
                True ->
                  listing_form(conn, s, csrf, "", [#("category_code", category)])
                False -> wisp.response(403)
              }
            http.Post, ["logout"] -> {
              use _ <- authorized_form(req, csrf, origin)
              let _ = db.logout(conn, token)
              wisp.redirect("/login")
              |> wisp.set_cookie(req, "nexus_session", "", wisp.Signed, 0)
            }
            http.Post, ["admin", "ai", "generate"] -> {
              use fields <- authorized_form(req, csrf, origin)
              case
                list.contains(
                  ["owner", "general_manager", "sales", "marketing", "editor"],
                  s.role,
                )
              {
                False -> wisp.response(403)
                True -> {
                  let category = field(fields, "category_code")
                  let locality = field(fields, "locality")
                  let current_title = field(fields, "title")
                  let capacity = field(fields, "capacity")
                  let field_name = field(fields, "field")
                  let res =
                    ai_generator.generate_all(
                      category,
                      locality,
                      current_title,
                      capacity,
                    )
                  let json_payload =
                    json.object([
                      #("success", json.bool(True)),
                      #("field", json.string(field_name)),
                      #("title", json.string(res.title)),
                      #("description", json.string(res.description)),
                      #("seo_title", json.string(res.seo_title)),
                      #("seo_description", json.string(res.seo_description)),
                    ])
                    |> json.to_string

                  case field(fields, "ajax") == "1" {
                    True ->
                      wisp.ok()
                      |> wisp.set_header(
                        "content-type",
                        "application/json; charset=utf-8",
                      )
                      |> wisp.string_body(json_payload)
                    False -> {
                      let updated_fields = [
                        #("title", res.title),
                        #("description", res.description),
                        #("seo_title", res.seo_title),
                        #("seo_description", res.seo_description),
                        ..fields
                      ]
                      listing_form(
                        conn,
                        s,
                        csrf,
                        "Yapay zeka içerikleri başarıyla üretildi ve forma yerleştirildi.",
                        updated_fields,
                      )
                    }
                  }
                }
              }
            }
            http.Post, ["admin", "ai", "sort_photos"] -> {
              use fields <- authorized_form(req, csrf, origin)
              case
                list.contains(
                  ["owner", "general_manager", "sales", "marketing", "editor"],
                  s.role,
                )
              {
                False -> wisp.response(403)
                True -> {
                  let category = field(fields, "category_code")
                  let hero_img = field(fields, "hero_image")
                  let gallery_raw = field(fields, "gallery_images")

                  let raw_list =
                    string.split(gallery_raw, "\n")
                    |> list.flat_map(fn(line) { string.split(line, ",") })
                    |> list.map(string.trim)
                    |> list.filter(fn(u) { u != "" })

                  let all_urls = case string.trim(hero_img) {
                    "" -> raw_list
                    h -> {
                      case list.contains(raw_list, h) {
                        True -> raw_list
                        False -> [h, ..raw_list]
                      }
                    }
                  }

                  let ranked = ai_generator.rank_photos(category, all_urls)

                  let #(recommended_hero, sorted_gallery) = case ranked {
                    [] -> #("", [])
                    [first, ..rest] -> #(
                      first.url,
                      list.map(rest, fn(item) { item.url }),
                    )
                  }

                  let ranked_json =
                    list.map(ranked, fn(item) {
                      json.object([
                        #("url", json.string(item.url)),
                        #("rank", json.int(item.rank)),
                        #("tag", json.string(item.tag)),
                        #("score", json.int(item.score)),
                        #("reason", json.string(item.reason)),
                        #("is_hero", json.bool(item.is_hero)),
                      ])
                    })

                  let json_payload =
                    json.object([
                      #("success", json.bool(True)),
                      #("category", json.string(category)),
                      #("recommended_hero", json.string(recommended_hero)),
                      #(
                        "sorted_gallery",
                        json.array(sorted_gallery, of: json.string),
                      ),
                      #(
                        "ranked_items",
                        json.array(ranked_json, of: fn(x) { x }),
                      ),
                    ])
                    |> json.to_string

                  case field(fields, "ajax") == "1" {
                    True ->
                      wisp.ok()
                      |> wisp.set_header(
                        "content-type",
                        "application/json; charset=utf-8",
                      )
                      |> wisp.string_body(json_payload)
                    False -> {
                      let updated_fields = [
                        #("hero_image", recommended_hero),
                        #(
                          "gallery_images",
                          string.join(sorted_gallery, with: "\n"),
                        ),
                        ..fields
                      ]
                      listing_form(
                        conn,
                        s,
                        csrf,
                        "Fotoğraflar yapay zeka tarafından rezervasyon dönüşümünü optimize edecek şekilde sıralandı.",
                        updated_fields,
                      )
                    }
                  }
                }
              }
            }
            http.Post, ["admin", "media", "upload"] -> {
              use fields <- authorized_form(req, csrf, origin)
              case
                list.contains(
                  ["owner", "general_manager", "sales", "marketing", "editor"],
                  s.role,
                )
              {
                False -> wisp.response(403)
                True -> {
                  let raw_data = field(fields, "data")
                  let clean = clean_base64(raw_data)
                  case bit_array.base64_decode(clean) {
                    Ok(bytes) -> {
                      let storage_config = storage.get_storage_config(conn, s)
                      let filename = wisp.random_string(24) <> ".avif"
                      case storage.save_media(storage_config, filename, bytes) {
                        Ok(saved) -> {
                          let json_resp =
                            json.object([
                              #("success", json.bool(True)),
                              #("url", json.string(saved.url)),
                              #("format", json.string("avif")),
                              #("filename", json.string(filename)),
                              #("driver", json.string(saved.driver)),
                              #("local_saved", json.bool(saved.local_saved)),
                              #("bunny_saved", json.bool(saved.bunny_saved)),
                            ])
                            |> json.to_string
                          wisp.ok()
                          |> wisp.set_header(
                            "content-type",
                            "application/json; charset=utf-8",
                          )
                          |> wisp.string_body(json_resp)
                        }
                        Error(err) ->
                          wisp.response(500)
                          |> wisp.set_header(
                            "content-type",
                            "application/json; charset=utf-8",
                          )
                          |> wisp.string_body(
                            "{\"success\":false,\"error\":\"" <> err <> "\"}",
                          )
                      }
                    }
                    Error(_) ->
                      wisp.response(400)
                      |> wisp.set_header(
                        "content-type",
                        "application/json; charset=utf-8",
                      )
                      |> wisp.string_body(
                        "{\"success\":false,\"error\":\"Geçersiz görsel verisi (Base64 decode hatası).\"}",
                      )
                  }
                }
              }
            }
            http.Post, ["admin", "storage", "test_bunny"] -> {
              use fields <- authorized_form(req, csrf, origin)
              case domain.can_manage_team(s.role) {
                False -> wisp.response(403)
                True -> {
                  let region = field(fields, "region")
                  let zone = field(fields, "zone")
                  let api_key = field(fields, "api_key")
                  case storage.bunny_test_connection(region, zone, api_key) {
                    Ok(_) -> {
                      let json_resp =
                        json.object([
                          #("success", json.bool(True)),
                          #(
                            "message",
                            json.string(
                              "BunnyCDN Storage Zone ve erişim anahtarı başarıyla doğrulandı!",
                            ),
                          ),
                        ])
                        |> json.to_string
                      wisp.ok()
                      |> wisp.set_header(
                        "content-type",
                        "application/json; charset=utf-8",
                      )
                      |> wisp.string_body(json_resp)
                    }
                    Error(err) -> {
                      let json_resp =
                        json.object([
                          #("success", json.bool(False)),
                          #("error", json.string(err)),
                        ])
                        |> json.to_string
                      wisp.response(400)
                      |> wisp.set_header(
                        "content-type",
                        "application/json; charset=utf-8",
                      )
                      |> wisp.string_body(json_resp)
                    }
                  }
                }
              }
            }
            http.Post, ["admin", "listings"] -> {
              use fields <- authorized_form(req, csrf, origin)
              case domain.can_manage_catalog(s.role) {
                False -> wisp.response(403)
                True ->
                  case
                    domain.validate(
                      field(fields, "title"),
                      field(fields, "locality"),
                      field(fields, "description"),
                      field(fields, "capacity"),
                      field(fields, "price"),
                      field(fields, "currency"),
                    )
                  {
                    Error(msg) -> listing_form(conn, s, csrf, msg, fields)
                    Ok(draft) -> {
                      let hero_image = field(fields, "hero_image")
                      let gallery_images = field(fields, "gallery_images")
                      let video_url = field(fields, "video_url")
                      let media_json =
                        build_media_json(hero_image, gallery_images)
                      let raw_attrs =
                        list.filter_map(fields, fn(pair) {
                          let #(key, value) = pair
                          case string.starts_with(key, "attr_") {
                            True ->
                              Ok(#(
                                string.drop_start(key, 5),
                                json.string(value),
                              ))
                            False -> Error(Nil)
                          }
                        })
                      let attrs_with_video = case video_url {
                        "" -> raw_attrs
                        v ->
                          list.append(raw_attrs, [
                            #("video_url", json.string(v)),
                          ])
                      }
                      let attributes =
                        json.object(attrs_with_video)
                        |> json.to_string

                      case
                        db.create_category(
                          conn,
                          s,
                          draft,
                          field(fields, "seo_title"),
                          field(fields, "seo_description"),
                          // Resolve the category through the shared helper.
                          // Defaulting to "villa" here wrote a retired code:
                          // villa is a holiday_home property type, and the
                          // supplier approval trigger rejects any code the
                          // supplier has no approved application for, so a
                          // listing created without an explicit category could
                          // never be saved.
                          field(fields, "category_code") |> category_or_default,
                          attributes,
                          media_json,
                          field(fields, "category_code") != "",
                        )
                      {
                        Ok(_) -> wisp.redirect("/admin/listings")
                        Error(_) ->
                          listing_form(
                            conn,
                            s,
                            csrf,
                            "Kayıt yapılamadı. Kategori zorunlu alanlarını, seçenekleri ve SEO uzunluklarını kontrol edin.",
                            fields,
                          )
                      }
                    }
                  }
              }
            }
            http.Get, ["admin", "listings", id, "quality"] -> {
              case
                calendar.rows_with(
                  conn,
                  s,
                  "select * from catalog.quality_report($1)",
                  [pog.text(id)],
                )
              {
                Ok([]) -> wisp.response(404)
                Ok(rows) -> html(quality_view.page(s, csrf, id, rows))
                Error(_) -> fail()
              }
            }
            http.Get, ["admin", "listings", id, "modules"] -> {
              let query_params = wisp.get_query(req)
              let f_code = list.key_find(query_params, "f") |> result.unwrap("")
              let feedback = case f_code {
                "pms_ok" -> "PMS oda/ünite durumu başarıyla güncellendi."
                "kbs_ok" ->
                  "KBS Emniyet kimlik bildirimi başarıyla AKBS sistemine iletildi."
                "ota_ok" -> "Kanal Yöneticisi OTA senkronizasyonu tamamlandı."
                "wa_ok" ->
                  "Misafir WhatsApp bilgilendirme mesajı başarıyla iletildi."
                "inv_ok" -> "GİB onaylı e-Arşiv faturası başarıyla oluşturuldu."
                "b2b_ok" -> "B2B Acenta sözleşmesi ve kontenjanı kaydedildi."
                "b2b_stop_ok" -> "Acenta Stop-Sale durumu güncellendi."
                "parity_ok" ->
                  "Tüm kanallarda canlı fiyat paritesi taraması tamamlandı."
                "maint_ok" ->
                  "Teknik servis arıza iş emri açıldı ve oda bakıma alındı."
                "maint_res_ok" ->
                  "Arıza iş emri çözüldü; oda tekrar hizmete açıldı."
                "cash_ok" -> "Ön büro kasa hareketi başarıyla kaydedildi."
                "trans_ok" ->
                  "Resmi sevk bildirimi EGM / Ulaştırma sistemine iletildi."
                "concierge_ok" -> "Misafir konsiyerj talebi başarıyla iletildi."
                "concierge_res_ok" ->
                  "Misafir konsiyerj talebi karşılandı olarak kapatıldı."
                "checkin_ok" ->
                  "Odaya hızlı giriş (Check-In) yapıldı ve konaklama folyosu açıldı."
                "checkout_ok" ->
                  "Oda çıkışı (Check-Out) yapıldı; oda temizlik bekliyor durumuna alındı."
                "clean_ok" ->
                  "Oda temizliği onaylandı; oda rezervasyona ve girişe hazır."
                "charge_ok" ->
                  "Harcama/adisyon tutarı oda folyo hesabına başarıyla işlendi."
                "settle_ok" ->
                  "Folyo hesabı kapatıldı ve tahsilat ön büro kasa defterine aktarıldı."
                "audit_ok" ->
                  "Otomatik Gün Sonu Devir (Night Audit) tamamlandı; resmi yönetici raporu kilitlendi."
                "yield_rule_ok" -> "Otopilot dinamik gelir kuralı kaydedildi."
                "yield_eval_ok" ->
                  "Otopilot fiyat simülasyonu başarıyla çalıştırıldı."
                "promo_ok" -> "Promosyon ve indirim kuponu tanımlandı."
                "msg_ok" ->
                  "Akıllı misafir mesajı başarıyla kuyruğa eklendi ve gönderildi."
                _ -> ""
              }
              case
                db.listing_modules_cockpit(conn, s, id),
                db.listing_pms_units(conn, s, id),
                db.listing_kbs_records(conn, s, id),
                db.listing_ota_channels(conn, s, id),
                db.listing_whatsapp_messages(conn, s, id),
                db.listing_invoices(conn, s, id),
                db.listing_b2b_agencies(conn, s, id),
                db.listing_rate_parity(conn, s, id),
                db.listing_maintenance_tickets(conn, s, id),
                db.listing_cash_desk(conn, s, id),
                db.listing_transport_notifications(conn, s, id),
                db.listing_guest_concierge_requests(conn, s, id),
                db.listing_room_rack(conn, s, id),
                db.listing_room_folios(conn, s, id),
                db.listing_night_audits(conn, s, id),
                db.listing_yield_rules(conn, s, id),
                db.listing_promo_codes(conn, s, id),
                db.listing_automated_messages(conn, s, id)
              {
                Ok(cockpit),
                  Ok(pms),
                  Ok(kbs),
                  Ok(ota),
                  Ok(wa),
                  Ok(inv),
                  Ok(b2b),
                  Ok(parity),
                  Ok(maint),
                  Ok(cash),
                  Ok(trans),
                  Ok(concierge),
                  Ok(rack),
                  Ok(folios),
                  Ok(audits),
                  Ok(yrules),
                  Ok(promos),
                  Ok(msgs)
                ->
                  html(listing_modules_view.render_listing_cockpit(
                    s,
                    cockpit,
                    pms,
                    kbs,
                    ota,
                    wa,
                    inv,
                    b2b,
                    parity,
                    maint,
                    cash,
                    trans,
                    concierge,
                    rack,
                    folios,
                    audits,
                    yrules,
                    promos,
                    msgs,
                    csrf,
                    feedback,
                  ))
                _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ -> fail()
              }
            }
            http.Post, ["admin", "listings", id, "modules", "pms"] -> {
              case
                domain.can_manage_availability(s.role)
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let unit_id = field(fields, "unit_id")
                  let occ = field(fields, "occupancy")
                  let hk = field(fields, "housekeeping")
                  case db.update_unit_status(conn, s, unit_id, occ, hk) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=pms_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "kbs"] -> {
              case domain.can_manage_reservations(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let guest = field(fields, "guest_name")
                  let tc = field(fields, "tc")
                  let room = field(fields, "room")
                  let cin = field(fields, "check_in")
                  let cout = field(fields, "check_out")
                  case db.dispatch_kbs(conn, id, guest, tc, room, cin, cout) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=kbs_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "ota"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.integrations.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let channel = field(fields, "channel")
                  case db.sync_ota_channel(conn, id, channel) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=ota_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "whatsapp"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.messages.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let phone = field(fields, "phone")
                  let template = field(fields, "template")
                  let content = field(fields, "content")
                  case
                    db.send_guest_whatsapp(conn, id, phone, template, content)
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=wa_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "invoice"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.accounting.manage",
                )
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.payments.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let recipient = field(fields, "recipient")
                  let amount = case int.parse(field(fields, "amount")) {
                    Ok(v) -> v * 100
                    Error(_) -> 100_000
                  }
                  case
                    db.generate_listing_invoice(conn, id, recipient, amount)
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=inv_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "b2b"] -> {
              case
                domain.can_manage_pricing(s.role)
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.offers.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let aname = field(fields, "agency_name")
                  let acode = field(fields, "agency_code")
                  let comm = case float.parse(field(fields, "commission_pct")) {
                    Ok(v) -> v
                    Error(_) -> 15.0
                  }
                  let allot = case int.parse(field(fields, "allotment")) {
                    Ok(v) -> v
                    Error(_) -> 3
                  }
                  let net = case int.parse(field(fields, "net_rate")) {
                    Ok(v) -> v * 100
                    Error(_) -> 0
                  }
                  case
                    db.add_b2b_agency(conn, id, aname, acode, comm, allot, net)
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=b2b_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "b2b", "stop-sale"]
            -> {
              case
                domain.can_manage_pricing(s.role)
                || domain.can_manage_availability(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let aid = field(fields, "agency_id")
                  case db.toggle_agency_stop_sale(conn, aid) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=b2b_stop_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "parity", "check"]
            -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.pricing.view",
                )
                || domain.can_manage_pricing(s.role)
              {
                False -> wisp.response(403)
                True -> {
                  use _fields <- authorized_form(req, csrf, origin)
                  case db.run_rate_parity_check(conn, id) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=parity_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "maintenance"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  let issue = field(fields, "issue_title")
                  let prio = field(fields, "priority")
                  let tech = field(fields, "technician")
                  case
                    db.create_maintenance_ticket(
                      conn,
                      id,
                      room,
                      issue,
                      prio,
                      tech,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=maint_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post,
              ["admin", "listings", id, "modules", "maintenance", "resolve"]
            -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let tid = field(fields, "ticket_id")
                  case db.resolve_maintenance_ticket(conn, tid) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=maint_res_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "cash"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.accounting.manage",
                )
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.payments.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let ttype = field(fields, "trans_type")
                  let cur = field(fields, "currency")
                  let method = field(fields, "payment_method")
                  let amt = case int.parse(field(fields, "amount")) {
                    Ok(v) -> v * 100
                    Error(_) -> 0
                  }
                  let room = field(fields, "room_code")
                  let notes = field(fields, "notes")
                  case
                    db.add_cash_transaction(
                      conn,
                      id,
                      ttype,
                      cur,
                      method,
                      amt,
                      room,
                      notes,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=cash_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "transport"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let sys = field(fields, "system_name")
                  let plate = field(fields, "plate_code")
                  let driver = field(fields, "driver_name")
                  let guest = field(fields, "guest_name")
                  let tc = field(fields, "tc_passport")
                  let dest = field(fields, "destination")
                  case
                    db.dispatch_transport_notification(
                      conn,
                      id,
                      sys,
                      plate,
                      driver,
                      guest,
                      tc,
                      dest,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=trans_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "concierge"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  let guest = field(fields, "guest_name")
                  let rtype = field(fields, "request_type")
                  let det = field(fields, "details")
                  case
                    db.create_guest_concierge_request(
                      conn,
                      id,
                      room,
                      guest,
                      rtype,
                      det,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=concierge_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post,
              ["admin", "listings", id, "modules", "concierge", "resolve"]
            -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let rid = field(fields, "request_id")
                  case db.resolve_concierge_request(conn, rid) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/"
                        <> id
                        <> "/modules?f=concierge_res_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "rack", "check-in"]
            -> {
              case
                domain.can_manage_reservations(s.role)
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  let guest = field(fields, "guest_name")
                  let nights =
                    field(fields, "nights")
                    |> int.parse
                    |> result.unwrap(1)
                  let rate =
                    field(fields, "rate_minor")
                    |> int.parse
                    |> result.unwrap(0)
                  case db.quick_check_in(conn, id, room, guest, nights, rate) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=checkin_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "rack", "check-out"]
            -> {
              case
                domain.can_manage_reservations(s.role)
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  case db.quick_check_out(conn, id, room) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=checkout_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "rack", "clean"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.tasks.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  case db.mark_room_clean(conn, id, room) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=clean_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "folio", "charge"]
            -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.accounting.manage",
                )
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.payments.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  let dept = field(fields, "department")
                  let desc = field(fields, "description")
                  let amt =
                    field(fields, "amount_minor")
                    |> int.parse
                    |> result.unwrap(0)
                  case
                    db.post_room_folio_charge(conn, id, room, dept, desc, amt)
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=charge_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "folio", "settle"]
            -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.accounting.manage",
                )
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.payments.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  let method = field(fields, "payment_method")
                  case db.settle_room_folio(conn, id, room, method) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=settle_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "audit", "run"] -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.accounting.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use _fields <- authorized_form(req, csrf, origin)
                  case db.run_night_audit(conn, id) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=audit_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "yield", "rule"] -> {
              case domain.can_manage_pricing(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let rtype = field(fields, "rule_type")
                  let thresh =
                    field(fields, "threshold_val")
                    |> float.parse
                    |> result.unwrap(75.0)
                  let adj =
                    field(fields, "adjustment_pct")
                    |> float.parse
                    |> result.unwrap(15.0)
                  case db.add_yield_rule(conn, id, rtype, thresh, adj) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=yield_rule_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "yield", "toggle"]
            -> {
              case domain.can_manage_pricing(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let rid = field(fields, "rule_id")
                  case db.toggle_yield_rule(conn, rid) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=yield_rule_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "yield", "evaluate"]
            -> {
              case domain.can_manage_pricing(s.role) {
                False -> wisp.response(403)
                True -> {
                  use _fields <- authorized_form(req, csrf, origin)
                  case db.evaluate_yield_autopilot(conn, id) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=yield_eval_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "modules", "promo", "add"] -> {
              case
                domain.can_manage_pricing(s.role)
                || domain.can_access_supplier_permission(
                  s.role,
                  "supplier.offers.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let code = field(fields, "promo_code")
                  let dtype = field(fields, "discount_type")
                  let dval =
                    field(fields, "discount_val")
                    |> int.parse
                    |> result.unwrap(10)
                  let max_u =
                    field(fields, "max_uses")
                    |> int.parse
                    |> result.unwrap(100)
                  case db.add_promo_code(conn, id, code, dtype, dval, max_u) {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=promo_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Post,
              ["admin", "listings", id, "modules", "messaging", "dispatch"]
            -> {
              case
                domain.can_access_supplier_permission(
                  s.role,
                  "supplier.messages.manage",
                )
              {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  let room = field(fields, "room_code")
                  let guest = field(fields, "guest_name")
                  let phone = field(fields, "phone")
                  let trig = field(fields, "trigger_type")
                  case
                    db.dispatch_guest_automated_message(
                      conn,
                      id,
                      room,
                      guest,
                      phone,
                      trig,
                    )
                  {
                    Ok(_) ->
                      wisp.redirect(
                        "/admin/listings/" <> id <> "/modules?f=msg_ok",
                      )
                    _ -> fail()
                  }
                }
              }
            }
            http.Get, ["admin", "listings", id, "edit"] -> {
              case
                calendar.rows_with(
                  conn,
                  s,
                  "select * from catalog.edit_values($1)",
                  [pog.text(id)],
                )
              {
                Ok([]) -> wisp.response(404)
                Ok(rows) ->
                  listing_form(
                    conn,
                    s,
                    csrf,
                    "",
                    list.filter_map(rows, fn(r) {
                      case r {
                        [k, v] -> Ok(#(k, v))
                        _ -> Error(Nil)
                      }
                    }),
                  )
                Error(_) -> fail()
              }
            }
            http.Post, ["admin", "listings", id, "edit"] -> {
              use fields <- authorized_form(req, csrf, origin)
              case domain.can_manage_catalog(s.role) {
                False -> wisp.response(403)
                True ->
                  case
                    domain.validate(
                      field(fields, "title"),
                      field(fields, "locality"),
                      field(fields, "description"),
                      field(fields, "capacity"),
                      field(fields, "price"),
                      field(fields, "currency"),
                    )
                  {
                    Error(msg) -> listing_form(conn, s, csrf, msg, fields)
                    Ok(d) -> {
                      let hero_image = field(fields, "hero_image")
                      let gallery_images = field(fields, "gallery_images")
                      let video_url = field(fields, "video_url")
                      let media_json =
                        build_media_json(hero_image, gallery_images)
                      let raw_attrs =
                        list.filter_map(fields, fn(pair) {
                          let #(k, v) = pair
                          case string.starts_with(k, "attr_") {
                            True ->
                              Ok(#(string.drop_start(k, 5), json.string(v)))
                            False -> Error(Nil)
                          }
                        })
                      let attrs_with_video = case video_url {
                        "" -> raw_attrs
                        v ->
                          list.append(raw_attrs, [
                            #("video_url", json.string(v)),
                          ])
                      }
                      let attributes =
                        json.object(attrs_with_video)
                        |> json.to_string
                      let answer =
                        calendar.command(
                          conn,
                          s,
                          "update catalog.properties set title=$1,locality=$2,description=$3,capacity=$4,nightly_minor=$5,currency=$6,seo_title=$7,seo_description=$8,attributes=attributes || $9::jsonb,media=$10::jsonb,schema_managed=true,status='draft',moderation_status=case when moderation_status='approved' then 'draft' else moderation_status end,version=version+1,updated_at=now() where id::text=$11 and version=$12 returning 'ok'",
                          [
                            pog.text(d.title),
                            pog.text(d.locality),
                            pog.text(d.description),
                            pog.int(d.capacity),
                            pog.int(d.nightly_minor),
                            pog.text(d.currency),
                            pog.text(field(fields, "seo_title")),
                            pog.text(field(fields, "seo_description")),
                            pog.text(attributes),
                            pog.text(media_json),
                            pog.text(id),
                            pog.int(
                              int.parse(field(fields, "version"))
                              |> result.unwrap(-1),
                            ),
                          ],
                        )
                      case answer {
                        Ok("ok") -> wisp.redirect("/admin/listings")
                        _ ->
                          listing_form(
                            conn,
                            s,
                            csrf,
                            "Kayıt yapılamadı: zorunlu alanları kontrol edin. İlan başka oturumda değişmişse yeniden açın.",
                            fields,
                          )
                      }
                    }
                  }
              }
            }
            http.Post, ["admin", "listings", id, "ai"] -> {
              case domain.can_manage_catalog(s.role) {
                False -> wisp.response(403)
                True -> {
                  use fields <- authorized_form(req, csrf, origin)
                  case
                    calendar.command(
                      conn,
                      s,
                      "select ai.queue_listing_request($1,$2,$3)",
                      [
                        pog.text(id),
                        pog.text(field(fields, "ai_capability")),
                        pog.text(field(fields, "prompt")),
                      ],
                    )
                  {
                    Ok("queued") ->
                      listing_form(
                        conn,
                        s,
                        csrf,
                        "AI görevi kuyruğa alındı; sonuç hazır olduğunda taslak olarak gösterilecek.",
                        fields,
                      )
                    Ok(answer) ->
                      listing_form(
                        conn,
                        s,
                        csrf,
                        calendar.message(answer),
                        fields,
                      )
                    Error(_) -> fail()
                  }
                }
              }
            }
            http.Post, ["admin", "listings", id, "status"] -> {
              use fields <- authorized_form(req, csrf, origin)
              let status = field(fields, "status")
              let version =
                int.parse(field(fields, "version")) |> result.unwrap(0)
              case s.workspace, status {
                "supplier", "published" | "supplier", "draft" ->
                  case domain.can_manage_catalog(s.role) {
                    False -> wisp.response(403)
                    True ->
                      case db.publish(conn, s, id, version, status) {
                        Ok(True) -> wisp.redirect("/admin/listings")
                        Ok(False) ->
                          wisp.response(409)
                          |> wisp.string_body(
                            "İlan başka bir oturumda güncellenmiş (sürüm çakışması).",
                          )
                        Error(_) -> wisp.response(403)
                      }
                  }
                "supplier", "submit" -> {
                  case domain.can_submit_listing_review(s.role) {
                    False -> wisp.response(403)
                    True -> {
                      let answer =
                        calendar.command(
                          conn,
                          s,
                          "select catalog.submit_for_review($1,$2)",
                          [pog.text(id), pog.int(version)],
                        )
                      case answer {
                        Ok("ok") -> wisp.redirect("/admin/listings")
                        Ok(code) ->
                          wisp.response(409)
                          |> wisp.string_body(calendar.message(code))
                        Error(_) -> wisp.response(403)
                      }
                    }
                  }
                }
                "supplier", "confirm_current" -> {
                  case domain.can_manage_catalog(s.role) {
                    False -> wisp.response(403)
                    True -> {
                      let answer =
                        calendar.command(
                          conn,
                          s,
                          "select catalog.confirm_listing_current($1,$2)",
                          [pog.text(id), pog.int(version)],
                        )
                      case answer {
                        Ok("ok") -> wisp.redirect("/admin/listings")
                        Ok(code) ->
                          wisp.response(409)
                          |> wisp.string_body(calendar.message(code))
                        Error(_) -> wisp.response(403)
                      }
                    }
                  }
                }
                "nexus", decision -> {
                  case domain.can_moderate_listings(s.role) {
                    False -> wisp.response(403)
                    True -> {
                      let answer =
                        calendar.command(
                          conn,
                          s,
                          "select catalog.review_listing_api($1,$2,$3,$4)",
                          [
                            pog.text(id),
                            pog.text(int.to_string(version)),
                            pog.text(decision),
                            pog.text(field(fields, "note")),
                          ],
                        )
                      case answer {
                        Ok("ok") -> wisp.redirect("/admin/listings")
                        Ok(code) ->
                          wisp.response(409)
                          |> wisp.string_body(calendar.message(code))
                        Error(_) -> wisp.response(403)
                      }
                    }
                  }
                }
                _, _ -> wisp.response(403)
              }
            }
            _, _ -> wisp.not_found()
          }
      }
    }
  }
}

fn platform_control_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
) {
  case s.workspace == "nexus" && s.role == "owner" {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(
          conn,
          s,
          "select * from operations.platform_control_checks()",
        )
      {
        Ok(rows) -> html(platform_control_view.page(s, csrf, rows))
        Error(_) -> fail()
      }
  }
}

fn partners_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  requests: Bool,
  message: String,
) {
  case s.workspace == "supplier" && !requests {
    True -> wisp.response(403)
    False -> {
      // partners.directory() is the NEXUS partner administration view and only
      // returns rows when the caller is a platform operator. An agency session
      // therefore saw an empty table and could not reach the products of the
      // suppliers it is connected to; it must read its own catalog instead.
      let sql = case requests, s.workspace {
        True, _ -> "select * from booking.requests()"
        False, "agency" -> "select * from partners.agency_catalog()"
        False, _ -> "select * from partners.directory()"
      }
      case calendar.rows(conn, s, sql) {
        Ok(rows) ->
          html(partners_view.page(
            s,
            csrf,
            wisp.random_string(32),
            rows,
            requests,
            message,
          ))
        Error(_) -> fail()
      }
    }
  }
}

fn connection_requests_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace == "nexus" && domain.can_manage_team(s.role) {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from partners.connection_requests()")
      {
        Ok(rows) -> html(connection_requests_view.page(s, csrf, rows, message))
        Error(_) -> fail()
      }
  }
}

fn users_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case domain.can_manage_team(s.role) {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from auth.managed_users()"),
        calendar.rows(conn, s, "select * from auth.managed_organizations()")
      {
        Ok(users), Ok(organizations) ->
          html(users_view.page(s, csrf, users, organizations, message))
        _, _ -> fail()
      }
  }
}

fn contact_feedback(
  conn: pog.Connection,
  csrf: String,
  status: Int,
  message: String,
  fields: List(#(String, String)),
) {
  case site.published(conn), site.contact(conn) {
    Ok(rows), Ok(values) ->
      case
        site.render_feedback(rows, "iletisim", values, csrf, message, fields)
      {
        Ok(body) -> wisp.response(status) |> wisp.html_body(body)
        Error(_) -> wisp.not_found()
      }
    _, _ -> fail()
  }
}

fn public_site(conn: pog.Connection, slug: String) {
  case site.published(conn) {
    Ok(rows) ->
      case
        site.render_contact(rows, slug, site.contact(conn) |> result.unwrap([]))
      {
        Ok(body) -> html(body)
        Error(_) -> wisp.not_found()
      }
    Error(_) -> fail()
  }
}

fn cms_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace == "nexus" && list.contains(["owner", "editor"], s.role) {
    False -> wisp.response(403)
    True ->
      case calendar.rows(conn, s, "select * from cms.editor_pages()") {
        Ok(rows) -> html(site.editor(s, csrf, rows, message))
        Error(_) -> fail()
      }
  }
}

fn onboarding_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace == "nexus" && domain.can_access_applications(s.role) {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from onboarding.queue()"),
        calendar.rows(
          conn,
          s,
          "select * from onboarding.documents_for_review()",
        ),
        calendar.rows(
          conn,
          s,
          "select * from onboarding.expiring_documents(30)",
        )
      {
        Ok(rows), Ok(documents), Ok(expiring) ->
          html(onboarding_view.queue(
            s,
            csrf,
            rows,
            documents,
            expiring,
            message,
          ))
        _, _, _ -> fail()
      }
  }
}

fn supplier_application_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case
    s.workspace == "supplier"
    && list.contains(["owner", "general_manager", "editor"], s.role)
  {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from onboarding.my_application()"),
        calendar.rows(
          conn,
          s,
          "select * from onboarding.categories_for_signup()",
        )
      {
        Ok(applications), Ok(categories) -> {
          let application_id = case applications {
            [[id, ..], ..] -> id
            _ -> ""
          }
          let documents = case application_id {
            "" -> Ok([])
            id ->
              calendar.rows_with(
                conn,
                s,
                "select * from onboarding.my_application_documents($1)",
                [pog.text(id)],
              )
          }
          case documents {
            Ok(rows) ->
              html(onboarding_view.supplier_page(
                s,
                csrf,
                applications,
                categories,
                rows,
                message,
              ))
            Error(_) -> fail()
          }
        }
        _, _ -> fail()
      }
  }
}

fn procedures_page(conn: pog.Connection, s: domain.Session, csrf: String) {
  case
    calendar.rows(conn, s, "select * from onboarding.all_category_procedures()")
  {
    Ok(rows) -> html(view.procedures_hub(s, csrf, rows))
    Error(_) -> fail()
  }
}

fn listing_form(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  error: String,
  values: List(#(String, String)),
) {
  let category = case field(values, "category_code") {
    "" -> "hotel"
    c -> c
  }
  let procedure_row = case
    calendar.rows_with(
      conn,
      s,
      "select * from onboarding.get_category_procedure($1)",
      [pog.text(category)],
    )
  {
    Ok([row, ..]) -> row
    _ -> []
  }
  let procedure_steps = case
    calendar.rows_with(
      conn,
      s,
      "select * from onboarding.get_category_procedure_steps($1)",
      [pog.text(category)],
    )
  {
    Ok(rows) -> rows
    _ -> []
  }
  case
    calendar.rows(conn, s, "select * from onboarding.categories_for_listing()"),
    calendar.rows_with(conn, s, "select * from onboarding.category_fields($1)", [
      pog.text(category),
    ])
  {
    Ok([]), _ -> wisp.redirect("/admin/application")
    Ok(categories), Ok(schema) -> {
      let page =
        view.category_listing(
          s,
          csrf,
          error,
          values,
          categories,
          schema,
          procedure_row,
          procedure_steps,
        )
      case error {
        "" -> html(page)
        _ -> wisp.response(422) |> wisp.html_body(page)
      }
    }
    _, _ -> fail()
  }
}

fn modules_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace == "nexus" && s.role == "owner" {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from onboarding.module_directory()"),
        calendar.rows(conn, s, "select * from onboarding.suppliers()"),
        calendar.rows(conn, s, "select * from onboarding.module_assignments()"),
        calendar.rows(conn, s, "select * from onboarding.supplier_overview()")
      {
        Ok(modules), Ok(suppliers), Ok(assignments), Ok(supplier_stats) ->
          html(modules_view.page(
            s,
            csrf,
            modules,
            suppliers,
            assignments,
            supplier_stats,
            message,
          ))
        _, _, _, _ -> fail()
      }
  }
}

fn supplier_modules_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  supplier_id: String,
  message: String,
) {
  case s.workspace == "nexus" && s.role == "owner" {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from onboarding.suppliers()"),
        calendar.rows_with(
          conn,
          s,
          "select * from onboarding.supplier_modules_matrix($1)",
          [pog.text(supplier_id)],
        )
      {
        Ok(suppliers), Ok(matrix) -> {
          let supplier_name =
            list.find_map(suppliers, fn(sup) {
              case sup {
                [id, name] if id == supplier_id -> Ok(name)
                _ -> Error(Nil)
              }
            })
            |> result.unwrap("Tedarikçi")
          html(modules_view.supplier_matrix_page(
            s,
            csrf,
            supplier_id,
            supplier_name,
            suppliers,
            matrix,
            message,
          ))
        }
        _, _ -> fail()
      }
  }
}

fn module_ops_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  module_code: String,
  message: String,
) {
  case
    calendar.rows_with(
      conn,
      s,
      "select * from onboarding.module_telemetry_logs($1)",
      [pog.text(module_code)],
    ),
    calendar.rows_with(
      conn,
      s,
      "select m.name, coalesce(d.family, m.family), m.description, coalesce(array_to_string(d.scope, ','), ''), coalesce(array_to_string(d.permissions, ','), '') from onboarding.product_modules m left join onboarding.supplier_panel_module_contract_details() d on d.code = m.code where m.code = $1",
      [pog.text(module_code)],
    )
  {
    Ok(logs), Ok([[name, family, description, scope, permissions], ..]) ->
      case domain.can_access_any_supplier_permission(s.role, permissions) {
        True ->
          html(modules_view.ops_page(
            s,
            csrf,
            module_code,
            name,
            family,
            description,
            scope,
            permissions,
            logs,
            message,
          ))
        False -> wisp.response(403)
      }
    Ok(logs), _ ->
      html(modules_view.ops_page(
        s,
        csrf,
        module_code,
        module_code,
        "",
        "",
        "",
        "",
        logs,
        message,
      ))
    _, _ -> fail()
  }
}

fn module_permission_allowed(
  conn: pog.Connection,
  s: domain.Session,
  module_code: String,
) -> Bool {
  case
    calendar.rows_with(
      conn,
      s,
      "select coalesce(array_to_string(permissions, ','), '') from onboarding.supplier_panel_module_contract_details() where code = $1",
      [pog.text(module_code)],
    )
  {
    Ok([[permissions], ..]) ->
      domain.can_access_any_supplier_permission(s.role, permissions)
    _ -> False
  }
}

fn departments_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace {
    "nexus" | "supplier" ->
      case calendar.rows(conn, s, "select * from organization.directory()") {
        Ok(rows) ->
          html(departments_view.page(s, csrf, s.workspace, rows, message))
        Error(_) -> fail()
      }
    _ -> wisp.response(403)
  }
}

fn ai_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace == "nexus" && domain.can_access_ai_hub(s.role) {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from ai.workforce_overview()"),
        calendar.rows(conn, s, "select * from ai.actions_feed()"),
        calendar.rows(conn, s, "select * from ai.executive_dashboard()")
      {
        Ok(roles), Ok(actions), Ok(insights) ->
          html(ai_governance.page(s, csrf, roles, actions, insights, message))
        _, _, _ -> fail()
      }
  }
}

fn finance_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case domain.can_access_accounting(s.role) {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(conn, s, "select * from finance.journals_directory()"),
        calendar.rows(conn, s, "select * from finance.settlement_directory()")
      {
        Ok(journals), Ok(settlements) ->
          html(finance_os.page(s, csrf, journals, settlements, message))
        _, _ -> fail()
      }
  }
}

fn pricing_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case calendar.rows(conn, s, "select * from pricing.rules_directory()") {
    Ok(rules) -> html(commercial_engine.page(s, csrf, rules, "", message))
    Error(_) -> fail()
  }
}

fn digital_twin_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case
    calendar.rows(conn, s, "select * from organization.digital_twin_cards()")
  {
    Ok(cards) -> html(digital_twin.page(s, csrf, cards, message))
    Error(_) -> fail()
  }
}

fn category_fields_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  category: String,
  message: String,
) {
  case s.workspace == "nexus" && domain.can_access_category_fields(s.role) {
    False -> wisp.response(403)
    True ->
      case
        calendar.rows(
          conn,
          s,
          "select * from onboarding.categories_for_signup()",
        ),
        calendar.rows_with(
          conn,
          s,
          "select * from onboarding.category_fields_admin($1)",
          [pog.text(category)],
        )
      {
        Ok(categories), Ok(rows) ->
          html(category_admin.page(s, csrf, category, categories, rows, message))
        _, _ -> fail()
      }
  }
}

fn settings_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case settings.allowed(s) {
    False ->
      wisp.response(403)
      |> wisp.string_body(
        "Ayarları yalnız çalışma alanı yöneticisi değiştirebilir.",
      )
    True ->
      case calendar.rows(conn, s, "select * from settings.list()") {
        Ok(rows) -> html(settings.page(s, csrf, rows, message))
        Error(_) -> fail()
      }
  }
}

fn reservations_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case calendar.rows(conn, s, "select * from booking.reservation_list()") {
    Ok(rows) -> html(partners_view.reservations(s, csrf, rows, message))
    Error(_) -> fail()
  }
}

fn calendar_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  options: Bool,
  message: String,
) {
  let rows = case options {
    True -> calendar.holds(conn, s)
    False -> calendar.days(conn, s)
  }
  case db.properties(conn, s), rows {
    Ok(items), Ok(rows) ->
      html(calendar_view.page(
        s,
        csrf,
        wisp.random_string(32),
        items,
        rows,
        options,
        message,
      ))
    _, _ -> fail()
  }
}

fn campaigns_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case s.workspace == "supplier" || s.workspace == "nexus" {
    False -> wisp.response(403)
    True ->
      case db.properties(conn, s), db.supplier_campaigns(conn, s) {
        Ok(props), Ok(camps) ->
          html(campaigns_view.page(s, csrf, props, camps, message))
        _, _ -> fail()
      }
  }
}

fn accounting_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case db.accounting_summary(conn, s), db.accounting_transactions(conn, s) {
    Ok(summary), Ok(txs) ->
      html(accounting_view.page(s, csrf, summary, txs, message))
    _, _ -> fail()
  }
}

fn social_media_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  let props = db.properties(conn, s) |> result.unwrap([])
  case db.social_posts(conn, s) {
    Ok(posts) -> html(social_media_view.page(s, csrf, props, posts, message))
    _ -> fail()
  }
}

fn hr_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  case
    db.hr_employees(conn, s),
    db.hr_candidates(conn, s),
    db.hr_payrolls(conn, s)
  {
    Ok(employees), Ok(candidates), Ok(payrolls) ->
      html(hr_view.page(s, csrf, employees, candidates, payrolls, message))
    _, _, _ -> fail()
  }
}

fn housekeeping_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  prop_id_param: String,
  message: String,
) {
  case db.properties(conn, s) {
    Ok(props) -> {
      let active_id = case prop_id_param {
        "" ->
          case list.first(props) {
            Ok(p) -> p.id
            Error(_) -> ""
          }
        id -> id
      }
      let rack = db.listing_room_rack(conn, s, active_id) |> result.unwrap([])
      let tasks = db.housekeeping_tasks(conn, s, active_id) |> result.unwrap([])
      let tickets =
        db.room_maintenance_tickets(conn, s, active_id) |> result.unwrap([])
      html(housekeeping_view.page(
        s,
        csrf,
        props,
        active_id,
        rack,
        tasks,
        tickets,
        message,
      ))
    }
    _ -> fail()
  }
}

fn crm_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  let guests =
    calendar.rows(
      conn,
      s,
      "select array[id::text, full_name, email, phone, nationality, total_stays, total_spend, vip_tier, preferences] from crm.list_guests()",
    )
    |> result.unwrap([])
  let messages =
    calendar.rows(
      conn,
      s,
      "select array[id::text, guest_name, phone, msg_type, message, status, sent_at] from crm.list_whatsapp_messages()",
    )
    |> result.unwrap([])
  let checkins =
    calendar.rows(
      conn,
      s,
      "select array[reservation_id, guest_name, tc_or_passport, phone, email, eta_time, door_pin_code, checked_in_at] from booking.list_online_checkins()",
    )
    |> result.unwrap([])
  html(crm_view.page(s, csrf, guests, messages, checkins, message))
}

fn rate_shopper_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  let rates =
    calendar.rows(
      conn,
      s,
      "select array[id::text, competitor_name, star_rating, room_type, channel, competitor_price, our_price, currency, check_in_date, ai_recommendation] from revenue.list_competitor_rates()",
    )
    |> result.unwrap([])
  html(rateshopper_view.page(s, csrf, rates, message))
}

fn tours_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  let activities =
    calendar.rows(
      conn,
      s,
      "select array[id::text, title, location, category, duration_hours, net_price, sale_price, currency, capacity] from tours.list_activities()",
    )
    |> result.unwrap([])
  let packages =
    calendar.rows(
      conn,
      s,
      "select array[id::text, package_code, guest_name, hotel_name, activity_name, transfer_included, total_price, currency, status, voucher_no] from tours.list_packages()",
    )
    |> result.unwrap([])
  html(tours_view.page(s, csrf, activities, packages, message))
}

fn fleet_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  let vehicles =
    calendar.rows(
      conn,
      s,
      "select array[id::text, plate_no, brand, model, model_year, transmission, fuel_type, current_km, daily_rate, currency, status, kabis] from fleet.list_vehicles()",
    )
    |> result.unwrap([])
  let rentals =
    calendar.rows(
      conn,
      s,
      "select array[id::text, agreement_no, vehicle_plate, driver_name, driver_tc_passport, driver_phone, start_date, end_date, total_days, total_amount, deposit_amount, status] from fleet.list_rentals()",
    )
    |> result.unwrap([])
  html(fleet_view.page(s, csrf, vehicles, rentals, message))
}

fn einvoice_page(
  conn: pog.Connection,
  s: domain.Session,
  csrf: String,
  message: String,
) {
  let invoices =
    calendar.rows(
      conn,
      s,
      "select array[id::text, ettn::text, invoice_no, invoice_type, receiver_name, receiver_vkn_tckn, net_amount, vat_amount, accommodation_tax, grand_total, currency, gib_status, profile, created_at] from invoicing.list_invoices()",
    )
    |> result.unwrap([])
  html(einvoice_view.page(s, csrf, invoices, message))
}

fn checkin_page(conn: pog.Connection, res_id: String, message: String) {
  let existing =
    pog.query(
      "select array[reservation_id, guest_name, tc_or_passport, phone, email, eta_time, door_pin_code, checked_in_at] from booking.get_online_checkin($1)",
    )
    |> pog.parameter(pog.text(res_id))
    |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
    |> pog.execute(conn)
    |> result.map(fn(r) { list.first(r.rows) |> result.unwrap([]) })
    |> result.unwrap([])
  html(checkin_view.page(res_id, existing, message))
}
