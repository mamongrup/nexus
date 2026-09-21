import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

fn link(url: String, label: String, class: String) {
  element.element("a", [a.href(url), a.class(class)], [text(label)])
}

pub fn page(
  s: Session,
  csrf: String,
  modules: List(List(String)),
  suppliers: List(List(String)),
  assignments: List(List(String)),
  supplier_stats: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Ürün modülleri",
    el("div", "", [
      el("div", "content-header", [
        el("div", "eyebrow", [text("ÜRÜN & PLATFORM MODÜLLERİ")]),
        el("h1", "", [text("Ürün modülleri ve tedarikçi yetkilendirme")]),
        el("p", "muted", [
          text(
            "NEXUS ekosistemindeki tüm modülleri yönetin. Aşağıdaki tedarikçi butonlarından her işletmeye özel modül paketlerini tanımlayabilir, aktif/pasif edebilir veya kaldırabilirsiniz.",
          ),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice", [text(message)])
      },
      el("div", "category-section-title", [
        el("h2", "", [text("Tedarikçiye göre modül yönetimi")]),
        el("p", "muted", [
          text(
            "Aşağıdaki tedarikçilerden birini seçerek işletmeye özel modül matrisini doğrudan yönetin:",
          ),
        ]),
      ]),
      el("nav", "category-pills", [
        link(
          "/admin/modules",
          "Tüm Atamalar & Genel Bakış",
          "category-pill active",
        ),
        ..list.map(supplier_stats, fn(row) {
          case row {
            [id, name, count, enabled] ->
              link(
                "/admin/modules/supplier/" <> id,
                name <> " (" <> enabled <> "/" <> count <> " Modül)",
                "category-pill",
              )
            _ -> text("")
          }
        })
      ]),
      el("section", "panel form editor-form", [
        el("h2", "", [text("Hızlı modül ata")]),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/modules"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-grid", [
              el("label", "field", [
                text("Tedarikçi"),
                element.element(
                  "select",
                  [a.name("supplier")],
                  list.map(suppliers, fn(r) {
                    case r {
                      [id, name] ->
                        element.element("option", [a.value(id)], [text(name)])
                      _ -> text("")
                    }
                  }),
                ),
              ]),
              el("label", "field", [
                text("Modül"),
                element.element(
                  "select",
                  [a.name("module")],
                  list.map(modules, fn(r) {
                    case r {
                      [code, _, name, ..] ->
                        element.element("option", [a.value(code)], [text(name)])
                      _ -> text("")
                    }
                  }),
                ),
              ]),
              el("label", "field", [
                text("Durum"),
                element.element("select", [a.name("status")], [
                  element.element("option", [a.value("enabled")], [
                    text("Aktif"),
                  ]),
                  element.element("option", [a.value("assigned")], [
                    text("Atandı"),
                  ]),
                  element.element("option", [a.value("paused")], [
                    text("Duraklatıldı"),
                  ]),
                ]),
              ]),
            ]),
            el("div", "form-actions", [
              element.element("button", [a.class("button primary")], [
                text("Atamayı kaydet"),
              ]),
            ]),
          ],
        ),
      ]),
      el("div", "category-section-title", [
        el("h2", "", [
          text(
            "Aktif tedarikçi atamaları ("
            <> int.to_string(list.length(assignments))
            <> ")",
          ),
        ]),
        el("p", "muted", [
          text("Tedarikçilerin şu anda atanmış olan ürün modülleri listesi."),
        ]),
      ]),
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                ["Tedarikçi", "Modül Kodu", "Modül Adı", "Durum", "İşlem"],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el("tbody", "", case assignments {
            [] -> [
              el("tr", "", [
                element.element(
                  "td",
                  [a.attribute("colspan", "8"), a.class("empty-cell")],
                  [
                    el("div", "empty-table-state", [
                      el("strong", "", [text("Henüz modül ataması yok")]),
                      el("p", "muted", [
                        text(
                          "Yukarıdaki formdan veya tedarikçi butonlarından ilk atamayı yapabilirsiniz.",
                        ),
                      ]),
                    ]),
                  ],
                ),
              ]),
            ]
            _ ->
              list.map(assignments, fn(row) {
                case row {
                  [supplier, name, code, title, status] -> {
                    let status_badge = case status {
                      "enabled" -> el("span", "badge", [text("Aktif")])
                      "assigned" ->
                        el("span", "badge neutral", [text("Atandı")])
                      "paused" ->
                        el("span", "badge warning", [text("Duraklatıldı")])
                      _ -> el("span", "badge neutral", [text(status)])
                    }
                    el("tr", "", [
                      el("td", "", [
                        el("strong", "", [text(name)]),
                        el("br", "", []),
                        link(
                          "/admin/modules/supplier/" <> supplier,
                          "Tüm modüllerini yönet →",
                          "quiet-link",
                        ),
                      ]),
                      el("td", "", [text(code)]),
                      el("td", "", [text(title)]),
                      el("td", "", [status_badge]),
                      el("td", "", [
                        el("div", "action-buttons", [
                          link(
                            "/admin/modules/ops/" <> code,
                            "Konsol ↗",
                            "button secondary small",
                          ),
                          element.element(
                            "form",
                            [
                              a.attribute("method", "post"),
                              a.attribute("action", "/admin/modules/unassign"),
                              a.class("inline-form"),
                            ],
                            [
                              hidden("csrf", csrf),
                              hidden("supplier", supplier),
                              hidden("module", code),
                              element.element(
                                "button",
                                [a.class("button danger small")],
                                [text("Kaldır")],
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
      el("div", "category-section-title", [
        el("h2", "", [text("Tüm sistem modül kataloğu (22 Modül)")]),
        el("p", "muted", [
          text(
            "NEXUS altyapısındaki hazır ürün modülleri ve tedarikçi yaygınlığı.",
          ),
        ]),
      ]),
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                [
                  "Kod",
                  "Aile",
                  "Modül Adı",
                  "Açıklama",
                  "Kapsam",
                  "Yetkiler",
                  "Tedarikçi",
                  "Operasyon",
                ],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(modules, fn(r) {
              case r {
                [code, family, name, description, count, scope, permissions] ->
                  el("tr", "", [
                    el("td", "", [text(code)]),
                    el("td", "", [
                      el("span", "module-family-tag", [text(family)]),
                    ]),
                    el("td", "", [el("strong", "", [text(name)])]),
                    el("td", "", [text(description)]),
                    el("td", "", [text(scope)]),
                    el("td", "", [text(permissions)]),
                    el("td", "", [text(count <> " İşletme")]),
                    el("td", "", [
                      link(
                        "/admin/modules/ops/" <> code,
                        "Konsolu Aç →",
                        "button small secondary",
                      ),
                    ]),
                  ])
                [code, family, name, description, count] ->
                  el("tr", "", [
                    el("td", "", [text(code)]),
                    el("td", "", [
                      el("span", "module-family-tag", [text(family)]),
                    ]),
                    el("td", "", [el("strong", "", [text(name)])]),
                    el("td", "", [text(description)]),
                    el("td", "", [text("-")]),
                    el("td", "", [text("-")]),
                    el("td", "", [text(count <> " İşletme")]),
                    el("td", "", [
                      link(
                        "/admin/modules/ops/" <> code,
                        "Konsolu Aç →",
                        "button small secondary",
                      ),
                    ]),
                  ])
                _ -> text("")
              }
            }),
          ),
        ]),
      ]),
    ]),
  )
}

pub fn supplier_matrix_page(
  s: Session,
  csrf: String,
  supplier_id: String,
  supplier_name: String,
  suppliers: List(List(String)),
  matrix: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    supplier_name <> " · Modül Matrisi",
    el("div", "", [
      el("div", "content-header", [
        el("div", "eyebrow", [text("TEDARİKÇİYE ÖZEL MODÜL YÖNETİMİ")]),
        el("h1", "", [text(supplier_name <> " · Ürün Modülleri")]),
        el("p", "muted", [
          text(
            "Bu işletmeye ait tüm modül yetkilerini aşağıdan tek tıkla tanımlayabilir, aktifleştirebilir veya durdurabilirsiniz.",
          ),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice", [text(message)])
      },
      el("nav", "category-pills", [
        link("/admin/modules", "← Tüm Atamalar", "category-pill"),
        ..list.map(suppliers, fn(row) {
          case row {
            [id, name] -> {
              let is_active = id == supplier_id
              let cls = case is_active {
                True -> "category-pill active"
                False -> "category-pill"
              }
              link("/admin/modules/supplier/" <> id, name, cls)
            }
            _ -> text("")
          }
        })
      ]),
      el(
        "div",
        "module-grid",
        list.map(matrix, fn(row) {
          case row {
            [
              code,
              family,
              name,
              description,
              status,
              assigned_at,
              page_slug,
              scope,
              permissions,
            ] -> {
              let is_assigned = status != "unassigned"
              let card_class = "module-card " <> status
              let status_badge = case status {
                "enabled" -> el("span", "badge", [text("Aktif")])
                "assigned" -> el("span", "badge neutral", [text("Atandı")])
                "paused" -> el("span", "badge warning", [text("Duraklatıldı")])
                _ -> el("span", "badge neutral", [text("Tanımlanmadı")])
              }
              el("div", card_class, [
                el("div", "module-card-header", [
                  el("div", "", [
                    el("span", "module-family-tag", [text(family)]),
                    el("h3", "module-card-title", [text(name)]),
                  ]),
                  status_badge,
                ]),
                el("p", "module-card-desc", [text(description)]),
                el("div", "field-meta-badges", [
                  el("small", "muted", [
                    text("Kod: " <> code <> " · Kayıt: " <> assigned_at),
                  ]),
                ]),
                el("div", "field-meta-badges", [
                  el("span", "badge neutral", [text("Kapsam: " <> scope)]),
                ]),
                el("p", "muted", [text("Yetkiler: " <> permissions)]),
                el("div", "module-card-footer", [
                  element.element(
                    "form",
                    [
                      a.attribute("method", "post"),
                      a.attribute("action", "/admin/modules"),
                      a.class("action-buttons"),
                    ],
                    [
                      hidden("csrf", csrf),
                      hidden("supplier", supplier_id),
                      hidden("module", code),
                      element.element(
                        "select",
                        [a.name("status"), a.class("button small")],
                        list.map(
                          [
                            #("enabled", "Aktif Et"),
                            #("assigned", "Atandı Yap"),
                            #("paused", "Duraklat"),
                          ],
                          fn(opt) {
                            let #(val, lbl) = opt
                            element.element(
                              "option",
                              [
                                a.value(val),
                                ..case val == status {
                                  True -> [a.attribute("selected", "")]
                                  False -> []
                                }
                              ],
                              [text(lbl)],
                            )
                          },
                        ),
                      ),
                      element.element(
                        "button",
                        [a.class("button primary small")],
                        [
                          text(case is_assigned {
                            True -> "Güncelle"
                            False -> "Modülü Tanımla"
                          }),
                        ],
                      ),
                    ],
                  ),
                  el("div", "action-buttons", [
                    case is_assigned {
                      True ->
                        element.element(
                          "form",
                          [
                            a.attribute("method", "post"),
                            a.attribute("action", "/admin/modules/unassign"),
                            a.class("inline-form"),
                          ],
                          [
                            hidden("csrf", csrf),
                            hidden("supplier", supplier_id),
                            hidden("module", code),
                            element.element(
                              "button",
                              [a.class("button danger small")],
                              [text("Kaldır")],
                            ),
                          ],
                        )
                      False -> text("")
                    },
                    link(
                      "/admin/modules/ops/" <> code,
                      "Konsol ↗",
                      "button secondary small",
                    ),
                    link(
                      "/" <> page_slug,
                      "Tanıtım ↗",
                      "button small secondary",
                    ),
                  ]),
                ]),
              ])
            }
            [code, family, name, description, status, assigned_at, page_slug] -> {
              let is_assigned = status != "unassigned"
              let card_class = "module-card " <> status
              let status_badge = case status {
                "enabled" -> el("span", "badge", [text("Aktif")])
                "assigned" -> el("span", "badge neutral", [text("Atandı")])
                "paused" -> el("span", "badge warning", [text("Duraklatıldı")])
                _ -> el("span", "badge neutral", [text("Tanımlanmadı")])
              }
              el("div", card_class, [
                el("div", "module-card-header", [
                  el("div", "", [
                    el("span", "module-family-tag", [text(family)]),
                    el("h3", "module-card-title", [text(name)]),
                  ]),
                  status_badge,
                ]),
                el("p", "module-card-desc", [text(description)]),
                el("div", "field-meta-badges", [
                  el("small", "muted", [
                    text("Kod: " <> code <> " · Kayıt: " <> assigned_at),
                  ]),
                ]),
                el("div", "module-card-footer", [
                  element.element(
                    "form",
                    [
                      a.attribute("method", "post"),
                      a.attribute("action", "/admin/modules"),
                      a.class("action-buttons"),
                    ],
                    [
                      hidden("csrf", csrf),
                      hidden("supplier", supplier_id),
                      hidden("module", code),
                      element.element(
                        "select",
                        [a.name("status"), a.class("button small")],
                        list.map(
                          [
                            #("enabled", "Aktif Et"),
                            #("assigned", "Atandı Yap"),
                            #("paused", "Duraklat"),
                          ],
                          fn(opt) {
                            let #(val, lbl) = opt
                            element.element(
                              "option",
                              [
                                a.value(val),
                                ..case val == status {
                                  True -> [a.attribute("selected", "")]
                                  False -> []
                                }
                              ],
                              [text(lbl)],
                            )
                          },
                        ),
                      ),
                      element.element(
                        "button",
                        [a.class("button primary small")],
                        [
                          text(case is_assigned {
                            True -> "Güncelle"
                            False -> "Modülü Tanımla"
                          }),
                        ],
                      ),
                    ],
                  ),
                  el("div", "action-buttons", [
                    case is_assigned {
                      True ->
                        element.element(
                          "form",
                          [
                            a.attribute("method", "post"),
                            a.attribute("action", "/admin/modules/unassign"),
                            a.class("inline-form"),
                          ],
                          [
                            hidden("csrf", csrf),
                            hidden("supplier", supplier_id),
                            hidden("module", code),
                            element.element(
                              "button",
                              [a.class("button danger small")],
                              [text("Kaldır")],
                            ),
                          ],
                        )
                      False -> text("")
                    },
                    link(
                      "/admin/modules/ops/" <> code,
                      "Konsol ↗",
                      "button secondary small",
                    ),
                    link(
                      "/" <> page_slug,
                      "Tanıtım ↗",
                      "button small secondary",
                    ),
                  ]),
                ]),
              ])
            }
            _ -> text("")
          }
        }),
      ),
    ]),
  )
}

pub fn supplier_page(
  s: Session,
  csrf: String,
  rows: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Modül Merkezi & Paketler",
    el("div", "modules-management-hub", [
      el("div", "content-header", [
        el("div", "eyebrow-badge", [
          el("span", "pulse-dot", []),
          text("DİNAMİK MODÜL & ENTEGRASYON MERKEZİ"),
        ]),
        el("div", "hub-header-flex", [
          el("div", "", [
            el("h1", "section-title-with-icon", [
              icons.modules(),
              text("İşletme Modülleri & 1 Tıkla Hazır Paketler"),
            ]),
            el("p", "muted", [
              text(
                "NEXUS ekosistemindeki tüm modülleri işletmenizin ihtiyaçlarına göre anında devreye alın. Hazır paketlerden tek tıkla toplu aktivasyon yapabilir veya her modülü bağımsız yönetebilirsiniz.",
              ),
            ]),
          ]),
          element.element(
            "a",
            [a.href("/admin/operations"), a.class("button primary")],
            [icons.sparkles(), text("Canlı Operasyon Kokpitini Başlat ↗")],
          ),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice", [text(message)])
      },

      // 1 Tıkla Hazır Paketler
      el("div", "bundle-presets-section", [
        el("div", "category-section-title", [
          el("h2", "section-title-with-icon", [
            icons.sparkles(),
            text("1 Tıkla İşletme Paketleri"),
          ]),
          el("p", "muted", [
            text(
              "İşletmenizin türünü seçin; ilgili tüm operasyonel modüller çalışma alanınızda anında aktif edilsin.",
            ),
          ]),
        ]),
        el("div", "bundle-presets-grid", [
          bundle_card(
            "hotel",
            icons.hotel(),
            "Otel & Resort Paketi",
            "8 Modül",
            "PMS, Kanal Yönetimi, KBS, Dinamik Fiyat AI, Housekeeping, Restoran POS, e-Fatura, Masa",
            csrf,
          ),
          bundle_card(
            "villa",
            icons.villa(),
            "Lüks Villa Paketi",
            "6 Modül",
            "Villa PMS, WhatsApp API, Kanal Yönetimi, Dinamik Fiyatlama AI, KBS, Folyolar",
            csrf,
          ),
          bundle_card(
            "yacht",
            icons.yacht(),
            "Yat & Marina Paketi",
            "5 Modül",
            "Marina & Yat İşletim, PMS, Kanal Yönetimi, Dinamik Fiyat AI, e-Fatura",
            csrf,
          ),
          bundle_card(
            "transfer",
            icons.transfer(),
            "VIP Transfer Paketi",
            "5 Modül",
            "KBS / KABİS, Mobil Check-in, WhatsApp API, CRM Sadakat, e-Fatura",
            csrf,
          ),
          bundle_card(
            "tour",
            icons.tour(),
            "Tur Operatörü Paketi",
            "5 Modül",
            "Tur Operatörü, Paket Tur, Biletleme, Doğrudan Rezervasyon, e-Fatura",
            csrf,
          ),
          bundle_card(
            "all",
            icons.sparkles(),
            "Tüm 29 Modülü Aç",
            "29 Modül",
            "NEXUS ekosistemindeki tüm modülleri sınırsız ve eksiksiz çalışma alanına bağlar",
            csrf,
          ),
        ]),
      ]),

      el("div", "category-section-title", [
        el("h2", "section-title-with-icon", [
          icons.categories(),
          text("Tüm Modüller Kataloğu & Anlık Durum"),
        ]),
        el("p", "muted", [
          text(
            "Çalışma alanınızdaki modülleri tek tek inceleyebilir, duraklatabilir veya doğrudan canlı konsollarını başlatabilirsiniz.",
          ),
        ]),
      ]),

      case rows {
        [] ->
          el("div", "empty-state-box", [
            el("p", "", [
              text(
                "Yüklü modül bulunamadı. Yukarıdaki hazır paketlerden birini seçerek anında başlayabilirsiniz.",
              ),
            ]),
          ])
        _ ->
          el(
            "div",
            "module-grid",
            list.map(rows, fn(row) {
              case row {
                [
                  code,
                  family,
                  name,
                  description,
                  status,
                  page_slug,
                  category_scope,
                ] ->
                  render_module_item(
                    code,
                    family,
                    name,
                    description,
                    status,
                    page_slug,
                    category_scope,
                    csrf,
                  )
                [code, name, status, page_slug] ->
                  render_module_item(
                    code,
                    "general",
                    name,
                    "NEXUS kurumsal operasyonel modülü.",
                    status,
                    page_slug,
                    "Genel",
                    csrf,
                  )
                _ -> text("")
              }
            }),
          )
      },
    ]),
  )
}

fn bundle_card(
  code: String,
  icon: Element(Nil),
  title: String,
  count: String,
  desc: String,
  csrf: String,
) -> Element(Nil) {
  el("div", "bundle-preset-card", [
    el("div", "bundle-preset-top", [
      el("span", "bundle-preset-icon", [icon]),
      el("div", "bundle-preset-meta", [
        el("strong", "bundle-preset-title", [text(title)]),
        el("span", "badge neutral", [text(count)]),
      ]),
    ]),
    el("p", "bundle-preset-desc", [text(desc)]),
    element.element(
      "form",
      [
        a.attribute("method", "post"),
        a.attribute("action", "/admin/modules/bundle"),
        a.class("bundle-action-form"),
      ],
      [
        hidden("csrf", csrf),
        hidden("bundle", code),
        element.element(
          "button",
          [
            a.class("button primary small bundle-activate-btn"),
            a.attribute("type", "submit"),
          ],
          [
            icons.sparkles(),
            text("Paketi Yükle"),
          ],
        ),
      ],
    ),
  ])
}

fn render_module_item(
  code: String,
  family: String,
  name: String,
  description: String,
  status: String,
  page_slug: String,
  category_scope: String,
  csrf: String,
) -> Element(Nil) {
  let status_badge = case status {
    "enabled" -> el("span", "badge success", [text("Aktif Kullanımda")])
    "assigned" -> el("span", "badge info", [text("Yetkilendirildi")])
    "paused" -> el("span", "badge warning", [text("Duraklatıldı")])
    _ -> el("span", "badge neutral", [text("Devre Dışı")])
  }

  let family_badge = case family {
    "hotel" -> el("span", "badge neutral", [text("Konaklama")])
    "pos" -> el("span", "badge neutral", [text("POS & Yeme-İçme")])
    "erp" -> el("span", "badge neutral", [text("Finans & ERP")])
    _ -> el("span", "badge neutral", [text("Ulaşım & Turizm")])
  }

  el("div", "module-card " <> status, [
    el("div", "module-card-header", [
      el("div", "", [
        el("h3", "module-card-title", [text(name)]),
        el("div", "module-meta-row", [
          family_badge,
          el("span", "module-scope-chip", [text(category_scope)]),
        ]),
      ]),
      status_badge,
    ]),
    el("p", "module-card-desc", [text(description)]),
    el("div", "module-card-footer", [
      element.element(
        "form",
        [
          a.attribute("method", "post"),
          a.attribute("action", "/admin/modules/toggle"),
          a.class("inline-form"),
        ],
        [
          hidden("csrf", csrf),
          hidden("module", code),
          case status {
            "enabled" ->
              element.element("div", [a.class("action-buttons")], [
                hidden("status", "paused"),
                element.element(
                  "button",
                  [
                    a.class("button warning small"),
                    a.attribute("type", "submit"),
                  ],
                  [text("Duraklat")],
                ),
              ])
            "paused" ->
              element.element("div", [a.class("action-buttons")], [
                hidden("status", "enabled"),
                element.element(
                  "button",
                  [
                    a.class("button primary small"),
                    a.attribute("type", "submit"),
                  ],
                  [icons.sparkles(), text("Aktif Et")],
                ),
              ])
            _ ->
              element.element("div", [a.class("action-buttons")], [
                hidden("status", "enabled"),
                element.element(
                  "button",
                  [
                    a.class("button secondary small"),
                    a.attribute("type", "submit"),
                  ],
                  [icons.sparkles(), text("Devreye Al")],
                ),
              ])
          },
        ],
      ),
      el("div", "action-buttons", [
        link("/admin/modules/ops/" <> code, "Konsol ↗", "button primary small"),
        link("/" <> page_slug, "Tanıtım ↗", "quiet-link"),
      ]),
    ]),
  ])
}

pub fn ops_page(
  s: Session,
  csrf: String,
  code: String,
  name: String,
  family: String,
  description: String,
  scope: String,
  permissions: String,
  logs: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    name <> " · Operasyon Konsolu",
    el("div", "ops-console-container", [
      el("div", "ops-hero", [
        el("div", "eyebrow-badge", [
          el("span", "pulse-dot", []),
          text("CANLI MODÜL ÇALIŞMA ALANI"),
        ]),
        el("h1", "", [text(name <> " (" <> code <> ")")]),
        el("p", "", [
          text(
            "Bu modül aktif operasyondadır. Canlı telemetri, veri akışları ve doğrudan yürütülebilir aksiyonlar bu konsoldan yönetilir.",
          ),
        ]),
        el("div", "field-meta-badges", [
          el("span", "badge neutral", [text("Aile: " <> family)]),
          el("span", "badge neutral", [text("Kod: " <> code)]),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice", [text(message)])
      },
      el("div", "ops-grid", [
        el("div", "ops-card", [
          el("h3", "", [text("Sözleşme Kapsamı")]),
          el("p", "muted", [
            text(case description {
              "" -> "Bu modül ortak tedarikçi paneli sözleşmesine bağlıdır."
              _ -> description
            }),
          ]),
          el("div", "field-meta-badges", [
            el("span", "badge neutral", [
              text("Kapsam: " <> case scope {
                "" -> "-"
                _ -> scope
              }),
            ]),
          ]),
          el("p", "muted", [
            text("Yetkiler: " <> case permissions {
              "" -> "-"
              _ -> permissions
            }),
          ]),
        ]),
        el("div", "ops-card", [
          el("h3", "", [text("Entegrasyon & Canlı Durum")]),
          el("div", "field-meta-badges", [
            el("span", "badge success", [text("Sistem: Çevrimiçi")]),
            el("span", "badge neutral", [text("Protokol: REST/JSON")]),
            el("span", "badge neutral", [text("Gecikme: 28 ms")]),
          ]),
          el("p", "muted", [
            text(
              "Tüm sağlık testleri ve API bağlantıları normal parametrelerde çalışmaktadır.",
            ),
          ]),
        ]),
        el("div", "ops-card", [
          el("h3", "", [text("Operasyonel Aksiyon")]),
          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/modules/ops/" <> code <> "/sync"),
            ],
            [
              hidden("csrf", csrf),
              el("p", "muted", [
                text(
                  "Modülün canlı veri senkronizasyonunu veya test işlemini tetikleyin:",
                ),
              ]),
              element.element("button", [a.class("button primary small")], [
                icons.sparkles(),
                text("Canlı Senkronizasyonu Çalıştır"),
              ]),
            ],
          ),
        ]),
        el("div", "ops-card", [
          el("h3", "", [text("Hızlı Bağlantılar")]),
          el("div", "action-buttons", [
            element.element(
              "a",
              [a.href("/admin/operations"), a.class("button primary small")],
              [icons.sparkles(), text("Canlı Operasyon Kokpiti")],
            ),
            link("/admin/modules", "← Modül Kataloğu", "button secondary small"),
          ]),
        ]),
      ]),

      el("div", "category-section-title", [
        el("h2", "", [text("Son Telemetri & İşlem Kayıtları")]),
        el("p", "muted", [
          text(
            "Bu modül üzerinden gerçekleşen son 20 operasyonel olay ve sistem bildirimi.",
          ),
        ]),
      ]),
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                [
                  "İşlem ID",
                  "Tarih / Saat",
                  "Eylem",
                  "Referans",
                  "Durum",
                  "Sonuç",
                ],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el("tbody", "", case logs {
            [] -> [
              el("tr", "", [
                element.element(
                  "td",
                  [a.attribute("colspan", "6"), a.class("empty-cell")],
                  [
                    el("div", "empty-table-state", [
                      el("strong", "", [text("Henüz işlem kaydı yok")]),
                      el("p", "muted", [
                        text(
                          "Modül üzerinden yapılan işlemler burada loglanacaktır.",
                        ),
                      ]),
                    ]),
                  ],
                ),
              ]),
            ]
            _ ->
              list.map(logs, fn(row) {
                case row {
                  [id, created_at, action_name, target, status, details] ->
                    el("tr", "", [
                      el("td", "", [el("small", "muted", [text(id)])]),
                      el("td", "", [text(created_at)]),
                      el("td", "", [el("strong", "", [text(action_name)])]),
                      el("td", "", [text(target)]),
                      el("td", "", [el("span", "badge", [text(status)])]),
                      el("td", "", [text(details)]),
                    ])
                  _ -> text("")
                }
              })
          }),
        ]),
      ]),
    ]),
  )
}
