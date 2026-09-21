import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/view.{el}

pub fn page(
  s: Session,
  csrf: String,
  cards: List(List(String)),
  message: String,
) {
  let _ = csrf
  view.shell(
    s,
    csrf,
    "İşletme Dijital İkizi & Sağlık Merkezi",
    el("div", "", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [
            text("KURUMSAL DİJİTAL İKİZ · PERFORMANS & RİSK ANALİZİ"),
          ]),
          el("h1", "", [text("İşletme Dijital İkizi & Sağlık Skorları")]),
          el("p", "muted", [
            text(
              "Tesis ve acentelerin operasyonel sağlık, yanıt hızı, takvim doluluğu ve finansal risk göstergelerini tek bir canlı kurumsal analiz ekranında izleyin.",
            ),
          ]),
        ]),
      ]),
      case message {
        "" -> text("")
        m -> el("div", "notice", [text(m)])
      },
      el("section", "panel", [
        el("h2", "", [text("Kurumsal Sağlık & Performans Skorları")]),
        el("p", "muted", [
          text(
            "Sağlık Skoru (onboarding, yanıt hızı, takvim tutarlılığı), Güven Skoru ve Risk Skoru.",
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
                    "Şirket / Marka",
                    "Tür",
                    "Sağlık Skoru",
                    "Güven Skoru",
                    "Risk Skoru",
                    "Toplam Ürün",
                    "Rezervasyon Sayısı",
                    "Brüt Hacim (GMV)",
                  ],
                  fn(h) { el("th", "", [text(h)]) },
                ),
              ),
            ]),
            el("tbody", "", case cards {
              [] -> [
                el("tr", "", [
                  element.element("td", [a.attribute("colspan", "8")], [
                    text("Henüz skorlanmış iş ortağı kaydı yok."),
                  ]),
                ]),
              ]
              _ ->
                list.map(cards, fn(r) {
                  case r {
                    [
                      _id,
                      name,
                      kind,
                      health,
                      trust,
                      risk,
                      prod_cnt,
                      res_cnt,
                      rev,
                    ] ->
                      el(
                        "tr",
                        "",
                        list.map(
                          [
                            name,
                            case kind {
                              "nexus" -> "NEXUS Merkez"
                              "agency" -> "Acente"
                              _ -> "Tedarikçi"
                            },
                            "%" <> health,
                            "%" <> trust,
                            "%" <> risk,
                            prod_cnt,
                            res_cnt,
                            rev <> " TL",
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
        el("h2", "", [
          text("AI Destekli Nakit Akış Tahmini (Cash-Flow Forecast)"),
        ]),
        el("p", "muted", [
          text(
            "Rezervasyon temposu ve sezonluk trendlere dayalı 7 / 30 / 90 günlük dinamik likidite projeksiyonu.",
          ),
        ]),
        el("div", "stats", [
          view.stat(
            "7 Günlük Tahmin",
            7,
            "Kısa vadeli tahakkuk eden tahsilat ve hakediş",
          ),
          view.stat(
            "30 Günlük Tahmin",
            30,
            "Orta vadeli kesinleşmiş ve bekleyen rezervasyon akışı",
          ),
          view.stat(
            "90 Günlük Tahmin",
            90,
            "Sezon sonu konsolide nakit dönüşüm beklentisi",
          ),
        ]),
      ]),
    ]),
  )
}
