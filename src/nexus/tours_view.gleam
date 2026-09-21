import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  activities: List(List(String)),
  packages: List(List(String)),
  notice: String,
) {
  let total_activities = list.length(activities)
  let total_packages = list.length(packages)

  view.shell(
    s,
    csrf,
    "Turlar & Dinamik Paketler",
    el("div", "ai-studio-container", [
      // Üst Başlık & Eylem Çubuğu
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text("TUR OPERASYONU · DİNAMİK PAKETLEME · DİJİTAL VOUCHER"),
            ]),
            el("span", "ai-status-pill", [
              icons.tour(),
              text("Dinamik Paketleme & Deneyim Masası"),
            ]),
          ]),
          el("h1", "studio-title", [
            text("Tur Operasyonları & Dinamik Çoklu Ürün Paketleme"),
          ]),
          el("p", "studio-subtitle", [
            text(
              "Günübirlik turlar, balon ve tekne gezileri, transferler ve otel konaklamalarını tek bir sepette birleştirin; anında QR kodlu tekil dijital voucher ve acente biletleri üretin.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          element.element(
            "a",
            [a.href("/admin/ai-hub"), a.class("btn-studio-secondary")],
            [icons.sparkles(), text("AI Tur & İlan Metni")],
          ),
          element.element(
            "a",
            [
              a.href("#package-form"),
              a.class("btn-studio-generate"),
              a.attribute(
                "style",
                "width: auto; padding: 8px 16px; font-size: 0.84rem;",
              ),
            ],
            [icons.categories(), text("Dinamik Paket Oluştur")],
          ),
        ]),
      ]),

      // Bildirim Mesajı
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
          el("div", "kpi-icon-wrap bg-blue", [icons.tour()]),
          el("div", "", [
            el("span", "kpi-label", [text("Tanımlı Deneyim")]),
            el("h3", "", [text(int.to_string(total_activities))]),
            el("span", "kpi-sub", [text("Balon, Gulet, Safari, Transfer")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.modules()]),
          el("div", "", [
            el("span", "kpi-label", [text("Oluşturulan Paketler")]),
            el("h3", "", [text(int.to_string(total_packages))]),
            el("span", "kpi-sub", [text("Karekodlu tekil voucher")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.trending_up()]),
          el("div", "", [
            el("span", "kpi-label", [text("Ortalama Tur Komisyonu")]),
            el("h3", "text-success", [text("+%32.5")]),
            el("span", "kpi-sub", [text("Net-Satış marj kazancı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-amber", [icons.agency()]),
          el("div", "", [
            el("span", "kpi-label", [text("Acente Entegrasyonu")]),
            el("h3", "text-primary", [text("Aktif & Canlı")]),
            el("span", "kpi-sub", [text("B2B acente dağıtım ağı")]),
          ]),
        ]),
      ]),

      // İki Kolonlu Form Alanı: Sol: Tur Aktivitesi Tanımlama, Sağ: Dinamik Paket Üretici
      el("div", "grid-2col", [
        // Sol Form: Yeni Tur / Deneyim Ekle
        el("div", "panel-card", [
          el("div", "tool-card-title-wrap mb-3", [
            el("div", "tool-card-icon", [icons.tour()]),
            el("div", "", [
              el("h3", "", [text("Yeni Deneyim / Tur Tanımla")]),
              el("p", "tool-desc", [
                text(
                  "Tedarikçi ağınızdan temin edilen tur veya transferi kataloğa ekleyin.",
                ),
              ]),
            ]),
          ]),

          // Hızlı Şablonlar
          el("div", "preset-suggestions mb-3", [
            el("span", "preset-label", [text("Şablonlar:")]),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyActivityPreset('Kapadokya Gün Doğumu Lüks Balon Turu', 'Göreme / Kapadokya', 'balloon', '3', '160', '220', 'EUR', '24')",
                ),
              ],
              [text("Balon Turu")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyActivityPreset('Göcek 12 Adalar Lüks Gulet Yat Turu', 'Göcek Marina', 'boat', '7', '450', '650', 'EUR', '12')",
                ),
              ],
              [text("Gulet Mavi Tur")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyActivityPreset('Bodrum Milas Havalimanı VIP Mercedes Vito Transfer', 'Bodrum / Milas', 'transfer', '1', '70', '110', 'EUR', '30')",
                ),
              ],
              [text("VIP Transfer")],
            ),
          ]),

          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/tours/activity"),
              a.class("ai-studio-form"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-group", [
                element.element("label", [], [text("Tur / Deneyim Başlığı *")]),
                element.element(
                  "input",
                  [
                    a.id("act-title"),
                    a.name("title"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute(
                      "placeholder",
                      "Örn: Kapadokya Gün Doğumu Lüks Balon Turu",
                    ),
                  ],
                  [],
                ),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Bölge / Konum *")]),
                  element.element(
                    "input",
                    [
                      a.id("act-location"),
                      a.name("location"),
                      a.class("studio-input"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "Göreme / Kapadokya"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Kategori *")]),
                  element.element(
                    "select",
                    [
                      a.id("act-category"),
                      a.name("category"),
                      a.class("studio-select"),
                    ],
                    [
                      element.element("option", [a.value("balloon")], [
                        text("Sıcak Hava Balonu"),
                      ]),
                      element.element("option", [a.value("boat")], [
                        text("Gulet / Tekne Turu"),
                      ]),
                      element.element("option", [a.value("safari")], [
                        text("ATV / Jeep Safari"),
                      ]),
                      element.element("option", [a.value("cultural")], [
                        text("Tarihi & Kültürel Gezi"),
                      ]),
                      element.element("option", [a.value("transfer")], [
                        text("VIP Havalimanı Transfer"),
                      ]),
                      element.element("option", [a.value("other")], [
                        text("Diğer Aktivite"),
                      ]),
                    ],
                  ),
                ]),
              ]),
              el("div", "form-row-3", [
                el("div", "form-group", [
                  element.element("label", [], [text("Süre (Saat)")]),
                  element.element(
                    "input",
                    [
                      a.id("act-duration"),
                      a.name("duration"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("value", "3"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Net Alış Fiyatı *")]),
                  element.element(
                    "input",
                    [
                      a.id("act-net-price"),
                      a.name("net_price"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "160"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Satış Fiyatı *")]),
                  element.element(
                    "input",
                    [
                      a.id("act-sale-price"),
                      a.name("sale_price"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "220"),
                    ],
                    [],
                  ),
                ]),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Para Birimi")]),
                  element.element(
                    "select",
                    [
                      a.id("act-currency"),
                      a.name("currency"),
                      a.class("studio-select"),
                    ],
                    [
                      element.element("option", [a.value("EUR")], [
                        text("EUR (€)"),
                      ]),
                      element.element("option", [a.value("USD")], [
                        text("USD ($)"),
                      ]),
                      element.element("option", [a.value("TRY")], [
                        text("TRY (₺)"),
                      ]),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Günlük Kontenjan")]),
                  element.element(
                    "input",
                    [
                      a.id("act-capacity"),
                      a.name("capacity"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("value", "20"),
                    ],
                    [],
                  ),
                ]),
              ]),
              element.element(
                "button",
                [
                  a.class("btn-studio-generate"),
                  a.attribute("type", "submit"),
                ],
                [icons.tour(), text("Turu Kataloğa Kaydet")],
              ),
            ],
          ),
        ]),

        // Sağ Form: Dinamik Paket & Tekil Voucher Üretici
        element.element("div", [a.id("package-form"), a.class("panel-card")], [
          el("div", "tool-card-title-wrap mb-3", [
            el("div", "tool-card-icon review-ico", [icons.modules()]),
            el("div", "", [
              el("h3", "", [text("Dinamik Çoklu Ürün Paketi Oluştur")]),
              el("p", "tool-desc", [
                text(
                  "Otel + Tur + VIP Transferi tek sepette birleştirin ve tek voucher üretin.",
                ),
              ]),
            ]),
          ]),

          // Hızlı Paket Şablonları
          el("div", "preset-suggestions mb-3", [
            el("span", "preset-label", [text("Paket Örnekleri:")]),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyPackagePreset('Ahmet Yılmaz', 'Kaya Cappadocia Cave Resort', 'Kapadokya Gün Doğumu Lüks Balon Turu', 'true', '1450')",
                ),
              ],
              [text("Kapadokya Balon + Cave")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyPackagePreset('Marcus Vance', 'Göcek D-Resort & Marina', 'Göcek 12 Adalar Lüks Gulet Yat Turu', 'true', '2200')",
                ),
              ],
              [text("Göcek Gulet + Resort")],
            ),
          ]),

          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/tours/package"),
              a.class("ai-studio-form"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-group", [
                element.element("label", [], [text("Misafir Ad Soyad *")]),
                element.element(
                  "input",
                  [
                    a.id("pkg-guest"),
                    a.name("guest_name"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "Örn: John Smith"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Konaklama / Otel Adı *")]),
                element.element(
                  "input",
                  [
                    a.id("pkg-hotel"),
                    a.name("hotel_name"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "Örn: Museum Hotel Cappadocia"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Dahil Edilen Aktivite *")]),
                element.element(
                  "input",
                  [
                    a.id("pkg-activity"),
                    a.name("activity_name"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute(
                      "placeholder",
                      "Örn: Kapadokya Gün Doğumu Lüks Balon Turu",
                    ),
                  ],
                  [],
                ),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("VIP Havalimanı Transfer")]),
                  element.element(
                    "select",
                    [
                      a.id("pkg-transfer"),
                      a.name("transfer"),
                      a.class("studio-select"),
                    ],
                    [
                      element.element("option", [a.value("true")], [
                        text("Dahil (Gidiş-Dönüş VIP)"),
                      ]),
                      element.element("option", [a.value("false")], [
                        text("Transfer Hariç"),
                      ]),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [
                    text("Toplam Paket Fiyatı (EUR) *"),
                  ]),
                  element.element(
                    "input",
                    [
                      a.id("pkg-price"),
                      a.name("price"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "1450"),
                    ],
                    [],
                  ),
                ]),
              ]),
              element.element(
                "button",
                [
                  a.class("btn-studio-generate review-btn"),
                  a.attribute("type", "submit"),
                ],
                [icons.document(), text("Paketi Onayla & Tekil Voucher Üret")],
              ),
            ],
          ),
        ]),
      ]),

      // Aktif Turlar Kataloğu Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("Aktif Deneyim & Tur Kataloğu")]),
            el("p", "muted text-sm", [
              text(
                "Satışa hazır turlar, net alış fiyatları ve kontenjan durumları.",
              ),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_activities) <> " Deneyim"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Tur Adı")]),
                element.element("th", [], [text("Konum")]),
                element.element("th", [], [text("Kategori")]),
                element.element("th", [], [text("Süre")]),
                element.element("th", [], [text("Net Alış")]),
                element.element("th", [], [text("Satış Fiyatı")]),
                element.element("th", [], [text("Kapasite")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(activities, fn(r) {
                case r {
                  [_id, title, loc, cat, dur, net_p, sale_p, cur, cap] ->
                    element.element("tr", [], [
                      element.element("td", [a.class("font-bold")], [
                        text(title),
                      ]),
                      element.element("td", [], [text(loc)]),
                      element.element("td", [], [
                        el("span", "badge dark", [text(cat)]),
                      ]),
                      element.element("td", [], [text(dur <> " Saat")]),
                      element.element("td", [a.class("text-muted")], [
                        text(cur <> " " <> net_p),
                      ]),
                      element.element(
                        "td",
                        [a.class("font-bold text-success")],
                        [text(cur <> " " <> sale_p)],
                      ),
                      element.element("td", [], [text(cap <> " kişi/gün")]),
                    ])
                  _ -> text("")
                }
              }),
            ),
          ]),
        ]),
      ]),

      // Dinamik Paketler ve Tekil Voucherlar
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [
              text("Dinamik Paket Rezervasyonları & Voucher Listesi"),
            ]),
            el("p", "muted text-sm", [
              text("Otel, tur ve transfer bileşenli kombine rezervasyonlar."),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_packages) <> " Paket"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Voucher No")]),
                element.element("th", [], [text("Misafir")]),
                element.element("th", [], [text("Konaklama")]),
                element.element("th", [], [text("Aktivite / Tur")]),
                element.element("th", [], [text("VIP Transfer")]),
                element.element("th", [], [text("Toplam Paket")]),
                element.element("th", [], [text("Durum")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(packages, fn(r) {
                case r {
                  [
                    _id,
                    _code,
                    guest,
                    hotel,
                    act,
                    trf,
                    price,
                    cur,
                    status,
                    voucher,
                  ] ->
                    element.element("tr", [], [
                      element.element(
                        "td",
                        [a.class("font-bold text-primary font-mono")],
                        [
                          element.element(
                            "button",
                            [
                              a.type_("button"),
                              a.class("pin-code-badge"),
                              a.attribute(
                                "style",
                                "color: #38bdf8; font-size: 0.85rem; padding: 4px 10px;",
                              ),
                              a.attribute(
                                "onclick",
                                "copyVoucher('" <> voucher <> "', this)",
                              ),
                            ],
                            [icons.document(), text(voucher)],
                          ),
                        ],
                      ),
                      element.element("td", [a.class("font-bold")], [
                        text(guest),
                      ]),
                      element.element("td", [], [text(hotel)]),
                      element.element("td", [], [text(act)]),
                      element.element("td", [], [
                        el(
                          "span",
                          case trf {
                            "true" -> "badge badge-success"
                            _ -> "badge dark"
                          },
                          [
                            text(case trf {
                              "true" -> "VIP Dahil"
                              _ -> "Transfer Yok"
                            }),
                          ],
                        ),
                      ]),
                      element.element(
                        "td",
                        [a.class("font-bold text-success")],
                        [text(cur <> " " <> price)],
                      ),
                      element.element("td", [], [
                        el("span", "badge badge-success", [text(status)]),
                      ]),
                    ])
                  _ -> text("")
                }
              }),
            ),
          ]),
        ]),
      ]),

      // Client-side Interactivity Script
      element.element("script", [], [
        text(
          "
        function applyActivityPreset(title, loc, cat, dur, net, sale, cur, cap) {
          document.getElementById('act-title').value = title;
          document.getElementById('act-location').value = loc;
          document.getElementById('act-category').value = cat;
          document.getElementById('act-duration').value = dur;
          document.getElementById('act-net-price').value = net;
          document.getElementById('act-sale-price').value = sale;
          document.getElementById('act-currency').value = cur;
          document.getElementById('act-capacity').value = cap;
        }

        function applyPackagePreset(guest, hotel, act, trf, price) {
          document.getElementById('pkg-guest').value = guest;
          document.getElementById('pkg-hotel').value = hotel;
          document.getElementById('pkg-activity').value = act;
          document.getElementById('pkg-transfer').value = trf;
          document.getElementById('pkg-price').value = price;
        }

        function copyVoucher(voucher, btn) {
          navigator.clipboard.writeText(voucher).then(function() {
            var oldText = btn.innerText;
            btn.innerText = '✓ ' + voucher;
            btn.style.borderColor = '#10b981';
            setTimeout(function() {
              btn.innerText = voucher;
              btn.style.borderColor = '';
            }, 1800);
          });
        }
        ",
        ),
      ]),
    ]),
  )
}
