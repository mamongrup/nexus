import gleam/int
import gleam/list
import gleam/result
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session, money}
import nexus/view.{el, hidden, input}

pub fn page(
  s: Session,
  csrf: String,
  key: String,
  rows: List(List(String)),
  requests: Bool,
  message: String,
) {
  let title = case requests {
    True -> "Opsiyon talepleri"
    False ->
      case s.workspace {
        "nexus" -> "NEXUS · İş ortakları"
        _ -> "Acente · Ürünler"
      }
  }
  let headings = case requests {
    True -> [
      "Ürün",
      "Tedarikçi",
      "Acente",
      "Giriş",
      "Çıkış",
      "Talep",
      "Opsiyon",
      "Toplam tutar",
      "İşlem",
    ]
    False ->
      case s.workspace {
        "nexus" -> ["Tedarikçi", "Acente", "Bağlantı", "İşlem"]
        _ -> ["Ürün", "Tedarikçi", "Konum", "Gecelik başlangıç"]
      }
  }
  view.shell(
    s,
    csrf,
    title,
    el("div", "", [
      el("h1", "", [text(title)]),
      el("p", "muted", [
        text(case requests {
          True ->
            "Acentelerden tedarikçilere iletilen geçici rezervasyon ve opsiyon taleplerini inceleyin, kontenjan durumuna göre onaylayın veya serbest bırakın."
          False ->
            case s.workspace {
              "nexus" ->
                "Tedarikçi ile acente arasındaki B2B dağıtım bağlantılarını ve aktif iş ortaklığı sözleşmelerini yönetin."
              "agency" ->
                "Anlaşmalı tedarikçilerin onaylanan portföyünü inceleyin, doğrudan rezervasyon ve opsiyon talepleri oluşturun."
              _ ->
                "Acentelerden gelen ürün bağlantı ve kontenjan taleplerini yönetin."
            }
        }),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice", [text(message)])
      },
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el("tr", "", list.map(headings, fn(h) { el("th", "", [text(h)]) })),
          ]),
          el("tbody", "", case rows {
            [] -> [
              el("tr", "", [
                element.element(
                  "td",
                  [
                    a.attribute("colspan", int.to_string(list.length(headings))),
                    a.class("empty-cell"),
                  ],
                  [
                    el("div", "empty-table-state", [
                      el("strong", "", [text("Kayıt bulunmuyor")]),
                      el("p", "muted", [
                        text(case requests {
                          True ->
                            "Şu anda bekleyen bir acente talebi bulunmuyor."
                          False ->
                            "Aktif bir opsiyon veya bağlantılı ürün kaydı bulunmuyor."
                        }),
                      ]),
                    ]),
                  ],
                ),
              ]),
            ]
            _ -> list.map(rows, fn(row) { render_row(row, s, csrf, requests) })
          }),
        ]),
      ]),
      case s.workspace == "agency" && !requests && rows != [] {
        False -> text("")
        True ->
          element.element(
            "form",
            [
              a.class("panel form editor-form"),
              a.attribute("method", "post"),
              a.attribute("action", "/admin/requests"),
            ],
            [
              el("h2", "", [text("Opsiyon talep et")]),
              hidden("csrf", csrf),
              hidden("request_key", key),
              el("label", "field", [
                text("Ürün"),
                element.element(
                  "select",
                  [a.name("property")],
                  list.map(rows, fn(row) {
                    case row {
                      [id, title, ..] ->
                        element.element("option", [a.value(id)], [text(title)])
                      _ -> text("")
                    }
                  }),
                ),
              ]),
              el("div", "form-grid", [
                input("Giriş", "start", "date", "", True),
                input("Çıkış (hariç)", "end", "date", "", True),
              ]),
              input(
                "Talep edilen süre (dakika)",
                "minutes",
                "number",
                "30",
                True,
              ),
              element.element("button", [a.class("button primary")], [
                text("Tedarikçiye talep gönder"),
              ]),
            ],
          )
      },
      case rows {
        [] ->
          el("p", "muted", [
            text(
              "Henüz kayıt yok. NEXUS bağlantısı ve tedarikçi yayını tamamlandığında ilgili kayıtlar burada görünür.",
            ),
          ])
        _ -> text("")
      },
    ]),
  )
}

