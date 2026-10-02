import gleeunit/should
import nexus/ai_client

pub fn fabricated_source_evidence_is_rejected_test() {
  ai_client.validate_listing_review(
    "{\"summary\":\"İnceleme\",\"findings\":[{\"kind\":\"contradiction\",\"field\":\"description\",\"evidence\":\"Özel havuz\",\"suggestion\":\"Kontrol edin\"}]}",
    "Gulet, 10 misafir",
  )
  |> should.be_error
}

pub fn literal_source_evidence_is_accepted_test() {
  ai_client.validate_listing_review(
    "{\"summary\":\"İnceleme\",\"findings\":[{\"kind\":\"unsupported_claim\",\"field\":\"description\",\"evidence\":\"En iyi\",\"suggestion\":\"Bu iddiayı kontrol edin\"}]}",
    "En iyi gulet",
  )
  |> should.be_ok
}

pub fn unavailable_provider_does_not_produce_review_test() {
  ai_client.review_listing_content(
    ai_client.AIConfig("openai", "", ""),
    "10 misafir",
  )
  |> should.be_error
}
