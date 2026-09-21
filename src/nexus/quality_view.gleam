import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(s: Session, csrf: String, id: String, rows: List(List(String))) {
  let total = list.length(rows)
  let done =
    list.length(
      list.filter(rows, fn(row) {
        case row {
          [_, "Dolu"] -> True
          _ -> False
        }
      }),
    )
  let score = case total {
    0 -> 0
    _ -> done * 100 / total
  }
  view.shell(
    s,
    csrf,
    "Kategori gereksinimleri",
    el("div", "quality-page", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [text("YAYIN HAZIRLIK KONTROLÜ")]),
          el("h1", "", [text("İlan Kalite & Uygunluk Kontrolü")]),
          el("p", "muted", [
            text(
              "İlanınızın yayına girmeden önceki zorunlu kriter eksiklerini, doluluk oranını ve içerik kalite puanını denetleyin.",
            ),
          ]),
        ]),
        element.element(
          "a",
          [
            a.href("/admin/listings/" <> id <> "/edit"),
            a.class("button primary"),
          ],
          [text("İlanı düzenle")],
        ),
      ]),
      el("section", "panel quality-summary", [
        el("div", "quality-score", [text("%" <> int.to_string(score))]),
        el("div", "quality-summary-copy", [
          el("h2", "", [text(quality_title(score))]),
          el("p", "muted", [
            text(
              int.to_string(done)
              <> " / "
              <> int.to_string(total)
              <> " zorunlu alan tamamlandı",
            ),
          ]),
          element.element("div", [a.class("quality-meter")], [
            element.element(
              "span",
              [
                a.style("width", int.to_string(score) <> "%"),
              ],
              [],
            ),
          ]),
        ]),
      ]),
      el("p", "muted", [
        text(
          "NEXUS incelemesine göndermeden önce kırmızı işaretli alanları tamamlayın. Kategori alanları, açıklama ve SEO bilgileri bu puana dahildir.",
        ),
      ]),
      el(
        "section",
        "panel quality-checklist",
        list.map(rows, fn(r) {
          case r {
            [label, status] ->
              el("div", "quality-check-row", [
                el("span", "quality-check-icon " <> status_class(status), [
                  text(case status {
                    "Dolu" -> "✓"
                    _ -> "!"
                  }),
                ]),
                el("span", "quality-check-label", [text(label)]),
                el("strong", status_class(status), [text(status)]),
              ])
            _ -> text("")
          }
        }),
      ),
    ]),
  )
}

fn quality_title(score: Int) -> String {
  case score {
    100 -> "İlan incelemeye hazır"
    n if n >= 70 -> "Tamamlanmak üzere"
    _ -> "Eksik bilgiler bulunuyor"
  }
}

fn status_class(status: String) -> String {
  case status {
    "Dolu" -> "is-complete"
    _ -> "is-missing"
  }
}
