import envoy
import gleam/erlang/process
import gleam/http/request.{type Request as HttpRequest}
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import gleam/string
import mist
import nexus/router
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  let assert Ok(app_env) = envoy.get("APP_ENV")
  let assert True = app_env == "development" || app_env == "production"
    as "APP_ENV must be development or production."
  let assert Ok(secret) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(password) = envoy.get("PGPASSWORD")
  let assert Ok(origin) = envoy.get("APP_ORIGIN")
  let _ = case app_env {
    "production" -> {
      let assert True = string.starts_with(origin, "https://")
        as "Production APP_ORIGIN must use HTTPS."
      let assert True = string.length(secret) >= 64
        as "Production SECRET_KEY_BASE must contain at least 64 characters."
      let assert Ok(public_host) = envoy.get("APP_PUBLIC_HOST")
      let assert True =
        public_host != ""
        && public_host != "localhost"
        && public_host != "127.0.0.1"
        as "Production APP_PUBLIC_HOST must name the public domain."
      Nil
    }
    _ -> Nil
  }
  let name = process.new_name("nexus_database")
  let config =
    pog.default_config(name)
    |> pog.host(envoy.get("PGHOST") |> result.unwrap("127.0.0.1"))
    |> pog.port(env_int("PGPORT", 5433))
    |> pog.database(envoy.get("PGDATABASE") |> result.unwrap("nexustraveltech"))
    |> pog.user(envoy.get("PGUSER") |> result.unwrap("nexus_app"))
    |> pog.password(option.Some(password))
    |> pog.pool_size(5)
  let assert Ok(_) = pog.start(config)
  let db = pog.named_connection(name)
  wisp.configure_logger()
  // The socket peer is the only address an attacker cannot choose. Resolve it
  // here, per request, and hand it to the router so rate limiting and audit
  // keys never depend on a client supplied forwarding header.
  let handler = fn(request: HttpRequest(mist.Connection)) {
    let peer = peer_address(request.body)
    let serve =
      wisp_mist.handler(
        fn(req) { router.handle(req, db, origin, peer) },
        secret,
      )
    serve(request)
  }
  let assert Ok(_) =
    handler
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(env_int("APP_PORT", 8080))
    |> mist.start
  io.println("NEXUS TravelTech: " <> origin)
  process.sleep_forever()
}

fn peer_address(connection: mist.Connection) -> String {
  case mist.get_connection_info(connection) {
    Ok(info) -> info.ip_address |> mist.ip_address_to_string |> normalize_ip
    Error(_) -> ""
  }
}

@external(erlang, "nexus_net", "normalize_ip")
fn normalize_ip_ffi(ip: String) -> String

/// Rewrites IPv4-mapped IPv6 spellings so a peer recorded as ::ffff:127.0.0.1
/// and a trusted rule written as 127.0.0.1 are recognised as the same host.
fn normalize_ip(ip: String) -> String {
  case string.trim(ip) {
    "" -> ""
    value -> normalize_ip_ffi(value)
  }
}

fn env_int(key: String, fallback: Int) -> Int {
  envoy.get(key) |> result.try(int.parse) |> result.unwrap(fallback)
}
