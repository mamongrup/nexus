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
  invoices: List(List(String)),
  notice: String,
) {
  let total_invoices = list.length(invoices)

  view.shell(
    s,
    csrf,
    "e-Fatura & GİB Entegratörü",
    el("div", "ai-studio-container", [
      // Üst Başlık & Eylem Çubuğu
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text(
                "GİB ÖZEL ENTEGRATÖR BAĞLANTISI · UBL-TR 1.2 E-FATURA STANDARDI",
              ),
            ]),
            el("span", "ai-status-pill", [
              icons.accounting(),
              text("Mali Mühür & e-Belge Portalı"),
            ]),
          ]),
          el("h1", "studio-title", [
            text("e-Fatura, e-Arşiv & %2 Konaklama Vergisi Portalı"),
          ]),
          el("p", "studio-subtitle", [
            text(
              "GİB mevzuatına tam uyumlu e-Fatura, e-Arşiv ve 7194 sayılı Kanun %2 Resmi Konaklama Vergisi hesaplama, ETTN tekil barkodlu fatura oluşturma ve muhasebe entegrasyonu.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          element.element(
            "a",
            [
              a.href("#new-invoice-form"),
              a.class("btn-studio-generate"),
              a.attribute(
                "style",
                "width: auto; padding: 8px 16px; font-size: 0.84rem;",
              ),
            ],
            [icons.document(), text("Yeni e-Belge Düzenle")],
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
          el("div", "kpi-icon-wrap bg-blue", [icons.document()]),
          el("div", "", [
            el("span", "kpi-label", [text("Kesilen e-Belge")]),
            el("h3", "", [text(int.to_string(total_invoices))]),
            el("span", "kpi-sub", [text("e-Fatura / e-Arşiv")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.kbs()]),
          el("div", "", [
            el("span", "kpi-label", [text("GİB Entegratör Durumu")]),
            el("h3", "text-success", [text("Aktif & Doğrulandı")]),
            el("span", "kpi-sub", [text("Özel Entegratör Web Servisi")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-amber", [icons.accounting()]),
          el("div", "", [
            el("span", "kpi-label", [text("Konaklama Vergisi")]),
            el("h3", "text-primary", [text("%2.0")]),
            el("span", "kpi-sub", [text("7194 sayılı Kanun")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.check()]),
          el("div", "", [
            el("span", "kpi-label", [text("GİB Onay Başarısı")]),
            el("h3", "text-success", [text("%100")]),
            el("span", "kpi-sub", [text("Hatasız 1200 Kodu")]),
          ]),
        ]),
      ]),

      // Form: Yeni Resmi e-Fatura / e-Arşiv Kesme
      element.element("div", [a.id("new-invoice-form"), a.class("panel-card")], [
        el("div", "tool-card-title-wrap mb-3", [
          el("div", "tool-card-icon review-ico", [icons.document()]),
          el("div", "", [
            el("h3", "", [text("Resmi e-Fatura / e-Arşiv Düzenle")]),
            el("p", "tool-desc", [
              text(
                "GİB e-Belge portalına anlık UBL-TR formatında fatura iletin. Konaklama vergisi ve KDV matraha göre otomatik hesaplanır.",
              ),
            ]),
          ]),
        ]),

        // Hızlı Şablonlar
        el("div", "preset-suggestions mb-3", [
          el("span", "preset-label", [text("Örnek Şablonlar:")]),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("chip-preset"),
              a.attribute(
                "onclick",
                "applyInvoicePreset('e-Arsiv', 'EARSIVFATURA', 'TRY', 'Burak Can Özkan', '12345678901', 'Beşiktaş V.D.', 10000)",
              ),
            ],
            [text("Bireysel e-Arşiv (₺10.000)")],
          ),
          element.element(
            "button",
            [
              a.type_("button"),
              a.class("chip-preset"),
              a.attribute(
                "onclick",
                "applyInvoicePreset('e-Fatura', 'TICARIFATURA', 'TRY', 'Global Travel Turizm Tic. A.Ş.', '4120556789', 'Büyük Mükellefler V.D.', 45000)",
              ),
            ],
            [text("Kurumsal e-Fatura (₺45.000)")],
          ),
        ]),

        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/admin/einvoice/issue"),
            a.class("ai-studio-form"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [text("Fatura Tipi *")]),
                element.element(
                  "select",
                  [a.id("inv-type"), a.name("type"), a.class("studio-select")],
                  [
                    element.element("option", [a.value("e-Arsiv")], [
                      text("e-Arşiv Fatura (Bireysel / Nihai Tüketici)"),
                    ]),
                    element.element("option", [a.value("e-Fatura")], [
                      text("e-Fatura (Vergi Mükellefi / Kurumsal)"),
                    ]),
                    element.element("option", [a.value("e-Irsaliye")], [
                      text("e-İrsaliye"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Fatura Profili")]),
                element.element(
                  "select",
                  [
                    a.id("inv-profile"),
                    a.name("profile"),
                    a.class("studio-select"),
                  ],
                  [
                    element.element("option", [a.value("EARSIVFATURA")], [
                      text("EARSIVFATURA"),
                    ]),
                    element.element("option", [a.value("TICARIFATURA")], [
                      text("TICARIFATURA"),
                    ]),
                    element.element("option", [a.value("TEMELFATURA")], [
                      text("TEMELFATURA"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Para Birimi")]),
                element.element(
                  "select",
                  [
                    a.id("inv-cur"),
                    a.name("currency"),
                    a.class("studio-select"),
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
            ]),

            el("div", "form-row-3", [
              el("div", "form-group", [
                element.element("label", [], [
                  text("Alıcı Ad Soyad / Ticaret Ünvanı *"),
                ]),
                element.element(
                  "input",
                  [
                    a.id("inv-name"),
                    a.name("name"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute(
                      "placeholder",
                      "Ahmet Yılmaz veya Örnek Turizm A.Ş.",
                    ),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("VKN / TCKN *")]),
                element.element(
                  "input",
                  [
                    a.id("inv-vkn"),
                    a.name("vkn"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "11111111111"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Vergi Dairesi")]),
                element.element(
                  "input",
                  [
                    a.id("inv-tax-office"),
                    a.name("tax_office"),
                    a.class("studio-input"),
                    a.attribute("placeholder", "Kadıköy V.D."),
                  ],
                  [],
                ),
              ]),
            ]),

            el("div", "form-row-4", [
              el("div", "form-group", [
                element.element("label", [], [text("Konaklama Net Matrah *")]),
                element.element(
                  "input",
                  [
                    a.id("inv-net"),
                    a.name("net"),
                    a.class("studio-input"),
                    a.attribute("type", "number"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "10000"),
                    a.attribute("oninput", "recalculateTaxes()"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("KDV Tutarı (%10)")]),
                element.element(
                  "input",
                  [
                    a.id("inv-vat"),
                    a.name("vat"),
                    a.class("studio-input"),
                    a.attribute("type", "number"),
                    a.attribute("value", "1000"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("%2 Konaklama Vergisi")]),
                element.element(
                  "input",
                  [
                    a.id("inv-acc-tax"),
                    a.name("acc_tax"),
                    a.class("studio-input"),
                    a.attribute("type", "number"),
                    a.attribute("value", "200"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Fatura Genel Toplamı *")]),
                element.element(
                  "input",
                  [
                    a.id("inv-total"),
                    a.name("total"),
                    a.class("studio-input"),
                    a.attribute("type", "number"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "11200"),
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
              [
                icons.document(),
                text("e-Faturayı Mali Mühürle İmzala & GİB'e Gönder"),
              ],
            ),
          ],
        ),
      ]),

      // Fatura Listesi Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("GİB e-Fatura & e-Arşiv Kayıtları")]),
            el("p", "muted text-sm", [
              text(
                "Kesilen resmi faturalar, ETTN barkodları ve GİB entegrasyon yanıtları.",
              ),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_invoices) <> " Belge"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Fatura No")]),
                element.element("th", [], [text("Tür & Profil")]),
                element.element("th", [], [text("Alıcı")]),
                element.element("th", [], [text("VKN / TCKN")]),
                element.element("th", [], [text("Matrah")]),
                element.element("th", [], [text("KDV (%10)")]),
                element.element("th", [], [text("%2 Konaklama V.")]),
                element.element("th", [], [text("Genel Toplam")]),
                element.element("th", [], [text("GİB Durumu")]),
                element.element("th", [], [text("Tarih")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(invoices, fn(r) {
                case r {
                  [
                    _id,
                    _ettn,
                    inv_no,
                    itype,
                    name,
                    vkn,
                    net,
                    vat,
                    acc,
                    total,
                    cur,
                    status,
                    prof,
                    dt,
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
                              "color: #38bdf8; font-size: 0.82rem; padding: 4px 10px;",
                            ),
                            a.attribute(
                              "onclick",
                              "copyInvoiceNo('" <> inv_no <> "', this)",
                            ),
                          ],
                          [icons.document(), text(inv_no)],
                        ),
                      ]),
                      element.element("td", [], [
                        el("span", "badge dark", [text(itype)]),
                        el("small", "text-muted d-block", [text(prof)]),
                      ]),
                      element.element("td", [a.class("font-bold")], [text(name)]),
                      element.element("td", [a.class("text-muted text-sm")], [
                        text(vkn),
                      ]),
                      element.element("td", [], [text(cur <> " " <> net)]),
                      element.element("td", [a.class("text-muted")], [
                        text(cur <> " " <> vat),
                      ]),
                      element.element(
                        "td",
                        [a.class("font-bold text-warning")],
                        [text(cur <> " " <> acc)],
                      ),
                      element.element(
                        "td",
                        [a.class("font-bold text-success")],
                        [text(cur <> " " <> total)],
                      ),
                      element.element("td", [], [
                        el("span", "badge badge-success", [text(status)]),
                      ]),
                      element.element("td", [a.class("text-muted text-sm")], [
                        text(dt),
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
        function recalculateTaxes() {
          var net = parseFloat(document.getElementById('inv-net').value) || 0;
          var vat = Math.round(net * 0.10);
          var accTax = Math.round(net * 0.02);
          var total = net + vat + accTax;

          document.getElementById('inv-vat').value = vat;
          document.getElementById('inv-acc-tax').value = accTax;
          document.getElementById('inv-total').value = total;
        }

        function applyInvoicePreset(itype, profile, cur, name, vkn, taxOffice, net) {
          document.getElementById('inv-type').value = itype;
          document.getElementById('inv-profile').value = profile;
          document.getElementById('inv-cur').value = cur;
          document.getElementById('inv-name').value = name;
          document.getElementById('inv-vkn').value = vkn;
          document.getElementById('inv-tax-office').value = taxOffice;
          document.getElementById('inv-net').value = net;
          recalculateTaxes();
        }

        function copyInvoiceNo(invNo, btn) {
          navigator.clipboard.writeText(invNo).then(function() {
            var oldText = btn.innerText;
            btn.innerText = '✓ ' + invNo;
            btn.style.borderColor = '#10b981';
            setTimeout(function() {
              btn.innerText = invNo;
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
