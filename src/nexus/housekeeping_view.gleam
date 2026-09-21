import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Property, type Session}
import nexus/icons
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  properties: List(Property),
  active_prop_id: String,
  room_rack: List(List(String)),
  tasks: List(List(String)),
  tickets: List(List(String)),
  message: String,
) -> String {
  let total_rooms = list.length(room_rack)

  let clean_rooms =
    list.filter(room_rack, fn(r) {
      case r {
        [_, _, _, _, _, hk, ..] -> hk == "clean"
        _ -> False
      }
    })
    |> list.length

  let dirty_rooms =
    list.filter(room_rack, fn(r) {
      case r {
        [_, _, _, _, _, hk, ..] -> hk == "dirty"
        _ -> False
      }
    })
    |> list.length

  let inspecting_rooms =
    list.filter(room_rack, fn(r) {
      case r {
        [_, _, _, _, _, hk, ..] -> hk == "inspecting" || hk == "out_of_service"
        _ -> False
      }
    })
    |> list.length

  let pending_tasks =
    list.filter(tasks, fn(t) {
      case t {
        [_, _, _, _, status, ..] ->
          status == "pending" || status == "in_progress"
        _ -> False
      }
    })
    |> list.length

  let open_tickets =
    list.filter(tickets, fn(t) {
      case t {
        [_, _, _, _, _, status, ..] ->
          status == "open" || status == "in_progress"
        _ -> False
      }
    })
    |> list.length

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
        [text(p.title <> " (" <> p.locality <> ")")],
      )
    })

  view.shell(
    s,
    csrf,
    "Oda Temizliği & Kat Hizmetleri",
    el("div", "campaigns-container", [
      el("header", "page-header", [
        el("div", "", [
          el("span", "badge primary", [text("HOUSEKEEPING & KAT HİZMETLERİ")]),
          el("h1", "", [
            icons.housekeeping(),
            text("Oda Takibi, Temizlik & Arıza Yönetimi"),
          ]),
          el("p", "muted", [
            text(
              "Tüm odaların anlık temizlik durumlarını (Temiz / Kirli / Kontrolde / Bakımda) canlı rack matrisinde izleyin, temizlik görevleri atayın ve teknik arıza kayıtlarını yönetin.",
            ),
          ]),
        ]),
        el("div", "header-actions", [
          element.element(
            "a",
            [a.href("/admin/operations"), a.class("button secondary")],
            [
              icons.pms(),
              text("Operasyon Kokpiti"),
            ],
          ),
          element.element(
            "a",
            [a.href("/admin/accounting"), a.class("button secondary")],
            [
              icons.accounting(),
              text("Kasa & Muhasebe"),
            ],
          ),
        ]),
      ]),

      // Tesis Seçici Barı
      el("div", "hub-controls-bar mb-4", [
        el("div", "prop-selector-box", [
          el("label", "prop-selector-label d-flex items-center gap-2", [
            icons.hotel(),
            text("Aktif Yönetilen Tesis:"),
          ]),
          element.element(
            "select",
            [
              a.class("prop-select-input"),
              a.attribute(
                "onchange",
                "window.location.href='/admin/housekeeping?prop_id=' + this.value",
              ),
            ],
            property_options,
          ),
        ]),
      ]),

      case message {
        "" -> text("")
        _ ->
          el("div", "notice notice-success mb-4", [
            el("span", "d-flex items-center gap-2", [
              icons.check(),
              text(message),
            ]),
          ])
      },

      // Kat Görevlisi Hızlı Oda Temizlik Bildirim Barı
      el("div", "panel-card mb-4", [
        el("div", "d-flex justify-between items-center flex-wrap gap-3", [
          el("div", "", [
            el("h3", "section-title-with-icon mb-1", [
              icons.housekeeping(),
              text("Hızlı Oda Temizlik Bildirimi"),
            ]),
            el("p", "muted text-sm mb-0", [
              text(
                "Temizliği biten odayı sisteme girin; odanın durumu anında 'Temiz' yapılarak bekleyen görev tamamlanır.",
              ),
            ]),
          ]),
          element.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/housekeeping/quick_clean"),
              a.class("d-flex items-center gap-2 flex-wrap"),
            ],
            [
              hidden("csrf", csrf),
              hidden("property_id", active_prop_id),
              element.element(
                "input",
                [
                  a.name("room_code"),
                  a.type_("text"),
                  a.class("input-text"),
                  a.placeholder("Oda Kodu (Örn: 101, 204)"),
                  a.attribute("required", "required"),
                ],
                [],
              ),
              element.element(
                "button",
                [
                  a.type_("submit"),
                  a.class("button primary"),
                ],
                [icons.check(), text("Temizlendi Olarak Bildir")],
              ),
            ],
          ),
        ]),
      ]),

      // KPI Kartları
      el("div", "stats-grid", [
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-blue", [icons.hotel()]),
          el("div", "", [
            el("span", "kpi-label", [text("Toplam Oda / Ünite")]),
            el("h2", "kpi-value", [text(int.to_string(total_rooms))]),
            el("span", "kpi-sub", [text("Aktif envanter")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.sparkles()]),
          el("div", "", [
            el("span", "kpi-label", [text("Temiz Odalar")]),
            el("h2", "kpi-value text-green", [text(int.to_string(clean_rooms))]),
            el("span", "kpi-sub", [text("Girişe hazır")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-amber", [icons.housekeeping()]),
          el("div", "", [
            el("span", "kpi-label", [text("Kirli Odalar")]),
            el("h2", "kpi-value text-amber", [text(int.to_string(dirty_rooms))]),
            el("span", "kpi-sub", [text("Temizlik bekliyor")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.document()]),
          el("div", "", [
            el("span", "kpi-label", [text("Bekleyen Görevler")]),
            el("h2", "kpi-value text-purple", [
              text(int.to_string(pending_tasks)),
            ]),
            el("span", "kpi-sub", [text("Kat personeli sürecinde")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-rose", [icons.security()]),
          el("div", "", [
            el("span", "kpi-label", [text("Açık Arızalar")]),
            el("h2", "kpi-value text-rose", [text(int.to_string(open_tickets))]),
            el("span", "kpi-sub", [
              text(
                int.to_string(inspecting_rooms) <> " Servis Dışı / Kontrolde",
              ),
            ]),
          ]),
        ]),
      ]),

      // 1. CANLI ODA KAT VE TEMİZLİK MATRİSİ (ROOM RACK)
      el("div", "card mb-5", [
        el("div", "card-header d-flex justify-between items-center", [
          el("div", "", [
            el("h2", "card-title section-title-with-icon", [
              icons.hotel(),
              text("Canlı Oda Katı & Temizlik Durum Matrisi"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Odaların doluluk ve temizlik durumunu anlık takip edin, tek tıkla durumlarını güncelleyin.",
              ),
            ]),
          ]),
        ]),
        el("div", "card-body", [
          case room_rack {
            [] ->
              el("div", "empty-state text-center p-4", [
                el("p", "muted", [
                  text(
                    "Bu tesise ait henüz kayıtlı oda/ünite bulunmuyor. Üniteler PMS modülünden otomatik listelenir.",
                  ),
                ]),
              ])
            _ ->
              el(
                "div",
                "room-rack-grid",
                list.map(room_rack, fn(room) {
                  render_room_card(room, csrf, active_prop_id)
                }),
              )
          },
        ]),
      ]),

      // 2. KAT HİZMETLERİ GÖREVLERİ & ATAMA
      el("div", "grid-2col mb-5", [
        // Görev Atama Formu
        el("div", "card", [
          el("div", "card-header", [
            el("h2", "card-title section-title-with-icon", [
              icons.plus(),
              text("Yeni Temizlik Görevi Ata"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Personele günlük veya çıkış sonrası derin temizlik görevi yönlendirin.",
              ),
            ]),
          ]),
          el("div", "card-body", [
            element.element(
              "form",
              [a.method("post"), a.action("/admin/housekeeping/task")],
              [
                hidden("csrf", csrf),
                hidden("property_id", active_prop_id),
                el("div", "form-group", [
                  el("label", "form-label", [text("Oda Kodu")]),
                  element.element(
                    "input",
                    [
                      a.class("form-control"),
                      a.name("room_code"),
                      a.type_("text"),
                      a.placeholder("Örn: 101, 204, VILLA-A"),
                      a.attribute("required", "required"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "form-label", [text("Görevli Kat Personeli")]),
                  element.element(
                    "input",
                    [
                      a.class("form-control"),
                      a.name("assigned_staff"),
                      a.type_("text"),
                      a.placeholder("Örn: Fatma Yılmaz (Kat Görevlisi)"),
                      a.attribute("required", "required"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "form-label", [text("Temizlik Tipi")]),
                  element.element(
                    "select",
                    [a.class("form-control"), a.name("task_type")],
                    [
                      element.element("option", [a.value("daily_clean")], [
                        text("Günlük Rutin Temizlik"),
                      ]),
                      element.element("option", [a.value("checkout_deep")], [
                        text("Çıkış Sonrası Derin Temizlik"),
                      ]),
                      element.element("option", [a.value("inspection")], [
                        text("Kat Şefi Denetimi & Kontrol"),
                      ]),
                      element.element("option", [a.value("turndown")], [
                        text("Akşam Turndown Servisi"),
                      ]),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "form-label", [text("Özel Talimatlar / Notlar")]),
                  element.element(
                    "textarea",
                    [
                      a.class("form-control"),
                      a.name("notes"),
                      a.rows(3),
                      a.placeholder(
                        "Örn: Çarşaflar antialerjik olacak, mini bar yenilenecek...",
                      ),
                    ],
                    [],
                  ),
                ]),
                element.element(
                  "button",
                  [a.type_("submit"), a.class("button primary full-width")],
                  [icons.plus(), text("Temizlik Görevi Ata")],
                ),
              ],
            ),
          ]),
        ]),

        // Görevler Listesi
        el("div", "card", [
          el("div", "card-header", [
            el("h2", "card-title section-title-with-icon", [
              icons.document(),
              text("Aktif & Tamamlanan Görevler"),
            ]),
            el("p", "muted text-sm", [
              text("Personelin yürüttüğü anlık kat temizlik işleri."),
            ]),
          ]),
          el("div", "card-body p-0", [
            case tasks {
              [] ->
                el("div", "empty-state text-center p-4", [
                  el("p", "muted", [
                    text("Henüz atanmış temizlik görevi bulunmuyor."),
                  ]),
                ])
              _ ->
                el("div", "table-responsive", [
                  element.element("table", [a.class("data-table")], [
                    element.element("thead", [], [
                      element.element("tr", [], [
                        element.element("th", [], [text("Oda")]),
                        element.element("th", [], [text("Görevli")]),
                        element.element("th", [], [text("Tip")]),
                        element.element("th", [], [text("Durum")]),
                        element.element("th", [], [text("İşlem")]),
                      ]),
                    ]),
                    element.element(
                      "tbody",
                      [],
                      list.map(tasks, fn(task) {
                        render_task_row(task, csrf, active_prop_id)
                      }),
                    ),
                  ]),
                ])
            },
          ]),
        ]),
      ]),

      // 3. ODA ARIZA & TEKNİK SERVİS BİLDİRİMLERİ
      el("div", "grid-2col", [
        // Arıza Bildirim Formu
        el("div", "card", [
          el("div", "card-header", [
            el("h2", "card-title section-title-with-icon", [
              icons.security(),
              text("Yeni Oda Arıza / Bakım Bildirimi"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Odada tespit edilen klima, tesisat, elektrik veya mobilya arızasını bildirin.",
              ),
            ]),
          ]),
          el("div", "card-body", [
            element.element(
              "form",
              [a.method("post"), a.action("/admin/housekeeping/maintenance")],
              [
                hidden("csrf", csrf),
                hidden("property_id", active_prop_id),
                el("div", "form-group", [
                  el("label", "form-label", [text("Oda Kodu")]),
                  element.element(
                    "input",
                    [
                      a.class("form-control"),
                      a.name("room_code"),
                      a.type_("text"),
                      a.placeholder("Örn: 204"),
                      a.attribute("required", "required"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "form-label", [text("Arıza Başlığı")]),
                  element.element(
                    "input",
                    [
                      a.class("form-control"),
                      a.name("issue_title"),
                      a.type_("text"),
                      a.placeholder(
                        "Örn: Klima soğutmuyor, Duş başlığı damlatıyor",
                      ),
                      a.attribute("required", "required"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "form-label", [text("Öncelik Seviyesi")]),
                  element.element(
                    "select",
                    [a.class("form-control"), a.name("priority")],
                    [
                      element.element("option", [a.value("low")], [
                        text("Düşük Öncelik"),
                      ]),
                      element.element(
                        "option",
                        [a.value("medium"), a.attribute("selected", "selected")],
                        [
                          text("Normal Öncelik"),
                        ],
                      ),
                      element.element("option", [a.value("urgent")], [
                        text("Acil / Giriş Var"),
                      ]),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  el("label", "form-label", [text("Detaylı Açıklama")]),
                  element.element(
                    "textarea",
                    [
                      a.class("form-control"),
                      a.name("description"),
                      a.rows(3),
                      a.placeholder(
                        "Arızanın detayları ve müdahale gereksinimleri...",
                      ),
                    ],
                    [],
                  ),
                ]),
                element.element(
                  "button",
                  [a.type_("submit"), a.class("button primary full-width")],
                  [icons.security(), text("Arıza Biletini Oluştur")],
                ),
              ],
            ),
          ]),
        ]),

        // Arıza Biletleri Tablosu
        el("div", "card", [
          el("div", "card-header", [
            el("h2", "card-title section-title-with-icon", [
              icons.security(),
              text("Oda Teknik Servis Biletleri"),
            ]),
            el("p", "muted text-sm", [
              text("Müdahale bekleyen ve çözümlenmiş oda teknik arızaları."),
            ]),
          ]),
          el("div", "card-body p-0", [
            case tickets {
              [] ->
                el("div", "empty-state text-center p-4", [
                  el("p", "muted", [
                    text("Kayıtlı aktif arıza bildirimi bulunmuyor."),
                  ]),
                ])
              _ ->
                el("div", "table-responsive", [
                  element.element("table", [a.class("data-table")], [
                    element.element("thead", [], [
                      element.element("tr", [], [
                        element.element("th", [], [text("Oda")]),
                        element.element("th", [], [text("Arıza")]),
                        element.element("th", [], [text("Öncelik")]),
                        element.element("th", [], [text("Durum")]),
                        element.element("th", [], [text("İşlem")]),
                      ]),
                    ]),
                    element.element(
                      "tbody",
                      [],
                      list.map(tickets, fn(ticket) {
                        render_ticket_row(ticket, csrf, active_prop_id)
                      }),
                    ),
                  ]),
                ])
            },
          ]),
        ]),
      ]),
    ]),
  )
}

fn render_room_card(
  room: List(String),
  csrf: String,
  prop_id: String,
) -> element.Element(Nil) {
  let #(id, code, name, utype, occ, hk, guest) = case room {
    [id, code, name, utype, occ, hk, guest, ..] -> #(
      id,
      code,
      name,
      utype,
      occ,
      hk,
      guest,
    )
    _ -> #("", "Oda", "", "", "vacant", "clean", "")
  }

  let is_clean = hk == "clean"
  let _is_dirty = hk == "dirty"
  let is_inspecting = hk == "inspecting"
  let is_oos = hk == "out_of_service"

  let border_class = case hk {
    "clean" -> "room-card-clean"
    "dirty" -> "room-card-dirty"
    "inspecting" -> "room-card-inspecting"
    _ -> "room-card-oos"
  }

  el("div", "room-card " <> border_class, [
    el("div", "room-card-top", [
      el("span", "room-code-badge", [text(code)]),
      el("span", "room-type-tag", [
        text(case utype {
          "" -> "Standart"
          t -> t
        }),
      ]),
    ]),
    el("div", "room-card-title", [
      text(case name {
        "" -> "Oda #" <> code
        n -> n
      }),
    ]),
    el("div", "room-card-status-badges", [
      // Doluluk Durumu
      case occ == "occupied" {
        True ->
          el("span", "badge error", [
            text(
              "Dolu"
              <> case guest {
                "" -> ""
                g -> " (" <> string.slice(g, 0, 12) <> ")"
              },
            ),
          ])
        False -> el("span", "badge success", [text("Boş")])
      },
      // Temizlik Durumu
      case hk {
        "clean" -> el("span", "badge success", [text("Temiz")])
        "dirty" -> el("span", "badge warning", [text("Kirli")])
        "inspecting" -> el("span", "badge info", [text("Kontrolde")])
        _ -> el("span", "badge error", [text("Bakımda")])
      },
    ]),
    // Hızlı Temizlik Durumu Değiştirme Butonları
    el("div", "room-quick-actions", [
      case is_clean {
        True ->
          element.element(
            "form",
            [a.method("post"), a.action("/admin/housekeeping/status")],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              hidden("unit_id", id),
              hidden("status", "dirty"),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-warning")],
                [
                  text("Kirli Yap"),
                ],
              ),
            ],
          )
        False ->
          element.element(
            "form",
            [a.method("post"), a.action("/admin/housekeeping/status")],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              hidden("unit_id", id),
              hidden("status", "clean"),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-success")],
                [
                  text("Temizle"),
                ],
              ),
            ],
          )
      },
      case is_inspecting {
        True -> text("")
        False ->
          element.element(
            "form",
            [a.method("post"), a.action("/admin/housekeeping/status")],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              hidden("unit_id", id),
              hidden("status", "inspecting"),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-info")],
                [
                  text("Kontrol"),
                ],
              ),
            ],
          )
      },
      case is_oos {
        True -> text("")
        False ->
          element.element(
            "form",
            [a.method("post"), a.action("/admin/housekeeping/status")],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              hidden("unit_id", id),
              hidden("status", "out_of_service"),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-danger")],
                [
                  text("Bakım"),
                ],
              ),
            ],
          )
      },
    ]),
  ])
}

fn render_task_row(
  task: List(String),
  csrf: String,
  prop_id: String,
) -> element.Element(Nil) {
  let #(id, room, staff, task_type, status, notes, _created) = case task {
    [id, room, staff, task_type, status, notes, created, ..] -> #(
      id,
      room,
      staff,
      task_type,
      status,
      notes,
      created,
    )
    _ -> #("", "-", "-", "-", "pending", "", "-")
  }

  let type_badge = case task_type {
    "daily_clean" -> el("span", "badge primary", [text("Günlük Temizlik")])
    "checkout_deep" -> el("span", "badge warning", [text("Derin Temizlik")])
    "inspection" -> el("span", "badge info", [text("Denetim")])
    _ -> el("span", "badge secondary", [text("Turndown")])
  }

  let status_badge = case status {
    "completed" -> el("span", "badge success", [text("Tamamlandı")])
    "in_progress" -> el("span", "badge info", [text("Süreçte")])
    "inspected" -> el("span", "badge primary", [text("Onaylandı")])
    _ -> el("span", "badge warning", [text("Bekliyor")])
  }

  element.element("tr", [], [
    element.element("td", [], [el("strong", "", [text(room)])]),
    element.element("td", [], [text(staff)]),
    element.element("td", [], [type_badge]),
    element.element("td", [], [
      status_badge,
      case notes {
        "" -> text("")
        n -> el("p", "muted text-xs mb-0 mt-1", [text(n)])
      },
    ]),
    element.element("td", [], [
      case status {
        "completed" | "inspected" ->
          el("span", "text-muted text-xs", [text("Bitti")])
        "in_progress" ->
          element.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/housekeeping/task/" <> id <> "/status"),
            ],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              hidden("status", "completed"),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-success")],
                [
                  icons.check(),
                  text(" Tamamla"),
                ],
              ),
            ],
          )
        _ ->
          element.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/housekeeping/task/" <> id <> "/status"),
            ],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              hidden("status", "in_progress"),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-info")],
                [
                  icons.sparkles(),
                  text(" Başlat"),
                ],
              ),
            ],
          )
      },
    ]),
  ])
}

