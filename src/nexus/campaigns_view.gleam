import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Property, type Session}
import nexus/icons
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  properties: List(Property),
  campaigns: List(List(String)),
  message: String,
) -> String {
  let total_count = list.length(campaigns)
  let active_count =
    list.filter(campaigns, fn(c) {
      case c {
        [_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, is_active, ..] ->
          is_active == "true"
        _ -> False
      }
    })
    |> list.length

  let total_uses =
    list.fold(campaigns, 0, fn(acc, c) {
      case c {
        [_, _, _, _, _, _, _, _, _, _, _, _, _, _, used, ..] ->
          acc + { int.parse(used) |> result_unwrap(0) }
        _ -> acc
      }
    })

  view.shell(
    s,
    csrf,
    "İndirimler & Kampanyalar",
    el("div", "campaigns-container", [
      el("header", "page-header", [
        el("div", "", [
          el("span", "badge primary", [text("GELİR & DOLULUK MOTORU")]),
          el("h1", "section-title-with-icon", [
            icons.categories(),
            text("İndirimler & Kampanya Yönetim Merkezi"),
          ]),
          el("p", "muted", [
            text(
              "Erken rezervasyon, son dakika, uzun konaklama ve promosyon kuponları oluşturun. İlanlarınızda parlayan rozetler ve dinamik indirimli fiyatlarla doğrudan rezervasyonlarınızı artırın.",
            ),
          ]),
        ]),
        el("div", "header-actions", [
          element.element(
            "a",
            [a.href("/admin/calendar"), a.class("button secondary")],
            [icons.calendar(), text("Takvim & Fiyatlar")],
          ),
          element.element(
            "a",
            [a.href("/admin/pricing"), a.class("button secondary")],
            [icons.dynamic_pricing(), text("Fiyat Kuralları")],
          ),
        ]),
      ]),
      case message {
        "" -> text("")
        _ ->
          el("div", "panel notice", [
            el("strong", "", [text("Bildirim: ")]),
            text(message),
          ])
      },
      // 1. KPI İstatistik Kartları
      el("div", "stats-grid-4", [
        el("div", "stat-card-modern", [
          el("div", "kpi-icon-wrap bg-primary", [icons.categories()]),
          el("div", "", [
            el("span", "stat-label", [text("Toplam Kampanya")]),
            el("h3", "stat-val", [text(int.to_string(total_count))]),
          ]),
        ]),
        el("div", "stat-card-modern", [
          el("div", "kpi-icon-wrap bg-emerald", [icons.sparkles()]),
          el("div", "", [
            el("span", "stat-label", [text("Aktif Kampanyalar")]),
            el("h3", "stat-val text-success", [
              text(int.to_string(active_count)),
            ]),
          ]),
        ]),
        el("div", "stat-card-modern", [
          el("div", "kpi-icon-wrap bg-teal", [icons.tag()]),
          el("div", "", [
            el("span", "stat-label", [text("Kampanyalı Rezervasyonlar")]),
            el("h3", "stat-val text-primary", [
              text(int.to_string(total_uses)),
            ]),
          ]),
        ]),
        el("div", "stat-card-modern", [
          el("div", "kpi-icon-wrap bg-amber", [icons.trending_up()]),
          el("div", "", [
            el("span", "stat-label", [text("Doluluk Artış Desteği")]),
            el("h3", "stat-val text-warning", [text("Otopilot Aktif")]),
          ]),
        ]),
      ]),
      // 2. 1-Tıkla Hazır Şablonlar
      el("div", "panel presets-panel", [
        el("div", "presets-header", [
          el("h3", "section-title-with-icon", [
            icons.sparkles(),
            text("Popüler Kampanya Şablonları (1-Tıkla Doldur)"),
          ]),
          el("p", "muted small", [
            text(
              "Tüm satış ve doğrudan rezervasyon kanallarında en çok dönüşüm getiren kampanya modellerini formunuza anında yükleyin.",
            ),
          ]),
        ]),
        el("div", "presets-button-grid", [
          element.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("button preset-btn"),
              a.attribute("data-preset", "early_bird"),
              a.attribute(
                "onclick",
                "applyPreset('2026 Yaz Erken Rezervasyon Fırsatı', 'early_bird', 'percentage', '15', '30', '3', '%15 Erken Rezervasyon', '')",
              ),
            ],
            [
              el("span", "preset-icon", [icons.beach()]),
              el("strong", "", [text("Erken Rezervasyon")]),
              el("small", "", [text("%15 İndirim (30+ Gün Öncesi)")]),
            ],
          ),
          element.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("button preset-btn"),
              a.attribute("data-preset", "last_minute"),
              a.attribute(
                "onclick",
                "applyPreset('Son Dakika Kaçamak Fırsatı', 'last_minute', 'percentage', '20', '3', '1', '%20 Son Dakika Fırsatı', '')",
              ),
            ],
            [
              el("span", "preset-icon", [icons.trending_up()]),
              el("strong", "", [text("Son Dakika Fırsatı")]),
              el("small", "", [text("%20 İndirim (Son 3 Gün Kala)")]),
            ],
          ),
          element.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("button preset-btn"),
              a.attribute("data-preset", "long_stay"),
              a.attribute(
                "onclick",
                "applyPreset('Haftalık Uzun Konaklama İndirimi', 'long_stay', 'percentage', '10', '0', '7', '7 Geceye %10 İndirim', '')",
              ),
            ],
            [
              el("span", "preset-icon", [icons.villa()]),
              el("strong", "", [text("Uzun Konaklama")]),
              el("small", "", [text("7+ Geceye %10 İndirim")]),
            ],
          ),
          element.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("button preset-btn"),
              a.attribute("data-preset", "promo_code"),
              a.attribute(
                "onclick",
                "applyPreset('Yaz Sezonu Özel Kupon Kampanyası', 'promo_code', 'percentage', '20', '0', '1', 'YAZ2026 ile %20 İndirim', 'YAZ2026')",
              ),
            ],
            [
              el("span", "preset-icon", [icons.tag()]),
              el("strong", "", [text("Promosyon Kuponu")]),
              el("small", "", [text("YAZ2026 Kodu ile %20")]),
            ],
          ),
        ]),
      ]),
      // 3. Yeni Kampanya Oluşturma Formu
      el("div", "panel form-card", [
        el("div", "panel-header", [
          el("h2", "section-title-with-icon", [
            icons.plus(),
            text("Yeni İndirim / Kampanya Tanımla"),
          ]),
          el("p", "muted", [
            text(
              "Tüm ilanlarınızda veya belirli bir tesiste geçerli kampanya kuralları belirleyin.",
            ),
          ]),
        ]),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/campaigns"),
            a.attribute("id", "campaign_form"),
            a.class("form grid-form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-2", [
              el("label", "field", [
                el("span", "", [text("Kampanya Adı *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("name"),
                    a.attribute("id", "camp_name"),
                    a.placeholder("Örn: 2026 Yaz Erken Rezervasyon Fırsatı"),
                    a.required(True),
                  ],
                  [],
                ),
              ]),
              el("label", "field", [
                el("span", "", [text("Kampanya Türü *")]),
                element.element(
                  "select",
                  [
                    a.name("campaign_type"),
                    a.attribute("id", "camp_type"),
                    a.required(True),
                  ],
                  [
                    element.element("option", [a.value("early_bird")], [
                      text("Erken Rezervasyon İndirimi (Early Bird)"),
                    ]),
                    element.element("option", [a.value("last_minute")], [
                      text("Son Dakika Fırsatı (Last Minute)"),
                    ]),
                    element.element("option", [a.value("long_stay")], [
                      text("Uzun Konaklama İndirimi (Long Stay)"),
                    ]),
                    element.element("option", [a.value("promo_code")], [
                      text("Promosyon Kupon Kodu (Promo Code)"),
                    ]),
                    element.element("option", [a.value("flash_sale")], [
                      text("Flaş / Sezonluk İndirim (Flash Sale)"),
                    ]),
                    element.element("option", [a.value("weekend_special")], [
                      text("Hafta Sonu Kaçamağı (Weekend Special)"),
                    ]),
                  ],
                ),
              ]),
            ]),
            el("div", "form-row-3", [
              el("label", "field", [
                el("span", "", [text("İndirim Tipi *")]),
                element.element(
                  "select",
                  [
                    a.name("discount_type"),
                    a.attribute("id", "camp_discount_type"),
                  ],
                  [
                    element.element("option", [a.value("percentage")], [
                      text("Yüzde İndirimi (%)"),
                    ]),
                    element.element("option", [a.value("fixed_minor")], [
                      text("Sabit Tutar İndirimi (TL)"),
                    ]),
                  ],
                ),
              ]),
              el("label", "field", [
                el("span", "", [text("İndirim Değeri (Yüzde veya TL) *")]),
                element.element(
                  "input",
                  [
                    a.type_("number"),
                    a.name("discount_val"),
                    a.attribute("id", "camp_discount_val"),
                    a.value("15"),
                    a.attribute("min", "1"),
                    a.required(True),
                  ],
                  [],
                ),
              ]),
              el("label", "field", [
                el("span", "", [text("Uygulanacak İlan")]),
                element.element(
                  "select",
                  [a.name("property_id"), a.attribute("id", "camp_prop_id")],
                  [
                    element.element("option", [a.value("")], [
                      text("Tüm İlanlarımda Geçerli"),
                    ]),
                    ..list.map(properties, fn(p) {
                      element.element("option", [a.value(p.id)], [
                        text(p.title <> " (" <> p.locality <> ")"),
                      ])
                    })
                  ],
                ),
              ]),
            ]),
            el("div", "form-row-2", [
              el("label", "field", [
                el("span", "", [text("Vitrin Rozeti (İlan Üzerinde Görünür)")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("badge_text"),
                    a.attribute("id", "camp_badge"),
                    a.value("%15 Erken Rezervasyon"),
                    a.placeholder("Örn: %20 Erken Rezervasyon, Son Dakika"),
                  ],
                  [],
                ),
              ]),
              el("label", "field", [
                el("span", "", [
                  text("Promosyon / Kupon Kodu (Yalnızca Kupon Türü İçin)"),
                ]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("promo_code"),
                    a.attribute("id", "camp_code"),
                    a.placeholder("Örn: YAZ2026, VIPGUEST"),
                    a.attribute("style", "text-transform: uppercase;"),
                  ],
                  [],
                ),
              ]),
            ]),
            el("div", "form-row-4", [
              el("label", "field", [
                el("span", "", [text("Min. Konaklama / Gece")]),
                element.element(
                  "input",
                  [
                    a.type_("number"),
                    a.name("min_stay_nights"),
                    a.attribute("id", "camp_min_stay"),
                    a.value("1"),
                    a.attribute("min", "1"),
                  ],
                  [],
                ),
              ]),
              el("label", "field", [
                el("span", "", [text("Gün Koşulu (Önce / Kala)")]),
                element.element(
                  "input",
                  [
                    a.type_("number"),
                    a.name("days_in_advance"),
                    a.attribute("id", "camp_days_adv"),
                    a.value("0"),
                    a.attribute("min", "0"),
                  ],
                  [],
                ),
              ]),
              el("label", "field", [
                el("span", "", [text("Başlangıç Tarihi")]),
                element.element(
                  "input",
                  [
                    a.type_("date"),
                    a.name("start_date"),
                    a.attribute("id", "camp_start"),
                  ],
                  [],
                ),
              ]),
              el("label", "field", [
                el("span", "", [text("Bitiş Tarihi")]),
                element.element(
                  "input",
                  [
                    a.type_("date"),
                    a.name("end_date"),
                    a.attribute("id", "camp_end"),
                  ],
                  [],
                ),
              ]),
            ]),
            el("div", "form-actions", [
              element.element(
                "button",
                [a.type_("submit"), a.class("button primary large")],
                [
                  icons.save(),
                  text("Kampanyayı Yayına Al & Aktifleştir"),
                ],
              ),
            ]),
          ],
        ),
      ]),
      // 4. Mevcut Kampanyalar Tablosu
      el("div", "panel table-card", [
        el("div", "panel-header", [
          el("h2", "section-title-with-icon", [
            icons.document(),
            text("Mevcut İndirim ve Kampanyalar"),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_count) <> " Kampanya"),
          ]),
        ]),
        el("div", "table-wrapper", [
          element.element("table", [a.class("data-table campaigns-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                el("th", "", [text("Kampanya & Rozet")]),
                el("th", "", [text("Tür")]),
                el("th", "", [text("Kapsam")]),
                el("th", "", [text("İndirim")]),
                el("th", "", [text("Kupon Kodu")]),
                el("th", "", [text("Geçerlilik")]),
                el("th", "", [text("Kullanım")]),
                el("th", "", [text("Durum")]),
                el("th", "", [text("İşlemler")]),
              ]),
            ]),
            element.element("tbody", [], case campaigns {
              [] -> [
                element.element("tr", [], [
                  element.element("td", [a.attribute("colspan", "9")], [
                    el("div", "empty-state-card", [
                      el("div", "kpi-icon-wrap bg-primary mb-3", [icons.tag()]),
                      el("h3", "", [text("Henüz kampanya oluşturulmadı.")]),
                      el("p", "muted", [
                        text(
                          "Yukarıdaki hazır şablonları kullanarak tek tıkla ilk kampanyanızı oluşturabilirsiniz.",
                        ),
                      ]),
                    ]),
                  ]),
                ]),
              ]
              rows ->
                list.map(rows, fn(r) {
                  case r {
                    [
                      id,
                      name,
                      ctype,
                      dtype,
                      dval,
                      _prop_id,
                      prop_title,
                      _cat,
                      code,
                      min_stay,
                      days_adv,
                      start_d,
                      end_d,
                      limit,
                      used,
                      is_active,
                      badge,
                    ] -> {
                      let active_bool = is_active == "true"
                      let dval_int = int.parse(dval) |> result_unwrap(0)
                      let discount_display = case dtype {
                        "percentage" -> "%" <> dval <> " İndirim"
                        _ ->
                          int.to_string(dval_int / 100) <> " TL Sabit İndirim"
                      }
                      let type_label = case ctype {
                        "early_bird" -> "Erken Rezervasyon"
                        "last_minute" -> "Son Dakika"
                        "long_stay" -> "Uzun Konaklama"
                        "promo_code" -> "Promosyon Kuponu"
                        "flash_sale" -> "Flaş İndirim"
                        "weekend_special" -> "Hafta Sonu"
                        _ -> ctype
                      }
                      element.element("tr", [a.class("campaign-row")], [
                        el("td", "", [
                          el("div", "camp-title-wrap", [
                            el("strong", "", [text(name)]),
                            el("span", "badge camp-pill-badge", [text(badge)]),
                          ]),
                        ]),
                        el("td", "", [
                          el("span", "type-pill", [text(type_label)]),
                        ]),
                        el("td", "", [
                          el("span", "scope-pill", [text(prop_title)]),
                        ]),
                        el("td", "", [
                          el("strong", "text-success", [text(discount_display)]),
                        ]),
                        el("td", "", [
                          case code {
                            "" -> el("span", "muted", [text("—")])
                            _ ->
                              el("span", "promo-code-badge", [
                                el("strong", "", [text(code)]),
                              ])
                          },
                        ]),
                        el("td", "", [
                          el("small", "muted", [
                            text(start_d <> " - " <> end_d),
                            case min_stay {
                              "1" -> text("")
                              _ ->
                                el("div", "", [
                                  text("Min: " <> min_stay <> " gece"),
                                ])
                            },
                            case days_adv {
                              "0" -> text("")
                              _ ->
                                el("div", "", [
                                  text("Şart: " <> days_adv <> " gün"),
                                ])
                            },
                          ]),
                        ]),
                        el("td", "", [
                          el("span", "usage-pill", [
                            text(used <> " / " <> limit),
                          ]),
                        ]),
                        el("td", "", [
                          case active_bool {
                            True ->
                              el("span", "badge status-badge active", [
                                text("● Aktif"),
                              ])
                            False ->
                              el("span", "badge status-badge inactive", [
                                text("○ Pasif"),
                              ])
                          },
                        ]),
                        el("td", "actions-cell", [
                          el("div", "action-buttons-group", [
                            element.element(
                              "form",
                              [
                                a.attribute("method", "post"),
                                a.attribute(
                                  "action",
                                  "/admin/campaigns/" <> id <> "/toggle",
                                ),
                              ],
                              [
                                hidden("csrf", csrf),
                                hidden("active", case active_bool {
                                  True -> "false"
                                  False -> "true"
                                }),
                                element.element(
                                  "button",
                                  [
                                    a.type_("submit"),
                                    a.class(case active_bool {
                                      True -> "button small quiet"
                                      False -> "button small primary"
                                    }),
                                  ],
                                  [
                                    text(case active_bool {
                                      True -> "Durdur"
                                      False -> "Etkinleştir"
                                    }),
                                  ],
                                ),
                              ],
                            ),
                            element.element(
                              "form",
                              [
                                a.attribute("method", "post"),
                                a.attribute(
                                  "action",
                                  "/admin/campaigns/" <> id <> "/delete",
                                ),
                                a.attribute(
                                  "onsubmit",
                                  "return confirm('Bu kampanyayı silmek istediğinizden emin misiniz?')",
                                ),
                              ],
                              [
                                hidden("csrf", csrf),
                                element.element(
                                  "button",
                                  [
                                    a.type_("submit"),
                                    a.class("button small danger"),
                                  ],
                                  [text("Sil")],
                                ),
                              ],
                            ),
                          ]),
                        ]),
                      ])
                    }
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),
      ]),
      // Preset JS Helper
      element.element("script", [], [
        text(
          "
function applyPreset(name, type, dtype, val, days, stay, badge, code) {
  var n = document.getElementById('camp_name'); if(n) n.value = name;
  var t = document.getElementById('camp_type'); if(t) t.value = type;
  var dt = document.getElementById('camp_discount_type'); if(dt) dt.value = dtype;
  var v = document.getElementById('camp_discount_val'); if(v) v.value = val;
  var d = document.getElementById('camp_days_adv'); if(d) d.value = days;
  var s = document.getElementById('camp_min_stay'); if(s) s.value = stay;
  var b = document.getElementById('camp_badge'); if(b) b.value = badge;
  var c = document.getElementById('camp_code'); if(c) c.value = code;
  var form = document.getElementById('campaign_form');
  if(form) {
    form.scrollIntoView({ behavior: 'smooth' });
    n.focus();
  }
}
",
        ),
      ]),
    ]),
  )
}

fn result_unwrap(res: Result(Int, a), default: Int) -> Int {
  case res {
    Ok(v) -> v
    Error(_) -> default
  }
}
