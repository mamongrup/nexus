import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

fn format_money(amount_str: String, cur: String) -> String {
  case int.parse(amount_str) {
    Ok(val) -> {
      let liras = val / 100
      let kurus = val % 100
      let kurus_str = case kurus < 10 {
        True -> "0" <> int.to_string(kurus)
        False -> int.to_string(kurus)
      }
      int.to_string(liras) <> "." <> kurus_str <> " " <> cur
    }
    Error(_) -> amount_str <> " " <> cur
  }
}

pub fn page(
  s: Session,
  csrf: String,
  summary: List(String),
  transactions: List(List(String)),
  message: String,
) -> String {
  let #(total_inc, total_exp, net_bal, cash_bal, bank_bal, tx_cnt) = case
    summary
  {
    [i, e, n, c, b, count, ..] -> #(i, e, n, c, b, count)
    _ -> #("0", "0", "0", "0", "0", "0")
  }

  view.shell(
    s,
    csrf,
    "Muhasebe & Kasa/Banka",
    el("div", "campaigns-container", [
      el("header", "page-header", [
        el("div", "", [
          el("span", "badge primary", [
            text(case s.role {
              "purchasing" -> "SATIN ALMA & MALZEME GİDER MASASI"
              _ -> "GELİR & GİDER TAKİP MERKEZİ"
            }),
          ]),
          el("h1", "", [
            icons.accounting(),
            text(case s.role {
              "purchasing" -> "Satın Alma, Malzeme & Fiş Girişi"
              _ -> "Ön Muhasebe, Kasa & Nakit Akışı"
            }),
          ]),
          el("p", "muted", [
            text(case s.role {
              "purchasing" ->
                "Satın aldığınız tüm ürünleri, sarf malzemelerini ve demirbaşları birim fiyatı, fiş numarası, toplam tutarı ve satıcı firma bilgisiyle anında muhasebe sistemine kaydedin."
              _ ->
                "Tüm oda gelirleri, POS tahsilatları, personel maaşları, enerji ve tedarik giderlerinizi tek ekrandan yönetin; net kârlılığınızı ve kasa bakiyelerinizi anlık izleyin."
            }),
          ]),
        ]),
        el("div", "header-actions", [
          element.element(
            "a",
            [a.href("/admin/finance"), a.class("button secondary")],
            [
              icons.accounting(),
              text("Finans & Hakediş"),
            ],
          ),
          element.element(
            "a",
            [a.href("/admin/hr"), a.class("button secondary")],
            [
              icons.user(),
              text("Personel & Bordro"),
            ],
          ),
        ]),
      ]),

      case message {
        "" -> text("")
        _ ->
          el("div", "notice notice-success", [
            el("span", "d-flex items-center gap-2", [
              icons.check(),
              text(message),
            ]),
          ])
      },

      // Canlı Finansal Özet KPI Kartları
      el("div", "stats-grid", [
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.trending_up()]),
          el("div", "", [
            el("span", "kpi-label", [text("Toplam Gelir")]),
            el("h2", "kpi-value text-green", [
              text(format_money(total_inc, "TRY")),
            ]),
            el("span", "kpi-sub", [text(tx_cnt <> " işlem kaydedildi")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-red", [icons.accounting()]),
          el("div", "", [
            el("span", "kpi-label", [text("Toplam Gider")]),
            el("h2", "kpi-value text-red", [
              text(format_money(total_exp, "TRY")),
            ]),
            el("span", "kpi-sub", [text("Tüm masraflar & alımlar")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-blue", [icons.dynamic_pricing()]),
          el("div", "", [
            el("span", "kpi-label", [text("Net Kâr / Bakiye")]),
            el("h2", "kpi-value", [text(format_money(net_bal, "TRY"))]),
            el("span", "kpi-sub", [text("Gelir - Gider farkı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.corporate()]),
          el("div", "", [
            el("span", "kpi-label", [text("Banka Hesapları")]),
            el("h2", "kpi-value", [text(format_money(bank_bal, "TRY"))]),
            el("span", "kpi-sub", [text("Mevduat bakiyesi")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-yellow", [icons.key()]),
          el("div", "", [
            el("span", "kpi-label", [text("Fiziki Kasa Bakiyesi")]),
            el("h2", "kpi-value", [text(format_money(cash_bal, "TRY"))]),
            el("span", "kpi-sub", [text("Nakit çekmecesi mevcudu")]),
          ]),
        ]),
      ]),

      // Yeni İşlem Ekleme Formu
      el("div", "panel-card", [
        el("h3", "section-title-with-icon", [
          icons.plus(),
          text(case s.role {
            "purchasing" -> "Yeni Satın Alma & Malzeme Fişi Girişi"
            _ -> "Yeni Gelir / Gider Fişi Ekle"
          }),
        ]),
        el("p", "muted", [
          text(case s.role {
            "purchasing" ->
              "Aldığınız ürün veya malzemenin adını, fiş numarasını, birim fiyatını ve tutarını girerek sisteme kaydedin."
            _ ->
              "Otel, villa veya tesisiniz için gelir ya da gider kaydı oluşturun."
          }),
        ]),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/accounting/transaction"),
            a.class("form modern-form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("İşlem Türü *")]),
                element.element(
                  "select",
                  [
                    a.name("tx_type"),
                    a.class("input-select"),
                    a.attribute("required", "required"),
                  ],
                  case s.role {
                    "purchasing" -> [
                      element.element("option", [a.value("expense")], [
                        text("Malzeme / Satın Alma Gideri (-)"),
                      ]),
                      element.element("option", [a.value("income")], [
                        text("Gelir (+)"),
                      ]),
                      element.element("option", [a.value("expense")], [
                        text("Gider (-)"),
                      ]),
                    ]
                    _ -> [
                      element.element("option", [a.value("income")], [
                        text("Gelir (+)"),
                      ]),
                      element.element("option", [a.value("expense")], [
                        text("Gider (-)"),
                      ]),
                    ]
                  },
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Kategori *")]),
                element.element(
                  "select",
                  [
                    a.name("category"),
                    a.class("input-select"),
                    a.attribute("required", "required"),
                  ],
                  [
                    element.element("option", [a.value("room_revenue")], [
                      text("Oda & Konaklama Geliri"),
                    ]),
                    element.element("option", [a.value("pos_fnb")], [
                      text("Restoran & Bar POS"),
                    ]),
                    element.element("option", [a.value("extra_services")], [
                      text("Ekstra Hizmetler & Minibar"),
                    ]),
                    element.element("option", [a.value("transfer_revenue")], [
                      text("VIP Transfer"),
                    ]),
                    element.element("option", [a.value("spa_wellness")], [
                      text("Spa & Wellness"),
                    ]),
                    element.element("option", [a.value("payroll")], [
                      text("Personel Maaş & Avans"),
                    ]),
                    element.element("option", [a.value("utilities")], [
                      text("Elektrik / Su / İnternet / Doğalgaz"),
                    ]),
                    element.element("option", [a.value("fnb_supply")], [
                      text("Yiyecek & İçecek Tedariki"),
                    ]),
                    element.element("option", [a.value("housekeeping_supply")], [
                      text("Temizlik Malzemeleri"),
                    ]),
                    element.element("option", [a.value("maintenance_repair")], [
                      text("Bakım & Onarım"),
                    ]),
                    element.element("option", [a.value("marketing_ads")], [
                      text("Pazarlama & Reklam"),
                    ]),
                    element.element("option", [a.value("tax_legal")], [
                      text("Vergi, SGK & Harç"),
                    ]),
                    element.element("option", [a.value("commission_ota")], [
                      text("Kanal / Acente Komisyonu"),
                    ]),
                    element.element("option", [a.value("other_expense")], [
                      text("Diğer Genel Giderler"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Ödeme Yöntemi *")]),
                element.element(
                  "select",
                  [a.name("payment_method"), a.class("input-select")],
                  [
                    element.element("option", [a.value("bank_transfer")], [
                      text("Banka Transferi / Havale-EFT"),
                    ]),
                    element.element("option", [a.value("cash")], [
                      text("Nakit Kasa"),
                    ]),
                    element.element("option", [a.value("credit_card")], [
                      text("Kredi Kartı / POS"),
                    ]),
                    element.element("option", [a.value("other")], [
                      text("Diğer"),
                    ]),
                  ],
                ),
              ]),
            ]),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("İşlem Başlığı *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("title"),
                    a.attribute(
                      "placeholder",
                      "Örn: Ağustos Ayı Elektrik Faturası / Oda 201 Konaklama",
                    ),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [
                  text("Tutar (Örn: 2500 veya 150.50) *"),
                ]),
                element.element(
                  "input",
                  [
                    a.type_("number"),
                    a.name("amount"),
                    a.attribute("step", "0.01"),
                    a.attribute("placeholder", "0.00"),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Para Birimi")]),
                element.element(
                  "select",
                  [a.name("currency"), a.class("input-select")],
                  [
                    element.element("option", [a.value("TRY")], [
                      text("TRY (₺)"),
                    ]),
                    element.element("option", [a.value("EUR")], [
                      text("EUR (€)"),
                    ]),
                    element.element("option", [a.value("USD")], [
                      text("USD ($)"),
                    ]),
                    element.element("option", [a.value("GBP")], [
                      text("GBP (£)"),
                    ]),
                  ],
                ),
              ]),
            ]),
            el("div", "form-row-2", [
              el("div", "form-group", [
                element.element("label", [], [text("Fatura / Fiş / Dekont No")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("invoice_no"),
                    a.attribute("placeholder", "Örn: GIB20260000123"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Açıklama & Detay")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("description"),
                    a.attribute("placeholder", "İşleme dair ek notlar"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
            ]),
            element.element(
              "button",
              [
                a.class("button primary"),
                a.attribute("type", "submit"),
              ],
              [icons.save(), text("Fişi Kaydet")],
            ),
          ],
        ),
      ]),

      // İşlem Listesi Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split", [
          el("div", "", [
            el("h3", "section-title-with-icon", [
              icons.document(),
              text("Son Gelir & Gider Hareketleri"),
            ]),
            el("p", "muted", [
              text("Kayıtlı son 50 finansal hareket listelenmektedir."),
            ]),
          ]),
          el("span", "badge dark", [text(tx_cnt <> " Kayıt")]),
        ]),

        case transactions {
          [] ->
            el("div", "empty-state-box", [
              el("p", "muted", [
                text("Henüz kayıtlı bir gelir ya da gider hareketi bulunmuyor."),
              ]),
            ])
          _ ->
            el("div", "table-responsive", [
              element.element("table", [a.class("table modern-table")], [
                element.element("thead", [], [
                  element.element("tr", [], [
                    element.element("th", [], [text("Tarih")]),
                    element.element("th", [], [text("Tür")]),
                    element.element("th", [], [text("Kategori")]),
                    element.element("th", [], [text("Başlık")]),
                    element.element("th", [], [text("Tutar")]),
                    element.element("th", [], [text("Ödeme Yolu")]),
                    element.element("th", [], [text("Fatura No")]),
                    element.element("th", [], [text("Kullanıcı")]),
                    element.element("th", [], [text("İşlem")]),
                  ]),
                ]),
                element.element(
                  "tbody",
                  [],
                  list.map(transactions, fn(row) {
                    case row {
                      [
                        id,
                        tx_type,
                        cat_name,
                        title,
                        amount,
                        cur,
                        pmethod,
                        inv,
                        tx_date,
                        user,
                        ..
                      ] -> {
                        let is_inc = tx_type == "income"
                        element.element("tr", [], [
                          element.element("td", [], [text(tx_date)]),
                          element.element("td", [], [
                            case is_inc {
                              True ->
                                el("span", "badge badge-success", [
                                  text("+ GELİR"),
                                ])
                              False ->
                                el("span", "badge badge-danger", [
                                  text("- GİDER"),
                                ])
                            },
                          ]),
                          element.element("td", [], [
                            el("span", "badge dark", [text(cat_name)]),
                          ]),
                          element.element("td", [a.class("font-medium")], [
                            text(title),
                          ]),
                          element.element(
                            "td",
                            [
                              a.class(case is_inc {
                                True -> "text-green font-bold"
                                False -> "text-red font-bold"
                              }),
                            ],
                            [
                              text(
                                case is_inc {
                                  True -> "+"
                                  False -> "-"
                                }
                                <> format_money(amount, cur),
                              ),
                            ],
                          ),
                          element.element("td", [], [
                            text(case pmethod {
                              "cash" -> "Nakit"
                              "bank_transfer" -> "Banka"
                              "credit_card" -> "Kredi Kartı"
                              _ -> "Diğer"
                            }),
                          ]),
                          element.element("td", [a.class("muted")], [
                            text(case inv {
                              "" -> "-"
                              _ -> inv
                            }),
                          ]),
                          element.element("td", [a.class("muted")], [text(user)]),
                          element.element("td", [], [
                            element.element(
                              "form",
                              [
                                a.attribute("method", "post"),
                                a.attribute(
                                  "action",
                                  "/admin/accounting/" <> id <> "/delete",
                                ),
                                a.attribute(
                                  "onsubmit",
                                  "return confirm('Bu işlemi silmek istediğinize emin misiniz?');",
                                ),
                              ],
                              [
                                hidden("csrf", csrf),
                                element.element(
                                  "button",
                                  [
                                    a.class("button quiet-danger-btn"),
                                    a.attribute("type", "submit"),
                                  ],
                                  [icons.trash(), text(" Sil")],
                                ),
                              ],
                            ),
                          ]),
                        ])
                      }
                      _ -> text("")
                    }
                  }),
                ),
              ]),
            ])
        },
      ]),
    ]),
  )
}
