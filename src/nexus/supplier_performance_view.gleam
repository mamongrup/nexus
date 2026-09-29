import gleam/list
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(
  s: Session,
  csrf: String,
  metrics: List(List(String)),
  settlements: List(List(String)),
) {
  view.shell(
    s,
    csrf,
    "Tedarikçi Performansı",
    el("div", "page-stack", [
      el("div", "content-header", [
        el("div", "eyebrow", [text("TEDARİKÇİ · OPERASYON VE FİNANS")]),
        el("h1", "", [text("Performans ve hakediş özeti")]),
        el("p", "muted", [
          text(
            "Yalnızca kuruluşunuzun doğrulanmış ilan, rezervasyon, belge ve hakediş kayıtlarından hesaplanır.",
          ),
        ]),
      ]),
      el(
        "div",
        "stats",
        list.map(metrics, fn(row) {
          case row {
            [label, value] ->
              el("section", "stat", [
                el("p", "muted", [text(label)]),
                el("strong", "number", [text(value)]),
              ])
            _ -> text("")
          }
        }),
      ),
      el("section", "panel", [
        el("h2", "", [text("Para birimine göre hakediş")]),
        el("p", "muted", [
          text(
            "Bekleyen ve ödenmiş net hakedişler ayrı gösterilir. Tutarlar para birimleri arasında toplanmaz.",
          ),
        ]),
        el("div", "table-scroll", [
          el("table", "", [
            el("thead", "", [
              el(
                "tr",
                "",
                list.map(["Para birimi", "Bekleyen", "Ödenen"], fn(label) {
                  el("th", "", [text(label)])
                }),
              ),
            ]),
            el("tbody", "", case settlements {
              [] -> [
                el("tr", "", [
                  el("td", "empty-cell", [text("Henüz hakediş kaydı yok.")]),
                ]),
              ]
              _ ->
                list.map(settlements, fn(row) {
                  case row {
                    [currency, pending, paid] ->
                      el("tr", "", [
                        el("td", "", [text(currency)]),
                        el("td", "", [text(pending <> " " <> currency)]),
                        el("td", "", [text(paid <> " " <> currency)]),
                      ])
                    _ -> text("")
                  }
                })
            }),
          ]),
        ]),
      ]),
      el("p", "muted", [
        text("Ayrıntılı ödeme kaydı için Finans ve Hakediş ekranını açın."),
      ]),
    ]),
  )
}
