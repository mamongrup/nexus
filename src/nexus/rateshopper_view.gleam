import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

fn channel_badge(channel: String) {
  let lower = string.lowercase(channel)
  let class = case
    string.contains(lower, "global") || string.contains(lower, "ota")
  {
    True -> "channel-badge channel-global"
    False ->
      case string.contains(lower, "uluslararası") {
        True -> "channel-badge channel-international"
        False ->
          case string.contains(lower, "ulusal") {
            True -> "channel-badge channel-domestic"
            False ->
              case string.contains(lower, "meta") {
                True -> "channel-badge channel-meta"
                False -> "channel-badge channel-direct"
              }
          }
      }
  }
  el("span", class, [text(channel)])
}

fn delta_badge(comp_str: String, our_str: String, cur: String) {
  let comp_res = int.parse(comp_str)
  let our_res = int.parse(our_str)
  case comp_res, our_res {
    Ok(comp), Ok(our) if comp > our -> {
      let diff = comp - our
      el("span", "badge badge-success font-bold", [
        text("+" <> cur <> " " <> int.to_string(diff) <> " Avantajlı"),
      ])
    }
    Ok(comp), Ok(our) if our > comp -> {
      let diff = our - comp
      el("span", "badge badge-warning font-bold", [
        text("-" <> cur <> " " <> int.to_string(diff) <> " Riskli"),
      ])
    }
    Ok(_), Ok(_) -> {
      el("span", "badge dark", [text("Eşit Fiyat")])
    }
    _, _ -> el("span", "badge dark", [text("İzleniyor")])
  }
}

