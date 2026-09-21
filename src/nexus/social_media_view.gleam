import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import nexus/domain.{type Property, type Session}
import nexus/icons
import nexus/view.{el, hidden}

fn link(url: String, label: String, class: String, icon: element.Element(Nil)) {
  element.element("a", [a.href(url), a.class(class)], [icon, text(" " <> label)])
}

fn platform_pill(platform: String) {
  let #(class, name) = case platform {
    "instagram" -> #("platform-pill platform-instagram", "Instagram")
    "facebook" -> #("platform-pill platform-facebook", "Facebook")
    "tiktok" -> #("platform-pill platform-tiktok", "TikTok")
    "x" -> #("platform-pill platform-x", "X (Twitter)")
    _ -> #("platform-pill platform-google", "Google Business")
  }
  el("span", class, [text(name)])
}

pub fn page(
  s: Session,
  csrf: String,
  properties: List(Property),
  posts: List(List(String)),
  message: String,
) -> String {
  let total_posts = list.length(posts)

  view.shell(
    s,
    csrf,
    "Sosyal Medya Otomasyonu",
    el("div", "ai-studio-container", [
      // Üst Başlık & Aksiyonlar
      el("header", "studio-header", [
        el("div", "studio-header-main", [
          el("div", "studio-eyebrow-row", [
            el("span", "studio-badge", [
              el("span", "ai-glow-dot", []),
              text("PAZARLAMA & SOSYAL MEDYA MOTORU · ÇOKLU KANAL"),
            ]),
            el("span", "ai-status-pill", [
              icons.share(),
              text("Canlı İçerik Senkronizasyonu"),
            ]),
          ]),
          el("h1", "studio-title", [
            text("Sosyal Medya Pazarlama & Gönderi Yönetimi"),
          ]),
          el("p", "studio-subtitle", [
            text(
              "Tesis ve ilanlarınızı Instagram, Facebook, TikTok, X ve Google Business hesaplarınızda tek tıkla paylaşın; içerik planlamanızı ve sosyal etkileşimlerinizi yönetin.",
            ),
          ]),
        ]),
        el("div", "studio-header-actions", [
          link(
            "/admin/ai-hub",
            "AI İçerik & Post Sihirbazı",
            "btn-studio-secondary",
            icons.sparkles(),
          ),
          link(
            "/admin/campaigns",
            "Aktif Kampanyalar",
            "btn-studio-secondary",
            icons.categories(),
          ),
        ]),
      ]),

      // Bildirim Mesajı
      case message {
        "" -> text("")
        _ ->
          el("div", "ai-notice-banner", [
            el("span", "ai-notice-icon", [icons.check()]),
            text(message),
          ])
      },

      // Sosyal Ağ Bağlantı Durumu Kartları
      el("div", "stats-grid", [
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-purple", [icons.share()]),
          el("div", "", [
            el("span", "kpi-label", [text("Instagram")]),
            el("h3", "", [text("@nexustravel_resort")]),
            el("span", "badge badge-success", [text("Aktif & Bağlı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-blue", [icons.chat()]),
          el("div", "", [
            el("span", "kpi-label", [text("Facebook")]),
            el("h3", "", [text("Nexus Travel Official")]),
            el("span", "badge badge-success", [text("Aktif & Bağlı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-dark", [icons.activity()]),
          el("div", "", [
            el("span", "kpi-label", [text("TikTok")]),
            el("h3", "", [text("@nexus_hotels")]),
            el("span", "badge badge-success", [text("Aktif & Bağlı")]),
          ]),
        ]),
        el("div", "kpi-card", [
          el("div", "kpi-icon-wrap bg-green", [icons.globe()]),
          el("div", "", [
            el("span", "kpi-label", [text("Google Business")]),
            el("h3", "", [text("Google Haritalar")]),
            el("span", "badge badge-success", [text("Doğrulandı")]),
          ]),
        ]),
      ]),

      // İki Kolonlu Workspace: Sol Form + Sağ Canlı Mobil Önizleme
      el("div", "ai-studio-grid", [
        // Sol Kolon: Yeni Gönderi Oluşturma Formu
        el("div", "panel-card", [
          el("div", "tool-card-title-wrap mb-3", [
            el("div", "tool-card-icon social-ico", [icons.share()]),
            el("div", "", [
              el("h3", "", [text("Yeni Sosyal Medya Gönderisi Yayınla")]),
              el("p", "tool-desc", [
                text(
                  "İlanlarınızı seçerek doğrudan tek tıkla sosyal ağlarınıza gönderin veya planlayın.",
                ),
              ]),
            ]),
          ]),

          // Hızlı Şablonlar
          el("div", "preset-suggestions mb-3", [
            el("span", "preset-label", [text("Hızlı İçerikler:")]),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyPostPreset('instagram', 'Bodrum Lüks Villa Gün Batımı Keyfi', 'Ege\\'nin büyüleyici kıyısında, sonsuzluk havuzlu özel villanızda unutulmaz anlar yaşayın. Erken rezervasyon fırsatıyla hemen yerinizi ayırtın!\\n\\n#Bodrum #LuksVilla #TatilKeyfi #NexusTravel #VillaTatili', 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800', 'https://nexustraveltech.com/ilan/bodrum-villa')",
                ),
              ],
              [icons.villa(), text(" Bodrum Villa (Instagram)")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyPostPreset('tiktok', 'Kapadokya\\'da Masalsı Sabah: Balon Manzaralı Cave Otel', 'Kapadokya\\'nın eşsiz peri bacaları ve gökyüzünü süsleyen rengarenk sıcak hava balonları eşliğinde güne uyanmaya hazır mısınız?\\n\\n#Kapadokya #CaveOtel #BalonTuru #Gezgin #TravelTurkey', 'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800', 'https://nexustraveltech.com/ilan/kapadokya-cave')",
                ),
              ],
              [icons.hotel(), text(" Kapadokya Balon (TikTok)")],
            ),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("chip-preset"),
                a.attribute(
                  "onclick",
                  "applyPostPreset('facebook', 'Hafta Sonu Kaçamağına Özel %20 İndirim Fırsatı!', 'Şehrin gürültüsünden uzaklaşıp doğayla baş başa huzur dolu bir hafta sonu geçirmek isteyenlere müjde! Web sitemize özel %20 indirim kodunuz: HAFTASONU20\\n\\nRezervasyon için linke tıklayın!', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800', 'https://nexustraveltech.com/firsatlar')",
                ),
              ],
              [icons.tag(), text(" İndirim Kampanyası (Facebook)")],
            ),
          ]),

          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/social-media/post"),
              a.class("ai-studio-form"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-row-3", [
                el("div", "form-group", [
                  element.element("label", [], [text("Yayınlanacak Platform *")]),
                  element.element(
                    "select",
                    [
                      a.id("post-platform"),
                      a.name("platform"),
                      a.class("studio-select"),
                      a.attribute("required", "required"),
                      a.attribute("onchange", "updatePreview()"),
                    ],
                    [
                      element.element("option", [a.value("instagram")], [
                        text("Instagram (@nexustravel_resort)"),
                      ]),
                      element.element("option", [a.value("facebook")], [
                        text("Facebook (Nexus Travel Official)"),
                      ]),
                      element.element("option", [a.value("tiktok")], [
                        text("TikTok (@nexus_hotels)"),
                      ]),
                      element.element("option", [a.value("x")], [
                        text("X (Twitter)"),
                      ]),
                      element.element("option", [a.value("google_business")], [
                        text("Google Business"),
                      ]),
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [
                    text("İlişkili İlan (Opsiyonel)"),
                  ]),
                  element.element(
                    "select",
                    [a.name("property_id"), a.class("studio-select")],
                    [
                      element.element("option", [a.value("")], [
                        text("Genel Tesis Duyurusu"),
                      ]),
                      ..list.map(properties, fn(p) {
                        element.element("option", [a.value(p.id)], [
                          text(p.title <> " (" <> p.locality <> ")"),
                        ])
                      })
                    ],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [text("Yayın Durumu *")]),
                  element.element(
                    "select",
                    [a.name("status"), a.class("studio-select")],
                    [
                      element.element("option", [a.value("published")], [
                        text("Hemen Yayınla"),
                      ]),
                      element.element("option", [a.value("scheduled")], [
                        text("Planla (İçerik Takvimi)"),
                      ]),
                      element.element("option", [a.value("draft")], [
                        text("Taslak Olarak Kaydet"),
                      ]),
                    ],
                  ),
                ]),
              ]),

              el("div", "form-group", [
                element.element("label", [], [
                  text("Gönderi Başlığı / Kampanya Adı *"),
                ]),
                element.element(
                  "input",
                  [
                    a.type_("text"),
                    a.id("post-title"),
                    a.name("title"),
                    a.attribute(
                      "placeholder",
                      "Örn: Hafta Sonu Kaçamağına Özel %20 İndirim!",
                    ),
                    a.attribute("required", "required"),
                    a.attribute("onkeyup", "updatePreview()"),
                    a.class("studio-input"),
                  ],
                  [],
                ),
              ]),

              el("div", "form-group", [
                element.element("label", [], [
                  text("Gönderi Metni & Açıklama (Hashtag'ler dahil) *"),
                ]),
                element.element(
                  "textarea",
                  [
                    a.id("post-caption"),
                    a.name("caption"),
                    a.attribute("rows", "5"),
                    a.attribute(
                      "placeholder",
                      "Tesisimizin eşsiz manzarası eşliğinde unutulmaz bir tatil sizi bekliyor! #Tatil #Villa #NexusTravel",
                    ),
                    a.attribute("required", "required"),
                    a.attribute("onkeyup", "updatePreview()"),
                    a.class("studio-textarea"),
                  ],
                  [],
                ),
              ]),

              el("div", "form-row-2", [
                el("div", "form-group", [
                  element.element("label", [], [text("Görsel / Video URL")]),
                  element.element(
                    "input",
                    [
                      a.type_("text"),
                      a.id("post-media-url"),
                      a.name("media_url"),
                      a.attribute(
                        "placeholder",
                        "https://images.unsplash.com/...",
                      ),
                      a.attribute("oninput", "updatePreview()"),
                      a.class("studio-input"),
                    ],
                    [],
                  ),
                ]),
                el("div", "form-group", [
                  element.element("label", [], [
                    text("Rezervasyon / Yönlendirme Linki"),
                  ]),
                  element.element(
                    "input",
                    [
                      a.type_("text"),
                      a.id("post-link-url"),
                      a.name("link_url"),
                      a.attribute(
                        "placeholder",
                        "https://nexustravel.com/ilan/...",
                      ),
                      a.attribute("oninput", "updatePreview()"),
                      a.class("studio-input"),
                    ],
                    [],
                  ),
                ]),
              ]),

              element.element(
                "button",
                [
                  a.class("btn-studio-generate social-btn"),
                  a.attribute("type", "submit"),
                ],
                [icons.share(), text("Gönderiyi Paylaş & Kanallara Dağıt")],
              ),
            ],
          ),
        ]),

        // Sağ Kolon: Canlı Mobil Feed Mockup (Live Preview)
        el("div", "social-preview-container", [
          el("div", "flex-between mb-1", [
            el("div", "result-badge-wrap", [
              el("span", "badge-ai-ready", [
                el("span", "pulse-green-dot", []),
                text("CANLI ÖNİZLEME"),
              ]),
              el("span", "badge-ai-tool", [text("Mobil Ekran")]),
            ]),
            element.element(
              "button",
              [
                a.type_("button"),
                a.class("btn-copy-action"),
                a.attribute("onclick", "copyCaptionToClipboard()"),
              ],
              [icons.copy(), text("Metni Kopyala")],
            ),
          ]),

          // Telefon Çerçevesi Mockup
          el("div", "social-phone-frame", [
            el("div", "phone-top-bar", [
              el("span", "", [text("09:41")]),
              el("div", "phone-notch", []),
              el("span", "", [text("5G 100%")]),
            ]),
            el("div", "phone-post-header", [
              el("div", "phone-avatar-info", [
                el("div", "phone-avatar", [text("NX")]),
                el("div", "", [
                  el("div", "phone-user-handle", [text("nexustravel_resort")]),
                  el("div", "phone-user-sub", [
                    text("Sponsorlu · Rezervasyon Açık"),
                  ]),
                ]),
              ]),
              el("span", "text-muted font-bold", [text("•••")]),
            ]),
            el("div", "phone-media-container", [
              element.element(
                "img",
                [
                  a.id("preview-image"),
                  a.class("phone-media-img"),
                  a.src(
                    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800",
                  ),
                  a.alt("Post Preview"),
                ],
                [],
              ),
            ]),
            el("div", "phone-actions-row", [
              el("div", "phone-action-icons", [
                el("span", "text-rose", [icons.star()]),
                icons.chat(),
                icons.share(),
              ]),
              el("span", "badge dark text-xs", [text("Kaydet")]),
            ]),
            el("div", "phone-caption-area", [
              el("div", "font-bold mb-1", [
                el("span", "phone-caption-handle", [text("nexustravel_resort")]),
                element.element("span", [a.id("preview-title")], [
                  text("Bodrum Lüks Villa Gün Batımı Keyfi"),
                ]),
              ]),
              element.element(
                "div",
                [a.id("preview-caption"), a.class("phone-caption-text")],
                [
                  text(
                    "Ege'nin büyüleyici kıyısında, sonsuzluk havuzlu özel villanızda unutulmaz anlar yaşayın. Erken rezervasyon fırsatıyla hemen yerinizi ayırtın!\n\n#Bodrum #LuksVilla #TatilKeyfi #NexusTravel",
                  ),
                ],
              ),
              element.element(
                "a",
                [
                  a.id("preview-link-badge"),
                  a.class("phone-link-badge"),
                  a.href("#"),
                  a.target("_blank"),
                ],
                [icons.arrow_up_right(), text("Şimdi İncele & Rezervasyon Yap")],
              ),
            ]),
          ]),
        ]),
      ]),

      // Paylaşılan & Planlanan Gönderiler Tablosu
      el("div", "panel-card", [
        el("div", "section-heading-split mb-3", [
          el("div", "", [
            el("h3", "", [text("Sosyal Medya İçerik Akışı")]),
            el("p", "muted text-sm", [
              text(
                "Yayınlanmış, planlanan ve taslak gönderilerinizin güncel durumu.",
              ),
            ]),
          ]),
          el("span", "badge dark", [
            text(int.to_string(total_posts) <> " Gönderi"),
          ]),
        ]),

        case posts {
          [] ->
            el("div", "empty", [
              el("div", "empty-icon", [icons.share()]),
              el("p", "muted", [
                text("Henüz yayınlanmış bir sosyal medya gönderisi bulunmuyor."),
              ]),
            ])
          _ ->
            el("div", "table-responsive", [
              element.element("table", [a.class("table modern-table")], [
                element.element("thead", [], [
                  element.element("tr", [], [
                    element.element("th", [], [text("Platform")]),
                    element.element("th", [], [text("Başlık")]),
                    element.element("th", [], [text("Açıklama")]),
                    element.element("th", [], [text("Durum")]),
                    element.element("th", [], [text("Etkileşim")]),
                    element.element("th", [], [text("Tarih")]),
                    element.element("th", [], [text("İşlem")]),
                  ]),
                ]),
                element.element(
                  "tbody",
                  [],
                  list.map(posts, fn(row) {
                    case row {
                      [
                        id,
                        platform,
                        title,
                        caption,
                        _media,
                        status,
                        likes,
                        views,
                        created_at,
                        ..
                      ] -> {
                        element.element("tr", [], [
                          element.element("td", [], [platform_pill(platform)]),
                          element.element("td", [a.class("font-medium")], [
                            text(title),
                          ]),
                          element.element("td", [a.class("muted text-sm")], [
                            text(caption),
                          ]),
                          element.element("td", [], [
                            el(
                              "span",
                              case status {
                                "published" -> "badge badge-success"
                                "scheduled" -> "badge badge-info"
                                _ -> "badge dark"
                              },
                              [
                                text(case status {
                                  "published" -> "Yayınlandı"
                                  "scheduled" -> "Planlandı"
                                  _ -> "Taslak"
                                }),
                              ],
                            ),
                          ]),
                          element.element(
                            "td",
                            [a.class("muted font-bold text-sm")],
                            [
                              text(likes <> " beğeni · " <> views <> " izlenme"),
                            ],
                          ),
                          element.element("td", [a.class("muted text-sm")], [
                            text(created_at),
                          ]),
                          element.element("td", [], [
                            element.element(
                              "form",
                              [
                                a.attribute("method", "post"),
                                a.attribute(
                                  "action",
                                  "/admin/social-media/" <> id <> "/delete",
                                ),
                              ],
                              [
                                hidden("csrf", csrf),
                                element.element(
                                  "button",
                                  [
                                    a.class("button danger small"),
                                    a.attribute("type", "submit"),
                                  ],
                                  [icons.trash(), text(" Sil")],
                                ),
                              ],
                            ),
                          ]),
                        ])
                      }
                      _ -> text("")
                    }
                  }),
                ),
              ]),
            ])
        },
      ]),

      // Client-side Interactivity Script
      element.element("script", [], [
        text(
          "
        function applyPostPreset(platform, title, caption, mediaUrl, linkUrl) {
          document.getElementById('post-platform').value = platform;
          document.getElementById('post-title').value = title;
          document.getElementById('post-caption').value = caption;
          document.getElementById('post-media-url').value = mediaUrl;
          document.getElementById('post-link-url').value = linkUrl;
          updatePreview();
        }

        function updatePreview() {
          var title = document.getElementById('post-title').value || 'Gönderi Başlığı';
          var caption = document.getElementById('post-caption').value || 'Açıklama ve hashtag detayları burada görüntülenecek...';
          var mediaUrl = document.getElementById('post-media-url').value || 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800';
          var linkUrl = document.getElementById('post-link-url').value || '#';

          document.getElementById('preview-title').innerText = title;
          document.getElementById('preview-caption').innerText = caption;
          var img = document.getElementById('preview-image');
          if (img) img.src = mediaUrl;
          var linkBadge = document.getElementById('preview-link-badge');
          if (linkBadge) linkBadge.href = linkUrl;
        }

        function copyCaptionToClipboard() {
          var caption = document.getElementById('post-caption').value;
          if (!caption) return;
          navigator.clipboard.writeText(caption).then(function() {
            var btn = document.querySelector('.btn-copy-action');
            if (btn) {
              var oldHtml = btn.innerHTML;
              btn.innerHTML = '✓ Kopyalandı!';
              btn.style.color = '#059669';
              setTimeout(function() {
                btn.innerHTML = oldHtml;
                btn.style.color = '';
              }, 2000);
            }
          });
        }
        ",
        ),
      ]),
    ]),
  )
}
