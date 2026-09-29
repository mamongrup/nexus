import gleam/json

@external(erlang, "nexus_agency_callback_http", "post_json")
fn post_json_ffi(
  url: String,
  body: String,
  auth: String,
) -> Result(String, String)

pub fn post_connection_approved(
  agency_endpoint: String,
  agency_id: String,
  api_key: String,
  callback_key: String,
) -> Result(String, String) {
  let url = clean_endpoint(agency_endpoint) <> "/v1/nexus/connection-approved"
  // Encode through the JSON writer so a quote or backslash inside an agency
  // identifier cannot corrupt the payload the remote panel parses.
  let body =
    json.object([
      #("agency_id", json.string(agency_id)),
      #("api_key", json.string(api_key)),
    ])
    |> json.to_string
  post_json_ffi(url, body, "Bearer " <> callback_key)
}

fn clean_endpoint(value: String) -> String {
  case value {
    "" -> ""
    _ -> trim_right_slash(value)
  }
}

fn trim_right_slash(value: String) -> String {
  case string_ends_with(value, "/") {
    True -> trim_right_slash(drop_last(value))
    False -> value
  }
}

fn string_ends_with(value: String, suffix: String) -> Bool {
  string_ends_with_ffi(value, suffix)
}

fn drop_last(value: String) -> String {
  drop_last_ffi(value)
}

@external(erlang, "nexus_agency_callback_http", "ends_with")
fn string_ends_with_ffi(value: String, suffix: String) -> Bool

@external(erlang, "nexus_agency_callback_http", "drop_last")
fn drop_last_ffi(value: String) -> String
