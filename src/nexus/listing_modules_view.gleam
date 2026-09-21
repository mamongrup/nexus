import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden, shell}

fn link(url: String, label: String, class: String) {
  element.element("a", [a.href(url), a.class(class)], [text(label)])
}

pub fn render_cockpit_body(
  _s: Session,
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
) -> Element(Nil) {
  case cockpit {
    [
      prop_id,
      title,
      locality,
      cat_code,
      nightly,
      cur,
      total_units,
      avail_units,
      kbs_count,
      ota_count,
      wa_count,
      inv_count,
      _,
    ] -> {
      let nightly_int = int.parse(nightly) |> result_unwrap(0)
      el("div", "listing-cockpit-container", [
        el("div", "integration-notice", [
          el("span", "integration-notice-icon", [text("!")]),
          el("div", "", [
            el("strong", "", [text("Entegrasyon doğrulaması gerekiyor")]),
            el("p", "", [
              text(
                "KBS, kanal eşitleme, WhatsApp ve e-fatura kayıtları test verisi içerebilir. Bağlantı doğrulanana kadar resmî teslimat kanıtı sayılmaz.",
              ),
            ]),
          ]),
        ]),
        el("div", "cockpit-top-nav", [
          link("/admin/listings", "← İlanlara Dön", "quiet-link"),
          el("span", "separator", [text("·")]),
          element.element(
            "a",
            [
              a.href("/ilan/" <> prop_id),
              a.class("button small secondary"),
            ],
            [icons.eye(), text(" Pazaryerinde Canlı İncele")],
          ),
        ]),
        case feedback {
          "" -> text("")
          msg -> el("div", "flash-message success", [text(msg)])
        },
        el("div", "cockpit-header-card", [
          el("div", "cockpit-header-left", [
            el("div", "cockpit-eyebrow", [
              el("span", "badge primary", [text(string.uppercase(cat_code))]),
              el("span", "cockpit-id", [
                text("İlan #" <> string.slice(prop_id, 0, 8)),
              ]),
            ]),
            el("h1", "cockpit-title", [text(title)]),
            el("p", "cockpit-locality flex align-center gap-1", [
              icons.beach(),
              text(" " <> locality),
            ]),
          ]),
          el("div", "cockpit-header-right", [
            el("div", "price-tag", [
              el("small", "muted", [text("Taban Fiyat")]),
              el("strong", "", [
                text(domain.money(nightly_int, cur) <> " / gece"),
              ]),
            ]),
          ]),
        ]),
        el("div", "cockpit-kpi-grid", [
          kpi_card(
            "PMS Odalar",
            total_units <> " Toplam (" <> avail_units <> " Müsait)",
            "success",
          ),
          kpi_card("KBS Emniyet", kbs_count <> " Bildirim Kaydı", "primary"),
          kpi_card("Kanal Eşitleme", ota_count <> " OTA Kanalı Aktif", "info"),
          kpi_card(
            "WhatsApp Logları",
            wa_count <> " İleti Gönderildi",
            "warning",
          ),
          kpi_card("e-Fatura / e-Arşiv", inv_count <> " Mali Belge", "dark"),
          kpi_card(
            "B2B Acentalar",
            int.to_string(list.length(b2b_agencies)) <> " Kontrat",
            "primary",
          ),
          kpi_card(
            "Fiyat Paritesi",
            int.to_string(list.length(rate_parity)) <> " Kanal Denetimi",
            "info",
          ),
          kpi_card(
            "Teknik Servis",
            int.to_string(list.length(maintenance_tickets)) <> " İş Emri",
            "warning",
          ),
          kpi_card(
            "Ön Kasa Defteri",
            int.to_string(list.length(cash_desk)) <> " Kasa Hareketi",
            "success",
          ),
          kpi_card(
            "KABİS / U-ETDS",
            int.to_string(list.length(transport_notifs)) <> " Resmi Bildirim",
            "dark",
          ),
          kpi_card(
            "Misafir Konsiyerj",
            int.to_string(list.length(concierge_requests)) <> " Mobil İstek",
            "primary",
          ),
          kpi_card(
            "Canlı Blokaj / Rack",
            int.to_string(list.length(room_rack)) <> " Ünite",
            "primary",
          ),
          kpi_card(
            "Aktif Folyolar",
            int.to_string(list.length(room_folios)) <> " Harcama",
            "warning",
          ),
          kpi_card(
            "Son Gün Devri",
            int.to_string(list.length(night_audits)) <> " Kapanış",
            "dark",
          ),
          kpi_card(
            "Gelir Otopilotu",
            int.to_string(list.length(yield_rules)) <> " Kural Aktif",
            "info",
          ),
          kpi_card(
            "Promosyonlar",
            int.to_string(list.length(promo_codes)) <> " Kupon",
            "success",
          ),
          kpi_card(
            "Oto-Mesajlaşma",
            int.to_string(list.length(auto_messages)) <> " İleti",
            "primary",
          ),
        ]),

        // 1. PMS Modülü
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.pms(),
              text("Ön Büro (PMS) & Ünite Durum Yönetimi"),
            ]),
            el("span", "badge", [text("Canlı PMS Entegrasyonu")]),
          ]),
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Ünite Kodu")]),
                el("th", "", [text("Oda Adı")]),
                el("th", "", [text("Tip")]),
                el("th", "", [text("Doluluk Durumu")]),
                el("th", "", [text("Temizlik")]),
                el("th", "", [text("Notlar")]),
                el("th", "", [text("İşlem")]),
              ]),
            ]),
            el("tbody", "", case pms_units {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [text("Tanımlı ünite bulunamadı.")]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [uid, ucode, uname, utype, occ, hk, notes] ->
                      el("tr", "", [
                        el("td", "", [el("strong", "", [text(ucode)])]),
                        el("td", "", [text(uname)]),
                        el("td", "", [text(utype)]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case occ {
                              "available" -> "success"
                              "occupied" -> "danger"
                              _ -> "warning"
                            },
                            [
                              text(case occ {
                                "available" -> "Müsait"
                                "occupied" -> "Dolu / Konaklıyor"
                                _ -> occ
                              }),
                            ],
                          ),
                        ]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case hk {
                              "clean" -> "success"
                              "dirty" -> "danger"
                              _ -> "warning"
                            },
                            [
                              text(case hk {
                                "clean" -> "Temiz"
                                "dirty" -> "Kirli"
                                _ -> hk
                              }),
                            ],
                          ),
                        ]),
                        el("td", "muted", [text(notes)]),
                        el("td", "", [
                          element.element(
                            "form",
                            [
                              a.attribute("method", "post"),
                              a.attribute(
                                "action",
                                "/admin/listings/" <> prop_id <> "/modules/pms",
                              ),
                            ],
                            [
                              hidden("csrf", csrf),
                              hidden("unit_id", uid),
                              hidden("occupancy", case occ {
                                "available" -> "occupied"
                                _ -> "available"
                              }),
                              hidden("housekeeping", case hk {
                                "clean" -> "dirty"
                                _ -> "clean"
                              }),
                              element.element(
                                "button",
                                [a.class("button small")],
                                [
                                  text(case occ {
                                    "available" -> "Dolu Yap"
                                    _ -> "Boşalt & Müsait Yap"
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ]),
                      ])
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),

        // 2. KBS Kimlik Bildirimi (Emniyet / Jandarma)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.security(),
              text("KBS Kimlik Bildirimi (EGM / Jandarma AKBS)"),
            ]),
            el("span", "badge warning", [text("KBS bağlantısı hazır değil")]),
          ]),
          el("div", "kbs-grid-layout", [
            el("div", "kbs-form-col", [
              el("h3", "", [text("Hızlı Misafir Bildirimi Gönder")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/kbs",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Misafir Ad Soyad")]),
                    element.element(
                      "input",
                      [a.type_("text"), a.name("guest_name"), a.required(True)],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("T.C. Kimlik / Pasaport No")]),
                    element.element(
                      "input",
                      [a.type_("text"), a.name("tc"), a.required(True)],
                      [],
                    ),
                  ]),
                  el("div", "form-row-2", [
                    el("div", "form-group", [
                      el("label", "", [text("Oda / Ünite No")]),
                      element.element(
                        "input",
                        [
                          a.type_("text"),
                          a.name("room"),
                          a.value("101"),
                          a.required(True),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      el("label", "", [text("Giriş Tarihi")]),
                      element.element(
                        "input",
                        [a.type_("date"), a.name("check_in"), a.required(True)],
                        [],
                      ),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Çıkış Tarihi")]),
                    element.element(
                      "input",
                      [a.type_("date"), a.name("check_out"), a.required(True)],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.security(),
                    text(" EGM AKBS'ye Anlık İlet"),
                  ]),
                ],
              ),
            ]),
            el("div", "kbs-table-col", [
              el("h3", "", [text("Son Kimlik Bildirim Kayıtları")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Misafir")]),
                    el("th", "", [text("Kimlik/Pasaport")]),
                    el("th", "", [text("Oda")]),
                    el("th", "", [text("Giriş - Çıkış")]),
                    el("th", "", [text("EGM Kod")]),
                    el("th", "", [text("Durum")]),
                  ]),
                ]),
                el("tbody", "", case kbs_records {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [text("KBS kaydı yok.")]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [_, gname, tc, room, cin, cout, _status, dcode, _time] ->
                          el("tr", "", [
                            el("td", "", [el("strong", "", [text(gname)])]),
                            el("td", "", [text(tc)]),
                            el("td", "", [text(room)]),
                            el("td", "", [text(cin <> " / " <> cout)]),
                            el("td", "", [el("code", "", [text(dcode)])]),
                            el("td", "", [
                              el("span", "badge success", [
                                text("EGM Onaylandı"),
                              ]),
                            ]),
                          ])
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // 3. Kanal Yöneticisi (Channel Manager)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.modules(),
              text("Kanal Yöneticisi (OTA 2-Way Sync)"),
            ]),
            el("span", "badge info", [
              text("Global OTA & Pazar Yeri Senkronizasyonu"),
            ]),
          ]),
          el("div", "ota-channels-grid", case ota_channels {
            [] -> [el("p", "empty-msg", [text("Bağlı OTA kanalı bulunamadı.")])]
            rows ->
              list.map(rows, fn(r) {
                case r {
                  [_, cname, rem_id, _status, last_sync, _auto_s] ->
                    el("div", "ota-channel-card", [
                      el("div", "ota-channel-top", [
                        el("h4", "", [text(cname)]),
                        el("span", "badge warning", [
                          text("Eşitleme doğrulanmadı"),
                        ]),
                      ]),
                      el("p", "muted", [text("Kanal İlan Ref: " <> rem_id)]),
                      el("p", "small", [text("Son Eşitleme: " <> last_sync)]),
                      element.element(
                        "form",
                        [
                          a.attribute("method", "post"),
                          a.attribute(
                            "action",
                            "/admin/listings/" <> prop_id <> "/modules/ota",
                          ),
                        ],
                        [
                          hidden("csrf", csrf),
                          hidden("channel", cname),
                          element.element("button", [a.class("button small")], [
                            text("Fiyat & Müsaitlik Gönder ⟳"),
                          ]),
                        ],
                      ),
                    ])
                  _ -> text("")
                }
              })
          }),
        ]),

        // 4. WhatsApp Misafir İletişimi
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.whatsapp(),
              text("WhatsApp API & Misafir İletişim Asistanı"),
            ]),
            el("span", "badge warning", [
              text("WhatsApp bağlantısı hazır değil"),
            ]),
          ]),
          el("div", "wa-grid-layout", [
            el("div", "wa-form-col", [
              el("h3", "", [text("Anlık Şablon Mesaj Gönder")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/whatsapp",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Misafir Telefon Numarası")]),
                    element.element(
                      "input",
                      [
                        a.type_("tel"),
                        a.name("phone"),
                        a.placeholder("+90 532 000 0000"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Mesaj Şablonu")]),
                    element.element("select", [a.name("template")], [
                      element.element("option", [a.value("welcome")], [
                        text("Rezervasyon Onayı & Yol Tarifi"),
                      ]),
                      element.element("option", [a.value("door_pin")], [
                        text("Akıllı Kapı PIN Kodu & WiFi"),
                      ]),
                      element.element("option", [a.value("checkout")], [
                        text("Çıkış & Memnuniyet Anketi"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Özel Mesaj (İsteğe Bağlı)")]),
                    element.element(
                      "textarea",
                      [a.name("content"), a.placeholder("Özel not ekleyin...")],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.whatsapp(),
                    text("WhatsApp ile Gönder"),
                  ]),
                ],
              ),
            ]),
            el("div", "wa-logs-col", [
              el("h3", "", [text("Gönderilen Mesaj Geçmişi")]),
              el("div", "wa-messages-list", case whatsapp_msgs {
                [] -> [
                  el("p", "empty-msg", [
                    text("Henüz WhatsApp mesajı gönderilmedi."),
                  ]),
                ]
                rows ->
                  list.map(rows, fn(r) {
                    case r {
                      [_, phone, tpl, content, status, time] ->
                        el("div", "wa-msg-bubble", [
                          el("div", "wa-msg-meta", [
                            el("strong", "", [text(phone)]),
                            el("span", "badge small", [text(tpl)]),
                            el("small", "muted", [text(time)]),
                          ]),
                          el("p", "wa-msg-text", [text(content)]),
                          el("span", "wa-msg-status", [text("✓✓ " <> status)]),
                        ])
                      _ -> text("")
                    }
                  })
              }),
            ]),
          ]),
        ]),

        // 5. e-Fatura / e-Arşiv Mali Entegrasyon
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.document(),
              text("e-Fatura & e-Arşiv (GİB Entegrasyonu)"),
            ]),
            el("span", "badge dark", [text("Mali Mühür & GİB e-Belge")]),
          ]),
          el("div", "invoice-grid-layout", [
            el("div", "invoice-form-col", [
              el("h3", "", [text("Hızlı e-Arşiv Fatura Düzenle")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/invoice",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Alıcı Ad / Ünvan")]),
                    element.element(
                      "input",
                      [a.type_("text"), a.name("recipient"), a.required(True)],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Tutar (TL)")]),
                    element.element(
                      "input",
                      [
                        a.type_("number"),
                        a.name("amount"),
                        a.value("12500"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.document(),
                    text(" GİB Onaylı e-Arşiv Kes"),
                  ]),
                ],
              ),
            ]),
            el("div", "invoice-table-col", [
              el("h3", "", [text("Kesilen Faturalar")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Fatura No")]),
                    el("th", "", [text("Alıcı")]),
                    el("th", "", [text("Tutar")]),
                    el("th", "", [text("%10 KDV")]),
                    el("th", "", [text("%2 Konaklama")]),
                    el("th", "", [text("GİB")]),
                    el("th", "", [text("Tarih")]),
                  ]),
                ]),
                el("tbody", "", case invoices {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [text("Fatura bulunamadı.")]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [_, inv_no, recip, tot, kdv, kon, cur, _status, time] ->
                          el("tr", "", [
                            el("td", "", [el("strong", "", [text(inv_no)])]),
                            el("td", "", [text(recip)]),
                            el("td", "", [text(tot <> " " <> cur)]),
                            el("td", "", [text(kdv <> " " <> cur)]),
                            el("td", "", [text(kon <> " " <> cur)]),
                            el("td", "", [
                              el("span", "badge warning", [
                                text("GİB onayı doğrulanmadı"),
                              ]),
                            ]),
                            el("td", "muted", [text(time)]),
                          ])
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // 6. B2B Acenta & Dağıtım Ağı
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.agency(),
              text("B2B Acenta & Dağıtım Ağı"),
            ]),
            el("span", "badge primary", [text("Allotment & Stop-Sale Yönetimi")]),
          ]),
          el("div", "module-grid", [
            el("div", "module-form-col", [
              el("h3", "", [text("Yeni B2B Acenta Sözleşmesi Ekle")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/b2b",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Acenta Adı / Ünvanı")]),
                    element.element(
                      "input",
                      [a.type_("text"), a.name("agency_name"), a.required(True)],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Acenta Kodu (Örn: ACN-001)")]),
                    element.element(
                      "input",
                      [a.type_("text"), a.name("agency_code"), a.required(True)],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Komisyon Oranı (%)")]),
                    element.element(
                      "input",
                      [
                        a.type_("number"),
                        a.name("commission_pct"),
                        a.value("15.0"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Ayrılan Kontenjan (Oda Sayısı)")]),
                    element.element(
                      "input",
                      [
                        a.type_("number"),
                        a.name("allotment"),
                        a.value("3"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Net Kontrat Fiyatı (TL)")]),
                    element.element(
                      "input",
                      [
                        a.type_("number"),
                        a.name("net_rate"),
                        a.value("7500"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.save(),
                    text("Acenta Sözleşmesini Kaydet"),
                  ]),
                ],
              ),
            ]),
            el("div", "module-table-col", [
              el("h3", "", [text("Kayıtlı Acenta Kontratları")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Acenta Adı")]),
                    el("th", "", [text("Kod")]),
                    el("th", "", [text("Komisyon")]),
                    el("th", "", [text("Kontenjan")]),
                    el("th", "", [text("Stop-Sale")]),
                    el("th", "", [text("İşlem")]),
                  ]),
                ]),
                el("tbody", "", case b2b_agencies {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [
                        text("Henüz B2B acenta kontratı tanımlanmadı."),
                      ]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [
                          aid,
                          aname,
                          acode,
                          acomm,
                          aallot,
                          astop,
                          _net,
                          _cur,
                          _time,
                        ] ->
                          el("tr", "", [
                            el("td", "", [el("strong", "", [text(aname)])]),
                            el("td", "", [el("code", "", [text(acode)])]),
                            el("td", "", [text("%" <> acomm)]),
                            el("td", "", [text(aallot <> " Oda")]),
                            el("td", "", [
                              el(
                                "span",
                                "badge "
                                  <> case astop {
                                  "true" -> "danger"
                                  _ -> "success"
                                },
                                [
                                  text(case astop {
                                    "true" -> "SATIŞ KAPALI (STOP-SALE)"
                                    _ -> "SATIŞA AÇIK"
                                  }),
                                ],
                              ),
                            ]),
                            el("td", "", [
                              element.element(
                                "form",
                                [
                                  a.attribute("method", "post"),
                                  a.attribute(
                                    "action",
                                    "/admin/listings/"
                                      <> prop_id
                                      <> "/modules/b2b/stop-sale",
                                  ),
                                ],
                                [
                                  hidden("csrf", csrf),
                                  hidden("agency_id", aid),
                                  element.element(
                                    "button",
                                    [
                                      a.class(
                                        "button small "
                                        <> case astop {
                                          "true" -> "secondary"
                                          _ -> "danger"
                                        },
                                      ),
                                    ],
                                    [
                                      text(case astop {
                                        "true" -> "Satışa Aç"
                                        _ -> "Stop-Sale Uygula"
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ]),
                          ])
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // 7. Fiyat Paritesi ve Gelir Zekası
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.trending_up(),
              text("Fiyat Paritesi & Gelir Zekası"),
            ]),
            el("div", "section-actions", [
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/parity/check",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  element.element("button", [a.class("button small primary")], [
                    icons.sparkles(),
                    text(" Canlı Parite Taraması Çalıştır"),
                  ]),
                ],
              ),
            ]),
          ]),
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Kanal")]),
                el("th", "", [text("Kanal Fiyatı")]),
                el("th", "", [text("Doğrudan Satış")]),
                el("th", "", [text("Fark %")]),
                el("th", "", [text("Parite Durumu")]),
                el("th", "", [text("Sistem Uyarısı")]),
                el("th", "", [text("Denetim Zamanı")]),
              ]),
            ]),
            el("tbody", "", case rate_parity {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [
                    text(
                      "Parite denetimi yapılmadı. Yukarıdaki butona tıklayarak tarama başlatın.",
                    ),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [
                      _pid,
                      pchan,
                      pcrate,
                      pdrate,
                      pcur,
                      pstatus,
                      pdiff,
                      pmsg,
                      ptime,
                    ] -> {
                      let crate_int = int.parse(pcrate) |> result_unwrap(0)
                      let drate_int = int.parse(pdrate) |> result_unwrap(0)
                      el("tr", "", [
                        el("td", "", [el("strong", "", [text(pchan)])]),
                        el("td", "", [text(domain.money(crate_int, pcur))]),
                        el("td", "", [text(domain.money(drate_int, pcur))]),
                        el("td", "", [text("%" <> pdiff)]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case pstatus {
                              "parity_ok" -> "success"
                              "underpricing_violation" -> "danger"
                              _ -> "info"
                            },
                            [
                              text(case pstatus {
                                "parity_ok" -> "Parite Korunuyor"
                                "underpricing_violation" -> "PARİTE İHLALİ"
                                _ -> "Fiyat Farkı Mevcut"
                              }),
                            ],
                          ),
                        ]),
                        el("td", "muted", [text(pmsg)]),
                        el("td", "muted", [text(ptime)]),
                      ])
                    }
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),

        // 8. Teknik Servis & Arıza Takip
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.housekeeping(),
              text("Teknik Servis & Arıza Takibi (Bakım İş Emirleri)"),
            ]),
            el("span", "badge warning", [text("Oda Bakım Entegrasyonu")]),
          ]),
          el("div", "module-grid", [
            el("div", "module-form-col", [
              el("h3", "", [text("Yeni Arıza İş Emri Aç")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/maintenance",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Oda / Bölüm Kodu")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("room_code"),
                        a.required(True),
                        a.placeholder("Örn: 101"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Arıza Tanımı")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("issue_title"),
                        a.required(True),
                        a.placeholder("Örn: Klima gaz kaçağı ve soğutmuyor"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Öncelik Seviyesi")]),
                    element.element("select", [a.name("priority")], [
                      element.element("option", [a.value("urgent")], [
                        text("Acil (Misafir Bekliyor)"),
                      ]),
                      element.element(
                        "option",
                        [a.value("normal"), a.selected(True)],
                        [text("Normal")],
                      ),
                      element.element("option", [a.value("low")], [
                        text("Düşük / Periyodik"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Görevli Teknisyen")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("technician"),
                        a.value("Nöbetçi Teknisyen"),
                      ],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button warning small")], [
                    icons.security(),
                    text("Arıza Kaydı Aç & Odayı Bakıma Al"),
                  ]),
                ],
              ),
            ]),
            el("div", "module-table-col", [
              el("h3", "", [text("Arıza İş Emirleri Listesi")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Oda")]),
                    el("th", "", [text("Arıza")]),
                    el("th", "", [text("Öncelik")]),
                    el("th", "", [text("Teknisyen")]),
                    el("th", "", [text("Durum")]),
                    el("th", "", [text("Bildirim")]),
                    el("th", "", [text("İşlem")]),
                  ]),
                ]),
                el("tbody", "", case maintenance_tickets {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [
                        text("Aktif arıza iş emri bulunmuyor."),
                      ]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [mid, mroom, missue, mprio, mtech, mstatus, mrep, _mres] ->
                          el("tr", "", [
                            el("td", "", [el("strong", "", [text(mroom)])]),
                            el("td", "", [text(missue)]),
                            el("td", "", [
                              el(
                                "span",
                                "badge "
                                  <> case mprio {
                                  "urgent" -> "danger"
                                  _ -> "warning"
                                },
                                [text(mprio)],
                              ),
                            ]),
                            el("td", "", [text(mtech)]),
                            el("td", "", [
                              el(
                                "span",
                                "badge "
                                  <> case mstatus {
                                  "resolved" -> "success"
                                  _ -> "danger"
                                },
                                [
                                  text(case mstatus {
                                    "resolved" -> "Çözüldü"
                                    _ -> "İşlem Bekliyor"
                                  }),
                                ],
                              ),
                            ]),
                            el("td", "muted", [text(mrep)]),
                            el("td", "", [
                              case mstatus {
                                "open" ->
                                  element.element(
                                    "form",
                                    [
                                      a.attribute("method", "post"),
                                      a.attribute(
                                        "action",
                                        "/admin/listings/"
                                          <> prop_id
                                          <> "/modules/maintenance/resolve",
                                      ),
                                    ],
                                    [
                                      hidden("csrf", csrf),
                                      hidden("ticket_id", mid),
                                      element.element(
                                        "button",
                                        [a.class("button small success")],
                                        [
                                          icons.check(),
                                          text(" Çözüldü Olarak Kapat"),
                                        ],
                                      ),
                                    ],
                                  )
                                _ ->
                                  el("span", "badge success", [
                                    text("Tamamlandı"),
                                  ])
                              },
                            ]),
                          ])
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // 9. Ön Büro Kasa & Çoklu Döviz Kasa Defteri
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.accounting(),
              text(
                "Ön Büro Kasa & Çoklu Dövizli Kasa Defteri (Resepsiyon Kasası)",
              ),
            ]),
            el("span", "badge success", [text("Nakit & POS Hareketleri")]),
          ]),
          el("div", "module-grid", [
            el("div", "module-form-col", [
              el("h3", "", [text("Kasa Hareketi Ekle")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/cash",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("İşlem Yönü")]),
                    element.element("select", [a.name("trans_type")], [
                      element.element("option", [a.value("collection")], [
                        text("Tahsilat (Giriş)"),
                      ]),
                      element.element("option", [a.value("disbursement")], [
                        text("Ödeme / Tediye (Çıkış)"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Para Birimi")]),
                    element.element("select", [a.name("currency")], [
                      element.element("option", [a.value("TRY")], [
                        text("TRY (Türk Lirası)"),
                      ]),
                      element.element("option", [a.value("EUR")], [
                        text("EUR (Euro)"),
                      ]),
                      element.element("option", [a.value("USD")], [
                        text("USD (Amerikan Doları)"),
                      ]),
                      element.element("option", [a.value("GBP")], [
                        text("GBP (İngiliz Sterlini)"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Ödeme Yöntemi")]),
                    element.element("select", [a.name("payment_method")], [
                      element.element("option", [a.value("cash")], [
                        text("Nakit Kasa"),
                      ]),
                      element.element("option", [a.value("pos")], [
                        text("Kredi Kartı (POS)"),
                      ]),
                      element.element("option", [a.value("bank_transfer")], [
                        text("Banka Havalesi"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Tutar")]),
                    element.element(
                      "input",
                      [
                        a.type_("number"),
                        a.name("amount"),
                        a.value("4500"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Oda Kodu / İlişki")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("room_code"),
                        a.placeholder("Örn: 204"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Açıklama")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("notes"),
                        a.value("Konaklama nakit tahsilatı"),
                      ],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.save(),
                    text("Kasa Föyüne İşle"),
                  ]),
                ],
              ),
            ]),
            el("div", "module-table-col", [
              el("h3", "", [text("Kasa Hareketleri Föyü")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Makbuz No")]),
                    el("th", "", [text("Tür")]),
                    el("th", "", [text("Yöntem")]),
                    el("th", "", [text("Tutar")]),
                    el("th", "", [text("Oda")]),
                    el("th", "", [text("Açıklama")]),
                    el("th", "", [text("Tarih")]),
                  ]),
                ]),
                el("tbody", "", case cash_desk {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [
                        text("Henüz kasa hareketi kaydedilmedi."),
                      ]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [
                          _cid,
                          ctype,
                          ccur,
                          cmeth,
                          camt,
                          croom,
                          crec,
                          cnotes,
                          ctime,
                        ] -> {
                          let amt_int = int.parse(camt) |> result_unwrap(0)
                          el("tr", "", [
                            el("td", "", [el("strong", "", [text(crec)])]),
                            el("td", "", [
                              el(
                                "span",
                                "badge "
                                  <> case ctype {
                                  "collection" -> "success"
                                  _ -> "danger"
                                },
                                [
                                  text(case ctype {
                                    "collection" -> "Tahsilat"
                                    _ -> "Tediye"
                                  }),
                                ],
                              ),
                            ]),
                            el("td", "", [text(cmeth)]),
                            el("td", "", [text(domain.money(amt_int, ccur))]),
                            el("td", "", [text(croom)]),
                            el("td", "muted", [text(cnotes)]),
                            el("td", "muted", [text(ctime)]),
                          ])
                        }
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // 10. KABİS & U-ETDS Resmi Emniyet / Ulaştırma Bildirimleri
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.security(),
              text("KABİS & U-ETDS Resmi Emniyet / Ulaştırma Bildirimleri"),
            ]),
            el("span", "badge dark", [text("Araç Kiralama & Transfer Mevzuatı")]),
          ]),
          el("div", "module-grid", [
            el("div", "module-form-col", [
              el("h3", "", [text("Resmi Sevk Bildirimi Gönder")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/transport",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Bildirim Sistemi")]),
                    element.element("select", [a.name("system_name")], [
                      element.element("option", [a.value("kabis")], [
                        text("EGM KABİS (Kiralık Araç Bildirim Sistemi)"),
                      ]),
                      element.element("option", [a.value("uetds")], [
                        text("Ulaştırma Bakanlığı U-ETDS (Transfer Bildirimi)"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Araç Plakası")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("plate_code"),
                        a.value("34 ABC 789"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Şoför / Sürücü")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("driver_name"),
                        a.value("Ali Yılmaz"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Misafir Adı")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("guest_name"),
                        a.value("Mehmet Kaya"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("T.C. Kimlik / Pasaport No")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("tc_passport"),
                        a.value("12345678901"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Varış Güzergahı / Lokasyon")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("destination"),
                        a.value("Antalya Havalimanı -> Kaş Merkez"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.security(),
                    text(" Bakanlık / Emniyet Sistemine Bildir"),
                  ]),
                ],
              ),
            ]),
            el("div", "module-table-col", [
              el("h3", "", [text("Resmi Bildirim Kayıtları")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Sistem")]),
                    el("th", "", [text("Plaka")]),
                    el("th", "", [text("Sürücü")]),
                    el("th", "", [text("Yolcu")]),
                    el("th", "", [text("Güzergah")]),
                    el("th", "", [text("Durum")]),
                    el("th", "", [text("Sevk Kodu")]),
                  ]),
                ]),
                el("tbody", "", case transport_notifs {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [
                        text("Henüz resmi taşıma bildirimi iletilmedi."),
                      ]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [
                          _tid,
                          tsys,
                          tplate,
                          tdriver,
                          tguest,
                          _ttc,
                          tdest,
                          _tstat,
                          tcode,
                          _ttime,
                        ] ->
                          el("tr", "", [
                            el("td", "", [
                              el("span", "badge primary", [
                                text(string.uppercase(tsys)),
                              ]),
                            ]),
                            el("td", "", [el("strong", "", [text(tplate)])]),
                            el("td", "", [text(tdriver)]),
                            el("td", "", [text(tguest)]),
                            el("td", "muted", [text(tdest)]),
                            el("td", "", [
                              el("span", "badge success", [
                                text("Resmi İletildi"),
                              ]),
                            ]),
                            el("td", "", [el("code", "", [text(tcode)])]),
                          ])
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // 11. Misafir Konsiyerj & Mobil İstekler
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.chat(),
              text(
                "Misafir Konsiyerj & Mobil İstekler (Dijital Misafir Portalı)",
              ),
            ]),
            el("span", "badge primary", [text("Mobil Misafir Portalı")]),
          ]),
          el("div", "module-grid", [
            el("div", "module-form-col", [
              el("h3", "", [text("Misafir Konsiyerj Talebi Oluştur")]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute(
                    "action",
                    "/admin/listings/" <> prop_id <> "/modules/concierge",
                  ),
                ],
                [
                  hidden("csrf", csrf),
                  el("div", "form-group", [
                    el("label", "", [text("Oda Kodu")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("room_code"),
                        a.value("302"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Misafir Adı")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("guest_name"),
                        a.value("Ayşe Demir"),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Talep Türü")]),
                    element.element("select", [a.name("request_type")], [
                      element.element("option", [a.value("housekeeping")], [
                        text("Kat Hizmetleri (Havlu / Temizlik)"),
                      ]),
                      element.element("option", [a.value("room_service")], [
                        text("Oda Servisi (Yiyecek / İçecek)"),
                      ]),
                      element.element("option", [a.value("reception")], [
                        text("Resepsiyon / Danışma"),
                      ]),
                      element.element("option", [a.value("concierge")], [
                        text("Konsiyerj (Taksi / Tur Talebi)"),
                      ]),
                    ]),
                  ]),
                  el("div", "form-group", [
                    el("label", "", [text("Talep Detayı")]),
                    element.element(
                      "input",
                      [
                        a.type_("text"),
                        a.name("details"),
                        a.value(
                          "2 adet ekstra banyo havlusu ve su rica edildi.",
                        ),
                        a.required(True),
                      ],
                      [],
                    ),
                  ]),
                  element.element("button", [a.class("button primary small")], [
                    icons.chat(),
                    text("Talebi İlet"),
                  ]),
                ],
              ),
            ]),
            el("div", "module-table-col", [
              el("h3", "", [text("Aktif Misafir Talepleri")]),
              el("table", "table", [
                el("thead", "", [
                  el("tr", "", [
                    el("th", "", [text("Oda")]),
                    el("th", "", [text("Misafir")]),
                    el("th", "", [text("Tür")]),
                    el("th", "", [text("Talep Detayı")]),
                    el("th", "", [text("Durum")]),
                    el("th", "", [text("İşlem")]),
                  ]),
                ]),
                el("tbody", "", case concierge_requests {
                  [] -> [
                    el("tr", "", [
                      el("td", "empty-cell", [
                        text("Bekleyen misafir talebi bulunmuyor."),
                      ]),
                    ]),
                  ]
                  rows ->
                    list.map(rows, fn(r) {
                      case r {
                        [
                          gid,
                          groom,
                          gguest,
                          greq_type,
                          gdet,
                          gstat,
                          _gtime,
                          _gcomp,
                        ] ->
                          el("tr", "", [
                            el("td", "", [el("strong", "", [text(groom)])]),
                            el("td", "", [text(gguest)]),
                            el("td", "", [
                              el("span", "badge info", [text(greq_type)]),
                            ]),
                            el("td", "", [text(gdet)]),
                            el("td", "", [
                              el(
                                "span",
                                "badge "
                                  <> case gstat {
                                  "completed" -> "success"
                                  _ -> "warning"
                                },
                                [
                                  text(case gstat {
                                    "completed" -> "Tamamlandı"
                                    _ -> "İşlem Bekliyor"
                                  }),
                                ],
                              ),
                            ]),
                            el("td", "", [
                              case gstat {
                                "pending" ->
                                  element.element(
                                    "form",
                                    [
                                      a.attribute("method", "post"),
                                      a.attribute(
                                        "action",
                                        "/admin/listings/"
                                          <> prop_id
                                          <> "/modules/concierge/resolve",
                                      ),
                                    ],
                                    [
                                      hidden("csrf", csrf),
                                      hidden("request_id", gid),
                                      element.element(
                                        "button",
                                        [a.class("button small success")],
                                        [
                                          icons.check(),
                                          text(" Karşılandı"),
                                        ],
                                      ),
                                    ],
                                  )
                                _ ->
                                  el("span", "badge success", [
                                    text("Tamamlandı"),
                                  ])
                              },
                            ]),
                          ])
                        _ -> text("")
                      }
                    })
                }),
              ]),
            ]),
          ]),
        ]),

        // ELİTE 1: Görsel Canlı Oda Planı (Room Rack & Tape Chart)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.hotel(),
              text("Görsel Canlı Oda Planı & Blokaj Tahtası (Room Rack)"),
            ]),
            el("span", "badge primary", [text("Opera Cloud & Mews Standardı")]),
          ]),
          el("p", "section-desc", [
            text(
              "Tüm odaların canlı doluluk, temizlik ve konaklama durumunu renk kodlu matrisle izleyin. Doğrudan oda üzerinden hızlı giriş (check-in), çıkış (check-out) ve temizlik onayını yönetin.",
            ),
          ]),
          el("div", "form-drawer", [
            el("h3", "section-title-with-icon", [
              icons.key(),
              text("Hızlı Giriş (Quick Check-In)"),
            ]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute(
                  "action",
                  "/admin/listings/" <> prop_id <> "/modules/rack/check-in",
                ),
                a.class("inline-form-grid"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-group", [
                  el("label", "", [text("Oda Kodu / No")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "room_code"),
                      a.attribute("placeholder", "Örn: 101"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Misafir Adı Soyadı")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "guest_name"),
                      a.attribute("placeholder", "Örn: Can Yılmaz"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Gece Sayısı")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("name", "nights"),
                      a.attribute("value", "1"),
                      a.attribute("min", "1"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Gecelik Fiyat (TL/Kuruş)")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("name", "rate_minor"),
                      a.attribute("value", nightly),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group action-cell", [
                  element.element("button", [a.class("button primary")], [
                    icons.check(),
                    text(" Odaya Giriş Yap (Check-In)"),
                  ]),
                ]),
              ],
            ),
          ]),
          el("div", "room-rack-grid", case room_rack {
            [] -> [
              el("div", "empty-cell", [
                text(
                  "Tanımlı oda bulunamadı. Lütfen PMS modülünden oda ekleyin.",
                ),
              ]),
            ]
            racks ->
              list.map(racks, fn(rk) {
                case rk {
                  [
                    _,
                    ucode,
                    uname,
                    utype,
                    occ,
                    hk,
                    guest,
                    rate_str,
                    checkin,
                    checkout,
                  ] -> {
                    let rate_num = int.parse(rate_str) |> result_unwrap(0)
                    let card_cls =
                      "room-rack-card "
                      <> case occ {
                        "occupied" -> "occupied"
                        "maintenance" -> "maintenance"
                        _ ->
                          case hk {
                            "dirty" -> "dirty"
                            _ -> "clean"
                          }
                      }
                    el("div", card_cls, [
                      el("div", "room-rack-header", [
                        el("span", "room-rack-code", [text(ucode)]),
                        el("span", "room-rack-type", [
                          text(utype <> " · " <> uname),
                        ]),
                      ]),
                      el("div", "room-rack-guest", [
                        case occ {
                          "occupied" ->
                            el("span", "badge danger", [
                              text("Dolu: " <> guest),
                            ])
                          "maintenance" ->
                            el("span", "badge warning", [
                              text("Bakımda / Arızalı"),
                            ])
                          _ ->
                            case hk {
                              "dirty" ->
                                el("span", "badge warning", [
                                  text("Temizlik Bekliyor"),
                                ])
                              _ ->
                                el("span", "badge success", [
                                  text("Müsait & Temiz"),
                                ])
                            }
                        },
                      ]),
                      el("div", "room-rack-meta", [
                        case occ {
                          "occupied" ->
                            text(
                              "Giriş: " <> checkin <> " | Çıkış: " <> checkout,
                            )
                          _ ->
                            text(
                              "Taban: "
                              <> domain.money(rate_num, cur)
                              <> " / Gece",
                            )
                        },
                      ]),
                      el("div", "room-rack-actions", [
                        case occ {
                          "occupied" ->
                            element.element(
                              "form",
                              [
                                a.attribute("method", "post"),
                                a.attribute(
                                  "action",
                                  "/admin/listings/"
                                    <> prop_id
                                    <> "/modules/rack/check-out",
                                ),
                              ],
                              [
                                hidden("csrf", csrf),
                                hidden("room_code", ucode),
                                element.element(
                                  "button",
                                  [a.class("button small secondary")],
                                  [
                                    icons.check(),
                                    text(" Hızlı Çıkış (Check-Out)"),
                                  ],
                                ),
                              ],
                            )
                          _ ->
                            case hk {
                              "dirty" ->
                                element.element(
                                  "form",
                                  [
                                    a.attribute("method", "post"),
                                    a.attribute(
                                      "action",
                                      "/admin/listings/"
                                        <> prop_id
                                        <> "/modules/rack/clean",
                                    ),
                                  ],
                                  [
                                    hidden("csrf", csrf),
                                    hidden("room_code", ucode),
                                    element.element(
                                      "button",
                                      [a.class("button small success")],
                                      [icons.check(), text(" Temizlik Onayla")],
                                    ),
                                  ],
                                )
                              _ ->
                                el("span", "badge success", [
                                  text("Rezervasyona Hazır"),
                                ])
                            }
                        },
                      ]),
                    ])
                  }
                  _ -> text("")
                }
              })
          }),
        ]),

        // ELİTE 2: Misafir Folyosu & Adisyon Masası (Room Folio & Billing)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.accounting(),
              text("Misafir Folyosu & Departman Adisyon Masası"),
            ]),
            el("span", "badge info", [
              text("Micros Opera & Toast POS Standardı"),
            ]),
          ]),
          el("p", "section-desc", [
            text(
              "Restoran POS, Bar, SPA, Minibar, Çamaşırhane veya Transfer harcamalarını misafirin oda hesabına aktarın. Çıkış anında folyo tek tıkla kapatılarak ön büro kasa defterine tahsil edilir.",
            ),
          ]),
          el("div", "form-drawer", [
            el("h3", "section-title-with-icon", [
              icons.plus(),
              text("Oda Hesabına Harcama / Adisyon Yaz"),
            ]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute(
                  "action",
                  "/admin/listings/" <> prop_id <> "/modules/folio/charge",
                ),
                a.class("inline-form-grid"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-group", [
                  el("label", "", [text("Oda Kodu / No")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "room_code"),
                      a.attribute("placeholder", "Örn: 101"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Departman")]),
                  element.element(
                    "select",
                    [
                      a.attribute("name", "department"),
                      a.attribute("required", "true"),
                    ],
                    [
                      element.element(
                        "option",
                        [a.attribute("value", "restaurant_pos")],
                        [text("Restoran POS")],
                      ),
                      element.element("option", [a.attribute("value", "bar")], [
                        text("Bar & Lounge"),
                      ]),
                      element.element(
                        "option",
                        [a.attribute("value", "spa_wellness")],
                        [text("SPA & Masaj")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "minibar")],
                        [text("Oda Minibar")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "laundry")],
                        [text("Çamaşırhane & Kuru Temizleme")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "transfer")],
                        [text("Havalimanı Transferi")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "other")],
                        [text("Diğer Ekstra")],
                      ),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Açıklama / Kalem")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "description"),
                      a.attribute(
                        "placeholder",
                        "Örn: Akşam Yemeği Adisyonu #402",
                      ),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Tutar (TL/Kuruş)")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("name", "amount_minor"),
                      a.attribute("placeholder", "Örn: 75000 (750 TL)"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group action-cell", [
                  element.element("button", [a.class("button primary")], [
                    icons.plus(),
                    text(" Odaya Yaz"),
                  ]),
                ]),
              ],
            ),
          ]),
          el("div", "form-drawer", [
            el("h3", "section-title-with-icon", [
              icons.accounting(),
              text("Folyoyu Kapat ve Kasa Defterine Aktar"),
            ]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute(
                  "action",
                  "/admin/listings/" <> prop_id <> "/modules/folio/settle",
                ),
                a.class("inline-form-grid"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-group", [
                  el("label", "", [text("Oda Kodu / No")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "room_code"),
                      a.attribute("placeholder", "Örn: 101"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Ödeme Türü")]),
                  element.element(
                    "select",
                    [
                      a.attribute("name", "payment_method"),
                      a.attribute("required", "true"),
                    ],
                    [
                      element.element(
                        "option",
                        [a.attribute("value", "credit_card")],
                        [text("Kredi Kartı")],
                      ),
                      element.element("option", [a.attribute("value", "cash")], [
                        text("Nakit Kasa"),
                      ]),
                      element.element(
                        "option",
                        [a.attribute("value", "bank_transfer")],
                        [text("Banka Havalesi")],
                      ),
                    ],
                  ),
                ]),
                el("div", "form-group action-cell", [
                  element.element("button", [a.class("button success")], [
                    icons.check(),
                    text(" Folyoyu Kapat ve Tahsil Et"),
                  ]),
                ]),
              ],
            ),
          ]),
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Oda")]),
                el("th", "", [text("Misafir")]),
                el("th", "", [text("Departman")]),
                el("th", "", [text("Açıklama")]),
                el("th", "", [text("Tutar")]),
                el("th", "", [text("Durum")]),
                el("th", "", [text("Tarih")]),
              ]),
            ]),
            el("tbody", "", case room_folios {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [
                    text("Kayıtlı folyo hareketi bulunamadı."),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [
                      _,
                      froom,
                      fguest,
                      fdept,
                      fdesc,
                      famt,
                      fcur,
                      fsettled,
                      fdate,
                    ] -> {
                      let amt_num = int.parse(famt) |> result_unwrap(0)
                      el("tr", "", [
                        el("td", "", [el("strong", "", [text(froom)])]),
                        el("td", "", [text(fguest)]),
                        el("td", "", [
                          el("span", "badge neutral", [text(fdept)]),
                        ]),
                        el("td", "", [text(fdesc)]),
                        el("td", "", [
                          el("strong", "", [text(domain.money(amt_num, fcur))]),
                        ]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case fsettled {
                              "true" -> "success"
                              _ -> "warning"
                            },
                            [
                              text(case fsettled {
                                "true" -> "Tahsil Edildi"
                                _ -> "Açık / Ödenmedi"
                              }),
                            ],
                          ),
                        ]),
                        el("td", "muted", [text(fdate)]),
                      ])
                    }
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),

        // ELİTE 3: Gün Sonu Devir (Night Audit Engine)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.clock(),
              text("Otomatik Gün Sonu Devir (Night Audit & Manager Flash)"),
            ]),
            el("span", "badge dark", [text("Uluslararası Otelcilik Standardı")]),
          ]),
          el("p", "section-desc", [
            text(
              "Günlük konaklama gelirlerini kilitleyin, oda ücretlerini folyolara yansıtın ve ADR (Ortalama Günlük Fiyat), RevPAR (Oda Başı Gelir) ve doluluk oranlarını hesaplayan resmi yönetici raporunu oluşturun.",
            ),
          ]),
          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute(
                "action",
                "/admin/listings/" <> prop_id <> "/modules/audit/run",
              ),
              a.attribute("style", "margin-bottom: 16px"),
            ],
            [
              hidden("csrf", csrf),
              element.element("button", [a.class("button dark")], [
                icons.clock(),
                text(" Otomatik Gün Sonu Devir (Night Audit) Çalıştır"),
              ]),
            ],
          ),
          case night_audits {
            [[_, adate, tot_r, occ_r, occ_p, r_rev, p_rev, adr, revpar, _], ..] -> {
              let r_rev_num = int.parse(r_rev) |> result_unwrap(0)
              let p_rev_num = int.parse(p_rev) |> result_unwrap(0)
              let adr_num = int.parse(adr) |> result_unwrap(0)
              let revpar_num = int.parse(revpar) |> result_unwrap(0)
              el("div", "audit-highlight-box", [
                el("div", "", [
                  el("div", "audit-metric-title", [text("Kapanış Tarihi")]),
                  el("div", "audit-metric-val", [text(adate)]),
                ]),
                el("div", "", [
                  el("div", "audit-metric-title", [text("Doluluk Oranı")]),
                  el("div", "audit-metric-val", [
                    text("%" <> occ_p <> " (" <> occ_r <> "/" <> tot_r <> ")"),
                  ]),
                ]),
                el("div", "", [
                  el("div", "audit-metric-title", [text("ADR (Ortalama Fiyat)")]),
                  el("div", "audit-metric-val", [
                    text(domain.money(adr_num, cur)),
                  ]),
                ]),
                el("div", "", [
                  el("div", "audit-metric-title", [
                    text("RevPAR (Oda Başı Gelir)"),
                  ]),
                  el("div", "audit-metric-val", [
                    text(domain.money(revpar_num, cur)),
                  ]),
                ]),
                el("div", "", [
                  el("div", "audit-metric-title", [text("Günlük Toplam Ciro")]),
                  el("div", "audit-metric-val", [
                    text(domain.money(r_rev_num + p_rev_num, cur)),
                  ]),
                ]),
              ])
            }
            _ -> text("")
          },
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Tarih")]),
                el("th", "", [text("Toplam Oda")]),
                el("th", "", [text("Dolu Oda")]),
                el("th", "", [text("Doluluk %")]),
                el("th", "", [text("Oda Geliri")]),
                el("th", "", [text("POS Geliri")]),
                el("th", "", [text("ADR")]),
                el("th", "", [text("RevPAR")]),
                el("th", "", [text("Kapanış Saati")]),
              ]),
            ]),
            el("tbody", "", case night_audits {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [
                    text(
                      "Henüz gün sonu devir kaydı bulunmuyor. Yukarıdaki butona tıklayarak ilk devri başlatabilirsiniz.",
                    ),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [_, adt, tr, oroom, opct, rr, pr, a_adr, a_revpar, adone] -> {
                      let rr_num = int.parse(rr) |> result_unwrap(0)
                      let pr_num = int.parse(pr) |> result_unwrap(0)
                      let a_adr_num = int.parse(a_adr) |> result_unwrap(0)
                      let a_revpar_num = int.parse(a_revpar) |> result_unwrap(0)
                      el("tr", "", [
                        el("td", "", [el("strong", "", [text(adt)])]),
                        el("td", "", [text(tr)]),
                        el("td", "", [text(oroom)]),
                        el("td", "", [
                          el("span", "badge info", [text("%" <> opct)]),
                        ]),
                        el("td", "", [text(domain.money(rr_num, cur))]),
                        el("td", "", [text(domain.money(pr_num, cur))]),
                        el("td", "", [text(domain.money(a_adr_num, cur))]),
                        el("td", "", [text(domain.money(a_revpar_num, cur))]),
                        el("td", "muted", [text(adone)]),
                      ])
                    }
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),

        // ELİTE 4: Otopilot Gelir Yönetimi & Promosyon Motoru (Yield Autopilot & Promo Engine)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.trending_up(),
              text("Otopilot Gelir Yönetimi & Promosyon Motoru"),
            ]),
            el("span", "badge success", [
              text("Gelişmiş gelir yönetimi standardı"),
            ]),
          ]),
          el("p", "section-desc", [
            text(
              "Doluluk ve son dakika kurallarına göre dinamik fiyat optimizasyonu çalıştırın ve doğrudan rezervasyonlarda geçerli promosyon kuponları oluşturun.",
            ),
          ]),
          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute(
                "action",
                "/admin/listings/" <> prop_id <> "/modules/yield/evaluate",
              ),
              a.attribute("style", "margin-bottom: 16px"),
            ],
            [
              hidden("csrf", csrf),
              element.element("button", [a.class("button secondary")], [
                icons.sparkles(),
                text("Otopilot Fiyat Simülasyonu Çalıştır"),
              ]),
            ],
          ),
          el("div", "form-drawer", [
            el("h3", "section-title-with-icon", [
              icons.plus(),
              text("Yeni Otopilot Gelir Kuralı Tanımla"),
            ]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute(
                  "action",
                  "/admin/listings/" <> prop_id <> "/modules/yield/rule",
                ),
                a.class("inline-form-grid"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-group", [
                  el("label", "", [text("Kural Türü")]),
                  element.element(
                    "select",
                    [
                      a.attribute("name", "rule_type"),
                      a.attribute("required", "true"),
                    ],
                    [
                      element.element(
                        "option",
                        [a.attribute("value", "high_occupancy_surge")],
                        [text("Yüksek Doluluk Fiyat Zammı")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "last_minute_discount")],
                        [text("Son Dakika İndirimi")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "weekend_multiplier")],
                        [text("Hafta Sonu Dinamik Çarpan")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "early_bird_discount")],
                        [text("Erken Rezervasyon İndirimi")],
                      ),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Eşik Değeri (Doluluk % veya Gün)")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("step", "0.01"),
                      a.attribute("name", "threshold_val"),
                      a.attribute("value", "75"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Fiyat Değişim Yüzdesi (+/- % )")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("step", "0.01"),
                      a.attribute("name", "adjustment_pct"),
                      a.attribute("value", "15"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group action-cell", [
                  element.element("button", [a.class("button primary")], [
                    icons.save(),
                    text(" Kuralı Kaydet"),
                  ]),
                ]),
              ],
            ),
          ]),
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Kural Adı")]),
                el("th", "", [text("Tür")]),
                el("th", "", [text("Eşik Değeri")]),
                el("th", "", [text("Fiyat Değişimi")]),
                el("th", "", [text("Durum")]),
                el("th", "", [text("İşlem")]),
              ]),
            ]),
            el("tbody", "", case yield_rules {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [
                    text("Tanımlı otopilot kuralı bulunamadı."),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [yid, yname, ytype, ythresh, yadj, yact, _] ->
                      el("tr", "", [
                        el("td", "", [el("strong", "", [text(yname)])]),
                        el("td", "", [text(ytype)]),
                        el("td", "", [text(ythresh)]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case string.starts_with(yadj, "-") {
                              True -> "warning"
                              False -> "success"
                            },
                            [text("%" <> yadj)],
                          ),
                        ]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case yact {
                              "true" -> "success"
                              _ -> "dark"
                            },
                            [
                              text(case yact {
                                "true" -> "Aktif"
                                _ -> "Durduruldu"
                              }),
                            ],
                          ),
                        ]),
                        el("td", "", [
                          element.element(
                            "form",
                            [
                              a.attribute("method", "post"),
                              a.attribute(
                                "action",
                                "/admin/listings/"
                                  <> prop_id
                                  <> "/modules/yield/toggle",
                              ),
                            ],
                            [
                              hidden("csrf", csrf),
                              hidden("rule_id", yid),
                              element.element(
                                "button",
                                [a.class("button small secondary")],
                                [
                                  text(case yact {
                                    "true" -> "Durdur"
                                    _ -> "Aktifleştir"
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ]),
                      ])
                    _ -> text("")
                  }
                })
            }),
          ]),
          el("div", "form-drawer", [
            el("h3", "section-title-with-icon", [
              icons.tag(),
              text("Yeni Promosyon / İndirim Kuponu Oluştur"),
            ]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute(
                  "action",
                  "/admin/listings/" <> prop_id <> "/modules/promo/add",
                ),
                a.class("inline-form-grid"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-group", [
                  el("label", "", [text("Kupon Kodu")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "promo_code"),
                      a.attribute("placeholder", "Örn: YAZ2026"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("İndirim Tipi")]),
                  element.element(
                    "select",
                    [
                      a.attribute("name", "discount_type"),
                      a.attribute("required", "true"),
                    ],
                    [
                      element.element(
                        "option",
                        [a.attribute("value", "percentage")],
                        [text("Yüzdelik İndirim (%)")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "fixed_minor")],
                        [text("Sabit İndirim (TL/Kuruş)")],
                      ),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("İndirim Değeri")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("name", "discount_val"),
                      a.attribute("value", "15"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Maksimum Kullanım")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "number"),
                      a.attribute("name", "max_uses"),
                      a.attribute("value", "100"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group action-cell", [
                  element.element("button", [a.class("button primary")], [
                    icons.save(),
                    text(" Kuponu Kaydet"),
                  ]),
                ]),
              ],
            ),
          ]),
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Kupon Kodu")]),
                el("th", "", [text("İndirim Tipi")]),
                el("th", "", [text("İndirim")]),
                el("th", "", [text("Kullanım")]),
                el("th", "", [text("Durum")]),
                el("th", "", [text("Geçerlilik")]),
              ]),
            ]),
            el("tbody", "", case promo_codes {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [
                    text("Aktif promosyon kodu bulunamadı."),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [_, pcode, ptype, pval, pmax, puse, pact, pvalid] ->
                      el("tr", "", [
                        el("td", "", [
                          el("span", "badge primary", [text(pcode)]),
                        ]),
                        el("td", "", [text(ptype)]),
                        el("td", "", [
                          el("strong", "", [
                            text(case ptype {
                              "percentage" -> "%" <> pval
                              _ -> pval <> " Kuruş"
                            }),
                          ]),
                        ]),
                        el("td", "", [text(puse <> " / " <> pmax)]),
                        el("td", "", [
                          el(
                            "span",
                            "badge "
                              <> case pact {
                              "true" -> "success"
                              _ -> "dark"
                            },
                            [
                              text(case pact {
                                "true" -> "Aktif"
                                _ -> "Pasif"
                              }),
                            ],
                          ),
                        ]),
                        el("td", "muted", [text(pvalid)]),
                      ])
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),

        // ELİTE 5: Çok Kanallı Otomatik Misafir Mesajlaşma (Automated Guest Communication)
        el("div", "cockpit-section-card", [
          el("div", "section-header", [
            el("h2", "section-title-with-icon", [
              icons.chat(),
              text("Çok Kanallı Otomatik Misafir Mesajlaşma"),
            ]),
            el("span", "badge primary", [
              text("Otomatik Misafir Karşılama Standardı"),
            ]),
          ]),
          el("p", "section-desc", [
            text(
              "Rezervasyon onayında karşılama, girişten 24 saat önce akıllı kapı şifresi ve konum rehberi, çıkış günü kılavuzu ve çıkış sonrası otomatik puanlama daveti gönderin.",
            ),
          ]),
          el("div", "form-drawer", [
            el("h3", "section-title-with-icon", [
              icons.whatsapp(),
              text("Akıllı Mesaj Gönder / Simüle Et"),
            ]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute(
                  "action",
                  "/admin/listings/" <> prop_id <> "/modules/messaging/dispatch",
                ),
                a.class("inline-form-grid"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-group", [
                  el("label", "", [text("Oda No")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "room_code"),
                      a.attribute("placeholder", "Örn: 101"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Misafir Adı")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "guest_name"),
                      a.attribute("placeholder", "Örn: Can Yılmaz"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Telefon / WhatsApp No")]),
                  element.element(
                    "input",
                    [
                      a.attribute("type", "text"),
                      a.attribute("name", "phone"),
                      a.attribute("value", "+90 555 123 4567"),
                      a.attribute("required", "true"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "", [text("Senaryo Tetikleyicisi")]),
                  element.element(
                    "select",
                    [
                      a.attribute("name", "trigger_type"),
                      a.attribute("required", "true"),
                    ],
                    [
                      element.element(
                        "option",
                        [a.attribute("value", "booking_confirmed")],
                        [text("Rezervasyon Onaylandı & Karşılama")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "pre_arrival_24h")],
                        [text("Girişe 24 Saat Kala (Kapı Şifresi & GPS)")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "in_stay_greeting")],
                        [text("Konaklama İlk Sabah Memnuniyet")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "checkout_instructions")],
                        [text("Çıkış Günü Yönergeleri")],
                      ),
                      element.element(
                        "option",
                        [a.attribute("value", "post_stay_review")],
                        [text("Çıkış Sonrası Yorum & Puanlama")],
                      ),
                    ],
                  ),
                ]),
                el("div", "form-group action-cell", [
                  element.element("button", [a.class("button primary")], [
                    icons.chat(),
                    text(" Mesajı Gönder"),
                  ]),
                ]),
              ],
            ),
          ]),
          el("table", "table", [
            el("thead", "", [
              el("tr", "", [
                el("th", "", [text("Kanal")]),
                el("th", "", [text("Oda")]),
                el("th", "", [text("Misafir")]),
                el("th", "", [text("İletişim")]),
                el("th", "", [text("Senaryo")]),
                el("th", "", [text("İleti İçeriği")]),
                el("th", "", [text("Durum")]),
                el("th", "", [text("Tarih")]),
              ]),
            ]),
            el("tbody", "", case auto_messages {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [
                    text("Kayıtlı mesajlaşma akışı bulunamadı."),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [
                      _,
                      mroom,
                      mguest,
                      mcontact,
                      mchan,
                      mtrig,
                      mbody,
                      mstat,
                      mdate,
                    ] ->
                      el("tr", "", [
                        el("td", "", [
                          el("span", "badge success", [
                            text(string.uppercase(mchan)),
                          ]),
                        ]),
                        el("td", "", [el("strong", "", [text(mroom)])]),
                        el("td", "", [text(mguest)]),
                        el("td", "", [text(mcontact)]),
                        el("td", "", [el("span", "badge info", [text(mtrig)])]),
                        el("td", "muted", [text(mbody)]),
                        el("td", "", [
                          el("span", "badge success", [text(mstat)]),
                        ]),
                        el("td", "muted", [text(mdate)]),
                      ])
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),
      ])
    }
    _ ->
      el("div", "container", [
        el("h1", "", [text("İlan Bilgisi Yüklenemedi")]),
        link("/admin/listings", "← İlanlara Dön", "button"),
      ])
  }
}

pub fn render_listing_cockpit(
  s: Session,
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
  let body =
    render_cockpit_body(
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
  shell(s, csrf, "İlan Modül Operasyonları", body)
}

fn kpi_card(title: String, value: String, variant: String) -> Element(Nil) {
  el("div", "cockpit-kpi-card " <> variant, [
    el("div", "kpi-title", [text(title)]),
    el("div", "kpi-val", [text(value)]),
  ])
}

fn result_unwrap(res: Result(a, b), default: a) -> a {
  case res {
    Ok(v) -> v
    Error(_) -> default
  }
}
