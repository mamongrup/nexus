import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(
  s: Session,
  csrf: String,
  rules: List(List(String)),
  calculation_result: String,
  message: String,
) {
  let _ = csrf
  view.shell(
    s,
    csrf,
    "Ticari Fiyatlama & Komisyon Motoru",
    el("div", "", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [
            text("DİNAMİK FİYATLAMA · KOMİSYON & TİCARİ KURALLAR"),
          ]),
          el("h1", "", [text("Fiyatlama, Komisyon & Markup Motoru")]),
          el("p", "muted", [
            text(
              "Tedarikçi taban maliyeti, kanal komisyonu, acente kâr marjı (markup) ve vergi dilimlerini kural önceliklerine göre dinamik olarak hesaplayın ve canlı simüle edin.",
            ),
          ]),
        ]),
      ]),
      case message {
        "" -> text("")
        m -> el("div", "notice", [text(m)])
      },
      case calculation_result {
        "" -> text("")
        calc ->
          el("section", "panel callout", [
            el("h2", "", [text("Canlı Fiyatlama Hesabı Simülasyonu")]),
            el("pre", "code-block", [text(calc)]),
          ])
      },
      el("section", "panel", [
        el("h2", "", [text("Kural Hiyerarşisi ve Öncelik Sıralaması")]),
        el("p", "muted", [
          text(
            "Öncelik sırası: Özel Kontrat (100) > Tarih Kuralı (50) > Kanal Kuralı (40) > Acente Kuralı (30) > Ürün Kuralı (20) > Tedarikçi Varsayılanı (10)",
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
                    "Kural ID",
                    "Kural Adı",
                    "Kural Tipi",
                    "Öncelik",
                    "Kanal",
                    "Tedarikçi Komisyonu",
                    "Acente Markup",
                    "NEXUS Payı",
                    "Durum",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el("tbody", "", case rules {
              [] -> [
                el("tr", "", [
                  element.element("td", [a.attribute("colspan", "9")], [
                    text(
                      "Henüz özel ticari kural tanımlanmamış. Varsayılan kural geçerlidir.",
                    ),
                  ]),
                ]),
              ]
              _ ->
                list.map(rules, fn(r) {
                  case r {
                    [id, name, ktype, prio, channel, comm, markup, take, status] ->
                      el(
                        "tr",
                        "",
                        list.map(
                          [
                            id,
                            name,
                            ktype,
                            prio,
                            channel,
                            comm,
                            markup,
                            take,
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
        el("h2", "", [text("NEXUS Fiyatlama Formülü Akışı")]),
        el("div", "formula-box", [
          el("ol", "formula-steps", [
            el("li", "", [
              el("strong", "", [text("1. Liste Fiyatı (List Price): ")]),
              text("Tedarikçinin gecelik baz fiyatı x Gece sayısı"),
            ]),
            el("li", "", [
              el("strong", "", [text("2. Tedarikçi Komisyonu: ")]),
              text(
                "Geçerli komisyon kuralına göre liste fiyatından düşülür -> Tedarikçi Net Tutarı",
              ),
            ]),
            el("li", "", [
              el("strong", "", [text("3. NEXUS Platform Bedeli: ")]),
              text("Platform altyapı ve ödeme hizmet bedeli eklenir"),
            ]),
            el("li", "", [
              el("strong", "", [text("4. Acente Özel Markup / Payı: ")]),
              text(
                "Acente sözleşmesine veya B2B kanalına göre kâr payı eklenir",
              ),
            ]),
            el("li", "", [
              el("strong", "", [text("5. Vergiler & KDV: ")]),
              text(
                "Hizmet tutarları üzerine yasal vergi oranı eklenerek Müşteri Satış Fiyatı (Sell Price) dondurulur",
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  )
}