fn render_row(row: List(String), s: Session, csrf: String, requests: Bool) {
  let cells = case row, requests {
    [id, title, supplier, agency, start, end, status, hold, amount, currency],
      True
    -> [
      text(title),
      text(supplier),
      text(agency),
      text(start),
      text(end),
      text(status),
      text(hold),
      text(case amount {
        "" -> "Onay bekliyor"
        _ -> money(int.parse(amount) |> result.unwrap(0), currency)
      }),
      case s.workspace == "supplier" && status == "pending" {
        True ->
          el("div", "form-actions", [
            decision(csrf, id, "approved", "Onayla"),
            decision(csrf, id, "rejected", "Reddet"),
          ])
        False ->
          case
            s.workspace == "agency" && status == "approved" && hold == "active"
          {
            True ->
              action(
                csrf,
                "/admin/requests/" <> id <> "/confirm",
                "Bu tutarla kesin rezervasyon yap (ödenmedi)",
              )
            False -> text("-")
          }
      },
    ]
    [supplier_id, supplier, agency_id, agency, status], False -> [
      text(supplier),
      text(agency),
      text(status),
      element.element(
        "form",
        [
          a.attribute("method", "post"),
          a.attribute("action", "/admin/partners"),
        ],
        [
          hidden("csrf", csrf),
          hidden("supplier", supplier_id),
          hidden("agency", agency_id),
          hidden("status", case status {
            "active" -> "paused"
            _ -> "active"
          }),
          element.element("button", [a.class("button small")], [
            text(case status {
              "active" -> "Bağlantıyı duraklat"
              _ -> "Bağlantıyı aç"
            }),
          ]),
        ],
      ),
    ]
    [_id, title, supplier, locality, minor, currency], False -> [
      text(title),
      text(supplier),
      text(locality),
      text(money(int.parse(minor) |> result.unwrap(0), currency)),
    ]
    _, _ -> [text("Kayıt okunamadı")]
  }
  el("tr", "", list.map(cells, fn(c) { el("td", "", [c]) }))
}

fn decision(csrf: String, id: String, value: String, label: String) {
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute("action", "/admin/requests/" <> id <> "/decide"),
    ],
    [
      hidden("csrf", csrf),
      hidden("decision", value),
      element.element("button", [a.class("button small")], [text(label)]),
    ],
  )
}

pub fn action(csrf: String, url: String, label: String) {
  element.element(
    "form",
    [a.attribute("method", "post"), a.attribute("action", url)],
    [
      hidden("csrf", csrf),
      element.element("button", [a.class("button small")], [text(label)]),
    ],
  )
}

pub fn reservations(
  s: Session,
  csrf: String,
  rows: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Rezervasyonlar",
    el("div", "", [
      el("div", "content-header", [
        el("div", "eyebrow", [text("B2B REZERVASYON OPERASYONU")]),
        el("h1", "", [text("Rezervasyonlar")]),
        el("p", "muted", [
          text(
            "Acente ve tedarikçi bazlı kesinleşen tüm rezervasyonları listeleyin; giriş-çıkış tarihlerini, toplam konaklama tutarlarını ve ödeme durumlarını anlık takip edin.",
          ),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice", [text(message)])
      },
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                [
                  "Ürün",
                  "Tedarikçi",
                  "Acente",
                  "Giriş",
                  "Çıkış",
                  "Tutar",
                  "Durum",
                  "Ödeme",
                  "İşlem",
                ],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el("tbody", "", case rows {
            [] -> [
              el("tr", "", [
                element.element(
                  "td",
                  [a.attribute("colspan", "9"), a.class("empty-cell")],
                  [
                    el("div", "empty-table-state", [
                      el("strong", "", [
                        text("Kayıtlı rezervasyon bulunmuyor"),
                      ]),
                      el("p", "muted", [
                        text(
                          "Acenteler tarafından kesinleştirilen veya tedarikçiler tarafından onaylanan tüm rezervasyonlar burada listelenir.",
                        ),
                      ]),
                    ]),
                  ],
                ),
              ]),
            ]
            _ ->
              list.map(rows, fn(row) {
                case row {
                  [
                    id,
                    title,
                    supplier,
                    agency,
                    start,
                    end,
                    amount,
                    currency,
                    status,
                    payment,
                  ] -> {
                    let status_badge = case status {
                      "confirmed" -> el("span", "badge", [text("Kesinleşti")])
                      "cancelled" ->
                        el("span", "badge neutral cancelled", [
                          text("İptal Edildi (cancelled)"),
                        ])
                      "pending" ->
                        el("span", "badge warning", [text("Beklemede")])
                      _ -> el("span", "badge neutral", [text(status)])
                    }
                    let payment_badge = case payment {
                      "unpaid" ->
                        el("span", "badge warning", [text("Ödenmedi")])
                      "paid" -> el("span", "badge", [text("Ödendi")])
                      _ -> el("span", "badge neutral", [text(payment)])
                    }
                    let cells = [
                      text(title),
                      text(supplier),
                      text(agency),
                      text(start),
                      text(end),
                      el("span", "amount-cell", [
                        text(money(
                          int.parse(amount) |> result.unwrap(0),
                          currency,
                        )),
                      ]),
                      status_badge,
                      payment_badge,
                      el("div", "action-buttons", [
                        case
                          s.workspace == "supplier"
                          && status == "confirmed"
                          && payment == "unpaid"
                        {
                          True ->
                            action(
                              csrf,
                              "/admin/reservations/" <> id <> "/cancel",
                              "İptal et",
                            )
                          False -> text("")
                        },
                        case status == "confirmed" {
                          True ->
                            action(
                              csrf,
                              "/admin/reservations/" <> id <> "/post-ledger",
                              "Yevmiyeye Kaydet",
                            )
                          False -> text("")
                        },
                      ]),
                    ]
                    el("tr", "", list.map(cells, fn(c) { el("td", "", [c]) }))
                  }
                  _ -> text("")
                }
              })
          }),
        ]),
      ]),
    ]),
  )
}
