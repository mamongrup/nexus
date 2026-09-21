import gleam/http
import gleam/list
import lustre/attribute as a
import lustre/element as e
import wisp

pub const languages = ["tr", "en", "de", "ru", "zh", "fr"]

pub fn copy(lang: String) -> #(String, String, String, String) {
  case lang {
    "en" -> #(
      "en",
      "Online booking is currently unavailable",
      "Your booking request has not been processed. Please try again later.",
      "Browse listings",
    )
    "de" -> #(
      "de",
      "Online-Buchungen sind derzeit nicht verfügbar",
      "Ihre Buchungsanfrage wurde nicht verarbeitet. Bitte versuchen Sie es später erneut.",
      "Angebote ansehen",
    )
    "ru" -> #(
      "ru",
      "Онлайн-бронирование временно недоступно",
      "Ваш запрос на бронирование не обработан. Пожалуйста, повторите попытку позже.",
      "Посмотреть предложения",
    )
    "zh" -> #("zh", "在线预订暂不可用", "您的预订请求尚未处理，请稍后重试。", "浏览房源")
    "fr" -> #(
      "fr",
      "La réservation en ligne est temporairement indisponible",
      "Votre demande de réservation n’a pas été traitée. Veuillez réessayer plus tard.",
      "Voir les offres",
    )
    _ -> #(
      "tr",
      "Online rezervasyon şu anda kullanılamıyor",
      "Rezervasyon talebiniz işleme alınmadı. Lütfen daha sonra tekrar deneyin.",
      "İlanlara dön",
    )
  }
}

pub fn content(lang: String) -> e.Element(Nil) {
  let #(locale, title, message, back) = copy(lang)
  e.element("main", [a.attribute("lang", locale)], [
    e.element("h1", [], [e.text(title)]),
    e.element("p", [], [e.text(message)]),
    e.element("a", [a.href("/ilanlar?lang=" <> locale)], [e.text(back)]),
  ])
}

pub fn unavailable(lang: String) -> wisp.Response {
  let #(locale, title, _, _) = copy(lang)
  let html =
    e.element("html", [a.attribute("lang", locale)], [
      e.element("head", [], [
        e.element("meta", [a.attribute("charset", "utf-8")], []),
        e.element(
          "meta",
          [
            a.name("viewport"),
            a.attribute("content", "width=device-width, initial-scale=1"),
          ],
          [],
        ),
        e.element("title", [], [e.text(title)]),
      ]),
      e.element("body", [], [content(locale)]),
    ])
  wisp.response(503)
  |> wisp.set_header("cache-control", "no-store")
  |> wisp.html_body("<!doctype html>" <> e.to_string(html))
}

/// Keep the unavailable sales route independent of database/provider side effects.
pub fn handle(req: wisp.Request) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  let lang = case wisp.get_query(req) |> list.key_find("lang") {
    Ok(value) -> value
    Error(_) -> "tr"
  }
  unavailable(lang)
}
