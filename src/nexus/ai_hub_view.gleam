import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

fn icon_link(url: String, icon: Element(Nil), label: String, class: String) {
  element.element("a", [a.href(url), a.class(class)], [icon, text(" " <> label)])
}

fn tab_button(
  id: String,
  title: String,
  desc: String,
  icon: Element(Nil),
  is_active: Bool,
) {
  let active_cls = case is_active {
    True -> "ai-tool-tab active"
    False -> "ai-tool-tab"
  }
  element.element(
    "button",
    [
      a.class(active_cls),
      a.attribute("type", "button"),
      a.attribute("data-tab-target", id),
      a.attribute("onclick", "switchAiTab('" <> id <> "')"),
    ],
    [
      el("div", "ai-tab-icon-wrap", [icon]),
      el("div", "ai-tab-text", [
        el("strong", "ai-tab-title", [text(title)]),
        el("small", "ai-tab-desc", [text(desc)]),
      ]),
    ],
  )
}

pub fn page(
  s: Session,
  csrf: String,
  extra_info: String,
  generated_result: String,
  message: String,
) -> String {
  view.shell(
    s,
    csrf,
    "Yapay Zeka Merkezi",
    el("div", "ai-studio-container", [
      // 1. Studio Header
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text("NEXUS AI LABS · GEMINI & NEXGEN TURİZM MOTORU"),
            ]),
            el("span", "ai-status-pill", [
              icons.sparkles(),
              text("Model: nexus-turbo-v2.5 (Aktif)"),
            ]),
          ]),
          el("h1", "studio-title", [
            text("Yapay Zeka Operasyon & İçerik Stüdyosu"),
          ]),
          el("p", "studio-subtitle", [
            text(
              "Tesisinizin pazarlama metinlerini, sosyal medya kampanyalarını, misafir yorum yanıtlarını ve dinamik talep-fiyat analizlerini saniyeler içinde üretin.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          icon_link(
            "/admin/social-media",
            icons.sparkles(),
            "Sosyal Medya Masası",
            "btn-studio-secondary",
          ),
          icon_link(
            "/admin/rate-shopper",
            icons.trending_up(),
            "Rate Shopper & Fiyat",
            "btn-studio-secondary",
          ),
          icon_link(
            "/admin/listings",
            icons.hotel(),
            "İlan Portföyü",
            "btn-studio-secondary",
          ),
        ]),
      ]),

      case message {
        "" -> text("")
        _ ->
          el("div", "ai-notice-banner", [
            el("span", "ai-notice-icon", [icons.check()]),
            el("span", "ai-notice-text", [text(message)]),
          ])
      },

      // 2. Interactive Tool Switcher (Segmented Tab Bar)
      el("div", "ai-tab-switcher", [
        tab_button(
          "tool-listing-seo",
          "İlan & SEO Sihirbazı",
          "Google & OTA uyumlu başlık ve açıklama",
          icons.document(),
          True,
        ),
        tab_button(
          "tool-social-post",
          "Sosyal Medya & Post",
          "Instagram & TikTok caption + hashtag",
          icons.blog(),
          False,
        ),
        tab_button(
          "tool-review-reply",
          "Misafir Yorum Yanıtı",
          "Google & TripAdvisor itibar yönetimi",
          icons.chat(),
          False,
        ),
        tab_button(
          "tool-demand-forecast",
          "Talep & Akıllı Fiyat",
          "Doluluk bazlı dinamik yield önerisi",
          icons.dynamic_pricing(),
          False,
        ),
      ]),

      // 3. Two-Column AI Studio Workspace
      el("div", "ai-studio-grid", [
        // ─── SOL KOLON: Aktif Form Paneli ───
        el("div", "ai-forms-column", [
          // ARAÇ 1: İLAN & SEO SİHİRBAZI
          element.element(
            "div",
            [
              a.id("tool-listing-seo"),
              a.class("ai-tool-panel active"),
            ],
            [
              el("div", "tool-card-header", [
                el("div", "tool-card-title-wrap", [
                  el("span", "tool-card-icon", [icons.document()]),
                  el("div", "", [
                    el("h3", "", [
                      text("İlan SEO Başlığı ve Açıklaması Üretici"),
                    ]),
                    el("p", "tool-desc", [
                      text(
                        "Tesisinizin konum ve özelliklerine göre Google ve OTA aramalarında üst sıralara çıkaracak başlık ve detaylı açıklama üretir.",
                      ),
                    ]),
                  ]),
                ]),
              ]),
              el("div", "preset-suggestions", [
                el("span", "preset-label", [text("Hızlı Doldur:")]),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillSeo('Villa Infinity Bodrum', 'villa', 'Muğla, Bodrum, Yalıkavak', 'Sonsuzluk Havuzu, Panoramik Deniz Manzarası, Jakuzi, Sauna, Wi-Fi')",
                    ),
                  ],
                  [icons.villa(), text(" Bodrum Lüks Villa")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillSeo('Cappadocia Cave Suites', 'hotel', 'Nevşehir, Göreme', 'Otantik Kaya Oda, Şömine, Sıcak Küvet, Balon Manzaralı Teras')",
                    ),
                  ],
                  [icons.hotel(), text(" Kapadokya Cave Otel")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillSeo('Gulet Barbaros Mavi Tur', 'gulet', 'Muğla, Fethiye, Göcek', '4 Lüks Kabin, Kaptan & Aşçı Hizmeti, Özel Koylarda Mavi Yolculuk, Su Sporları')",
                    ),
                  ],
                  [icons.yacht(), text(" Göcek Mavi Tur")],
                ),
              ]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute("action", "/admin/ai-hub/generate"),
                  a.class("ai-studio-form"),
                ],
                [
                  hidden("csrf", csrf),
                  hidden("tool_type", "listing_seo"),
                  el("div", "form-row-2", [
                    el("div", "form-group", [
                      element.element("label", [], [text("İlan Adı / Başlık *")]),
                      element.element(
                        "input",
                        [
                          a.id("seo-title"),
                          a.type_("text"),
                          a.name("title"),
                          a.attribute(
                            "placeholder",
                            "Örn: Villa Infinity Bodrum",
                          ),
                          a.attribute("required", "required"),
                          a.class("studio-input"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [text("Kategori *")]),
                      element.element(
                        "select",
                        [
                          a.id("seo-cat"),
                          a.name("category"),
                          a.class("studio-select"),
                        ],
                        [
                          element.element("option", [a.value("villa")], [
                            text("Villa & Tatil Evi"),
                          ]),
                          element.element("option", [a.value("hotel")], [
                            text("Otel & Butik Tesis"),
                          ]),
                          element.element("option", [a.value("gulet")], [
                            text("Yat & Marina"),
                          ]),
                          element.element("option", [a.value("tour")], [
                            text("Tur & Deneyim"),
                          ]),
                        ],
                      ),
                    ]),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [text("Konum / Bölge Detayı")]),
                    element.element(
                      "input",
                      [
                        a.id("seo-loc"),
                        a.type_("text"),
                        a.name("locality"),
                        a.attribute(
                          "placeholder",
                          "Örn: Muğla, Bodrum, Yalıkavak",
                        ),
                        a.class("studio-input"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [
                      text("Önemli Özellikler & Olanaklar"),
                    ]),
                    element.element(
                      "input",
                      [
                        a.id("seo-amenities"),
                        a.type_("text"),
                        a.name("amenities"),
                        a.attribute(
                          "placeholder",
                          "Örn: Sonsuzluk Havuzu, Deniz Manzarası, Jakuzi, Sauna, Wi-Fi",
                        ),
                        a.class("studio-input"),
                      ],
                      [],
                    ),
                  ]),
                  element.element(
                    "button",
                    [
                      a.class("btn-studio-generate"),
                      a.attribute("type", "submit"),
                    ],
                    [
                      icons.sparkles(),
                      text(" SEO Başlığı & Açıklama Üret"),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ARAÇ 2: SOSYAL MEDYA & KAMPANYA POSTU
          element.element(
            "div",
            [
              a.id("tool-social-post"),
              a.class("ai-tool-panel"),
            ],
            [
              el("div", "tool-card-header", [
                el("div", "tool-card-title-wrap", [
                  el("span", "tool-card-icon social-ico", [icons.blog()]),
                  el("div", "", [
                    el("h3", "", [
                      text("Sosyal Medya Gönderi ve Kampanya Metni Üretici"),
                    ]),
                    el("p", "tool-desc", [
                      text(
                        "Instagram, TikTok ve Facebook için yüksek etkileşimli görsel altı metin, emojiler ve sektörel hashtag'ler oluşturur.",
                      ),
                    ]),
                  ]),
                ]),
              ]),
              el("div", "preset-suggestions", [
                el("span", "preset-label", [text("Hızlı Şablon:")]),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillSocial('Lüks Kaş Balayı Villası', 'villa', '20', 'energetic')",
                    ),
                  ],
                  [icons.trending_up(), text(" %20 Erken Rezervasyon")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillSocial('Sapanca Göl Manzaralı Bungalov', 'hotel', '15', 'luxury')",
                    ),
                  ],
                  [icons.sparkles(), text(" Romantik Kaçamak")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillSocial('Fethiye Mavi Tur Lüks Gulet', 'gulet', '25', 'friendly')",
                    ),
                  ],
                  [icons.beach(), text(" Yaz Fırsatı Kampanyası")],
                ),
              ]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute("action", "/admin/ai-hub/generate"),
                  a.class("ai-studio-form"),
                ],
                [
                  hidden("csrf", csrf),
                  hidden("tool_type", "social_post"),
                  el("div", "form-row-2", [
                    el("div", "form-group", [
                      element.element("label", [], [
                        text("Tesis / Kampanya Adı *"),
                      ]),
                      element.element(
                        "input",
                        [
                          a.id("soc-title"),
                          a.type_("text"),
                          a.name("title"),
                          a.attribute("placeholder", "Örn: Lüks Kaş Villası"),
                          a.attribute("required", "required"),
                          a.class("studio-input"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [text("Kategori *")]),
                      element.element(
                        "select",
                        [
                          a.id("soc-cat"),
                          a.name("category"),
                          a.class("studio-select"),
                        ],
                        [
                          element.element("option", [a.value("villa")], [
                            text("Villa & Tatil Evi"),
                          ]),
                          element.element("option", [a.value("hotel")], [
                            text("Otel & Konaklama"),
                          ]),
                          element.element("option", [a.value("gulet")], [
                            text("Yat & Marina"),
                          ]),
                        ],
                      ),
                    ]),
                  ]),
                  el("div", "form-row-2", [
                    el("div", "form-group", [
                      element.element("label", [], [
                        text("İndirim Oranı % (Varsa)"),
                      ]),
                      element.element(
                        "input",
                        [
                          a.id("soc-discount"),
                          a.type_("text"),
                          a.name("promo_discount"),
                          a.attribute("placeholder", "Örn: 20 veya 15"),
                          a.class("studio-input"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [
                        text("İletişim Tonu (Tone of Voice)"),
                      ]),
                      element.element(
                        "select",
                        [
                          a.id("soc-tone"),
                          a.name("tone"),
                          a.class("studio-select"),
                        ],
                        [
                          element.element("option", [a.value("energetic")], [
                            text("Enerjik, Hızlı & Aksiyon Odaklı"),
                          ]),
                          element.element("option", [a.value("luxury")], [
                            text("Lüks, Ayrıcalıklı & Prestijli"),
                          ]),
                          element.element("option", [a.value("friendly")], [
                            text("Sıcak, Samimi & Bilgilendirici"),
                          ]),
                        ],
                      ),
                    ]),
                  ]),
                  element.element(
                    "button",
                    [
                      a.class("btn-studio-generate social-btn"),
                      a.attribute("type", "submit"),
                    ],
                    [
                      icons.sparkles(),
                      text(" Sosyal Medya Metni & Hashtag Üret"),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ARAÇ 3: MİSAFİR YORUM YANITLAYICI
          element.element(
            "div",
            [
              a.id("tool-review-reply"),
              a.class("ai-tool-panel"),
            ],
            [
              el("div", "tool-card-header", [
                el("div", "tool-card-title-wrap", [
                  el("span", "tool-card-icon review-ico", [icons.chat()]),
                  el("div", "", [
                    el("h3", "", [text("Misafir Yorumu Akıllı Yanıtlayıcı")]),
                    el("p", "tool-desc", [
                      text(
                        "Tüm harita ve seyahat platformlarındaki misafir yorumlarına kurumsal, nazik ve rezervasyonu teşvik eden profesyonel yanıtlar üretir.",
                      ),
                    ]),
                  ]),
                ]),
              ]),
              el("div", "preset-suggestions", [
                el("span", "preset-label", [text("Örnek Senaryo:")]),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillReview('Ahmet Yılmaz', '5', 'Personel son derece ilgiliydi, oda tertemizdi ve havuz manzarası harikaydı. Kesinlikle tekrar geleceğiz.')",
                    ),
                  ],
                  [icons.check(), text(" 5 Yıldız: Teşekkür & Övgü")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillReview('Deniz Kaya', '3', 'Tesis genel olarak güzel ancak sabah kahvaltısında yoğunluk vardı ve internet hızı zaman zaman düştü.')",
                    ),
                  ],
                  [icons.warning(), text(" 3 Yıldız: Yapıcı Eleştiri")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillReview('Selim Demir', '1', 'Girişte odamız zamanında hazır değildi ve klimada arıza yaşadık. Memnun kalmadık.')",
                    ),
                  ],
                  [icons.security(), text(" 1 Yıldız: Kriz & Özür")],
                ),
              ]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute("action", "/admin/ai-hub/generate"),
                  a.class("ai-studio-form"),
                ],
                [
                  hidden("csrf", csrf),
                  hidden("tool_type", "review_reply"),
                  el("div", "form-row-2", [
                    el("div", "form-group", [
                      element.element("label", [], [text("Misafir Adı")]),
                      element.element(
                        "input",
                        [
                          a.id("rev-guest"),
                          a.type_("text"),
                          a.name("guest_name"),
                          a.attribute("placeholder", "Örn: Mehmet Bey"),
                          a.class("studio-input"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [
                        text("Verilen Puan (Yıldız)"),
                      ]),
                      element.element(
                        "select",
                        [
                          a.id("rev-rating"),
                          a.name("rating"),
                          a.class("studio-select"),
                        ],
                        [
                          element.element("option", [a.value("5")], [
                            text("5 Yıldız (Mükemmel)"),
                          ]),
                          element.element("option", [a.value("4")], [
                            text("4 Yıldız (Çok İyi)"),
                          ]),
                          element.element("option", [a.value("3")], [
                            text("3 Yıldız (Orta)"),
                          ]),
                          element.element("option", [a.value("2")], [
                            text("2 Yıldız (Zayıf)"),
                          ]),
                          element.element("option", [a.value("1")], [
                            text("1 Yıldız (Olumsuz)"),
                          ]),
                        ],
                      ),
                    ]),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [
                      text("Misafirin Yorum Metni *"),
                    ]),
                    element.element(
                      "textarea",
                      [
                        a.id("rev-comment"),
                        a.name("comment"),
                        a.attribute("rows", "3"),
                        a.attribute(
                          "placeholder",
                          "Örn: Tesis çok temizdi, personel ilgiliydi, havuz mükemmeldi.",
                        ),
                        a.attribute("required", "required"),
                        a.class("studio-textarea"),
                      ],
                      [],
                    ),
                  ]),
                  element.element(
                    "button",
                    [
                      a.class("btn-studio-generate review-btn"),
                      a.attribute("type", "submit"),
                    ],
                    [
                      icons.sparkles(),
                      text(" Kurumsal Misafir Yanıtı Hazırla"),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ARAÇ 4: TALEP & AKILLI FİYAT ANALİZİ
          element.element(
            "div",
            [
              a.id("tool-demand-forecast"),
              a.class("ai-tool-panel"),
            ],
            [
              el("div", "tool-card-header", [
                el("div", "tool-card-title-wrap", [
                  el("span", "tool-card-icon pricing-ico", [
                    icons.dynamic_pricing(),
                  ]),
                  el("div", "", [
                    el("h3", "", [
                      text("Talep Seviyesi ve Dinamik Fiyat Stratejisi"),
                    ]),
                    el("p", "tool-desc", [
                      text(
                        "Tesisinizin mevcut doluluk yüzdesine ve bölgesel piyasa koşullarına göre gelir maksimizasyonu (yield) ve fiyat artırma / aksiyon önerisi sunar.",
                      ),
                    ]),
                  ]),
                ]),
              ]),
              el("div", "preset-suggestions", [
                el("span", "preset-label", [text("Hızlı Doluluk Senaryosu:")]),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillDemand('Otel', 'Antalya, Kaş', '45')",
                    ),
                  ],
                  [icons.trending_down(), text(" %45 Düşük Sezon")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillDemand('Villa', 'Muğla, Bodrum', '72')",
                    ),
                  ],
                  [icons.accounting(), text(" %72 Dengeli Pazar")],
                ),
                element.element(
                  "button",
                  [
                    a.class("chip-preset"),
                    a.attribute("type", "button"),
                    a.attribute(
                      "onclick",
                      "fillDemand('Villa', 'Kalkan, Kaş', '94')",
                    ),
                  ],
                  [icons.trending_up(), text(" %94 Yüksek Talep / Pik")],
                ),
              ]),
              element.element(
                "form",
                [
                  a.attribute("method", "post"),
                  a.attribute("action", "/admin/ai-hub/generate"),
                  a.class("ai-studio-form"),
                ],
                [
                  hidden("csrf", csrf),
                  hidden("tool_type", "demand_forecast"),
                  el("div", "form-row-3", [
                    el("div", "form-group", [
                      element.element("label", [], [text("Tesis Kategorisi *")]),
                      element.element(
                        "select",
                        [
                          a.id("dem-cat"),
                          a.name("category"),
                          a.class("studio-select"),
                        ],
                        [
                          element.element("option", [a.value("Otel")], [
                            text("Otel & Konaklama"),
                          ]),
                          element.element("option", [a.value("Villa")], [
                            text("Villa"),
                          ]),
                          element.element("option", [a.value("Yat")], [
                            text("Yat & Tekne"),
                          ]),
                        ],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [text("Bölge")]),
                      element.element(
                        "input",
                        [
                          a.id("dem-loc"),
                          a.type_("text"),
                          a.name("locality"),
                          a.attribute("placeholder", "Örn: Antalya, Kaş"),
                          a.class("studio-input"),
                        ],
                        [],
                      ),
                    ]),
                    el("div", "form-group", [
                      element.element("label", [], [
                        text("Mevcut Doluluk Yüzdesi (%) *"),
                      ]),
                      element.element(
                        "input",
                        [
                          a.id("dem-occ"),
                          a.type_("number"),
                          a.name("occupancy_pct"),
                          a.attribute("placeholder", "Örn: 75"),
                          a.attribute("min", "0"),
                          a.attribute("max", "100"),
                          a.class("studio-input"),
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
                      icons.dynamic_pricing(),
                      text(" Piyasa & Fiyat Stratejisi Analizi Başlat"),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ]),

        // ─── SAĞ KOLON: Canlı AI Konsolu & Asistan ───
        el("div", "ai-console-column", [
          case generated_result {
            "" ->
              el("div", "studio-empty-card", [
                el("div", "empty-icon-wrap", [icons.sparkles()]),
                el("h3", "", [text("Canlı AI Konsolu Hazır")]),
                el("p", "muted", [
                  text(
                    "Sol panelden dilediğiniz yapay zeka aracını seçin veya hızlı doldur butonlarına tıklayarak saniyeler içinde çıktınızı alın.",
                  ),
                ]),
                el("div", "studio-tips-box", [
                  el("h4", "section-title-with-icon", [
                    icons.sparkles(),
                    text("Önemli İpuçları:"),
                  ]),
                  el("ul", "studio-tips-list", [
                    el("li", "", [
                      text(
                        "Konum ve olanakları detaylandırdığınızda Google ve OTA listeleme skoru artar.",
                      ),
                    ]),
                    el("li", "", [
                      text(
                        "Misafir yorumlarına hızlı ve nazik AI yanıtları doğrudan rezervasyon güvenini pekiştirir.",
                      ),
                    ]),
                    el("li", "", [
                      text(
                        "Doluluk %85 üzerine çıktığında AI Yield motoru taban fiyat artışını önerir.",
                      ),
                    ]),
                  ]),
                ]),
              ])

            _ ->
              el("div", "studio-result-card", [
                el("div", "result-card-header", [
                  el("div", "result-badge-wrap", [
                    el("span", "badge-ai-ready", [
                      el("span", "pulse-green-dot", []),
                      text("ÇIKTI HAZIR"),
                    ]),
                    case extra_info {
                      "" -> text("")
                      _ -> el("span", "badge-ai-tool", [text(extra_info)])
                    },
                  ]),
                  element.element(
                    "button",
                    [
                      a.id("btn-copy-ai"),
                      a.class("btn-copy-action"),
                      a.attribute("type", "button"),
                      a.attribute("onclick", "copyAiResult()"),
                    ],
                    [
                      icons.copy(),
                      el("span", "copy-btn-label", [text("Kopyala")]),
                    ],
                  ),
                ]),
                el("div", "result-content-wrap", [
                  element.element(
                    "textarea",
                    [
                      a.id("ai-result-textarea"),
                      a.class("studio-result-text"),
                      a.attribute("readonly", "readonly"),
                    ],
                    [text(generated_result)],
                  ),
                ]),
                el("div", "result-footer-actions", [
                  icon_link(
                    "/admin/social-media",
                    icons.sparkles(),
                    "Sosyal Medyada Paylaş",
                    "btn-result-primary",
                  ),
                  icon_link(
                    "/admin/listings",
                    icons.hotel(),
                    "İlan Portföyüne Aktar",
                    "btn-result-secondary",
                  ),
                ]),
              ])
          },
        ]),
      ]),

      // 4. Interactive Script for instant tab switching, presets, and copy
      element.element("script", [], [
        text(
          "
          function switchAiTab(tabId) {
            document.querySelectorAll('.ai-tool-tab').forEach(function(b) {
              b.classList.remove('active');
            });
            document.querySelectorAll('.ai-tool-panel').forEach(function(p) {
              p.classList.remove('active');
            });
            var targetBtn = document.querySelector('[data-tab-target=\"' + tabId + '\"]');
            var targetPanel = document.getElementById(tabId);
            if (targetBtn) targetBtn.classList.add('active');
            if (targetPanel) targetPanel.classList.add('active');
          }

          function fillSeo(title, cat, loc, amen) {
            document.getElementById('seo-title').value = title;
            document.getElementById('seo-cat').value = cat;
            document.getElementById('seo-loc').value = loc;
            document.getElementById('seo-amenities').value = amen;
          }

          function fillSocial(title, cat, discount, tone) {
            document.getElementById('soc-title').value = title;
            document.getElementById('soc-cat').value = cat;
            document.getElementById('soc-discount').value = discount;
            document.getElementById('soc-tone').value = tone;
          }

          function fillReview(guest, rating, comment) {
            document.getElementById('rev-guest').value = guest;
            document.getElementById('rev-rating').value = rating;
            document.getElementById('rev-comment').value = comment;
          }

          function fillDemand(cat, loc, occ) {
            document.getElementById('dem-cat').value = cat;
            document.getElementById('dem-loc').value = loc;
            document.getElementById('dem-occ').value = occ;
          }

          function copyAiResult() {
            var txt = document.getElementById('ai-result-textarea');
            if (txt) {
              txt.select();
              navigator.clipboard.writeText(txt.value).then(function() {
                var btnLabel = document.querySelector('.copy-btn-label');
                if (btnLabel) {
                  btnLabel.innerText = 'Kopyalandı! ✓';
                  setTimeout(function() { btnLabel.innerText = 'Kopyala'; }, 2000);
                }
              });
            }
          }
          ",
        ),
      ]),
    ]),
  )
}
