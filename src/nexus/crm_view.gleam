import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  guests: List(List(String)),
  messages: List(List(String)),
  checkins: List(List(String)),
  notice: String,
) {
  let total_guests = list.length(guests)
  let total_messages = list.length(messages)
  let total_checkins = list.length(checkins)

  view.shell(
    s,
    csrf,
    "CRM & WhatsApp Hub",
    el("div", "ai-studio-container", [
      // Üst Başlık & Eylem Çubuğu
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text("ÇOKLU KANAL İLETİŞİM · WHATSAPP ENTEGRASYONU · MOBİL GİRİŞ"),
            ]),
            el("span", "ai-status-pill", [
              icons.whatsapp(),
              text("Omnichannel Misafir Hub"),
            ]),
          ]),
          el("h1", "studio-title", [
            text("Omnichannel Misafir CRM & WhatsApp Otomasyonu"),
          ]),
          el("p", "studio-subtitle", [
            text(
              "Misafirlerinizin rezervasyon geçmişini, iletişim tercihlerini ve anlık WhatsApp mesajlaşmalarını tek merkezden yönetin; otomatik kapı PIN kodları ve online check-in bağlantıları iletin.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          element.element(
            "a",
            [a.href("/admin/ai-hub"), a.class("btn-studio-secondary")],
            [icons.sparkles(), text("AI Misafir Yanıtlayıcı")],
          ),
          element.element(
            "a",
            [
              a.href("#whatsapp-form"),
              a.class("btn-studio-generate"),
              a.attribute(
                "style",
                "width: auto; padding: 8px 16px; font-size: 0.84rem; background: #25d366; box-shadow: 0 4px 14px rgba(37, 211, 102, 0.3);",
              ),
            ],
            [icons.whatsapp(), text("Hızlı WhatsApp Mesajı")],
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
          el("div", "kpi-icon-wrap bg-blue", [icons.user()]),
          el("div", "", [
            el("span", "kpi-label", [text("Kayıtlı Misafir")]),
            el("h3", "", [text(int.to_string(total_guests))]),
            el("span", "kpi-sub", [text("Misafir veri tabanı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.whatsapp()]),
          el("div", "", [
            el("span", "kpi-label", [text("WhatsApp Bildirimleri")]),
            el("h3", "", [text(int.to_string(total_messages))]),
            el("span", "kpi-sub", [text("WhatsApp Cloud API")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.mobile_checkin()]),
          el("div", "", [
            el("span", "kpi-label", [text("Online Check-In")]),
            el("h3", "text-primary", [text(int.to_string(total_checkins))]),
            el("span", "kpi-sub", [text("Dijital kapı PIN sistemi")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-amber", [icons.trending_up()]),
          el("div", "", [
            el("span", "kpi-label", [text("Doğrudan Rezervasyon")]),
            el("h3", "text-success", [text("+%18.4")]),
            el("span", "kpi-sub", [text("Doğrudan rezervasyon motoru")]),
          ]),
        ]),
      ]),

      // Canlı Mobil Check-In ve Kapı PIN Kodları Masası
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [
              text("Canlı Mobil Online Check-In & Kapı PIN Kodları Masası"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Misafirlerin mobil cihazlarından gerçekleştirdiği temassız girişler, atanan elektronik kapı PIN kodları ve varış saatleri:",
              ),
            ]),
          ]),
          el("span", "badge badge-success", [text("Canlı Akış Aktif")]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Rezervasyon No")]),
                element.element("th", [], [text("Misafir Adı")]),
                element.element("th", [], [text("Kimlik / Pasaport")]),
                element.element("th", [], [text("İletişim")]),
                element.element("th", [], [text("Tahmini Varış")]),
                element.element("th", [], [
                  text("Kapı PIN Kodu (Tıkla Kopyala)"),
                ]),
                element.element("th", [], [text("Giriş Zamanı")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(checkins, fn(r) {
                case r {
                  [rid, name, tc, phone, email, eta, pin, dt] ->
                    element.element("tr", [], [
                      element.element(
                        "td",
                        [a.class("font-bold text-primary")],
                        [text(rid)],
                      ),
                      element.element("td", [a.class("font-bold")], [text(name)]),
                      element.element("td", [a.class("text-muted text-sm")], [
                        text(tc),
                      ]),
                      element.element("td", [a.class("text-sm")], [
                        text(phone <> " · " <> email),
                      ]),
                      element.element("td", [], [
                        el("span", "badge dark", [text(eta)]),
                      ]),
                      element.element("td", [], [
                        element.element(
                          "button",
                          [
                            a.type_("button"),
                            a.class("pin-code-badge"),
                            a.attribute("title", "Kodu Kopyala"),
                            a.attribute(
                              "onclick",
                              "copyDoorPin('" <> pin <> "', this)",
                            ),
                          ],
                          [icons.lock(), text(pin)],
                        ),
                      ]),
                      element.element("td", [a.class("text-sm text-muted")], [
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

      // Doğrudan Rezervasyon & Fiyat Kıyaslama Widget'ı
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("Doğrudan Rezervasyon & Fiyat Kıyaslama Motoru")]),
            el("p", "muted text-sm", [
              text(
                "Web sitenizdeki ziyaretçilere OTA kanallarındaki komisyonlu fiyatları anlık kıyaslayıp doğrudan rezervasyona yönlendiren dinamik bar:",
              ),
            ]),
          ]),
          el("span", "badge badge-success", [text("Web Sitenizde Canlı")]),
        ]),
        el("div", "stats-grid", [
          el("div", "p-3 bg-light rounded border-primary", [
            el("span", "badge primary mb-2", [text("SİZİN SİTENİZ (EN UCUZ)")]),
            el("h4", "text-primary font-bold text-lg", [text("€ 200 / gece")]),
            el("small", "text-muted", [
              text(
                "Ücretsiz İptal · Hoş Geldiniz İkramı · En İyi Fiyat Garantisi",
              ),
            ]),
          ]),
          el("div", "p-3 bg-light rounded opacity-75", [
            el("span", "badge dark mb-2", [text("Global Seyahat Portalları")]),
            el("h4", "text-danger font-bold text-lg", [text("€ 245 / gece")]),
            el("small", "text-muted", [text("+%22.5 komisyon farkı")]),
          ]),
          el("div", "p-3 bg-light rounded opacity-75", [
            el("span", "badge dark mb-2", [text("Diğer Acente Ağları")]),
            el("h4", "text-danger font-bold text-lg", [text("€ 250 / gece")]),
            el("small", "text-muted", [text("+%25.0 komisyon farkı")]),
          ]),
        ]),
      ]),

      // İki Kolonlu Form Alanı: WhatsApp Mesajı & Yeni CRM Kartı
      el("div", "grid-2col", [
        // Sol Form: WhatsApp İletişim Otomasyonu
        element.element("div", [a.id("whatsapp-form"), a.class("panel-card")], [
          el("div", "tool-card-title-wrap mb-3", [
            el("div", "tool-card-icon", [
              element.element(
                "span",
                [a.attribute("style", "color: #25d366;")],
                [icons.whatsapp()],
              ),
            ]),
            el("div", "", [
              el("h3", "", [text("Hızlı WhatsApp Mesajı Gönder")]),
              el("p", "tool-desc", [
                text(
                  "Misafire check-in öncesi rehber, kapı şifresi veya memnuniyet anketi iletin.",
                ),
              ]),
            ]),
          ]),

          // Hızlı Mesaj Şablonları
          el("div", "preset-suggestions mb-3", [
            el("span", "preset-label", [text("Hızlı Şablonlar:")]),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyWaTemplate('pre_arrival', 'Sayın Misafirimiz, Nexus Travel Resort tesisimize hoş geldiniz! Rezervasyonunuz onaylandı. Giriş saatinizde kullanacağınız 4 haneli temassız kapı şifreniz aktif edilmiştir. Tesis konumumuz: https://maps.google.com/?q=NexusResort. İyi yolculuklar dileriz!')",
                ),
              ],
              [text("Giriş Öncesi PIN & Konum")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyWaTemplate('in_house', 'Değerli Misafirimiz, umarız konaklamanız harika geçiyordur! Odanızla ilgili ek havlu, oda servisi veya tur rehberliği gibi her türlü ihtiyacınız için bu hat üzerinden resepsiyona anında yazabilirsiniz. Wi-Fi Şifreniz: NexusGuest2026')",
                ),
              ],
              [text("Konaklama & Wi-Fi")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyWaTemplate('post_departure', 'Değerli Misafirimiz, bizi tercih ettiğiniz için teşekkür ederiz. Deneyiminizi 1 dakikada Google Haritalar üzerinden değerlendirmeniz bizi çok mutlu eder: https://g.page/r/nexus-travel/review. Bir sonraki konaklamanızda %10 indirim kodunuz: TEKRARHOSGELDIN')",
                ),
              ],
              [text("Çıkış Sonrası Yorum")],
            ),
          ]),

          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/crm/message"),
              a.class("ai-studio-form"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-group", [
                element.element("label", [], [text("Misafir Adı Soyadı *")]),
                element.element(
                  "input",
                  [
                    a.id("wa-guest-name"),
                    a.name("guest_name"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "Örn: Alperen Yılmaz"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [
                  text("Telefon Numarası (WhatsApp) *"),
                ]),
                element.element(
                  "input",
                  [
                    a.id("wa-phone"),
                    a.name("phone"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "Örn: +905321112233"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Mesaj Şablonu / Türü *")]),
                element.element(
                  "select",
                  [
                    a.id("wa-msg-type"),
                    a.name("msg_type"),
                    a.class("studio-select"),
                  ],
                  [
                    element.element("option", [a.value("pre_arrival")], [
                      text("Giriş Öncesi Hoş Geldiniz & Konum/GPS Bilgisi"),
                    ]),
                    element.element("option", [a.value("in_house")], [
                      text("Konaklama Sırasında İhtiyaç & Concierge Kontrolü"),
                    ]),
                    element.element("option", [a.value("post_departure")], [
                      text("Çıkış Sonrası Teşekkür & Google Yorum Talebi"),
                    ]),
                    element.element("option", [a.value("promo")], [
                      text("Özel İndirim & Erken Rezervasyon Fırsatı"),
                    ]),
                    element.element("option", [a.value("custom")], [
                      text("Özel Mesaj"),
                    ]),
                  ],
                ),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Mesaj İçeriği *")]),
                element.element(
                  "textarea",
                  [
                    a.id("wa-message"),
                    a.name("message"),
                    a.class("studio-textarea"),
                    a.attribute("rows", "4"),
                    a.attribute("required", "required"),
                    a.attribute(
                      "placeholder",
                      "Sayın Misafirimiz, tesisimize hoş geldiniz...",
                    ),
                  ],
                  [],
                ),
              ]),
              element.element(
                "button",
                [
                  a.class("btn-studio-generate"),
                  a.attribute("type", "submit"),
                  a.attribute(
                    "style",
                    "background: #25d366; box-shadow: 0 4px 14px rgba(37, 211, 102, 0.35);",
                  ),
                ],
                [icons.whatsapp(), text("WhatsApp Mesajını Hemen İlet")],
              ),
            ],
          ),
        ]),

        // Sağ Form: Yeni Misafir CRM Kartı (IRI CRM)
        el("div", "panel-card", [
          el("div", "tool-card-title-wrap mb-3", [
            el("div", "tool-card-icon", [icons.user_add()]),
            el("div", "", [
              el("h3", "", [text("Yeni Misafir Profili Ekle")]),
              el("p", "tool-desc", [
                text(
                  "Misafir tercihlerini, sadakat statüsünü ve özel notlarını kaydedin.",
                ),
              ]),
            ]),
          ]),

          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/crm/guest"),
              a.class("ai-studio-form"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-group", [
                element.element("label", [], [text("Ad Soyad *")]),
                element.element(
                  "input",
                  [
                    a.name("full_name"),
                    a.class("studio-input"),
                    a.attribute("required", "required"),
                    a.attribute("placeholder", "Örn: Mehmet Özkan"),
                  ],
                  [],
                ),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("E-posta")]),
                  element.element(
                    "input",
                    [
                      a.name("email"),
                      a.class("studio-input"),
                      a.attribute("type", "email"),
                      a.attribute("placeholder", "misafir@domain.com"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Telefon")]),
                  element.element(
                    "input",
                    [
                      a.name("phone"),
                      a.class("studio-input"),
                      a.attribute("placeholder", "+90 532 ..."),
                    ],
                    [],
                  ),
                ]),
              ]),
              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Milliyet")]),
                  element.element(
                    "input",
                    [
                      a.name("nationality"),
                      a.class("studio-input"),
                      a.attribute("value", "TR"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("VIP Sadakat Seviyesi")]),
                  element.element(
                    "select",
                    [a.name("vip_tier"), a.class("studio-select")],
                    [
                      element.element("option", [a.value("standard")], [
                        text("Standard"),
                      ]),
                      element.element("option", [a.value("silver")], [
                        text("Silver"),
                      ]),
                      element.element("option", [a.value("gold")], [
                        text("Gold"),
                      ]),
                      element.element("option", [a.value("vip")], [
                        text("VIP Misafir"),
                      ]),
                      element.element("option", [a.value("platinum")], [
                        text("Platinum"),
                      ]),
                    ],
                  ),
                ]),
              ]),
              el("div", "form-group", [
                element.element("label", [], [text("Özel Tercihler & Notlar")]),
                element.element(
                  "input",
                  [
                    a.name("preferences"),
                    a.class("studio-input"),
                    a.attribute(
                      "placeholder",
                      "Deniz manzaralı oda, sessiz kat, late checkout talebi",
                    ),
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
                [icons.user_add(), text("Misafir Profilini Kaydet")],
              ),
            ],
          ),
        ]),
      ]),

      // Misafir Listesi Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("Misafir CRM Portföyü")]),
            el("p", "muted text-sm", [
              text(
                "Kayıtlı misafirlerin harcama geçmişi, konaklama sıklığı ve VIP statüleri.",
              ),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_guests) <> " Misafir"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Misafir")]),
                element.element("th", [], [text("İletişim")]),
                element.element("th", [], [text("Milliyet")]),
                element.element("th", [], [text("Konaklama")]),
                element.element("th", [], [text("Toplam Harcama")]),
                element.element("th", [], [text("VIP Statü")]),
                element.element("th", [], [text("Tercihler")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(guests, fn(r) {
                case r {
                  [_id, name, email, phone, nat, stays, spend, tier, pref] ->
                    element.element("tr", [], [
                      element.element("td", [a.class("font-bold")], [text(name)]),
                      element.element("td", [a.class("text-sm")], [
                        text(phone <> " · " <> email),
                      ]),
                      element.element("td", [], [
                        el("span", "badge dark", [text(nat)]),
                      ]),
                      element.element("td", [], [text(stays <> " kez")]),
                      element.element(
                        "td",
                        [a.class("font-bold text-success")],
                        [text("₺ " <> spend)],
                      ),
                      element.element("td", [], [
                        el(
                          "span",
                          "badge "
                            <> case tier {
                            "vip" -> "primary"
                            "platinum" -> "primary"
                            "gold" -> "warning"
                            _ -> "dark"
                          },
                          [text(tier)],
                        ),
                      ]),
                      element.element("td", [a.class("text-sm text-muted")], [
                        text(pref),
                      ]),
                    ])
                  _ -> text("")
                }
              }),
            ),
          ]),
        ]),
      ]),

      // WhatsApp Mesaj Geçmişi
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [
              text("WhatsApp İletişim Akışı & Mesajlaşma Kayıtları"),
            ]),
            el("p", "muted text-sm", [
              text(
                "İletilen bildirimler, otomatik şablonlar ve gönderim durumları.",
              ),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_messages) <> " Mesaj"),
          ]),
        ]),
        el("div", "table-responsive", [
          element.element("table", [a.class("table modern-table")], [
            element.element("thead", [], [
              element.element("tr", [], [
                element.element("th", [], [text("Alıcı")]),
                element.element("th", [], [text("Telefon")]),
                element.element("th", [], [text("Tür")]),
                element.element("th", [], [text("Mesaj İçeriği")]),
                element.element("th", [], [text("Durum")]),
                element.element("th", [], [text("Tarih")]),
                element.element("th", [], [text("İşlem")]),
              ]),
            ]),
            element.element(
              "tbody",
              [],
              list.map(messages, fn(r) {
                case r {
                  [_id, name, phone, mtype, msg, status, date] -> {
                    let clean_phone =
                      string.replace(phone, "+", "") |> string.replace(" ", "")
                    element.element("tr", [], [
                      element.element("td", [a.class("font-bold")], [text(name)]),
                      element.element("td", [a.class("text-sm")], [text(phone)]),
                      element.element("td", [], [
                        el("span", "badge dark", [text(mtype)]),
                      ]),
                      element.element("td", [a.class("text-sm")], [text(msg)]),
                      element.element("td", [], [
                        el("span", "badge badge-success", [text(status)]),
                      ]),
                      element.element("td", [a.class("text-muted text-sm")], [
                        text(date),
                      ]),
                      element.element("td", [], [
                        element.element(
                          "a",
                          [
                            a.href("https://wa.me/" <> clean_phone),
                            a.target("_blank"),
                            a.class("button secondary small"),
                          ],
                          [icons.whatsapp(), text(" WhatsApp'ta Aç")],
                        ),
                      ]),
                    ])
                  }
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
        function applyWaTemplate(type, msg) {
          document.getElementById('wa-msg-type').value = type;
          document.getElementById('wa-message').value = msg;
        }

        function copyDoorPin(pin, btn) {
          navigator.clipboard.writeText(pin).then(function() {
            var oldText = btn.innerText;
            btn.innerText = '✓ ' + pin;
            btn.style.borderColor = '#10b981';
            btn.style.color = '#10b981';
            setTimeout(function() {
              btn.innerText = pin;
              btn.style.borderColor = '';
              btn.style.color = '';
            }, 1800);
          });
        }
        ",
        ),
      ]),
    ]),
  )
}