fn render_ticket_row(
  ticket: List(String),
  csrf: String,
  prop_id: String,
) -> element.Element(Nil) {
  let #(id, room, title, desc, priority, status, reported, _created) = case
    ticket
  {
    [id, room, title, desc, priority, status, reported, created, ..] -> #(
      id,
      room,
      title,
      desc,
      priority,
      status,
      reported,
      created,
    )
    _ -> #("", "-", "-", "-", "medium", "open", "-", "-")
  }

  let priority_badge = case priority {
    "urgent" -> el("span", "badge error", [text("Acil")])
    "low" -> el("span", "badge secondary", [text("Düşük")])
    _ -> el("span", "badge warning", [text("Normal")])
  }

  let status_badge = case status {
    "resolved" -> el("span", "badge success", [text("Çözüldü")])
    _ -> el("span", "badge error", [text("Açık")])
  }

  element.element("tr", [], [
    element.element("td", [], [el("strong", "", [text(room)])]),
    element.element("td", [], [
      el("strong", "", [text(title)]),
      case desc {
        "" -> text("")
        d -> el("p", "muted text-xs mb-0", [text(d)])
      },
    ]),
    element.element("td", [], [priority_badge]),
    element.element("td", [], [
      status_badge,
      el("p", "muted text-xs mb-0", [text("Bildiren: " <> reported)]),
    ]),
    element.element("td", [], [
      case status {
        "resolved" -> el("span", "text-muted text-xs", [text("Tamamlandı")])
        _ ->
          element.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/housekeeping/maintenance/" <> id <> "/resolve"),
            ],
            [
              hidden("csrf", csrf),
              hidden("property_id", prop_id),
              element.element(
                "button",
                [a.type_("submit"), a.class("btn-xs btn-outline-success")],
                [
                  icons.check(),
                  text(" Çöz"),
                ],
              ),
            ],
          )
      },
    ]),
  ])
}
