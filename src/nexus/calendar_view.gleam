import gleam/int
import gleam/list
import gleam/result
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Property, type Session}
import nexus/view.{el, hidden, input}

pub fn page(
  s: Session,
  csrf: String,
  key: String,
  items: List(Property),
  rows: List(List(String)),
  options: Bool,
  message: String,
) {
  let title = case options {
    True -> "Opsiyonlar"
    False -> "Takvim ve fiyat"
  }
  let action = case options {
    True -> "/admin/options"
    False -> "/admin/calendar"
  }
  view.shell(
    s,
    csrf,
    title,
    el("div", "", [
      el("h1", "", [text(title)]),
      el("p", "muted", [
        text(case options {
          True ->
            "Acenteler veya doğrudan misafirler için seçili geceleri geçici olarak bloke edin; onaylanmayan opsiyonlar otomatik olarak serbest bırakılır."
          False ->
            "Tüm oda ve konaklama tipleri için tarih aralığına göre gecelik taban fiyatları, asgari konaklama kurallarını ve müsaitlik durumunu belirleyin."
        }),
      ]),
      case message {
        "" -> text("")
        _ ->
          element.element(
            "div",
            [a.class("notice"), a.attribute("role", "status")],
            [text(message)],
          )
      },
      case items {
        [] ->
          el("section", "panel empty", [
            text("Önce İlanlar bölümünden bir ilan / tesis oluşturun."),
          ])
        _ ->
          element.element(
            "form",
            [
              a.class("panel form editor-form"),
              a.attribute("method", "post"),
              a.attribute("action", action),
            ],
            [
              hidden("csrf", csrf),
              hidden("request_key", key),
              el("label", "field", [
                text("İlan / Tesis seçimi"),
                element.element(
                  "select",
                  [a.name("property")],
                  list.map(items, fn(p) {
                    element.element("option", [a.value(p.id)], [
                      text(p.title <> " · " <> p.currency),
                    ])
                  }),
                ),
              ]),
              el("div", "form-grid", [
                input("Başlangıç / giriş", "start", "date", "", True),
                input("Bitiş / çıkış (hariç)", "end", "date", "", True),
              ]),
              case options {
                True ->
                  input(
                    "Opsiyon süresi (1-1440 dakika)",
                    "minutes",
                    "number",
                    "30",
                    True,
                  )
                False ->
                  el("div", "form-grid", [
                    input(
                      "Her gece için fiyat (ilan para birimi)",
                      "price",
                      "text",
                      "",
                      True,
                    ),
                    el("label", "field", [
                      text("Müsaitlik"),
                      element.element("select", [a.name("blocked")], [
                        element.element("option", [a.value("false")], [
                          text("Satışa açık"),
                        ]),
                        element.element("option", [a.value("true")], [
                          text("Satışa kapalı"),
                        ]),
                      ]),
                    ]),
                  ])
              },
              element.element(
                "button",
                [a.class("button primary"), a.attribute("type", "submit")],
                [
                  text(case options {
                    True -> "Opsiyon oluştur"
                    False -> "Takvime uygula"
                  }),
                ],
              ),
            ],
          )
      },
      el("p", "muted", [
        text(case options {
          True ->
            "Son 100 opsiyon · Saatler Türkiye saati. Süresi dolan opsiyonlar yeni işlemde atomik olarak serbest bırakılır."
          False ->
            "Bugünden itibaren ilk 120 gece kaydı. Fiyatlar ek ücret, vergi ve komisyon hesaplaması içermez."
        }),
      ]),
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                case options {
                  True -> [
                    "İlan / Tesis",
                    "Giriş",
                    "Çıkış",
                    "Toplam",
                    "Durum",
                    "Son süre",
                    "İşlem",
                  ]
                  False -> ["İlan / Tesis", "Gece", "Fiyat", "Durum"]
                },
                fn(t) { el("th", "", [text(t)]) },
              ),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(rows, fn(row) { row_view(row, csrf, options) }),
          ),
        ]),
      ]),
    ]),
  )
}

fn row_view(row: List(String), csrf: String, options: Bool) {
  let cells = case row, options {
    [id, title, start, end, amount, currency, status, expiry], True -> [
      text(title),
      text(start),
      text(end),
      text(format_money(amount, currency)),
      text(case status {
        "active" -> "Aktif"
        "expired" -> "Süresi doldu"
        "released" -> "Bırakıldı"
        _ -> status
      }),
      text(expiry),
      case status {
        "active" ->
          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/options/" <> id <> "/release"),
            ],
            [
              hidden("csrf", csrf),
              element.element("button", [a.class("button small")], [
                text("Serbest bırak"),
              ]),
            ],
          )
        _ -> text("-")
      },
    ]
    [title, date, amount, currency, status], False -> [
      text(title),
      text(date),
      text(format_money(amount, currency)),
      text(status),
    ]
    _, _ -> [text("Kayıt okunamadı")]
  }
  el("tr", "", list.map(cells, fn(c) { el("td", "", [c]) }))
}

fn format_money(amount: String, currency: String) {
  domain.money(int.parse(amount) |> result.unwrap(0), currency)
}
