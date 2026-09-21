import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import mist
import nexus/router
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  let assert Ok("development") = envoy.get("APP_ENV")
    as "Local development only. Read docs/production-gates.md."
  let assert Ok(secret) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(password) = envoy.get("PGPASSWORD")
  let assert Ok(origin) = envoy.get("APP_ORIGIN")
  let name = process.new_name("nexus_database")
  let config =
    pog.default_config(name)
    |> pog.host("127.0.0.1")
    |> pog.port(env_int("PGPORT", 5433))
    |> pog.database("nexustraveltech")
    |> pog.user("nexus_app")
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
