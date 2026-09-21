import gleam/list

import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Property, type Session}
import nexus/icons
import nexus/listing_modules_view
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  properties: List(Property),
  active_prop_id: String,
  cockpit: List(String),
  pms_units: List(List(String)),
  kbs_records: List(List(String)),
  ota_channels: List(List(String)),
  whatsapp_msgs: List(List(String)),
  invoices: List(List(String)),
  b2b_agencies: List(List(String)),
  rate_parity: List(List(String)),
  maintenance_tickets: List(List(String)),
  cash_desk: List(List(String)),
  transport_notifs: List(List(String)),
  concierge_requests: List(List(String)),
  room_rack: List(List(String)),
  room_folios: List(List(String)),
  night_audits: List(List(String)),
  yield_rules: List(List(String)),
  promo_codes: List(List(String)),
  auto_messages: List(List(String)),
  csrf: String,
  feedback: String,
) -> String {
  let property_options =
    list.map(properties, fn(p) {
      element.element(
        "option",
        [
          a.value(p.id),
          ..case p.id == active_prop_id {
            True -> [a.attribute("selected", "selected")]
            False -> []
          }
        ],
        [
          text(p.title <> " (" <> p.locality <> ")"),
        ],
      )
    })

  let hub_header =
    el("div", "operations-hub-header", [
      el("div", "hub-title-row", [
        el("div", "", [
          el("span", "badge dark", [text("CANLI YÖNETİM PLATFORMU")]),
          el("h1", "section-title-with-icon", [
            icons.modules(),
            text("Operasyon Merkezi & Canlı Modül Kokpiti"),
          ]),
          el("p", "muted", [
            text(
              "Tesisinizin günlük tüm operasyonlarını, oda durumlarını (Rack), misafir folyolarını, gece denetimini ve çoklu kanal senkronizasyonunu tek ekrandan canlı olarak izleyin ve yönetin.",
            ),
          ]),
        ]),
        el("div", "hub-quick-nav", [
          element.element(
            "a",
            [a.href("/admin/modules"), a.class("button secondary")],
            [icons.modules(), text("Modül Kataloğu & Paketler")],
          ),
          element.element(
            "a",
            [a.href("/admin/campaigns"), a.class("button secondary")],
            [icons.categories(), text("İndirimler & Kuponlar")],
          ),
        ]),
      ]),
      // Tesis Seçici ve Hızlı Paket Aktivasyonu
      el("div", "hub-controls-bar", [
        el("div", "prop-selector-box", [
          el("label", "prop-selector-label section-title-with-icon", [
            icons.hotel(),
            text("Aktif Yönetilen Tesis:"),
          ]),
          element.element(
            "select",
            [
              a.class("prop-select-input"),
              a.attribute(
                "onchange",
                "window.location.href='/admin/operations?prop_id=' + this.value",
              ),
            ],
            property_options,
          ),
        ]),
        el("div", "bundle-shortcuts", [
          el("span", "bundle-label section-title-with-icon", [
            icons.sparkles(),
            text("1 Tıkla Hazır Paket Yükle:"),
          ]),
          bundle_button("hotel", "Otel", csrf),
          bundle_button("villa", "Villa", csrf),
          bundle_button("yacht", "Yat", csrf),
          bundle_button("transfer", "Transfer", csrf),
          bundle_button("all", "Tüm 29 Modül", csrf),
        ]),
      ]),
    ])

  let inner_body =
    listing_modules_view.render_cockpit_body(
      s,
      cockpit,
      pms_units,
      kbs_records,
      ota_channels,
      whatsapp_msgs,
      invoices,
      b2b_agencies,
      rate_parity,
      maintenance_tickets,
      cash_desk,
      transport_notifs,
      concierge_requests,
      room_rack,
      room_folios,
      night_audits,
      yield_rules,
      promo_codes,
      auto_messages,
      csrf,
      feedback,
    )

  view.shell(
    s,
    csrf,
    "Canlı Operasyon Kokpiti",
    el("div", "operations-page-wrapper", [
      hub_header,
      el("div", "operations-inner-content", [inner_body]),
    ]),
  )
}

fn bundle_icon(code: String) -> Element(Nil) {
  case code {
    "hotel" -> icons.hotel()
    "villa" -> icons.villa()
    "yacht" -> icons.yacht()
    "transfer" -> icons.transfer()
    _ -> icons.sparkles()
  }
}

fn bundle_button(code: String, label: String, csrf: String) {
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute("action", "/admin/modules/bundle"),
      a.class("inline-form"),
    ],
    [
      hidden("csrf", csrf),
      hidden("bundle", code),
      element.element(
        "button",
        [
          a.class("button small secondary bundle-pill-btn"),
          a.attribute("type", "submit"),
        ],
        [bundle_icon(code), text(label)],
      ),
    ],
  )
}
