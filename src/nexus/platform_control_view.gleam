import gleam/list
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/view

pub fn page(s: Session, csrf: String, rows: List(List(String))) -> String {
  view.shell(
    s,
    csrf,
    "Platform denetimleri",
    view.el("section", "admin-section", [
      view.el("div", "page-heading", [
        view.el("h1", "", [text("Platform denetimleri")]),
        view.el("p", "muted", [
          text(
            "Tüm tenantlar için canlı, toplulaştırılmış sonuçlar. Ayrıntılı işlemler ilgili yönetim ekranındadır.",
          ),
        ]),
      ]),
      view.el("div", "control-check-grid", list.map(rows, check_card)),
    ]),
  )
}

fn check_card(row: List(String)) -> Element(Nil) {
  case row {
    [title, status, metric, href, detail] ->
      view.el("article", "control-check-card", [
        view.el("div", "control-check-heading", [
          view.el("h2", "", [text(title)]),
          view.el(
            "span",
            case status {
              "ok" -> "control-ok"
              _ -> "control-attention"
            },
            [
              text(case status {
                "ok" -> "Normal"
                _ -> "İnceleme gerekli"
              }),
            ],
          ),
        ]),
        view.el("strong", "control-check-metric", [text(metric)]),
        view.el("p", "muted", [text(detail)]),
        element.element("a", [a.href(href), a.class("button secondary")], [
          text("Yönet"),
        ]),
      ])
    _ -> view.el("div", "", [])
  }
}