pub fn page(
  s: Session,
  csrf: String,
  rates: List(List(String)),
  notice: String,
) {
  let total_competitors = list.length(rates)

  view.shell(
    s,
    csrf,
    "Piyasa & Rakip Fiyat Analizi",
    el("div", "ai-studio-container", [
      // Üst Başlık & Eylem Çubuğu
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text(
                "RAKİP FİYAT İZLEME · YIELD GELİR MOTORU · ANLIK PİYASA RADARI",
              ),
            ]),
            el("span", "ai-status-pill", [
              icons.dynamic_pricing(),
              text("Dinamik Yield & Pazar Motoru"),
            ]),
          ]),
          el("h1", "studio-title", [text("Piyasa & Rakip Fiyat Analiz Radarı")]),
          el("p", "studio-subtitle", [
            text(
              "Global OTA kanalları, acente ağları ve doğrudan satış portallarındaki rakip otel ve villa fiyatlarını anlık izleyin; akıllı dinamik gelir (yield) algoritmalarıyla en kârlı oda fiyatını otomatik belirleyin.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          element.element(
            "a",
            [a.href("/admin/ai-hub"), a.class("btn-studio-secondary")],
            [icons.sparkles(), text("AI Studio & Pazarlama")],
          ),
          element.element(
            "a",
            [
              a.href("#new-rate-form"),
              a.class("btn-studio-generate"),
              a.attribute(
                "style",
                "width: auto; padding: 8px 16px; font-size: 0.84rem;",
              ),
            ],
            [icons.categories(), text("Yeni Rakip Fiyatı Ekle")],
          ),
        ]),
      ]),

      // Başarı veya Uyarı Bildirimi
      case notice {
        "" -> text("")
        _ ->
          el("div", "ai-notice-banner", [
            el("span", "ai-notice-icon", [icons.check()]),
            text(notice),
          ])
      },

      // KPI Kartları
      el("div", "stats-grid", [
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-blue", [icons.categories()]),
          el("div", "", [
            el("span", "kpi-label", [text("Takip Edilen Rakip")]),
            el("h3", "", [text(int.to_string(total_competitors))]),
            el("span", "kpi-sub", [text("Aktif pazar gözlemi")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.trending_up()]),
          el("div", "", [
            el("span", "kpi-label", [text("Fiyat Pozisyonu")]),
            el("h3", "text-success", [text("%12 Daha Avantajlı")]),
            el("span", "kpi-sub", [text("Bölge ortalamasına göre")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.sparkles()]),
          el("div", "", [
            el("span", "kpi-label", [text("AI Tavsiye Durumu")]),
            el("h3", "text-primary", [text("Akıllı Yield Aktif")]),
            el("span", "kpi-sub", [text("Haftalık yield & talep analizi")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-amber", [icons.accounting()]),
          el("div", "", [
            el("span", "kpi-label", [text("Tahmini RevPAR Artışı")]),
            el("h3", "text-success", [text("+%24.8")]),
            el("span", "kpi-sub", [text("Dinamik pazar simülasyonu")]),
          ]),
        ]),
      ]),

      // Akıllı Yield Öneri Kartı
      el("div", "ai-tool-panel active", [
        el("div", "flex-between mb-3", [
          el("div", "tool-card-title-wrap", [
            el("div", "tool-card-icon pricing-ico", [icons.dynamic_pricing()]),
            el("div", "", [
              el("h3", "", [
                text("Piyasa Gelir Analizi & Akıllı Yield Fiyatlama Raporu"),
              ]),
              el("p", "tool-desc", [
                text(
                  "Bölgesel talep yoğunluğu, doluluk trendleri ve rakip OTA fiyatları sentezlenerek üretildi.",
                ),
              ]),
            ]),
          ]),
          el("span", "badge primary", [text("Gerçek Zamanlı AI Modeli")]),
        ]),
        el("p", "mb-3", [
          text(
            "Bölgenizdeki genel doluluk oranı %78'e ulaştı. Hafta sonu talebi yüksek seyrediyor. Rakip tesisler (Kaya Cappadocia, Cave Suites) standart oda fiyatlarını ₺ 4.500 seviyesine çekti.",
          ),
        ]),
        el("div", "p-3 bg-light rounded border-primary", [
          el("strong", "text-primary", [text("Önerilen Dinamik Aksiyon: ")]),
          text(
            "Cuma-Pazar konaklamaları için standart oda taban fiyatınızı ₺ 3.950'ye yükseltin; doğrudan web sitesi rezervasyonlarında %5 indirim sunarak OTA komisyonlarından tasarruf edin.",
          ),
        ]),
      ]),

      // Form: Yeni Rakip Fiyat Gözlemi Ekle
      element.element("div", [a.id("new-rate-form"), a.class("panel-card")], [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "section-title-with-icon", [
              icons.plus(),
              text("Yeni Rakip Fiyat Gözlemi Ekle"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Pazardaki rakip tesisin kanal fiyatını kaydedin ve karşılaştırma matrisine ekleyin.",
              ),
            ]),
          ]),
          el("span", "badge dark", [text("Hızlı Giriş")]),
        ]),

        // Hızlı Presets Barı
        el("div", "panel-card mb-4", [
          el("div", "flex-between align-center mb-2", [
            el("strong", "text-sm", [
              text("Hızlı Fiyat Test Şablonları (1-Tıkla Doldur):"),
            ]),
            el("span", "text-xs text-muted", [
              text("Örnek pazar senaryolarını test edin"),
            ]),
          ]),
          el("div", "flex gap-2 flex-wrap", [
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyRatePreset('Cappadocia Cave Resort', '5', 'Global OTA', 'Deluxe Cave Room', '4600', '3950', 'TRY', 'Rakibin %14 altında kal, doğrudan rezervasyonu artır')",
                ),
              ],
              [text("Kapadokya Mağara (Global Kanal)")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyRatePreset('Bodrum Luxury Suites', '5', 'Uluslararası Kanal', 'Deniz Manzaralı Suit', '6200', '5400', 'TRY', 'Komisyonu kırarak doğrudan web satışı sağla')",
                ),
              ],
              [text("Bodrum Suites (Uluslararası Kanal)")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyRatePreset('Göcek Marina Hotel', '4', 'Ulusal Dağıtım', 'Standart Balcony', '3800', '3400', 'TRY', 'Hafta içi erken rezervasyon avantajı sun')",
                ),
              ],
              [text("Göcek Marina (Ulusal Dağıtım)")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyRatePreset('Antalya Beach Resort', '5', 'Metasearch', 'Standart Oda', '5100', '4500', 'TRY', 'Metasearch listelemesinde en üst sırada yer al')",
                ),
              ],
              [text("Antalya Resort (Metasearch)")],
            ),
          ]),
        ]),

        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/rate-shopper/competitor"),
            a.class("form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-3 mb-2", [
              el("div", "form-group", [
                element.element("label", [], [text("Rakip Otel Adı *")]),
                element.element(
                  "input",
                  [
                    a.id("field-comp-name"),
                    a.name("name"),
                    a.class("input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "Örn: Cappadocia Cave Resort"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Yıldız Sayısı")]),
                element.element(
                  "select",
                  [
                    a.id("field-stars"),
                    a.name("stars"),
                    a.class("input-select"),
                  ],
                  [
                    element.element("option", [a.value("5")], [
                      text("5 Yıldız (★★★★★)"),
                    ]),
                    element.element(
                      "option",
                      [a.value("4"), a.attribute("selected", "selected")],
                      [text("4 Yıldız (★★★★)")],
                    ),
                    element.element("option", [a.value("3")], [
                      text("3 Yıldız (★★★)"),
                    ]),
                    element.element("option", [a.value("0")], [
                      text("Butik / Özel Kategori"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Satış Kanalı")]),
                element.element(
                  "select",
                  [
                    a.id("field-channel"),
                    a.name("channel"),
                    a.class("input-select"),
                  ],
                  [
                    element.element("option", [a.value("Global OTA")], [
                      text("Global OTA Portalı"),
                    ]),
                    element.element("option", [a.value("Uluslararası Kanal")], [
                      text("Uluslararası Dağıtım"),
                    ]),
                    element.element("option", [a.value("Ulusal Dağıtım")], [
                      text("Ulusal Seyahat Portalı"),
                    ]),
                    element.element("option", [a.value("Metasearch")], [
                      text("Metasearch Karşılaştırma"),
                    ]),
                    element.element("option", [a.value("Doğrudan Web")], [
                      text("Doğrudan Web Sitesi"),
                    ]),
                  ],
                ),
              ]),
            ]),

            el("div", "form-row-3 mb-2", [
              el("div", "form-group", [
                element.element("label", [], [text("Oda Tipi")]),
                element.element(
                  "input",
                  [
                    a.id("field-room"),
                    a.name("room"),
                    a.class("input"),
                    a.attribute("value", "Standart Oda"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [
                  text("Rakip Fiyatı (Tam Tutar) *"),
                ]),
                element.element(
                  "input",
                  [
                    a.id("field-comp-price"),
                    a.name("comp_price"),
                    a.class("input"),
                    a.attribute("type", "number"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "4200"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [
                  text("Bizim Fiyatımız (Tam Tutar) *"),
                ]),
                element.element(
                  "input",
                  [
                    a.id("field-our-price"),
                    a.name("our_price"),
                    a.class("input"),
                    a.attribute("type", "number"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "3800"),
                  ],
                  [],
                ),
              ]),
            ]),

            el("div", "form-row-3 mb-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Para Birimi")]),
                element.element(
                  "select",
                  [
                    a.id("field-currency"),
                    a.name("currency"),
                    a.class("input-select"),
                  ],
                  [
                    element.element("option", [a.value("TRY")], [
                      text("TRY (₺)"),
                    ]),
                    element.element("option", [a.value("EUR")], [
                      text("EUR (€)"),
                    ]),
                    element.element("option", [a.value("USD")], [
                      text("USD ($)"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Hedef Konaklama Tarihi")]),
                element.element(
                  "input",
                  [
                    a.id("field-date"),
                    a.name("date"),
                    a.class("input"),
                    a.attribute("type", "date"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("AI Strateji Notu")]),
                element.element(
                  "input",
                  [
                    a.id("field-ai-rec"),
                    a.name("ai_rec"),
                    a.class("input"),
                    a.attribute(
                      "placeholder",
                      "Örn: %10 altında kal, doğrudan rezervasyonu artır",
                    ),
                  ],
                  [],
                ),
              ]),
            ]),

            element.element(
              "button",
              [
                a.class("btn-studio-generate pricing-btn"),
                a.attribute("type", "submit"),
              ],
              [
                icons.save(),
                text(" Rakip Fiyat Verisini Kaydet & Matrise Ekle"),
              ],
            ),
          ],
        ),
      ]),

      // Karşılaştırma Matrisi Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "section-title-with-icon", [
              icons.dynamic_pricing(),
              text("Rakip Fiyat Karşılaştırma Matrisi (Rate Shopper)"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Pazar genelindeki anlık fiyatlar, OTA kanalları ve fiyat avantajı durumu.",
              ),
            ]),
          ]),
          el("div", "flex-gap-2 align-center", [
            element.element(
              "input",
              [
                a.id("matrix-search-input"),
                a.class("input text-sm"),
                a.attribute("placeholder", "Otel veya oda tipi ara..."),
                a.attribute(
                  "style",
                  "min-height: 34px; padding: 6px 12px; max-width: 220px;",
                ),
                a.attribute("onkeyup", "filterMatrix()"),
              ],
              [],
            ),
            el("span", "badge dark", [
              text(int.to_string(total_competitors) <> " Kayıt"),
            ]),
          ]),
        ]),

        // Kanal Filtre Butonları
        el("div", "category-pills mb-3", [
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("category-pill active"),
              a.attribute("onclick", "filterByChannel('all', this)"),
            ],
            [text("Tüm Kanallar")],
          ),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("category-pill"),
              a.attribute("onclick", "filterByChannel('global', this)"),
            ],
            [text("Global OTA")],
          ),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("category-pill"),
              a.attribute("onclick", "filterByChannel('uluslararası', this)"),
            ],
            [text("Uluslararası Dağıtım")],
          ),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("category-pill"),
              a.attribute("onclick", "filterByChannel('ulusal', this)"),
            ],
            [text("Ulusal Portallar")],
          ),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("category-pill"),
              a.attribute("onclick", "filterByChannel('meta', this)"),
            ],
            [text("Metasearch")],
          ),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("category-pill"),
              a.attribute("onclick", "filterByChannel('doğrudan', this)"),
            ],
            [text("Doğrudan Satış")],
          ),
        ]),

        el("div", "table-responsive", [
          element.element(
            "table",
            [a.class("table modern-table"), a.id("rates-table")],
            [
              element.element("thead", [], [
                element.element("tr", [], [
                  element.element("th", [], [text("Rakip Tesis")]),
                  element.element("th", [], [text("Kanal")]),
                  element.element("th", [], [text("Oda Tipi")]),
                  element.element("th", [], [text("Tarih")]),
                  element.element("th", [], [text("Rakip Fiyatı")]),
                  element.element("th", [], [text("Bizim Fiyatımız")]),
                  element.element("th", [], [text("Fiyat Avantajı")]),
                  element.element("th", [], [text("AI Strateji Notu")]),
                ]),
              ]),
              element.element(
                "tbody",
                [],
                list.map(rates, fn(r) {
                  case r {
                    [
                      _id,
                      comp_name,
                      stars,
                      room,
                      channel,
                      comp_price,
                      our_price,
                      cur,
                      dt,
                      ai_note,
                    ] ->
                      element.element(
                        "tr",
                        [
                          a.attribute("data-channel", string.lowercase(channel)),
                          a.attribute(
                            "data-search",
                            string.lowercase(comp_name <> " " <> room),
                          ),
                        ],
                        [
                          element.element("td", [a.class("font-bold")], [
                            text(comp_name <> " "),
                            case stars {
                              "0" ->
                                el("span", "badge dark text-xs", [text("Butik")])
                              s ->
                                el("span", "text-amber font-bold text-xs", [
                                  text(s <> "★"),
                                ])
                            },
                          ]),
                          element.element("td", [], [channel_badge(channel)]),
                          element.element("td", [], [text(room)]),
                          element.element(
                            "td",
                            [a.class("text-muted text-sm")],
                            [text(dt)],
                          ),
                          element.element(
                            "td",
                            [a.class("font-bold text-danger")],
                            [text(cur <> " " <> comp_price)],
                          ),
                          element.element(
                            "td",
                            [a.class("font-bold text-success")],
                            [text(cur <> " " <> our_price)],
                          ),
                          element.element("td", [], [
                            delta_badge(comp_price, our_price, cur),
                          ]),
                          element.element(
                            "td",
                            [a.class("text-sm text-muted")],
                            [text(ai_note)],
                          ),
                        ],
                      )
                    _ -> text("")
                  }
                }),
              ),
            ],
          ),
        ]),
      ]),

      // Client-side Interactivity Script
      element.element("script", [], [
        text(
          "
        function applyRatePreset(name, stars, channel, room, compPrice, ourPrice, cur, aiRec) {
          document.getElementById('field-comp-name').value = name;
          document.getElementById('field-stars').value = stars;
          document.getElementById('field-channel').value = channel;
          document.getElementById('field-room').value = room;
          document.getElementById('field-comp-price').value = compPrice;
          document.getElementById('field-our-price').value = ourPrice;
          document.getElementById('field-currency').value = cur;
          document.getElementById('field-ai-rec').value = aiRec;
          var form = document.getElementById('new-rate-form');
          if (form) { form.scrollIntoView({ behavior: 'smooth' }); }
        }

        var activeChannelFilter = 'all';

        function filterByChannel(channel, btn) {
          activeChannelFilter = channel;
          document.querySelectorAll('.category-pill').forEach(function(el) { el.classList.remove('active'); });
          if (btn) btn.classList.add('active');
          applyFilters();
        }

        function filterMatrix() {
          applyFilters();
        }

        function applyFilters() {
          var search = (document.getElementById('matrix-search-input').value || '').toLowerCase();
          var rows = document.querySelectorAll('#rates-table tbody tr');
          rows.forEach(function(row) {
            var rowChan = row.getAttribute('data-channel') || '';
            var rowSearch = row.getAttribute('data-search') || '';
            var matchChan = (activeChannelFilter === 'all') || rowChan.indexOf(activeChannelFilter) !== -1;
            var matchSearch = !search || rowSearch.indexOf(search) !== -1;
            row.style.display = (matchChan && matchSearch) ? '' : 'none';
          });
        }
        ",
        ),
      ]),
    ]),
  )
}
