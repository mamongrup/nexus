import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  roles: List(List(String)),
  actions: List(List(String)),
  insights: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "AI Komuta & Yönetişim Merkezi",
    el("div", "", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [text("AI WORKFORCE ORCHESTRATION & GOVERNANCE")]),
          el("h1", "", [text("AI Çalışan & Karar Merkezi")]),
          el("p", "muted", [
            text(
              "Worker -> Manager -> Director -> AI GM hiyerarşisi, otonomi seviyeleri ve insan onay merkezi.",
            ),
          ]),
        ]),
      ]),
      case message {
        "" -> text("")
        m -> el("div", "notice", [text(m)])
      },
      el("section", "panel", [
        el("h2", "", [text("AI General Manager · 5 Kritik Risk ve Fırsat")]),
        el("p", "muted", [
          text(
            "AI GM tarafından proaktif olarak tespit edilen, sorumlusu ve son tarihi belirlenmiş yönetim öngörüleri.",
          ),
        ]),
        el("div", "table-scroll", [
          el("table", "", [
            el("thead", "", [
              el(
                "tr",
                "",
                list.map(
                  [
                    "Tür",
                    "Başlık",
                    "Açıklama",
                    "Sorumlu Rol",
                    "Termin",
                    "Beklenen Etki",
                    "Öncelik",
                    "Durum",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el("tbody", "", case insights {
              [] -> [
                el("tr", "", [
                  element.element("td", [a.attribute("colspan", "8")], [
                    text("Henüz kayıtlı kritik risk veya fırsat yok."),
                  ]),
                ]),
              ]
              _ ->
                list.map(insights, fn(r) {
                  case r {
                    [
                      _id,
                      itype,
                      title,
                      desc,
                      owner,
                      deadline,
                      impact,
                      prio,
                      status,
                    ] ->
                      el(
                        "tr",
                        "",
                        list.map(
                          [
                            case itype {
                              "risk" -> "Risk"
                              _ -> "Fırsat"
                            },
                            title,
                            desc,
                            owner,
                            deadline,
                            impact,
                            "P" <> prio,
                            status,
                          ],
                          fn(v) { el("td", "", [text(v)]) },
                        ),
                      )
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),
      ]),
      el("section", "panel", [
        el("h2", "", [text("AI Workforce Rol Hiyerarşisi & Yetki Matrisi")]),
        el("p", "muted", [
          text(
            "Politika sınırları: AUTO (otonom), RECOMMEND (öneri), APPROVAL (onay şartı), HUMAN_ONLY (AI başlatamaz).",
          ),
        ]),
        el("div", "table-scroll", [
          el("table", "", [
            el("thead", "", [
              el(
                "tr",
                "",
                list.map(
                  [
                    "Rol Kodu",
                    "Ünvan",
                    "Kademe",
                    "Yetki Seviyesi",
                    "Bekleyen Onay",
                    "Uygulanan Eylem",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el(
              "tbody",
              "",
              list.map(roles, fn(r) {
                case r {
                  [code, title, tier, auth_lvl, pending, executed] ->
                    el(
                      "tr",
                      "",
                      list.map(
                        [code, title, tier, auth_lvl, pending, executed],
                        fn(v) { el("td", "", [text(v)]) },
                      ),
                    )
                  _ -> text("")
                }
              }),
            ),
          ]),
        ]),
      ]),
      el("section", "panel", [
        el("h2", "", [text("AI Action Bus · Karar & Onay Akışı")]),
        el("p", "muted", [
          text(
            "Yüksek riskli veya APPROVAL yetkili AI kararları insan onayı bekler. Tek tıkla onaylayabilir veya reddedebilirsiniz.",
          ),
        ]),
        el("div", "table-scroll", [
          el("table", "", [
            el("thead", "", [
              el(
                "tr",
                "",
                list.map(
                  [
                    "Zaman",
                    "Rol",
                    "Eylem Türü",
                    "Yetki",
                    "Risk",
                    "Gerekçe",
                    "Durum",
                    "İşlem",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el("tbody", "", case actions {
              [] -> [
                el("tr", "", [
                  element.element("td", [a.attribute("colspan", "8")], [
                    text("Henüz AI eylem kaydı bulunmuyor."),
                  ]),
                ]),
              ]
              _ ->
                list.map(actions, fn(r) {
                  case r {
                    [
                      id,
                      role_title,
                      act_type,
                      auth_lvl,
                      status,
                      risk,
                      _res,
                      just,
                      created,
                    ] ->
                      el("tr", "", [
                        el("td", "", [text(created)]),
                        el("td", "", [text(role_title)]),
                        el("td", "", [text(act_type)]),
                        el("td", "", [text(auth_lvl)]),
                        el("td", "", [text("%" <> risk)]),
                        el("td", "", [text(just)]),
                        el("td", "", [text(status)]),
                        el("td", "", [
                          case status {
                            "pending_approval" ->
                              el("div", "action-buttons", [
                                element.element(
                                  "form",
                                  [
                                    a.attribute("method", "post"),
                                    a.attribute(
                                      "action",
                                      "/admin/ai/actions/" <> id <> "/decide",
                                    ),
                                    a.class("inline-form"),
                                  ],
                                  [
                                    hidden("csrf", csrf),
                                    hidden("decision", "approved"),
                                    element.element(
                                      "button",
                                      [
                                        a.class("button primary small"),
                                        a.attribute("type", "submit"),
                                      ],
                                      [icons.check(), text(" Onayla")],
                                    ),
                                  ],
                                ),
                                element.element(
                                  "form",
                                  [
                                    a.attribute("method", "post"),
                                    a.attribute(
                                      "action",
                                      "/admin/ai/actions/" <> id <> "/decide",
                                    ),
                                    a.class("inline-form"),
                                  ],
                                  [
                                    hidden("csrf", csrf),
                                    hidden("decision", "rejected"),
                                    element.element(
                                      "button",
                                      [
                                        a.class("button secondary small"),
                                        a.attribute("type", "submit"),
                                      ],
                                      [icons.trash(), text(" Reddet")],
                                    ),
                                  ],
                                ),
                              ])
                            _ -> text("Tamamlandı")
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
  )
}
