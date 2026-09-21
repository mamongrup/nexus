import gleam/list
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(s: Session, csrf: String, rows: List(List(String))) {
  view.shell(
    s,
    csrf,
    "AI görevleri",
    el("div", "", [
      el("h1", "", [text("AI görevleri")]),
      el("p", "muted", [
        text("Tedarikçi ilanlarından gelen AI üretim istekleri."),
      ]),
      case rows {
        [] ->
          el("div", "panel notice", [
            text(
              "Henüz AI görevi yok. Tedarikçi ilan ekranındaki AI butonlarından biri kullanıldığında işler burada görünecek.",
            ),
          ])
        _ -> text("")
      },
      el("section", "panel table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                ["Tedarikçi", "İlan", "Alan", "Durum", "Sağlayıcı", "Tarih"],
                fn(h) { el("th", "", [text(h)]) },
              ),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(rows, fn(r) {
              case r {
                [_, supplier, property, capability, status, provider, created] ->
                  el(
                    "tr",
                    "",
                    list.map(
                      [
                        supplier,
                        property,
                        capability,
                        status,
                        provider,
                        created,
                      ],
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
  )
}
