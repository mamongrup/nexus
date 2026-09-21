import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/booking_status
import nexus/domain
import nexus/icons
import nexus/view.{el}

fn link(url: String, label: String, class: String) {
  element.element("a", [a.href(url), a.class(class)], [text(label)])
}

pub fn render_catalog(
  items: List(List(String)),
  q: String,
  category: String,
  locality: String,
) -> Element(Nil) {
  el("div", "marketplace-container", [
    el("div", "marketplace-hero", [
      el("div", "hero-badge", [text("NEXUS CANLI REZERVASYON & PAZARYERİ")]),
      el("h1", "hero-title", [text("Türkiye'nin En Seçkin Tatil Deneyimleri")]),
      el("p", "hero-subtitle", [
        text(
          "Lüks villalardan tarihi Boğaz otellerine, mavi tur guletlerinden mağara süitlerine anlık rezervasyon.",
        ),
      ]),
      element.element(
        "form",
        [
          a.attribute("method", "get"),
          a.attribute("action", "/ilanlar"),
          a.class("marketplace-search-bar"),
        ],
        [
          el("div", "search-field", [
            el("label", "", [text("Nereye?")]),
            element.element(
              "input",
              [
                a.type_("text"),
                a.name("q"),
                a.value(q),
                a.placeholder("Bodrum, İstanbul, Göcek, Kapadokya..."),
              ],
              [],
            ),
          ]),
          el("div", "search-field", [
            el("label", "", [text("Kategori")]),
            element.element(
              "select",
              [a.name("category")],
              list.map(
                [
                  #("", "Tüm Kategoriler"),
                  #("villa", "Villa & Tatil Evi"),
                  #("hotel", "Otel & Butik Konaklama"),
                  #("yacht", "Yat & Mavi Tur"),
                  #("tour", "Tur & Deneyim"),
                ],
                fn(pair) {
                  let #(val, lbl) = pair
                  element.element(
                    "option",
                    [
                      a.value(val),
                      case val == category {
                        True -> a.attribute("selected", "selected")
                        False -> a.class("")
                      },
                    ],
                    [text(lbl)],
                  )
                },
              ),
            ),
          ]),
          el("div", "search-field", [
            el("label", "", [text("Konum / Bölge")]),
            element.element(
              "input",
              [
                a.type_("text"),
                a.name("locality"),
                a.value(locality),
                a.placeholder("Muğla, Nevşehir, İzmir..."),
              ],
              [],
            ),
          ]),
          element.element(
            "button",
            [a.type_("submit"), a.class("button primary search-btn")],
            [icons.search(), text(" İlanları Ara")],
          ),
        ],
      ),
    ]),
    el("div", "portal-network-banner", [
      el("span", "pulse-dot", []),
      el("div", "", [
        el("strong", "", [text("B2B Seyahat Portalları Ağı: ")]),
        text("NEXUS altyapısındaki bu envanter, yakında doğrudan "),
        element.element(
          "a",
          [
            a.href("https://www.rezervasyonyap.com.tr"),
            a.attribute("target", "_blank"),
            a.class("portal-tag"),
          ],
          [text("www.rezervasyonyap.com.tr")],
        ),
        text(" ve "),
        element.element(
          "a",
          [
            a.href("https://www.reservastioninturkey.com"),
            a.attribute("target", "_blank"),
            a.class("portal-tag"),
          ],
          [text("www.reservastioninturkey.com")],
        ),
        text(
          " seyahat acentesi tüketici portallarında yayınlanacak ve rezervasyon alacaktır.",
        ),
      ]),
    ]),
    el("div", "marketplace-stats-bar", [
      el("span", "stat-item", [
        el("strong", "", [text(int.to_string(list.length(items)))]),
        text(" Aktif İlan Yayında"),
      ]),
      el("span", "stat-item", [
        el("strong", "", [text("22")]),
        text(" Entegre Modül Aktif"),
      ]),
      el("span", "stat-item", [
        el("strong", "", [text("7/24")]),
        text(" Anlık Onay & KBS Bildirimi"),
      ]),
    ]),
    case items {
      [] ->
        el("div", "empty-state-box", [
          el("p", "", [
            text(
              "Aramanıza uygun ilan bulunamadı. Filtreleri temizleyip tekrar deneyebilirsiniz.",
            ),
          ]),
          link("/ilanlar", "Tüm İlanları Göster", "button"),
        ])
      _ ->
        el(
          "div",
          "marketplace-grid",
          list.map(items, fn(row) {
            case row {
              [
                id,
                title,
                loc,
                _cat_code,
                cap,
                nightly,
                cur,
                desc,
                img,
                amenities_str,
                cat_name,
                ..extra
              ] -> {
                let nightly_int = int.parse(nightly) |> result_unwrap(0)
                let #(campaign_badge, discount_pct) = case extra {
                  [badge, pct, ..] -> #(
                    badge,
                    int.parse(pct) |> result_unwrap(0),
                  )
                  _ -> #("", 0)
                }
                el("div", "marketplace-card", [
                  el("div", "card-media", [
                    element.element(
                      "img",
                      [
                        a.src(img),
                        a.alt(title),
                        a.class("card-img"),
                        a.attribute("loading", "lazy"),
                        a.attribute(
                          "onerror",
                          "this.onerror=null;this.src='https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80';",
                        ),
                      ],
                      [],
                    ),
                    case campaign_badge {
                      "" -> text("")
                      _ ->
                        el("span", "card-campaign-badge", [
                          text(campaign_badge),
                        ])
                    },
                    el("span", "card-category-badge", [text(cat_name)]),
                    el("span", "card-capacity-badge", [text(cap <> " Misafir")]),
                  ]),
                  el("div", "card-body", [
                    el("div", "card-locality flex align-center gap-1", [
                      icons.beach(),
                      text(" " <> loc),
                    ]),
                    el("h3", "card-title", [
                      link("/ilan/" <> id, title, "card-title-link"),
                    ]),
                    el("p", "card-desc", [text(truncate_text(desc, 120))]),
                    el("div", "card-amenities", [
                      el("small", "muted", [
                        text(
                          "Öne Çıkanlar: " <> truncate_text(amenities_str, 60),
                        ),
                      ]),
                    ]),
                    el("div", "card-footer", [
                      el("div", "card-pricing", [
                        case discount_pct > 0 {
                          True -> {
                            let discounted_nightly =
                              nightly_int - { nightly_int * discount_pct / 100 }
                            el("div", "pricing-with-discount", [
                              el("span", "original-price-strikethrough", [
                                text(domain.money(nightly_int, cur)),
                              ]),
                              el("span", "price-amount text-campaign-discount", [
                                text(domain.money(discounted_nightly, cur)),
                              ]),
                              el("span", "price-unit", [text(" / gece")]),
                            ])
                          }
                          False ->
                            el("div", "card-normal-pricing", [
                              el("span", "price-amount", [
                                text(domain.money(nightly_int, cur)),
                              ]),
                              el("span", "price-unit", [text(" / gece")]),
                            ])
                        },
                      ]),
                      link(
                        "/ilan/" <> id,
                        "İncele & Ayırt →",
                        "button primary small",
                      ),
                    ]),
                  ]),
                ])
              }
              _ -> text("")
            }
          }),
        )
    },
  ])
}

