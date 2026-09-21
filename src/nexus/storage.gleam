import envoy
import gleam/list
import gleam/result
import gleam/string
import nexus/calendar
import nexus/domain.{type Session}
import pog
import simplifile

@external(erlang, "nexus_bunnycdn", "upload")
pub fn bunny_upload(
  region: String,
  zone: String,
  api_key: String,
  remote_path: String,
  data: BitArray,
) -> Result(BitArray, String)

@external(erlang, "nexus_bunnycdn", "test_connection")
pub fn bunny_test_connection(
  region: String,
  zone: String,
  api_key: String,
) -> Result(BitArray, String)

pub type StorageConfig {
  StorageConfig(
    driver: String,
    local_path: String,
    local_url_prefix: String,
    bunny_zone: String,
    bunny_api_key: String,
    bunny_region: String,
    bunny_pull_zone: String,
  )
}

pub type SaveResult {
  SaveResult(url: String, driver: String, local_saved: Bool, bunny_saved: Bool)
}

pub fn get_storage_config(db: pog.Connection, s: Session) -> StorageConfig {
  let db_settings = case calendar.rows(db, s, "select * from settings.list()") {
    Ok(rows) -> rows
    Error(_) -> []
  }

  let get_setting = fn(
    key: String,
    agency_key: String,
    env_key: String,
    fallback: String,
  ) -> String {
    let target_key = case s.workspace == "agency" {
      True -> agency_key
      False -> key
    }
    let row = list.find(db_settings, fn(r) { list.first(r) == Ok(target_key) })
    let db_val = case row {
      Ok([_, _, _, _, _, _, val, "saved", _]) if val != "" -> val
      _ -> ""
    }
    case db_val {
      "" -> envoy.get(env_key) |> result.unwrap(fallback)
      v -> v
    }
  }

  let local_path =
    get_setting(
      "storage.local_path",
      "agency_storage.local_path",
      "LOCAL_STORAGE_PATH",
      "priv/static/uploads",
    )
  let local_url_prefix =
    get_setting(
      "storage.local_url_prefix",
      "agency_storage.local_url_prefix",
      "LOCAL_STORAGE_URL_PREFIX",
      "/static/uploads",
    )
  let bunny_zone =
    get_setting(
      "storage.bunny_zone",
      "agency_storage.bunny_zone",
      "BUNNY_STORAGE_ZONE",
      "",
    )
  let bunny_api_key =
    get_setting(
      "storage.bunny_api_key",
      "agency_storage.bunny_api_key",
      "BUNNY_API_KEY",
      "",
    )
  let bunny_region =
    get_setting(
      "storage.bunny_region",
      "agency_storage.bunny_region",
      "BUNNY_REGION",
      "storage.bunnycdn.com",
    )
  let bunny_pull_zone =
    get_setting(
      "storage.bunny_pull_zone",
      "agency_storage.bunny_pull_zone",
      "BUNNY_PULL_ZONE",
      "",
    )

  let default_driver = case bunny_zone != "" && bunny_api_key != "" {
    True -> "both"
    False -> "local"
  }
  let driver =
    get_setting(
      "storage.driver",
      "agency_storage.driver",
      "STORAGE_DRIVER",
      default_driver,
    )

  StorageConfig(
    driver: driver,
    local_path: local_path,
    local_url_prefix: local_url_prefix,
    bunny_zone: bunny_zone,
    bunny_api_key: bunny_api_key,
    bunny_region: bunny_region,
    bunny_pull_zone: bunny_pull_zone,
  )
}

pub fn save_media(
  config: StorageConfig,
  filename: String,
  bytes: BitArray,
) -> Result(SaveResult, String) {
  let clean_local_path = case string.ends_with(config.local_path, "/") {
    True ->
      string.slice(config.local_path, 0, string.length(config.local_path) - 1)
    False -> config.local_path
  }
  let clean_url_prefix = case string.ends_with(config.local_url_prefix, "/") {
    True ->
      string.slice(
        config.local_url_prefix,
        0,
        string.length(config.local_url_prefix) - 1,
      )
    False -> config.local_url_prefix
  }

  let local_file_path = clean_local_path <> "/" <> filename
  let local_url = clean_url_prefix <> "/" <> filename

  let should_save_local = config.driver == "local" || config.driver == "both"
  let should_save_bunny =
    { config.driver == "bunnycdn" || config.driver == "both" }
    && config.bunny_zone != ""
    && config.bunny_api_key != ""

  // 1. Save Local if driver includes local or as safe fallback
  let local_result = case should_save_local || !should_save_bunny {
    True -> {
      let _ = simplifile.create_directory_all(clean_local_path)
      simplifile.write_bits(local_file_path, bytes)
      |> result.replace_error("Lokal dosyaya yazilamadi: " <> local_file_path)
    }
    False -> Ok(Nil)
  }

  // 2. Upload to BunnyCDN if enabled
  case should_save_bunny {
    True -> {
      let remote_path = "uploads/" <> filename
      case
        bunny_upload(
          config.bunny_region,
          config.bunny_zone,
          config.bunny_api_key,
          remote_path,
          bytes,
        )
      {
        Ok(_) -> {
          let cdn_base = case config.bunny_pull_zone {
            "" -> "https://" <> config.bunny_zone <> ".b-cdn.net"
            pz ->
              case string.ends_with(pz, "/") {
                True -> string.slice(pz, 0, string.length(pz) - 1)
                False -> pz
              }
          }
          let cdn_url = cdn_base <> "/uploads/" <> filename
          Ok(SaveResult(
            url: cdn_url,
            driver: config.driver,
            local_saved: result.is_ok(local_result),
            bunny_saved: True,
          ))
        }
        Error(_) -> {
          // If BunnyCDN upload failed, graceful fallback to local URL
          case local_result {
            Ok(_) ->
              Ok(SaveResult(
                url: local_url,
                driver: "local_fallback",
                local_saved: True,
                bunny_saved: False,
              ))
            Error(e) -> Error("Lokal ve BunnyCDN depolama basarisiz: " <> e)
          }
        }
      }
    }
    False -> {
      case local_result {
        Ok(_) ->
          Ok(SaveResult(
            url: local_url,
            driver: "local",
            local_saved: True,
            bunny_saved: False,
          ))
        Error(e) -> Error(e)
      }
    }
  }
}
