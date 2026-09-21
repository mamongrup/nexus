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
      int.to_string(liras) <> " " <> cur
    }
    Error(_) -> amount_str <> " " <> cur
  }
}

pub fn page(
  s: Session,
  csrf: String,
  employees: List(List(String)),
  candidates: List(List(String)),
  payrolls: List(List(String)),
  message: String,
) -> String {
  let total_emp = list.length(employees)
  let active_emp =
    list.filter(employees, fn(e) {
      case e {
        [_, _, _, _, _, _, _, _, status, ..] -> status == "active"
        _ -> False
      }
    })
    |> list.length

  let total_candidates = list.length(candidates)

  view.shell(
    s,
    csrf,
    "İnsan Kaynakları & Bordro",
    el("div", "campaigns-container", [
      el("header", "page-header", [
        el("div", "", [
          el("span", "badge primary", [text("İK & PERSONEL YÖNETİMİ")]),
          el("h1", "", [
            icons.user(),
            text("İnsan Kaynakları, İşe Alım & Bordro"),
          ]),
          el("p", "muted", [
            text(
              "Tesis personelinizin tüm özlük bilgilerini, işe alım aday havuzunu, mülakat aşamalarını ve aylık maaş/avans ödemelerini tek merkezden yönetin.",
            ),
          ]),
        ]),
        el("div", "header-actions", [
          element.element(
            "a",
            [a.href("/admin/departments"), a.class("button secondary")],
            [
              icons.corporate(),
              text("Departmanlar"),
            ],
          ),
          element.element(
            "a",
            [a.href("/admin/accounting"), a.class("button secondary")],
            [
              icons.accounting(),
              text("Muhasebe & Kasa"),
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

      // KPI Kartları
      el("div", "stats-grid", [
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-blue", [icons.user()]),
          el("div", "", [
            el("span", "kpi-label", [text("Toplam Personel")]),
            el("h2", "kpi-value", [text(int.to_string(total_emp))]),
            el("span", "kpi-sub", [
              text(int.to_string(active_emp) <> " Aktif Çalışan"),
            ]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.briefcase()]),
          el("div", "", [
            el("span", "kpi-label", [text("İşe Alım Aday Havuzu")]),
            el("h2", "kpi-value", [text(int.to_string(total_candidates))]),
            el("span", "kpi-sub", [text("Başvuru & Mülakat aşamasında")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.accounting()]),
          el("div", "", [
            el("span", "kpi-label", [text("Bordro Kayıtları")]),
            el("h2", "kpi-value", [text(int.to_string(list.length(payrolls)))]),
            el("span", "kpi-sub", [text("Son yapılan maaş & avans ödemeleri")]),
          ]),
        ]),
      ]),

      // 1. Yeni Personel Ekleme Formu
      el("div", "panel-card", [
        el("h3", "section-title-with-icon", [
          icons.user_add(),
          text("Yeni Personel Kartı Oluştur"),
        ]),
        el("p", "muted", [
          text(
            "İşe başlayan personelin özlük, departman ve maaş bilgilerini kaydedin.",
          ),
        ]),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/hr/employee"),
            a.class("form modern-form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Ad Soyad *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("full_name"),
                    a.attribute("placeholder", "Örn: Ahmet Yılmaz"),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("T.C. Kimlik / Pasaport No")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("national_id"),
                    a.attribute("placeholder", "11 haneli T.C. No"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Telefon Numarası *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("phone"),
                    a.attribute("placeholder", "0532 000 0000"),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
            ]),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Departman *")]),
                element.element(
                  "select",
                  [a.name("department"), a.class("input-select")],
                  [
                    element.element(
                      "option",
                      [a.value("Ön Büro (Front Office)")],
                      [text("Ön Büro (Front Office)")],
                    ),
                    element.element(
                      "option",
                      [a.value("Kat Hizmetleri (Housekeeping)")],
                      [text("Kat Hizmetleri (Housekeeping)")],
                    ),
                    element.element(
                      "option",
                      [a.value("Yiyecek & İçecek (F&B)")],
                      [text("Yiyecek & İçecek (F&B)")],
                    ),
                    element.element("option", [a.value("Mutfak")], [
                      text("Mutfak"),
                    ]),
                    element.element("option", [a.value("Teknik Servis")], [
                      text("Teknik Servis & Bakım"),
                    ]),
                    element.element(
                      "option",
                      [a.value("Pazarlama & Rezervasyon")],
                      [text("Pazarlama & Rezervasyon")],
                    ),
                    element.element("option", [a.value("Yönetim & Muhasebe")], [
                      text("Yönetim & Muhasebe"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Görevi / Pozisyonu *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("position_title"),
                    a.attribute(
                      "placeholder",
                      "Örn: Resepsiyonist / Kat Şefi / Aşçı",
                    ),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Aylık Net Maaş (TL)")]),
                element.element(
                  "input",
                  [
                    a.type_("number"),
                    a.name("salary"),
                    a.attribute("placeholder", "Örn: 35000"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
            ]),
            el("div", "form-row-2", [
              el("div", "form-group", [
                element.element("label", [], [text("IBAN Numarası")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("iban"),
                    a.attribute(
                      "placeholder",
                      "TR00 0000 0000 0000 0000 0000 00",
                    ),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("E-posta Adresi")]),
                element.element(
                  "input",
                  [
                    a.type_("email"),
                    a.name("email"),
                    a.attribute("placeholder", "ahmet@otel.com"),
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
              [icons.save(), text("Personeli Kaydet")],
            ),
          ],
        ),
      ]),

      // Personel Listesi Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split", [
          el("div", "", [
            el("h3", "section-title-with-icon", [
              icons.document(),
              text("Personel Listesi"),
            ]),
            el("p", "muted", [
              text("Aktif ve izinli çalışanların özlük listesi."),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_emp) <> " Çalışan"),
          ]),
        ]),

        case employees {
          [] ->
            el("div", "empty-state-box", [
              el("p", "muted", [text("Henüz kayıtlı bir personel bulunmuyor.")]),
            ])
          _ ->
            el("div", "table-responsive", [
              element.element("table", [a.class("table modern-table")], [
                element.element("thead", [], [
                  element.element("tr", [], [
                    element.element("th", [], [text("Ad Soyad")]),
                    element.element("th", [], [text("Departman")]),
                    element.element("th", [], [text("Unvan")]),
                    element.element("th", [], [text("Telefon")]),
                    element.element("th", [], [text("Maaş")]),
                    element.element("th", [], [text("Giriş Tarihi")]),
                    element.element("th", [], [text("Durum")]),
                  ]),
                ]),
                element.element(
                  "tbody",
                  [],
                  list.map(employees, fn(row) {
                    case row {
                      [_id, name, dept, pos, phone, sal, cur, sdate, status, ..] -> {
                        element.element("tr", [], [
                          element.element("td", [a.class("font-medium")], [
                            text(name),
                          ]),
                          element.element("td", [], [
                            el("span", "badge dark", [text(dept)]),
                          ]),
                          element.element("td", [], [text(pos)]),
                          element.element("td", [a.class("muted")], [
                            text(phone),
                          ]),
                          element.element("td", [a.class("font-bold")], [
                            text(format_money(sal, cur)),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(sdate),
                          ]),
                          element.element("td", [], [
                            el(
                              "span",
                              case status {
                                "active" -> "badge badge-success"
                                "on_leave" -> "badge badge-info"
                                _ -> "badge dark"
                              },
                              [
                                text(case status {
                                  "active" -> "Aktif"
                                  "on_leave" -> "İzinde"
                                  _ -> "Ayrıldı"
                                }),
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

      // 2. İşe Alım & Mülakat Formu & Tablosu
      el("div", "panel-card", [
        el("h3", "section-title-with-icon", [
          icons.briefcase(),
          text("İşe Alım Aday Havuzu & Mülakat Takibi"),
        ]),
        el("p", "muted", [
          text(
            "Açık pozisyonlara başvuran adayları ve mülakat aşamalarını takip edin.",
          ),
        ]),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/hr/candidate"),
            a.class("form modern-form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Aday Adı Soyadı *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("candidate_name"),
                    a.attribute("placeholder", "Örn: Ayşe Demir"),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Başvurulan Pozisyon *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("position_applied"),
                    a.attribute(
                      "placeholder",
                      "Örn: Kat Hizmetleri Görevlisi / Resepsiyonist",
                    ),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Telefon *")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("phone"),
                    a.attribute("placeholder", "0544 000 0000"),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
            ]),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Süreç Aşaması *")]),
                element.element(
                  "select",
                  [a.name("stage"), a.class("input-select")],
                  [
                    element.element("option", [a.value("applied")], [
                      text("Yeni Başvuru"),
                    ]),
                    element.element("option", [a.value("interview")], [
                      text("Mülakat Planlandı"),
                    ]),
                    element.element("option", [a.value("offered")], [
                      text("Teklif Yapıldı"),
                    ]),
                    element.element("option", [a.value("hired")], [
                      text("İşe Alındı"),
                    ]),
                    element.element("option", [a.value("rejected")], [
                      text("Reddedildi"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Mülakat Tarihi (Varsa)")]),
                element.element(
                  "input",
                  [
                    a.type_("date"),
                    a.name("interview_date"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Değerlendirme Notu")]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.name("notes"),
                    a.attribute(
                      "placeholder",
                      "Örn: 3 yıl otel tecrübesi var, İngilizcesi iyi.",
                    ),
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
              [icons.plus(), text("Adayı Havuza Ekle")],
            ),
          ],
        ),

        // Aday Listesi
        case candidates {
          [] -> text("")
          _ ->
            el("div", "table-responsive margin-top-md", [
              element.element("table", [a.class("table modern-table")], [
                element.element("thead", [], [
                  element.element("tr", [], [
                    element.element("th", [], [text("Aday Adı")]),
                    element.element("th", [], [text("Pozisyon")]),
                    element.element("th", [], [text("Telefon")]),
                    element.element("th", [], [text("Aşama")]),
                    element.element("th", [], [text("Mülakat Tarihi")]),
                    element.element("th", [], [text("Notlar")]),
                    element.element("th", [], [text("Kayıt Tarihi")]),
                  ]),
                ]),
                element.element(
                  "tbody",
                  [],
                  list.map(candidates, fn(crow) {
                    case crow {
                      [
                        _id,
                        cname,
                        cpos,
                        cphone,
                        cstage,
                        idate,
                        cnotes,
                        cdate,
                        ..
                      ] -> {
                        element.element("tr", [], [
                          element.element("td", [a.class("font-medium")], [
                            text(cname),
                          ]),
                          element.element("td", [], [
                            el("span", "badge dark", [text(cpos)]),
                          ]),
                          element.element("td", [a.class("muted")], [
                            text(cphone),
                          ]),
                          element.element("td", [], [
                            el(
                              "span",
                              case cstage {
                                "hired" -> "badge badge-success"
                                "interview" -> "badge badge-info"
                                "offered" -> "badge primary"
                                "rejected" -> "badge badge-danger"
                                _ -> "badge dark"
                              },
                              [
                                text(case cstage {
                                  "hired" -> "İşe Alındı"
                                  "interview" -> "Mülakat"
                                  "offered" -> "Teklif"
                                  "rejected" -> "Reddedildi"
                                  _ -> "Başvuru"
                                }),
                              ],
                            ),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(idate),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(cnotes),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(cdate),
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

      // 3. Maaş & Avans Ödeme Girişi
      el("div", "panel-card", [
        el("h3", "section-title-with-icon", [
          icons.accounting(),
          text("Maaş, Avans & Prim Bordro Ödemesi"),
        ]),
        el("p", "muted", [
          text(
            "Personele yapılan maaş veya avans ödemelerini kaydedin; dekont takibini yapın.",
          ),
        ]),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/hr/payroll"),
            a.class("form modern-form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Personel Seçin *")]),
                element.element(
                  "select",
                  [
                    a.name("employee_id"),
                    a.class("input-select"),
                    a.attribute("required", "required"),
                  ],
                  [
                    element.element("option", [a.value("")], [
                      text("-- Personel Seçiniz --"),
                    ]),
                    ..list.map(employees, fn(e) {
                      case e {
                        [eid, ename, edept, ..] ->
                          element.element("option", [a.value(eid)], [
                            text(ename <> " (" <> edept <> ")"),
                          ])
                        _ ->
                          element.element("option", [a.value("")], [text("")])
                      }
                    })
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Ödeme Türü *")]),
                element.element(
                  "select",
                  [a.name("payment_type"), a.class("input-select")],
                  [
                    element.element("option", [a.value("salary")], [
                      text("Aylık Maaş"),
                    ]),
                    element.element("option", [a.value("advance")], [
                      text("Maaş Avansı"),
                    ]),
                    element.element("option", [a.value("bonus")], [
                      text("Prim / İkramiye"),
                    ]),
                    element.element("option", [a.value("overtime")], [
                      text("Fazla Mesai Ücreti"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Tutar (TL) *")]),
                element.element(
                  "input",
                  [
                    a.type_("number"),
                    a.name("amount"),
                    a.attribute("step", "0.01"),
                    a.attribute("placeholder", "Örn: 25000"),
                    a.attribute("required", "required"),
                    a.class("input-text"),
                  ],
                  [],
                ),
              ]),
            ]),
            el("div", "form-group", [
              element.element("label", [], [text("Banka Dekont No / Referans")]),
              element.element(
                "input",
                [
                  a.type_("text"),
                  a.name("reference_no"),
                  a.attribute("placeholder", "Örn: DEK-2026-08912"),
                  a.class("input-text"),
                ],
                [],
              ),
            ]),
            element.element(
              "button",
              [
                a.class("button primary"),
                a.attribute("type", "submit"),
              ],
              [icons.save(), text("Ödemeyi Kaydet")],
            ),
          ],
        ),

        // Ödeme Listesi
        case payrolls {
          [] -> text("")
          _ ->
            el("div", "table-responsive margin-top-md", [
              element.element("table", [a.class("table modern-table")], [
                element.element("thead", [], [
                  element.element("tr", [], [
                    element.element("th", [], [text("Personel")]),
                    element.element("th", [], [text("Tür")]),
                    element.element("th", [], [text("Tutar")]),
                    element.element("th", [], [text("Dönem")]),
                    element.element("th", [], [text("Ödeme Tarihi")]),
                    element.element("th", [], [text("Dekont No")]),
                    element.element("th", [], [text("Durum")]),
                  ]),
                ]),
                element.element(
                  "tbody",
                  [],
                  list.map(payrolls, fn(prow) {
                    case prow {
                      [
                        _pid,
                        emp_name,
                        ptype,
                        pamount,
                        pcur,
                        pperiod,
                        pdate,
                        pstatus,
                        pref,
                        ..
                      ] -> {
                        element.element("tr", [], [
                          element.element("td", [a.class("font-medium")], [
                            text(emp_name),
                          ]),
                          element.element("td", [], [
                            el("span", "badge dark", [
                              text(case ptype {
                                "salary" -> "Maaş"
                                "advance" -> "Avans"
                                "bonus" -> "Prim"
                                _ -> "Mesai"
                              }),
                            ]),
                          ]),
                          element.element(
                            "td",
                            [a.class("font-bold text-green")],
                            [text(format_money(pamount, pcur))],
                          ),
                          element.element("td", [a.class("muted")], [
                            text(pperiod),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(pdate),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(case pref {
                              "" -> "-"
                              _ -> pref
                            }),
                          ]),
                          element.element("td", [], [
                            el(
                              "span",
                              case pstatus {
                                "paid" -> "badge badge-success"
                                _ -> "badge dark"
                              },
                              [
                                text(case pstatus {
                                  "paid" -> "Ödendi"
                                  _ -> "Bekliyor"
                                }),
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