pub fn render_detail(
  item: List(String),
  _csrf: String,
  feedback: String,
) -> Element(Nil) {
  render_detail_locale(item, feedback, "tr")
}

pub fn render_detail_locale(
  item: List(String),
  feedback: String,
  lang: String,
) -> Element(Nil) {
  case item {
    [
      _id,
      title,
      loc,
      _cat_code,
      cap,
      nightly,
      cur,
      desc,
      img,
      amenities_str,
      cat_name,
      supplier_name,
      _ver,
      ..extra
    ] -> {
      let #(media_json, video_url) = case extra {
        [m, v, ..] -> #(m, v)
        [m] -> #(m, "")
        _ -> #("[]", "")
      }
      let gallery_urls = parse_media_list(media_json)
      let nightly_int = int.parse(nightly) |> result_unwrap(0)
      el("div", "property-detail-container", [
        link("/ilanlar", "← Tüm İlanlara Dön", "back-link"),
        case feedback {
          "" -> text("")
          msg -> el("div", "flash-message warning", [text(msg)])
        },
        el("div", "property-header-section", [
          el("div", "property-header-main", [
            el("span", "badge primary", [text(cat_name)]),
            el("h1", "property-title", [text(title)]),
            el("p", "property-locality flex align-center gap-1", [
              icons.beach(),
              text(" " <> loc <> " · Sağlayıcı: " <> supplier_name),
            ]),
          ]),
          el("div", "property-header-price", [
            el("span", "nightly-price-badge", [
              el("strong", "", [text(domain.money(nightly_int, cur))]),
              text(" / gece"),
            ]),
          ]),
        ]),
        el("div", "property-detail-grid", [
          el("div", "detail-main-content", [
            el("div", "property-gallery", [
              element.element(
                "img",
                [
                  a.src(img),
                  a.alt(title),
                  a.class("detail-hero-img"),
                  a.attribute("id", "marketplace_main_img"),
                  a.attribute("loading", "lazy"),
                  a.attribute(
                    "onerror",
                    "this.onerror=null;this.src='https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80';",
                  ),
                ],
                [],
              ),
              case gallery_urls {
                [] -> text("")
                urls ->
                  el(
                    "div",
                    "detail-thumbnail-strip",
                    list.map(urls, fn(thumb_url) {
                      element.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("thumb-btn"),
                          a.attribute(
                            "onclick",
                            "document.getElementById('marketplace_main_img').src='"
                              <> thumb_url
                              <> "'",
                          ),
                        ],
                        [
                          element.element(
                            "img",
                            [
                              a.src(thumb_url),
                              a.class("detail-thumb-img"),
                              a.attribute("alt", "Fotoğraf"),
                              a.attribute("loading", "lazy"),
                              a.attribute(
                                "onerror",
                                "this.onerror=null;this.src='https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=400&q=80';",
                              ),
                            ],
                            [],
                          ),
                        ],
                      )
                    }),
                  )
              },
            ]),
            render_video_embed(video_url),
            el("div", "detail-card", [
              el("h2", "", [text("Konaklama Hakkında")]),
              el("p", "description-body", [text(desc)]),
              el("hr", "", []),
              el("h3", "", [text("Özellikler & Olanaklar")]),
              el("div", "amenities-pill-grid", [
                el("span", "amenity-pill flex align-center gap-1", [
                  icons.user(),
                  text(" Kapasite: " <> cap <> " Kişi"),
                ]),
                el("span", "amenity-pill flex align-center gap-1", [
                  icons.security(),
                  text(" KBS Emniyet Bildirimi"),
                ]),
                el("span", "amenity-pill flex align-center gap-1", [
                  icons.whatsapp(),
                  text(" WhatsApp Kapı & Check-in Desteği"),
                ]),
                el("span", "amenity-pill flex align-center gap-1", [
                  icons.document(),
                  text(" Resmi e-Fatura / e-Arşiv"),
                ]),
                el("span", "amenity-pill flex align-center gap-1", [
                  icons.housekeeping(),
                  text(" Profesyonel Temizlik & PMS Takibi"),
                ]),
                el("span", "amenity-pill", [text(amenities_str)]),
              ]),
            ]),
            el("div", "detail-card campaigns-showcase-card", [
              el("div", "campaign-card-header", [
                el("span", "badge primary", [text("GÜNCEL İNDİRİMLER")]),
                el("h3", "section-title-with-icon", [
                  icons.tag(),
                  text("Bu İlanda Geçerli Kampanyalar & Fırsatlar"),
                ]),
              ]),
              el("p", "muted small", [
                text(
                  "Rezervasyon oluştururken tarih şartlarına göre indirim otomatik uygulanır veya kupon kodu girilerek avantaj sağlanır:",
                ),
              ]),
              el("div", "campaigns-benefits-grid", [
                el("div", "campaign-benefit-item", [
                  el("span", "benefit-badge early flex align-center gap-1", [
                    icons.trending_up(),
                    text(" %15 Erken Rezervasyon"),
                  ]),
                  el("span", "muted small", [
                    text("30 gün ve öncesi rezervasyonlarda"),
                  ]),
                ]),
                el("div", "campaign-benefit-item", [
                  el("span", "benefit-badge coupon flex align-center gap-1", [
                    icons.tag(),
                    text(" Kupon: YAZ2026"),
                  ]),
                  el("span", "muted small", [
                    text("Formda kodu girin, %20 indirim kazanın"),
                  ]),
                ]),
                el("div", "campaign-benefit-item", [
                  el("span", "benefit-badge longstay flex align-center gap-1", [
                    icons.villa(),
                    text(" %10 Uzun Konaklama"),
                  ]),
                  el("span", "muted small", [
                    text("7 gece ve üzeri kiralamalarda"),
                  ]),
                ]),
              ]),
            ]),
          ]),
          el("div", "detail-sidebar", [booking_status.content(lang)]),
        ]),
      ])
    }
    _ ->
      el("div", "container", [
        el("h1", "", [text("İlan Bulunamadı")]),
        link("/ilanlar", "← İlanlar Listesine Dön", "button"),
      ])
  }
}

