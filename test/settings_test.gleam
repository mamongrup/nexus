import gleam/result
import nexus/settings

const key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

pub fn encrypted_secret_roundtrip_test() {
  let assert Ok(a) =
    settings.seal("test-api-secret", key, "tenant:ai.openai_key")
  let assert Ok(b) =
    settings.seal("test-api-secret", key, "tenant:ai.openai_key")
  assert a != b
  assert a != "test-api-secret"
  assert settings.open(a, key, "tenant:ai.openai_key") == Ok("test-api-secret")
  assert result.is_error(settings.open(a, key, "other:ai.openai_key"))
  assert result.is_error(settings.open(
    a,
    key <> "wrong",
    "tenant:ai.openai_key",
  ))
  assert result.is_error(settings.open(
    a <> "tampered",
    key,
    "tenant:ai.openai_key",
  ))
  assert result.is_error(settings.seal("secret", "short", "context"))
}

pub fn settings_validation_test() {
  assert settings.valid("https", "https://example.com", "")
  assert !settings.valid("https", "http://example.com", "")
  assert !settings.valid("https", "https://user:pass@example.com", "")
  assert !settings.valid("https", "https://localhost", "")
  assert !settings.valid("https", "https://", "")
  assert settings.valid("select", "marketplace", "marketplace")
  assert !settings.valid("select", "standard", "marketplace")
  assert !settings.valid("number", "-1", "")
  assert !settings.valid("number", "1e3", "")
  assert settings.valid("number", "12345", "")
}
