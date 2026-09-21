import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el, hidden}

pub fn queue(
  s: Session,
  csrf: String,
  rows: List(List(String)),
  documents: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Tedarikçi başvuruları",
    el("div", "", [
      el("h1", "", [text("Tedarikçi başvuruları")]),
      el("p", "muted", [
        text(
          "Platforma başvuran tedarikçilerin kurumsal evraklarını, vergi levhalarını ve kimlik doğrulama süreçlerini inceleyin ve onaylayın.",
        ),
      ]),
      case message {
        "" -> text("")
        _ -> el("p", "notice", [text(message)])
      },
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                ["Başvuru", "İşletme", "Kategori", "Kimlik", "Durum", "İşlem"],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(rows, fn(row) {
              case row {
                [id, legal, category, identity, status, _created] ->
                  el("tr", "", [
                    el("td", "", [text(id)]),
                    el("td", "", [text(legal)]),
                    el("td", "", [text(category)]),
                    el("td", "", [text(identity)]),
                    el("td", "", [text(status)]),
                    el("td", "", [
                      case domain.can_manage_documents(s.role) {
                        True ->
                          el("div", "form-actions", [
                            decision(csrf, id, "verified", "Kimlik doğrulandı"),
                            decision(csrf, id, "failed", "Kimlik reddedildi"),
                            decision(csrf, id, "approved", "Onayla"),
                            decision(csrf, id, "rejected", "Reddet"),
                          ])
                        False ->
                          el("span", "badge muted", [text("Karar yetkisi yok")])
                      }
                    ]),
                  ])
                _ -> text("")
              }
            }),
          ),
        ]),
      ]),
      el("h2", "", [text("Başvuru belgeleri")]),
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(["İşletme", "Belge", "Dosya", "Durum", "İşlem"], fn(h) {
                el("th", "", [text(h)])
              }),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(documents, fn(row) {
              case row {
                [id, legal, label, name, url, status] ->
                  el("tr", "", [
                    el("td", "", [text(legal)]),
                    el("td", "", [text(label)]),
                    el("td", "", [
                      element.element(
                        "a",
                        [
                          a.href(document_href(url)),
                          a.attribute("target", "_blank"),
                          a.attribute("rel", "noopener noreferrer"),
                        ],
                        [text(name)],
                      ),
                    ]),
                    el("td", "", [text(status)]),
                    el("td", "", [
                      case domain.can_manage_documents(s.role) {
                        True ->
                          el("div", "form-actions", [
                            document_decision(csrf, id, "accepted", "Kabul et"),
                            document_decision(csrf, id, "rejected", "Reddet"),
                          ])
                        False ->
                          el("span", "badge muted", [text("İnceleme yetkisi yok")])
                      }
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

pub fn supplier_page(
  s: Session,
  csrf: String,
  applications: List(List(String)),
  categories: List(List(String)),
  documents: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Başvuru ve belgeler",
    el("div", "supplier-onboarding", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [text("TEDARİKÇİ ONBOARDING")]),
          el("h1", "", [text("Başvuru ve belge merkezi")]),
          el("p", "muted", [
            text(
              "Kimlik ve kategori belgelerinizi tamamlayın; NEXUS onayından sonra ilanlarınızı incelemeye gönderebilirsiniz.",
            ),
          ]),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("p", "notice", [text(message)])
      },
      case applications {
        [] ->
          el("section", "panel", [
            el("h2", "", [text("Başvuru oluştur")]),
            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute("action", "/admin/application"),
              ],
              [
                hidden("csrf", csrf),
                el("label", "field", [
                  text("İşletmenin yasal adı"),
                  element.element(
                    "input",
                    [a.name("legal_name"), a.attribute("required", "")],
                    [],
                  ),
                ]),
                el("div", "form-grid", [
                  el("label", "field", [
                    text("Yetkili ad soyad"),
                    element.element(
                      "input",
                      [
                        a.name("full_name"),
                        a.placeholder("Kimlikte yazdığı biçimde"),
                        a.attribute("required", ""),
                      ],
                      [],
                    ),
                  ]),
                  el("label", "field", [
                    text("T.C. kimlik numarası"),
                    element.element(
                      "input",
                      [
                        a.name("tc"),
                        a.attribute("inputmode", "numeric"),
                        a.attribute("pattern", "[0-9]{11}"),
                        a.attribute("maxlength", "11"),
                        a.placeholder("11 haneli kimlik numarası"),
                        a.attribute("required", ""),
                      ],
                      [],
                    ),
                  ]),
                ]),
                el("p", "identity-privacy-note", [
                  text(
                    "Bilgiler NVI/KPS otomatik doğrulama kuyruğuna alınır. Doğrulama başarısız veya servis erişilemezse NEXUS yöneticisi manuel inceleme yapar; T.C. numarası sistemde açık olarak saklanmaz.",
                  ),
                ]),
                el("label", "field", [
                  text("Faaliyet kategorisi"),
                  element.element(
                    "select",
                    [a.name("category")],
                    list.map(categories, fn(row) {
                      case row {
                        [code, name, _] ->
                          element.element("option", [a.value(code)], [
                            text(name),
                          ])
                        _ -> text("")
                      }
                    }),
                  ),
                ]),
                element.element("button", [a.class("button primary")], [
                  text("Başvuruyu oluştur"),
                ]),
              ],
            ),
          ])
        [[id, category, legal, status, identity, _created], ..] ->
          el("div", "", [
            el("section", "application-hero", [
              el("div", "application-hero-copy", [
                el("span", "application-kicker", [text("İŞLETME BAŞVURUSU")]),
                el("h2", "", [text(legal)]),
                el("div", "application-meta", [
                  el("span", "", [text("Kategori · " <> category)]),
                  el("span", "", [text("Başvuru · " <> status_label(status))]),
                  el("span", "", [text("Kimlik · " <> identity_label(identity))]),
                ]),
              ]),
              el("div", "application-score", [
                el("strong", "", [
                  text(int.to_string(document_score(documents)) <> "%"),
                ]),
                el("span", "", [text("Belge hazırlığı")]),
              ]),
            ]),
            el("section", "onboarding-progress", [
              progress_step("1", "Başvuru", True),
              progress_step("2", "Kimlik", identity == "verified"),
              progress_step("3", "Belgeler", document_score(documents) == 100),
              progress_step(
                "4",
                "NEXUS onayı",
                status == "approved"
                  && identity == "verified"
                  && document_score(documents) == 100,
              ),
            ]),
            el("div", "document-section-heading", [
              el("div", "", [
                el("h2", "", [text("Zorunlu belgeler")]),
                el("p", "muted", [
                  text(
                    "Her karttan PDF, JPG veya PNG dosyanızı seçip doğrudan NEXUS incelemesine gönderin.",
                  ),
                ]),
              ]),
              el("span", "badge neutral", [
                text(int.to_string(list.length(documents)) <> " belge"),
              ]),
            ]),
            el(
              "div",
              "document-grid",
              list.map(documents, fn(row) {
                case row {
                  [requirement, label, required, name, url, document_status] ->
                    el("section", "document-card " <> document_status, [
                      el("div", "document-card-head", [
                        el("span", "document-icon", [
                          text(document_icon(document_status)),
                        ]),
                        el("div", "", [
                          el("h3", "", [text(label)]),
                          el("span", "document-requirement", [
                            text(case required {
                              "true" -> "Zorunlu belge"
                              _ -> "İsteğe bağlı"
                            }),
                          ]),
                        ]),
                        el("span", "document-status " <> document_status, [
                          text(document_status_label(document_status)),
                        ]),
                      ]),
                      case name {
                        "" ->
                          el("p", "document-empty", [
                            text("Henüz belge gönderilmedi"),
                          ])
                        _ ->
                          el("div", "document-current", [
                            el("div", "", [
                              el("small", "", [text("Yüklenen belge")]),
                              el("strong", "", [text(name)]),
                            ]),
                            element.element(
                              "a",
                              [
                                a.href(document_href(url)),
                                a.attribute("target", "_blank"),
                                a.attribute("rel", "noopener noreferrer"),
                                a.class("button small"),
                              ],
                              [text("Görüntüle ↗")],
                            ),
                          ])
                      },
                      element.element(
                        "form",
                        [
                          a.class("document-upload-form"),
                          a.attribute("method", "post"),
                          a.attribute("enctype", "multipart/form-data"),
                          a.attribute(
                            "action",
                            "/admin/application/" <> id <> "/document",
                          ),
                        ],
                        [
                          hidden("csrf", csrf),
                          hidden("requirement", requirement),
                          el("label", "file-drop-field", [
                            el("span", "file-drop-icon", [text("↑")]),
                            el("span", "file-drop-copy", [
                              el("strong", "", [
                                text("Bilgisayarınızdan belge seçin"),
                              ]),
                              el("small", "", [
                                text("PDF, JPG veya PNG · En fazla 10 MB"),
                              ]),
                            ]),
                            element.element(
                              "input",
                              [
                                a.name("document"),
                                a.attribute("type", "file"),
                                a.attribute(
                                  "accept",
                                  ".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png",
                                ),
                                a.attribute("required", ""),
                              ],
                              [],
                            ),
                          ]),
                          element.element(
                            "button",
                            [a.class("button primary small")],
                            [
                              text(case name {
                                "" -> "İncelemeye gönder"
                                _ -> "Belgeyi güncelle"
                              }),
                            ],
                          ),
                        ],
                      ),
                    ])
                  _ -> text("")
                }
              }),
            ),
          ])
        _ -> text("")
      },
    ]),
  )
}

fn progress_step(number: String, label: String, complete: Bool) {
  el(
    "div",
    "onboarding-step "
      <> case complete {
      True -> "complete"
      False -> "pending"
    },
    [
      el("span", "", [
        text(case complete {
          True -> "✓"
          False -> number
        }),
      ]),
      el("strong", "", [text(label)]),
    ],
  )
}

fn document_score(documents: List(List(String))) -> Int {
  let total = list.length(documents)
  let complete =
    list.length(
      list.filter(documents, fn(row) {
        case row {
          [_, _, _, _, _, "accepted"] -> True
          _ -> False
        }
      }),
    )
  case total {
    0 -> 0
    _ -> complete * 100 / total
  }
}

fn status_label(status: String) -> String {
  case status {
    "approved" -> "Onaylandı"
    "pending" -> "İncelemede"
    "rejected" -> "Reddedildi"
    _ -> status
  }
}

fn identity_label(status: String) -> String {
  case status {
    "verified" -> "Doğrulandı"
    "failed" -> "Doğrulanamadı"
    _ -> "Bekliyor"
  }
}

fn document_status_label(status: String) -> String {
  case status {
    "accepted" -> "Onaylandı"
    "submitted" -> "İncelemede"
    "rejected" -> "Düzeltme gerekli"
    _ -> "Eksik"
  }
}

fn document_icon(status: String) -> String {
  case status {
    "accepted" -> "✓"
    "submitted" -> "◷"
    "rejected" -> "!"
    _ -> "+"
  }
}

fn document_href(storage: String) -> String {
  case string.starts_with(storage, "upload:") {
    True -> "/admin/documents/" <> string.drop_start(storage, 7)
    False -> storage
  }
}

fn document_decision(csrf: String, id: String, status: String, label: String) {
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute("action", "/admin/applications/document/" <> id),
    ],
    [
      hidden("csrf", csrf),
      hidden("status", status),
      element.element("button", [a.class("button small")], [text(label)]),
    ],
  )
}

fn decision(csrf: String, id: String, value: String, label: String) {
  let identity = value == "verified" || value == "failed"
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute("action", case identity {
        True -> "/admin/applications/" <> id <> "/identity"
        False -> "/admin/applications/" <> id <> "/decision"
      }),
    ],
    [
      hidden("csrf", csrf),
      hidden(
        case identity {
          True -> "result"
          False -> "decision"
        },
        value,
      ),
      hidden("reason", "NEXUS yönetici işlemi"),
      element.element("button", [a.class("button small")], [text(label)]),
    ],
  )
}
