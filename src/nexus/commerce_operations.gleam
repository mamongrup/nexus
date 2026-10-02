import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import nexus/ai_client
import nexus/calendar
import nexus/database
import nexus/domain.{type Session}
import nexus/settings
import pog
import wisp

@external(erlang, "nexus_commerce_operations", "page")
pub fn page(csrf: String) -> wisp.Response

@external(erlang, "nexus_commerce_operations", "export")
pub fn export(db: pog.Connection, token: String) -> wisp.Response

@external(erlang, "nexus_commerce_operations", "action")
fn ffi_action(
  db: pog.Connection,
  tenant: String,
  actor: String,
  action: String,
  fields: List(#(String, String)),
) -> wisp.Response

pub fn data(db: pog.Connection, s: Session) -> wisp.Response {
  case
    calendar.command(
      db,
      s,
      "select inventory.commerce_operations_data($1::uuid,$2::uuid)::text",
      [pog.text(s.tenant), pog.text(s.user_id)],
    )
  {
    Ok(value) -> wisp.ok() |> wisp.json_body(value)
    Error(_) ->
      wisp.response(403)
      |> wisp.json_body("{\"error\":\"Operasyon erişimi reddedildi.\"}")
  }
}

// Establish the same checked transaction context used by central inventory.
pub fn action(
  db: pog.Connection,
  s: Session,
  action: String,
  fields: List(#(String, String)),
) -> wisp.Response {
  let listing = list.key_find(fields, "listing_id") |> result.unwrap("")
  let feed = list.key_find(fields, "feed_id") |> result.unwrap("")
  case
    calendar.command(
      db,
      s,
      "select inventory.calendar_target_scope(nullif($1,'')::uuid,nullif($2,'')::uuid)::text",
      [pog.text(listing), pog.text(feed)],
    )
  {
    Error(_) -> error("İlan veya takvim erişimi reddedildi.", 403)
    Ok(tenant) -> {
      let response =
        database.scope(db, s, fn(tx) {
          Ok(ffi_action(tx, tenant, s.user_id, action, fields))
        })
      response |> result.unwrap(wisp.response(422))
    }
  }
}

fn error(message: String, status: Int) -> wisp.Response {
  wisp.response(status)
  |> wisp.json_body(
    json.object([#("error", json.string(message))]) |> json.to_string,
  )
}

pub fn review(
  db: pog.Connection,
  s: Session,
  fields: List(#(String, String)),
) -> wisp.Response {
  let id = list.key_find(fields, "listing_id") |> result.unwrap("")
  case
    calendar.command(
      db,
      s,
      "select operations.listing_review_source($1::uuid)",
      [pog.text(id)],
    )
  {
    Error(_) -> error("İlan bulunamadı veya erişiminiz yok.", 404)
    Ok(source) ->
      case source == "" || string.length(source) > 12_000 {
        True -> error("Kaynak içerik boş veya inceleme sınırını aşıyor.", 422)
        False -> review_source(db, s, id, source)
      }
  }
}

fn review_source(
  db: pog.Connection,
  s: Session,
  id: String,
  source: String,
) -> wisp.Response {
  let raw =
    calendar.command(
      db,
      s,
      "select operations.listing_review_config()::text",
      [],
    )
    |> result.unwrap("{}")
  let config_decoder = {
    use tenant <- decode.field("tenant", decode.string)
    use values <- decode.field(
      "settings",
      decode.dict(decode.string, decode.string),
    )
    decode.success(#(tenant, values))
  }
  case json.parse(raw, config_decoder) {
    Error(_) ->
      error("Yapay zekâ bağlantısını yönetim ayarlarından tamamlayın.", 503)
    Ok(#(tenant, values)) -> {
      let provider =
        dict.get(values, "ai.provider") |> result.unwrap("disabled")
      let key_name = case provider {
        "google" | "gemini" -> "ai.gemini_key"
        "deepseek" -> "ai.deepseek_key"
        "glm" -> "ai.glm_key"
        _ -> "ai.openai_key"
      }
      let sealed = dict.get(values, key_name) |> result.unwrap("")
      let key = case envoy.get("NEXUS_CONFIG_KEY") {
        Ok(k) ->
          settings.open(sealed, k, tenant <> ":" <> key_name)
          |> result.unwrap("")
        Error(_) -> ""
      }
      let model =
        dict.get(values, "ai.model")
        |> result.unwrap(ai_client.default_model(provider))
      case
        ai_client.review_listing_content(
          ai_client.AIConfig(provider, key, model),
          source,
        )
      {
        Error(_) ->
          error(
            "İnceleme üretilemedi. Sağlayıcı, model ve bağlantı ayarlarını kontrol edin.",
            503,
          )
        Ok(review) ->
          case
            calendar.command(
              db,
              s,
              "select operations.save_listing_review($1::uuid,$2,$3::jsonb,$4,$5)",
              [
                pog.text(id),
                pog.text(source),
                pog.text(review),
                pog.text(provider),
                pog.text(model),
              ],
            )
          {
            Ok("saved") ->
              wisp.ok()
              |> wisp.json_body(
                json.object([
                  #("review", json.string(review)),
                  #("advisory", json.bool(True)),
                ])
                |> json.to_string,
              )
            _ ->
              error(
                "İlan inceleme sırasında değişti veya sonuç kaydedilemedi. Yeniden deneyin.",
                409,
              )
          }
      }
    }
  }
}
