import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  rows: List(List(String)),
  message: String,
) -> String {
  view.shell(
    s,
    csrf,
    "Acente bağlantı onayları",
    el("div", "page-stack", [
      el("div", "content-header", [
        el("div", "eyebrow", [text("NEXUS · DAĞITIM AĞI")]),
        el("h1", "", [text("Acente bağlantı onayları")]),
        el("p", "muted", [
          text(
            "Acentelerden gelen bağlantı isteklerini onaylayın. Onay sırasında hangi kategorilerin ve en fazla kaç ilanın aktarılacağını belirleyin.",
          ),
        ]),
      ]),
      case message {
        "" -> text("")
        value -> el("div", "notice", [text(value)])
      },
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                [
                  "Acente",
                  "İstek durumu",
                  "Adres",
                  "Kapsam / sınır",
                  "Callback",
                  "Oluşturma",
                  "İşlem",
                ],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el("tbody", "", case rows {
            [] -> [
              el("tr", "", [
                el("td", "empty-cell", [
                  text("Bekleyen bağlantı isteği bulunmuyor."),
                ]),
              ]),
            ]
            _ -> list.map(rows, fn(row) { render_row(row, csrf) })
          }),
        ]),
      ]),
      el("p", "muted", [
        text(
          "Kategori alanına boş bırakırsanız tüm aktif kategoriler aktarılır. Örnek: hotel,holiday_home,tour. Sınır 1–10.000 ilan arasındadır.",
        ),
      ]),
    ]),
  )
}

fn render_row(row: List(String), csrf: String) {
  case row {
    [
      id,
      _agency_id,
      agency_name,
      endpoint,
      status,
      categories,
      limit,
      created_at,
      note,
      callback_status,
      callback_error,
    ] ->
      el("tr", "", [
        el("td", "", [
          el("strong", "", [text(agency_name)]),
          el("small", "muted", [text(note)]),
        ]),
        el("td", "", [
          el(
            "span",
            case status {
              "pending" -> "status-pill warning"
              "approved" -> "status-pill success"
              _ -> "status-pill"
            },
            [
              text(case status {
                "pending" -> "Bekliyor"
                "approved" -> "Onaylandı"
                "rejected" -> "Reddedildi"
                _ -> status
              }),
            ],
          ),
        ]),
        el("td", "muted", [text(endpoint)]),
        el("td", "", [
          text(case categories {
            "" -> "Tüm kategoriler"
            value -> value
          }),
          text(" · "),
          text(limit <> " ilan"),
        ]),
        el("td", "", [callback_badge(callback_status, callback_error)]),
        el("td", "muted", [text(created_at)]),
        el("td", "", [
          case status {
            "pending" -> decision_form(csrf, id, categories, limit)
            "approved" -> retry_callback_form(csrf, id, callback_status)
            _ ->
              el("small", "muted", [
                text("Ayarları görmek için yeniden istekte bulunun"),
              ])
          },
        ]),
      ])
    _ -> el("tr", "", [el("td", "", [text("İstek okunamadı")])])
  }
}

fn callback_badge(status: String, error: String) {
  case status {
    "sent" -> el("span", "status-pill success", [text("Acenteye yazıldı")])
    "failed" ->
      el("span", "status-pill warning", [
        text("Hata"),
        case error {
          "" -> text("")
          value -> el("small", "muted", [text(value)])
        },
      ])
    "pending" -> el("span", "status-pill warning", [text("Bekliyor")])
    "" -> el("span", "status-pill", [text("—")])
    _ -> el("span", "status-pill", [text(status)])
  }
}

fn retry_callback_form(csrf: String, id: String, callback_status: String) {
  case callback_status {
    "sent" -> el("small", "muted", [text("Bağlantı aktif")])
    _ ->
      element.element(
        "form",
        [
          a.attribute("method", "post"),
          a.attribute(
            "action",
            "/admin/partners/connection-requests/" <> id <> "/retry-callback",
          ),
          a.class("connection-decision-form"),
        ],
        [
          hidden("csrf", csrf),
          element.element("button", [a.class("button primary")], [
            text("Callback tekrar gönder"),
          ]),
        ],
      )
  }
}

fn decision_form(csrf: String, id: String, categories: String, limit: String) {
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute(
        "action",
        "/admin/partners/connection-requests/" <> id <> "/decide",
      ),
      a.class("connection-decision-form"),
    ],
    [
      hidden("csrf", csrf),
      element.element(
        "input",
        [
          a.name("categories"),
          a.attribute("value", categories),
          a.attribute("placeholder", "hotel,tour"),
        ],
        [],
      ),
      element.element(
        "input",
        [
          a.name("listing_limit"),
          a.attribute("value", case int.parse(limit) {
            Ok(value) -> int.to_string(value)
            Error(_) -> "100"
          }),
          a.attribute("type", "number"),
          a.attribute("min", "1"),
          a.attribute("max", "10000"),
        ],
        [],
      ),
      element.element(
        "input",
        [a.name("note"), a.attribute("placeholder", "İnceleme notu")],
        [],
      ),
      element.element(
        "button",
        [a.class("button primary"), a.name("decision"), a.value("approved")],
        [text("Onayla & aktarımı aç")],
      ),
      element.element(
        "button",
        [a.class("button quiet"), a.name("decision"), a.value("rejected")],
        [text("Reddet")],
      ),
    ],
  )
}
