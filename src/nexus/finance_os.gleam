import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(
  s: Session,
  csrf: String,
  journals: List(List(String)),
  settlements: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Finans & Hakediş Takası",
    el("div", "", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [
            text("ÇİFT TARAFLI DEFTER-İ KEBİR · HAKEDİŞ & CARİ TAKAS"),
          ]),
          el("h1", "", [text("Finans, Hakediş & Mutabakat")]),
          el("p", "muted", [
            text(
              "Rezervasyon bazlı finansal kayıtları, çift taraflı defter-i kebir borç/alacak hareketlerini, tedarikçi net hakedişlerini ve acente komisyon mutabakatlarını anlık takip edin.",
            ),
          ]),
        ]),
      ]),
      case message {
        "" -> text("")
        m -> el("div", "notice", [text(m)])
      },
      el("section", "panel", [
        el("h2", "", [text("Hakediş ve Takas Durumu (Settlements & Payouts)")]),
        el("p", "muted", [
          text(
            "Tedarikçi net hakedişi, acente komisyon/markup payı ve NEXUS platform payı.",
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
                    "Takas ID",
                    "Rezervasyon",
                    "Tedarikçi",
                    "Satış Kanalı / Acente",
                    "Toplam Tutar",
                    "Tedarikçi Net",
                    "NEXUS Payı",
                    "Acente Payı",
                    "Durum",
                    "Ödeme Tarihi",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el("tbody", "", case settlements {
              [] -> [
                el("tr", "", [
                  element.element("td", [a.attribute("colspan", "10")], [
                    text("Henüz kesinleşmiş takas/hakediş kaydı bulunmuyor."),
                  ]),
                ]),
              ]
              _ ->
                list.map(settlements, fn(r) {
                  case r {
                    [
                      _id,
                      res,
                      supp,
                      ag,
                      gross,
                      net,
                      nexus_fee,
                      agency_markup,
                      status,
                      due,
                    ] ->
                      el(
                        "tr",
                        "",
                        list.map(
                          [
                            "TAK-" <> res,
                            res,
                            supp,
                            ag,
                            gross,
                            net,
                            nexus_fee,
                            agency_markup,
                            status,
                            due,
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
        el("h2", "", [text("Çift Taraflı Yevmiye Defteri (Journals & Lines)")]),
        el("p", "muted", [
          text(
            "Her rezervasyon işleminde Borç (Debit) ve Alacak (Credit) eşitliği garanti edilir (Immutable Double-Entry Ledger).",
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
                    "Yevmiye No",
                    "Tarih",
                    "Tüzel Kişilik / Şirket",
                    "Para Birimi",
                    "Durum",
                    "Toplam Borç (Debit)",
                    "Toplam Alacak (Credit)",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el("tbody", "", case journals {
              [] -> [
                el("tr", "", [
                  element.element("td", [a.attribute("colspan", "7")], [
                    text("Henüz kaydedilmiş çift taraflı muhasebe fişi yok."),
                  ]),
                ]),
              ]
              _ ->
                list.map(journals, fn(r) {
                  case r {
                    [id, dt, org, curr, state, debit, credit] ->
                      el(
                        "tr",
                        "",
                        list.map(
                          [id, dt, org, curr, state, debit, credit],
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
    ]),
  )
}
