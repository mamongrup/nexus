import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeunit
import nexus/contract
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

fn contract_file() -> String {
  case
    simplifile.read("contracts/supplier-listing-contract.v1.json")
    |> result.map(fn(contents) { contents })
  {
    Ok(contents) -> contents
    Error(_) -> ""
  }
}

/// The HTTP bodies report this version. The agency app compares the two and
/// refuses to sync when they differ, so a silent drift here is an outage that
/// only shows up on the other project.
pub fn reported_version_matches_the_contract_file_test() {
  let contents = contract_file()
  assert contents != ""
  assert string.contains(
      contents,
      "\"contract_version\": \"" <> contract.version <> "\"",
    )
    || string.contains(
      contents,
      "\"contract_version\":\"" <> contract.version <> "\"",
    )
}

/// The bodies splice the field in as a prefix, so the value is only useful if
/// the result is still valid JSON once the rest of the body is appended.
pub fn version_field_produces_valid_json_test() {
  let body = "{\"ok\":true," <> contract.version_field() <> ",\"count\":0}"
  assert json.parse(body, decode.dynamic) |> result.is_ok
}

/// A version must look like a version. A placeholder such as "0.0.0" or an
/// empty string would pass the equality check above while telling an agency
/// nothing about which contract it is speaking.
pub fn version_is_not_a_placeholder_test() {
  let parts = string.split(contract.version, ".")
  assert list.length(parts) == 3
  assert !string.starts_with(contract.version, "0.")
  assert !string.ends_with(contract.version, ".0.0")
}

/// The contract file must stay parseable; a broken file would let the version
/// check above pass on a string match while the rest of the file is unusable.
pub fn contract_file_is_valid_json_test() {
  let contents = contract_file()
  assert contents != ""
  assert json.parse(contents, decode.dynamic) |> result.is_ok
}
