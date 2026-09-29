import envoy
import gleam/erlang/process
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
  let handler = fn(req) { router.handle(req, db, origin) }
  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret)
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(env_int("APP_PORT", 8080))
    |> mist.start
  io.println("NEXUS TravelTech: " <> origin)
  process.sleep_forever()
}

fn env_int(key: String, fallback: Int) -> Int {
  envoy.get(key) |> result.try(int.parse) |> result.unwrap(fallback)
}