// Legacy callers must never render an unverified provider result as confirmation.
pub fn render_confirmation(_result_json: String) -> Element(Nil) {
  booking_status.content("tr")
}

fn truncate_text(val: String, max_len: Int) -> String {
  case string.length(val) > max_len {
    True -> string.slice(val, 0, max_len) <> "..."
    False -> val
  }
}

fn result_unwrap(res: Result(a, b), default: a) -> a {
  case res {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn parse_media_list(media_json: String) -> List(String) {
  let cleaned =
    media_json
    |> string.trim
    |> string.drop_start(1)
    |> string.drop_end(1)
  case cleaned {
    "" -> []
    _ ->
      string.split(cleaned, ",")
      |> list.map(fn(s) {
        string.trim(s)
        |> string.replace("\"", "")
        |> string.replace("\\/", "/")
      })
      |> list.filter(fn(s) { s != "" })
  }
}

fn render_video_embed(video_url: String) -> Element(Nil) {
  let url = string.trim(video_url)
  case url {
    "" -> text("")
    _ -> {
      let is_youtube =
        string.contains(url, "youtube.com") || string.contains(url, "youtu.be")
      let is_vimeo = string.contains(url, "vimeo.com")

      let embed_src = case is_youtube {
        True -> {
          case string.split_once(url, "v=") {
            Ok(#(_, id_part)) -> {
              let video_id =
                string.split(id_part, "&")
                |> list.first
                |> result_unwrap(id_part)
              "https://www.youtube-nocookie.com/embed/" <> video_id
            }
            Error(_) -> {
              case string.split_once(url, "youtu.be/") {
                Ok(#(_, id_part)) -> {
                  let video_id =
                    string.split(id_part, "?")
                    |> list.first
                    |> result_unwrap(id_part)
                  "https://www.youtube-nocookie.com/embed/" <> video_id
                }
                Error(_) -> url
              }
            }
          }
        }
        False -> {
          case is_vimeo {
            True -> {
              case string.split(url, "/") |> list.last {
                Ok(id) -> "https://player.vimeo.com/video/" <> id
                Error(_) -> url
              }
            }
            False -> url
          }
        }
      }

      el("div", "detail-card video-card", [
        el("div", "video-card-header", [
          el("h3", "section-title-with-icon", [
            icons.eye(),
            text("Video Tanıtımı & Sanal Tur"),
          ]),
          link(url, "Videoyu Yeni Sekmede Aç ↗", "video-ext-link"),
        ]),
        case is_youtube || is_vimeo {
          True ->
            element.element(
              "iframe",
              [
                a.src(embed_src),
                a.class("detail-video-iframe"),
                a.attribute("frameborder", "0"),
                a.attribute(
                  "allow",
                  "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture",
                ),
                a.attribute("allowfullscreen", "true"),
              ],
              [],
            )
          False ->
            element.element(
              "video",
              [
                a.src(embed_src),
                a.class("detail-video-player"),
                a.attribute("controls", "true"),
                a.attribute("preload", "metadata"),
              ],
              [],
            )
        },
      ])
    }
  }
}
