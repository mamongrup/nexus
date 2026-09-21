import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  workspace: String,
  rows: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Departmanlar",
    el("div", "", [
      el("h1", "", [
        text(case workspace {
          "nexus" -> "NEXUS departmanları"
          _ -> "Tedarikçi departmanları"
        }),
      ]),
      el("p", "muted", [
        text(
          "İşletmenizin kurumsal yapısındaki departmanları (Ön Büro, Kat Hizmetleri, Muhasebe, Satın Alma, Satış ve Teknik Servis) tanımlayın ve yetki sınırlarını yönetin.",
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
                ["Kod", "Departman", "Açıklama", "Durum", "İşlem"],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(rows, fn(row) {
              case row {
                [code, name, description, status] ->
                  el("tr", "", [
                    el("td", "", [text(code)]),
                    el("td", "", [text(name)]),
                    el("td", "", [text(description)]),
                    el("td", "", [text(status)]),
                    el("td", "", [
                      element.element(
                        "form",
                        [
                          a.attribute("method", "post"),
                          a.attribute("action", "/admin/departments"),
                        ],
                        [
                          hidden("csrf", csrf),
                          hidden("workspace", workspace),
                          hidden("code", code),
                          hidden("status", case status {
                            "active" -> "paused"
                            _ -> "active"
                          }),
                          element.element("button", [a.class("button small")], [
                            text(case status {
                              "active" -> "Pasifleştir"
                              _ -> "Aktifleştir"
                            }),
                          ]),
                        ],
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
