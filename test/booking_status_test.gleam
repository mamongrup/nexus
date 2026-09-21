import gleam/http
import gleam/list
import gleam/string
import lustre/element
import nexus/booking_status
import nexus/marketplace_view
import wisp/simulate

pub fn unavailable_response_in_all_active_languages_test() {
  list.each(booking_status.languages, fn(lang) {
    let #(locale, title, message, back) = booking_status.copy(lang)
    assert locale == lang
    assert title != ""
    assert message != ""
    assert back != ""
    let response =
      simulate.browser_request(http.Post, "/ilan/test/book?lang=" <> lang)
      |> booking_status.handle
    assert response.status == 503
    let body = simulate.read_body(response)
    assert string.contains(body, title)
    assert string.contains(body, message)
    assert string.contains(body, "lang=\"" <> lang <> "\"")
    assert !string.contains(body, "raw-json-data")
    case lang {
      "tr" -> Nil
      _ -> {
        let #(_, turkish_title, turkish_message, _) = booking_status.copy("tr")
        assert title != turkish_title
        assert message != turkish_message
      }
    }
  })
}

pub fn unverified_result_never_becomes_confirmation_test() {
  let body =
    marketplace_view.render_confirmation(
      "{\"status\":\"ok\",\"pnr\":\"FAKE-PNR\",\"guest\":\"private@example.com\"}",
    )
    |> element.to_string
  assert !string.contains(body, "FAKE-PNR")
  assert !string.contains(body, "private@example.com")
  assert !string.contains(body, "Onaylandı")
  assert string.contains(body, "işleme alınmadı")
}

pub fn listing_does_not_offer_unavailable_checkout_test() {
  list.each(booking_status.languages, fn(lang) {
    let body =
      marketplace_view.render_detail_locale(
        [
          "fixture",
          "Test listing",
          "Test",
          "villa",
          "2",
          "10000",
          "TRY",
          "Description",
          "",
          "",
          "Villa",
          "Supplier",
          "1",
        ],
        "",
        lang,
      )
      |> element.to_string
    let #(_, title, _, _) = booking_status.copy(lang)
    assert string.contains(body, title)
    assert !string.contains(body, "/book")
    assert !string.contains(body, "EN İYİ FİYAT GARANTİSİ")
    assert !string.contains(body, "KBS kimlik bildirimi")
  })
}

pub fn unavailable_rejects_other_methods_and_unknown_locale_test() {
  assert booking_status.copy("<script>") == booking_status.copy("tr")
  let response =
    simulate.browser_request(http.Get, "/ilan/test/book")
    |> booking_status.handle
  assert response.status == 405
}
