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
  vehicles: List(List(String)),
  rentals: List(List(String)),
  notice: String,
) {
  let total_vehicles = list.length(vehicles)
  let total_rentals = list.length(rentals)

  view.shell(
    s,
    csrf,
    "Araç Kiralama & Filo Yönetimi",
    el("div", "ai-studio-container", [
      // Üst Başlık & Eylem Çubuğu
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text(
                "ARAÇ KİRALAMA MOTORU · EGM KABİS ENTEGRASYONU · DİJİTAL SÖZLEŞME",
              ),
            ]),
            el("span", "ai-status-pill", [
              icons.car(),
              text("Filo & Rent A Car Masası"),
            ]),
          ]),
          el("h1", "studio-title", [
            text("Araç Filo Yönetimi & Dijital Kiralama Masası"),
          ]),
          el("p", "studio-subtitle", [
            text(
              "Kiralık araç filonuzun bakım, kasko, muayene ve kilometre durumlarını takip edin; EGM KABİS polis bildirimini ve dijital teslim sözleşmelerini otomatik oluşturun.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          element.element(
            "a",
            [
              a.href("#new-rental-form"),
              a.class("btn-studio-generate"),
              a.attribute(
                "style",
                "width: auto; padding: 8px 16px; font-size: 0.84rem;",
              ),
            ],
            [icons.document(), text("Yeni Kiralama Sözleşmesi")],
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
          el("div", "kpi-icon-wrap bg-blue", [icons.car()]),
          el("div", "", [
            el("span", "kpi-label", [text("Toplam Araç")]),
            el("h3", "", [text(int.to_string(total_vehicles))]),
            el("span", "kpi-sub", [text("Filodaki aktif araçlar")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.document()]),
          el("div", "", [
            el("span", "kpi-label", [text("Kiralama Sözleşmeleri")]),
            el("h3", "", [text(int.to_string(total_rentals))]),
            el("span", "kpi-sub", [text("Resmi dijital kira kontratı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.kbs()]),
          el("div", "", [
            el("span", "kpi-label", [text("KABIS Bildirim Durumu")]),
            el("h3", "text-success", [text("Tam Uyumlu (%100)")]),
            el("span", "kpi-sub", [text("Emniyet Genel Müdürlüğü")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-amber", [icons.trending_up()]),
          el("div", "", [
            el("span", "kpi-label", [text("Filo Doluluk Oranı")]),
            el("h3", "text-primary", [text("%75")]),
            el("span", "kpi-sub", [text("Mevcut kiralamalar")]),
          ]),
        ]),
      ]),

      // İki Form Alanı: Sol: Yeni Araç Ekle, Sağ: Yeni Kiralama Sözleşmesi
      el("div", "grid-2col", [
        // Sol Form: Yeni Araç Tanımlama
        el("div", "panel-card", [
          el("div", "tool-card-title-wrap mb-3", [
            el("div", "tool-card-icon", [icons.car()]),
            el("div", "", [
              el("h3", "", [text("Yeni Filo Aracı Ekle")]),
              el("p", "tool-desc", [
                text(
                  "Kiralık araç envanterine yeni araç tanıtın ve KABIS onayına açın.",
                ),
              ]),
            ]),
          ]),

          // Hızlı Şablonlar
          el("div", "preset-suggestions mb-3", [
            el("span", "preset-label", [text("Araç Şablonları:")]),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyVehiclePreset('34 NEX 701', 'Mercedes-Benz', 'E-Class AMG', '2024', 'automatic', 'diesel', '12000', '4800')",
                ),
              ],
              [text("Mercedes E-Class")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyVehiclePreset('34 NEX 702', 'BMW', '520i M Sport', '2024', 'automatic', 'gasoline', '8500', '5200')",
                ),
              ],
              [text("BMW 520i")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyVehiclePreset('34 NEX 703', 'Renault', 'Clio Touch', '2023', 'automatic', 'gasoline', '28000', '1650')",
                ),
              ],
              [text("Renault Clio")],
            ),
          ]),

          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/fleet/vehicle"),
              a.class("ai-studio-form"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Plaka No *")]),
                  element.element(
                    "input",
                    [
                      a.id("veh-plate"),
                      a.name("plate"),
                      a.class("studio-input"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "34 NEX 123"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Model Yılı")]),
                  element.element(
                    "input",
                    [
                      a.id("veh-year"),
                      a.name("year"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("value", "2024"),
                    ],
                    [],
                  ),
                ]),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Marka *")]),
                  element.element(
                    "input",
                    [
                      a.id("veh-brand"),
                      a.name("brand"),
                      a.class("studio-input"),
                      a.attribute("required", "required"),
                      a.attribute(
                        "placeholder",
                        "Mercedes-Benz / BMW / Renault",
                      ),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Model *")]),
                  element.element(
                    "input",
                    [
                      a.id("veh-model"),
                      a.name("model"),
                      a.class("studio-input"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "E-Class / Clio / Megane"),
                    ],
                    [],
                  ),
                ]),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Vites")]),
                  element.element(
                    "select",
                    [
                      a.id("veh-trans"),
                      a.name("trans"),
                      a.class("studio-select"),
                    ],
                    [
                      element.element("option", [a.value("automatic")], [
                        text("Otomatik"),
                      ]),
                      element.element("option", [a.value("manual")], [
                        text("Manuel"),
                      ]),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Yakıt Tipi")]),
                  element.element(
                    "select",
                    [a.id("veh-fuel"), a.name("fuel"), a.class("studio-select")],
                    [
                      element.element("option", [a.value("diesel")], [
                        text("Dizel"),
                      ]),
                      element.element("option", [a.value("gasoline")], [
                        text("Benzin"),
                      ]),
                      element.element("option", [a.value("hybrid")], [
                        text("Hibrit"),
                      ]),
                      element.element("option", [a.value("electric")], [
                        text("Elektrik"),
                      ]),
                    ],
                  ),
                ]),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Mevcut Kilometre (KM)")]),
                  element.element(
                    "input",
                    [
                      a.id("veh-km"),
                      a.name("km"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("value", "15000"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [
                    text("Günlük Kiralama Ücreti (₺) *"),
                  ]),
                  element.element(
                    "input",
                    [
                      a.id("veh-rate"),
                      a.name("rate"),
                      a.class("studio-input"),
                      a.attribute("type", "number"),
                      a.attribute("required", "required"),
                      a.attribute("placeholder", "3500"),
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
                [icons.car(), text("Aracı Filoya Ekle")],
              ),
            ],
          ),
        ]),

        // Sağ Form: Yeni Kiralama Sözleşmesi & Ekspertiz
        element.element(
          "div",
          [a.id("new-rental-form"), a.class("panel-card")],
          [
            el("div", "tool-card-title-wrap mb-3", [
              el("div", "tool-card-icon review-ico", [icons.document()]),
              el("div", "", [
                el("h3", "", [text("Yeni Dijital Kiralama Sözleşmesi")]),
                el("p", "tool-desc", [
                  text(
                    "Müşteriye aracı teslim edin, depozitoyu ve hasar notlarını işleyin.",
                  ),
                ]),
              ]),
            ]),

            element.element(
              "form",
              [
                a.attribute("method", "post"),
                a.attribute("action", "/admin/fleet/rental"),
                a.class("ai-studio-form"),
              ],
              [
                hidden("csrf", csrf),
                el("div", "form-row-2", [
                  el("div", "form-group", [
                    element.element("label", [], [text("Araç Plakası *")]),
                    element.element(
                      "input",
                      [
                        a.name("plate"),
                        a.class("studio-input"),
                        a.attribute("required", "required"),
                        a.attribute("placeholder", "34 NEX 777"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [text("Sürücü Ad Soyad *")]),
                    element.element(
                      "input",
                      [
                        a.name("driver"),
                        a.class("studio-input"),
                        a.attribute("required", "required"),
                        a.attribute("placeholder", "Caner Demir"),
                      ],
                      [],
                    ),
                  ]),
                ]),
                el("div", "form-row-2", [
                  el("div", "form-group", [
                    element.element("label", [], [
                      text("TC Kimlik / Pasaport No *"),
                    ]),
                    element.element(
                      "input",
                      [
                        a.name("tc"),
                        a.class("studio-input"),
                        a.attribute("required", "required"),
                        a.attribute("placeholder", "12345678901"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [text("Telefon Numarası *")]),
                    element.element(
                      "input",
                      [
                        a.name("phone"),
                        a.class("studio-input"),
                        a.attribute("required", "required"),
                        a.attribute("placeholder", "+905332223344"),
                      ],
                      [],
                    ),
                  ]),
                ]),
                el("div", "form-row-3", [
                  el("div", "form-group", [
                    element.element("label", [], [text("Başlangıç Tarihi")]),
                    element.element(
                      "input",
                      [
                        a.name("start"),
                        a.class("studio-input"),
                        a.attribute("type", "date"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [text("Bitiş Tarihi")]),
                    element.element(
                      "input",
                      [
                        a.name("end"),
                        a.class("studio-input"),
                        a.attribute("type", "date"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [text("Gün")]),
                    element.element(
                      "input",
                      [
                        a.name("days"),
                        a.class("studio-input"),
                        a.attribute("type", "number"),
                        a.attribute("value", "3"),
                      ],
                      [],
                    ),
                  ]),
                ]),
                el("div", "form-row-2", [
                  el("div", "form-group", [
                    element.element("label", [], [
                      text("Toplam Kiralama Tutarı (₺) *"),
                    ]),
                    element.element(
                      "input",
                      [
                        a.name("amount"),
                        a.class("studio-input"),
                        a.attribute("type", "number"),
                        a.attribute("required", "required"),
                        a.attribute("placeholder", "10500"),
                      ],
                      [],
                    ),
                  ]),
                  el("div", "form-group", [
                    element.element("label", [], [
                      text("Depozito / Provizyon (₺)"),
                    ]),
                    element.element(
                      "input",
                      [
                        a.name("deposit"),
                        a.class("studio-input"),
                        a.attribute("type", "number"),
                        a.attribute("value", "5000"),
                      ],
                      [],
                    ),
                  ]),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [
                    text("Dijital Hasar & Ekspertiz Notları"),
                  ]),
                  element.element(
                    "input",
                    [
                      a.name("damage"),
                      a.class("studio-input"),
                      a.attribute(
                        "placeholder",
                        "Ön tamponda hafif çizik mevcut, yakıt deposu dolu teslim edildi",
                      ),
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
                  [icons.kbs(), text("Sözleşmeyi Oluştur & KABIS'e Bildir")],
                ),
              ],
            ),
          ],
        ),
      ]),

      // Filo Envanteri Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("Filo Araç Envanteri")]),
            el("p", "muted text-sm", [
              text(
                "Kayıtlı araçlar, model yılları ve KABIS emniyet bildirim durumu.",
              ),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_vehicles) <> " Araç"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Plaka")]),
                element.element("th", [], [text("Marka & Model")]),
                element.element("th", [], [text("Yıl")]),
                element.element("th", [], [text("Vites / Yakıt")]),
                element.element("th", [], [text("Kilometre")]),
                element.element("th", [], [text("Günlük Ücret")]),
                element.element("th", [], [text("Durum")]),
                element.element("th", [], [text("KABIS")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(vehicles, fn(r) {
                case r {
                  [
                    _id,
                    plate,
                    brand,
                    model,
                    year,
                    trans,
                    fuel,
                    km,
                    rate,
                    cur,
                    status,
                    kabis,
                  ] ->
                    element.element("tr", [], [
                      element.element("td", [], [
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
                              "copyPlate('" <> plate <> "', this)",
                            ),
                          ],
                          [icons.car(), text(plate)],
                        ),
                      ]),
                      element.element("td", [a.class("font-bold")], [
                        text(brand <> " " <> model),
                      ]),
                      element.element("td", [], [text(year)]),
                      element.element("td", [], [text(trans <> " · " <> fuel)]),
                      element.element("td", [], [text(km <> " KM")]),
                      element.element(
                        "td",
                        [a.class("font-bold text-success")],
                        [text(cur <> " " <> rate)],
                      ),
                      element.element("td", [], [
                        el(
                          "span",
                          "badge "
                            <> case status {
                            "available" -> "badge-success"
                            "rented" -> "badge-warning"
                            _ -> "dark"
                          },
                          [text(status)],
                        ),
                      ]),
                      element.element("td", [], [
                        el("span", "badge badge-success", [text(kabis)]),
                      ]),
                    ])
                  _ -> text("")
                }
              }),
            ),
          ]),
        ]),
      ]),

      // Kiralama Sözleşmeleri Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("Kiralama Sözleşmeleri & Teslimat Kayıtları")]),
            el("p", "muted text-sm", [
              text("Aktif ve geçmiş kiralamaların dijital evrak takibi."),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_rentals) <> " Sözleşme"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Sözleşme No")]),
                element.element("th", [], [text("Araç Plaka")]),
                element.element("th", [], [text("Sürücü")]),
                element.element("th", [], [text("İletişim / TC")]),
                element.element("th", [], [text("Tarihler")]),
                element.element("th", [], [text("Gün")]),
                element.element("th", [], [text("Toplam Tutar")]),
                element.element("th", [], [text("Depozito")]),
                element.element("th", [], [text("Durum")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(rentals, fn(r) {
                case r {
                  [
                    _id,
                    agree,
                    plate,
                    driver,
                    tc,
                    phone,
                    sdate,
                    edate,
                    days,
                    amt,
                    dep,
                    status,
                  ] ->
                    element.element("tr", [], [
                      element.element(
                        "td",
                        [a.class("font-bold text-primary font-mono")],
                        [text(agree)],
                      ),
                      element.element("td", [a.class("font-bold")], [
                        text(plate),
                      ]),
                      element.element("td", [], [text(driver)]),
                      element.element("td", [a.class("text-sm text-muted")], [
                        text(phone <> " (" <> tc <> ")"),
                      ]),
                      element.element("td", [a.class("text-sm")], [
                        text(sdate <> " - " <> edate),
                      ]),
                      element.element("td", [], [text(days <> " Gün")]),
                      element.element(
                        "td",
                        [a.class("font-bold text-success")],
                        [text("₺ " <> amt)],
                      ),
                      element.element("td", [], [text("₺ " <> dep)]),
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
        function applyVehiclePreset(plate, brand, model, year, trans, fuel, km, rate) {
          document.getElementById('veh-plate').value = plate;
          document.getElementById('veh-brand').value = brand;
          document.getElementById('veh-model').value = model;
          document.getElementById('veh-year').value = year;
          document.getElementById('veh-trans').value = trans;
          document.getElementById('veh-fuel').value = fuel;
          document.getElementById('veh-km').value = km;
          document.getElementById('veh-rate').value = rate;
        }

        function copyPlate(plate, btn) {
          navigator.clipboard.writeText(plate).then(function() {
            var oldText = btn.innerText;
            btn.innerText = '✓ ' + plate;
            btn.style.borderColor = '#10b981';
            setTimeout(function() {
              btn.innerText = plate;
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
