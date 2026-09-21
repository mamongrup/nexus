import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden, input}
import pog

pub fn published(db: pog.Connection) {
  pog.query("select * from cms.public_pages()")
  |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { r.rows })
}

fn link(url: String, label: String, class: String) {
  element.element("a", [a.href(url), a.class(class)], [text(label)])
}

pub fn submit_contact(
  db: pog.Connection,
  name: String,
  email: String,
  message: String,
) {
  pog.query("select cms.contact_submit($1,$2,$3)")
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.text(email))
  |> pog.parameter(pog.text(message))
  |> pog.returning(decode.field(0, decode.string, decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { list.first(r.rows) |> result.unwrap("invalid") })
}

fn site_brand() {
  element.element("a", [a.href("/"), a.class("site-brand")], [
    el("span", "site-brand-mark", [text("N")]),
    el("div", "site-brand-copy", [
      el("strong", "", [text("NEXUS")]),
      el("small", "", [text("TRAVELTECH")]),
    ]),
  ])
}

fn category_item(
  icon: Element(Nil),
  title: String,
  desc: String,
  href: String,
) {
  element.element("a", [a.href(href), a.class("dropdown-item")], [
    el("span", "dropdown-icon", [icon]),
    el("div", "dropdown-text", [
      el("strong", "", [text(title)]),
      el("small", "", [text(desc)]),
    ]),
  ])
}

fn module_item(icon: Element(Nil), title: String, desc: String, href: String) {
  element.element("a", [a.href(href), a.class("dropdown-item")], [
    el("span", "dropdown-icon module-ico", [icon]),
    el("div", "dropdown-text", [
      el("strong", "", [text(title)]),
      el("small", "", [text(desc)]),
    ]),
  ])
}

fn nav_sub_item(icon: Element(Nil), title: String, desc: String, href: String) {
  element.element("a", [a.href(href), a.class("sub-dropdown-item")], [
    el("span", "sub-item-icon", [icon]),
    el("div", "sub-item-content", [
      el("strong", "sub-item-title", [text(title)]),
      el("small", "sub-item-desc", [text(desc)]),
    ]),
  ])
}

fn lang_option(code: String, flag: String, name: String, short: String) {
  element.element(
    "button",
    [
      a.class("lang-option-btn"),
      a.attribute("data-lang", code),
      a.attribute("type", "button"),
    ],
    [
      el("span", "lang-flag", [text(flag)]),
      el("span", "lang-name", [text(name)]),
      el("span", "lang-short", [text(short)]),
    ],
  )
}

pub fn site_header(_rows: List(List(String))) {
  el("div", "site-header-wrapper", [
    el("header", "site-header", [
      site_brand(),
      el("nav", "site-nav", [
        // 1. Anasayfa
        link("/", "Anasayfa", "nav-link nav-home-link"),

        // 2. Kurumsal Dropdown
        el("details", "nav-dropdown corporate-menu", [
          el("summary", "nav-dropdown-trigger", [
            el("span", "nav-icon", [icons.corporate()]),
            text("Kurumsal"),
            el("span", "nav-chevron", [text("▾")]),
          ]),
          el("div", "nav-dropdown-card corporate-card", [
            el("div", "dropdown-header", [
              el("span", "", [text("KURUMSAL")]),
              el("span", "portal-notice-chip", [text("NEXUS HQ")]),
            ]),
            el("div", "dropdown-vertical-list", [
              nav_sub_item(
                icons.corporate(),
                "Hakkımızda",
                "NEXUS vizyonu, teknolojisi ve kurumsal yapısı",
                "/hakkimizda",
              ),
              nav_sub_item(
                icons.document(),
                "Belge & Yasal İzinler",
                "TÜRSAB, 7464 Konut İzinleri ve yasal sertifikasyonlar",
                "/hakkimizda#mevzuat",
              ),
              nav_sub_item(
                icons.security(),
                "Güvenlik & KVKK",
                "Yüksek güvenlikli bulut mimarisi ve veri koruma",
                "/hakkimizda#guvenlik",
              ),
            ]),
          ]),
        ]),

        // 3. Kategoriler Mega Menu
        el("details", "nav-dropdown categories-menu", [
          el("summary", "nav-dropdown-trigger", [
            el("span", "nav-icon", [icons.categories()]),
            text("Kategoriler"),
            el("span", "nav-chevron", [text("▾")]),
          ]),
          el("div", "nav-dropdown-card mega-categories", [
            el("div", "dropdown-header", [
              el("span", "", [text("TURİZM ÜRÜN KATEGORİLERİ")]),
              el("span", "portal-notice-chip", [
                text("Canlı Rezervasyon Portalları"),
              ]),
            ]),
            el("div", "dropdown-grid", [
              category_item(
                icons.hotel(),
                "Otel & Konaklama",
                "Yıldızlı otel, butik otel, tatil köyü",
                "/ilanlar?category=hotel",
              ),
              category_item(
                icons.villa(),
                "Villa & Tatil Evi",
                "Müstakil villa, lüks konut, dağ evi",
                "/ilanlar?category=villa",
              ),
              category_item(
                icons.tour(),
                "Tur & Deneyim",
                "Günübirlik & paket turlar, aktiviteler",
                "/ilanlar?category=tour",
              ),
              category_item(
                icons.activity(),
                "Aktivite & Macera",
                "Sıcak hava balonu, yamaç paraşütü, rafting",
                "/ilanlar?category=activity",
              ),
              category_item(
                icons.yacht(),
                "Yat & Marina",
                "Lüks gulet, motoryat, mavi tur",
                "/ilanlar?category=yacht",
              ),
              category_item(
                icons.transfer(),
                "VIP Transfer",
                "Havalimanı karşılama, şoförlü VIP filo",
                "/ilanlar?category=transfer",
              ),
              category_item(
                icons.car(),
                "Araç Kiralama",
                "Binek, SUV ve filo kiralama",
                "/ilanlar?category=car",
              ),
              category_item(
                icons.beach(),
                "Plaj & Beach Club",
                "Özel plaj, şezlong, VIP loca",
                "/ilanlar?category=beach",
              ),
            ]),
            el("div", "dropdown-footer", [
              el("span", "dropdown-hint", [
                text("Tüm kategoriler doğrudan rezervasyon portallarını besler"),
              ]),
              link(
                "/ilanlar",
                "Tüm İlanları Canlı Vitrinde Gör ➔",
                "dropdown-footer-link",
              ),
            ]),
          ]),
        ]),

        // 4. Modüller Mega Menu
        el("details", "nav-dropdown modules-menu", [
          el("summary", "nav-dropdown-trigger", [
            el("span", "nav-icon", [icons.modules()]),
            text("Modüller"),
            el("span", "nav-chevron", [text("▾")]),
          ]),
          el("div", "nav-dropdown-card mega-modules", [
            el("div", "dropdown-header", [
              el("span", "", [text("OPERASYONEL YAZILIM MODÜLLERİ")]),
              el("span", "portal-notice-chip", [text("29 Entegre Sistem")]),
            ]),
            el("div", "dropdown-grid", [
              module_item(
                icons.pms(),
                "Ön Büro (PMS)",
                "Oda, rezervasyon ve folyo yönetimi",
                "/modul-pms",
              ),
              module_item(
                icons.channel_manager(),
                "Kanal Yöneticisi",
                "Çoklu kanal & OTA iki yönlü senkronu",
                "/modul-channel-manager",
              ),
              module_item(
                icons.kbs(),
                "KBS Kimlik Bildirimi",
                "Otomatik emniyet & jandarma akışı",
                "/modul-kbs",
              ),
              module_item(
                icons.dynamic_pricing(),
                "Dinamik Fiyatlama AI",
                "Yapay zeka yield ve talep motoru",
                "/modul-dinamik-fiyat",
              ),
              module_item(
                icons.accounting(),
                "Muhasebe & Cari",
                "Cari, fatura, e-Arşiv ve banka",
                "/modul-accounting",
              ),
              module_item(
                icons.pos(),
                "Restoran & POS",
                "Adisyon, masa ve sipariş yönetimi",
                "/modul-pos",
              ),
              module_item(
                icons.housekeeping(),
                "Kat Hizmetleri & Oda",
                "Oda temizliği, arıza bildirimleri",
                "/modul-housekeeping",
              ),
              module_item(
                icons.mobile_checkin(),
                "Mobil Check-in",
                "Temassız pasaport/kimlik okuma",
                "/modul-mobile-checkin",
              ),
            ]),
            el("div", "dropdown-footer", [
              el("span", "dropdown-hint", [
                text("PMS, Channel Manager, KBS ve POS altyapısı"),
              ]),
              link(
                "/program",
                "Tüm 29 Modülü ve Şemayı İncele ➔",
                "dropdown-footer-link",
              ),
            ]),
          ]),
        ]),

        // 5. Blog
        link("/blog", "Blog", "nav-link"),

        // 6. İletişim
        link("/iletisim", "İletişim", "nav-link"),
      ]),

      // SAĞ TARAF: Dil Seçici + Üye İkonu Dropdown (Üye Ol, Tedarikçi Girişi, Acente Girişi) + Panoya Giriş
      el("div", "site-header-actions", [
        // 1. Dil Seçici
        el("details", "nav-dropdown lang-dropdown", [
          el("summary", "chic-selector-pill lang-pill", [
            el("span", "pill-icon", [icons.globe()]),
            el("span", "pill-lang-label", [text("TR")]),
            el("span", "pill-chevron", [text("▾")]),
          ]),
          el("div", "nav-dropdown-card lang-card", [
            el("div", "lang-options-list", [
              lang_option("tr", "🇹🇷", "Türkçe", "TR"),
              lang_option("en", "🇬🇧", "English", "EN"),
              lang_option("de", "🇩🇪", "Deutsch", "DE"),
              lang_option("ru", "🇷🇺", "Русский", "RU"),
              lang_option("ar", "🇸🇦", "العربية", "AR"),
              lang_option("fr", "🇫🇷", "Français", "FR"),
            ]),
          ]),
        ]),

        // 2. Üye İkonu Dropdown (Dilin sağ tarafında: Üye Ol, Tedarikçi Girişi, Acente Girişi)
        el("details", "nav-dropdown user-auth-dropdown", [
          el("summary", "chic-selector-pill user-auth-pill", [
            el("span", "pill-icon user-pill-icon", [icons.user()]),
            el("span", "pill-user-label", [text("Giriş / Üye Ol")]),
            el("span", "pill-chevron", [text("▾")]),
          ]),
          el("div", "nav-dropdown-card user-auth-card", [
            el("div", "dropdown-header", [
              el("span", "", [text("KULLANICI İŞLEMLERİ")]),
              el("span", "portal-notice-chip", [text("B2B & Ortaklık")]),
            ]),
            el("div", "dropdown-vertical-list", [
              nav_sub_item(
                icons.user_add(),
                "Üye Ol",
                "Yeni tedarikçi, otel veya seyahat acentesi başvurusu",
                "/login",
              ),
              nav_sub_item(
                icons.supplier(),
                "Tedarikçi Girişi",
                "Otel, villa, tur, araç ve aktivite işletme paneli",
                "/tedarikci",
              ),
              nav_sub_item(
                icons.agency(),
                "Acente Girişi",
                "B2B seyahat acenteleri, toptan envanter ve rezervasyon",
                "/acente",
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}

pub fn render(rows: List(List(String)), slug: String) {
  render_contact(rows, slug, [])
}

pub fn contact(db: pog.Connection) {
  pog.query("select * from cms.public_contact()")
  |> pog.returning(decode.field(0, decode.list(decode.string), decode.success))
  |> pog.execute(db)
  |> result.map(fn(r) { r.rows })
}

fn site_footer() {
  el("footer", "site-footer", [
    el("div", "footer-brand", [
      el("strong", "footer-logo", [text("NEXUS")]),
      el("span", "footer-tagline", [text("TravelTech")]),
      el("p", "", [text("Seyahatin arkasındaki çalışma alanı.")]),
    ]),
    el("div", "footer-column", [
      el("h3", "", [text("NEXUS")]),
      link("/program", "Platform", ""),
      link("/hakkimizda", "Hakkımızda", ""),
      link("/blog", "Blog", ""),
      link("/iletisim", "İletişim", ""),
    ]),
    el("div", "footer-column", [
      el("h3", "", [text("Çözümler")]),
      link("/program", "Tüm modüller", ""),
      link("/tedarikci", "Tedarikçi ağı", ""),
      link("/acente", "Acente çalışma alanı", ""),
      link("/login", "Çalışma alanına giriş", ""),
    ]),
    el("div", "footer-column footer-contact", [
      el("h3", "", [text("Bize ulaşın")]),
      link("mailto:info@nexustraveltech.com", "info@nexustraveltech.com", ""),
      link("https://wa.me/905320000000", "WhatsApp ↗", ""),
      el("small", "", [text("© 2026 NEXUS TravelTech")]),
    ]),
  ])
}

fn contact_item(
  values: List(List(String)),
  key: String,
  label: String,
  prefix: String,
) {
  case list.find(values, fn(r) { list.first(r) == Ok(key) }) {
    Ok([_, value]) if value != "" ->
      case prefix {
        "" -> el("p", "", [text(label <> ": " <> value)])
        "https" ->
          case string.starts_with(value, "https://") {
            True -> link(value, label <> " ↗", "quiet")
            False -> text("")
          }
        _ -> link(prefix <> value, label <> ": " <> value, "quiet")
      }
    _ -> text("")
  }
}

pub fn render_contact(
  rows: List(List(String)),
  slug: String,
  contact_values: List(List(String)),
) {
  render_form(rows, slug, contact_values, "")
}

pub fn render_form(
  rows: List(List(String)),
  slug: String,
  contact_values: List(List(String)),
  csrf: String,
) {
  render_feedback(rows, slug, contact_values, csrf, "", [])
}

pub fn render_feedback(
  rows: List(List(String)),
  slug: String,
  contact_values: List(List(String)),
  csrf: String,
  feedback: String,
  fields: List(#(String, String)),
) {
  let value = fn(key) { list.key_find(fields, key) |> result.unwrap("") }
  use row <- result.try(list.find(rows, fn(r) { list.first(r) == Ok(slug) }))
  case row {
    [_, title, summary, body] ->
      Ok(
        "<!doctype html>"
        <> element.to_string(
          element.element("html", [a.attribute("lang", "tr")], [
            element.element("head", [], [
              element.element("meta", [a.attribute("charset", "utf-8")], []),
              element.element(
                "meta",
                [
                  a.name("viewport"),
                  a.attribute("content", "width=device-width, initial-scale=1"),
                ],
                [],
              ),
              element.element(
                "meta",
                [a.name("description"), a.attribute("content", summary)],
                [],
              ),
              element.element(
                "meta",
                [a.name("robots"), a.attribute("content", "noindex,nofollow")],
                [],
              ),
              element.element("title", [], [
                text(title <> " · NEXUS TravelTech"),
              ]),
              element.element(
                "link",
                [
                  a.attribute("rel", "stylesheet"),
                  a.href("/static/site.css?v=20260911-glasses"),
                ],
                [],
              ),
            ]),
            el("body", "", [
              site_header(rows),
              el("main", "", [
                element.element(
                  "p",
                  [a.id("locale-status"), a.class("locale-status")],
                  [],
                ),
                el("section", "hero", [
                  el("div", "hero-copy", [
                    el("p", "eyebrow", [
                      text("SEYAHAT İŞLETMELERİ İÇİN ORTAK ÇALIŞMA ALANI"),
                    ]),
                    el("h1", "", [text(title)]),
                    el("p", "intro", [text(summary)]),
                    el("div", "actions", [
                      link("/login", "Programı aç ↗", "button"),
                      element.element(
                        "a",
                        [a.href("/ilanlar"), a.class("button primary")],
                        [
                          icons.beach(),
                          text(" Canlı İlanlar & Rezervasyon"),
                        ],
                      ),
                      link("#yaklasim", "NEXUS’u keşfet ↓", "quiet"),
                    ]),
                  ]),
                  el("div", "system-map", [
                    el("p", "map-caption", [
                      text("BİRBİRİNE BAĞLI BİR OPERASYON"),
                    ]),
                    el("div", "map-card", [
                      el("span", "step", [text("01")]),
                      el("h2", "", [text("Tedarikçi")]),
                      el("p", "", [text("Ürün · fiyat · müsaitlik")]),
                    ]),
                    el("div", "connector", [text("↓")]),
                    el("div", "map-card central", [
                      el("span", "step", [text("02")]),
                      el("h2", "", [text("NEXUS")]),
                      el("p", "", [text("İş ortakları · operasyon · kontrol")]),
                    ]),
                    el("div", "connector", [text("↓")]),
                    el("div", "map-card", [
                      el("span", "step", [text("03")]),
                      el("h2", "", [text("Acente")]),
                      el("p", "", [text("Talep · opsiyon · rezervasyon")]),
                    ]),
                  ]),
                ]),
                element.element(
                  "section",
                  [a.class("approach"), a.id("yaklasim")],
                  [
                    el("p", "eyebrow", [text("ORTAK VERİ. NET SORUMLULUKLAR.")]),
                    el("h2", "section-title", [
                      text("Her işletmenin alanı ayrı. İş akışı ortak."),
                    ]),
                    el("p", "body-copy", [text(body)]),
                    case slug {
                      "iletisim" ->
                        el("div", "contact-layout", [
                          element.element(
                            "form",
                            [
                              a.class("contact-form"),
                              a.attribute("method", "post"),
                              a.attribute("action", "/iletisim"),
                            ],
                            [
                              hidden("csrf", csrf),
                              el("h3", "", [text("Bize yazın")]),
                              case feedback {
                                "" -> text("")
                                _ ->
                                  element.element(
                                    "p",
                                    [
                                      a.attribute("role", "status"),
                                      a.class("notice"),
                                    ],
                                    [text(feedback)],
                                  )
                              },
                              input(
                                "Ad soyad",
                                "name",
                                "text",
                                value("name"),
                                True,
                              ),
                              input(
                                "E-posta",
                                "email",
                                "email",
                                value("email"),
                                True,
                              ),
                              el("label", "field", [
                                text("Mesajınız"),
                                element.element(
                                  "textarea",
                                  [
                                    a.name("message"),
                                    a.attribute("rows", "5"),
                                    a.attribute("required", ""),
                                    a.attribute("minlength", "5"),
                                    a.attribute("maxlength", "5000"),
                                  ],
                                  [text(value("message"))],
                                ),
                              ]),
                              element.element("button", [a.class("button")], [
                                text("Mesaj gönder"),
                              ]),
                            ],
                          ),
                          el("div", "contact-details", [
                            el("h3", "", [text("İletişim bilgileri")]),
                            contact_item(
                              contact_values,
                              "contact.phone",
                              "Telefon",
                              "tel:",
                            ),
                            contact_item(
                              contact_values,
                              "contact.email",
                              "E-posta",
                              "mailto:",
                            ),
                            contact_item(
                              contact_values,
                              "contact.address",
                              "Adres",
                              "",
                            ),
                            el("div", "social-links", [
                              contact_item(
                                contact_values,
                                "contact.whatsapp",
                                "WhatsApp",
                                "https://wa.me/",
                              ),
                              contact_item(
                                contact_values,
                                "contact.linkedin",
                                "LinkedIn",
                                "https",
                              ),
                              contact_item(
                                contact_values,
                                "contact.instagram",
                                "Instagram",
                                "https",
                              ),
                            ]),
                            el("div", "map-preview", [
                              el("span", "map-pin", [text("●")]),
                              el("strong", "", [text("NEXUS merkez")]),
                              contact_item(
                                contact_values,
                                "contact.address",
                                "Adres",
                                "",
                              ),
                              contact_item(
                                contact_values,
                                "contact.map_url",
                                "Haritada aç",
                                "https",
                              ),
                            ]),
                          ]),
                        ])
                      _ -> text("")
                    },
                    el(
                      "div",
                      "cards",
                      list.map(
                        list.filter(rows, fn(r) {
                          list.contains(
                            ["program", "tedarikci", "acente"],
                            list.first(r) |> result.unwrap(""),
                          )
                        }),
                        fn(r) {
                          case r {
                            [id, heading, description, _] ->
                              el("article", "feature", [
                                el("p", "eyebrow", [text(label(id))]),
                                el("h3", "", [text(heading)]),
                                el("p", "", [text(description)]),
                                link("/" <> id, "İncele ↗", "quiet"),
                              ])
                            _ -> text("")
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ]),
              element.element(
                "script",
                [
                  a.attribute("src", "/static/preferences.js"),
                  a.attribute("defer", ""),
                ],
                [],
              ),
              site_footer(),
            ]),
          ]),
        ),
      )
    _ -> Error(Nil)
  }
}

pub fn render_custom_page(
  rows: List(List(String)),
  title: String,
  summary: String,
  content: element.Element(Nil),
) -> String {
  "<!doctype html>"
  <> element.to_string(
    element.element("html", [a.attribute("lang", "tr")], [
      element.element("head", [], [
        element.element("meta", [a.attribute("charset", "utf-8")], []),
        element.element(
          "meta",
          [
            a.name("viewport"),
            a.attribute("content", "width=device-width, initial-scale=1"),
          ],
          [],
        ),
        element.element(
          "meta",
          [a.name("description"), a.attribute("content", summary)],
          [],
        ),
        element.element("title", [], [
          text(title <> " · NEXUS TravelTech"),
        ]),
        element.element(
          "link",
          [
            a.attribute("rel", "stylesheet"),
            a.href("/static/site.css?v=20260911-glasses"),
          ],
          [],
        ),
      ]),
      el("body", "", [
        site_header(rows),
        el("main", "custom-page-main", [content]),
        site_footer(),
        element.element(
          "script",
          [
            a.attribute("src", "/static/preferences.js"),
            a.attribute("defer", ""),
          ],
          [],
        ),
      ]),
    ]),
  )
}

fn label(slug: String) {
  case slug {
    "program" -> "Program"
    "tedarikci" -> "Tedarikçiler"
    "acente" -> "Acenteler"
    "hakkimizda" -> "Hakkımızda"
    "iletisim" -> "İletişim"
    "home" -> "Ana sayfa"
    _ -> slug
  }
}

pub fn program(s: Session, csrf: String) {
  view.shell(
    s,
    csrf,
    "Program yönetimi",
    el("div", "", [
      el("h1", "", [text("NEXUS program yönetimi")]),
      el("p", "muted", [
        text(
          "İş ortaklarını, rezervasyon süreçlerini ve sistem bağlantılarını buradan yönetin.",
        ),
      ]),
      el("div", "next-grid", [
        card(
          "İş ortakları",
          "Tedarikçi ve acente bağlantılarını yönet.",
          "/admin/partners",
        ),
        card(
          "Talep ve opsiyonlar",
          "Tedarikçi onaylarını ve acente taleplerini takip et.",
          "/admin/requests",
        ),
        card(
          "Rezervasyonlar",
          "Rezervasyon ve tahsilat durumlarını incele.",
          "/admin/reservations",
        ),
        card(
          "Sistem ayarları",
          "ParamPOS, AI ve bağlantı bilgilerini yönet.",
          "/admin/settings",
        ),
        card(
          "Site içerik yönetimi",
          "NEXUS tanıtım sitesinin metinlerini düzenle ve yayınla.",
          "/admin/site",
        ),
      ]),
    ]),
  )
}

fn card(title: String, description: String, url: String) {
  el("section", "panel next", [
    el("h2", "", [text(title)]),
    el("p", "muted", [text(description)]),
    link(url, "Bölümü aç ↗", "button"),
  ])
}

pub fn editor(
  s: Session,
  csrf: String,
  rows: List(List(String)),
  message: String,
) {
  view.shell(
    s,
    csrf,
    "Site içerik yönetimi",
    el("div", "", [
      el("h1", "", [text("NEXUS site içerik yönetimi")]),
      el("p", "muted", [
        text(
          "Taslak kaydetmek yayındaki metni değiştirmez. Yayınla işlemi kaydedilmiş sürümü siteye aktarır. Metin alanları HTML çalıştırmaz.",
        ),
      ]),
      case message {
        "" -> text("")
        _ -> el("p", "notice", [text(message)])
      },
      element.element(
        "form",
        [
          a.class("panel form editor-form"),
          a.attribute("method", "post"),
          a.attribute("action", "/admin/site"),
        ],
        [
          el("h2", "", [text("Yeni sayfa oluştur")]),
          hidden("csrf", csrf),
          input("URL adı (ör. cozumler)", "slug", "text", "", True),
          input("Sayfa başlığı", "title", "text", "", True),
          element.element("button", [a.class("button primary")], [
            text("Taslak sayfa oluştur"),
          ]),
        ],
      ),
      ..list.map(rows, fn(row) {
        case row {
          [slug, title, summary, body, version, status] ->
            el("details", "panel", [
              el("summary", "panel-head", [text(label(slug) <> " · " <> status)]),
              element.element(
                "form",
                [
                  a.class("form editor-form"),
                  a.attribute("method", "post"),
                  a.attribute("action", "/admin/site/" <> slug <> "/save"),
                ],
                [
                  link(
                    "/admin/site/" <> slug <> "/preview",
                    "Kaydedilmiş taslağı önizle ↗",
                    "quiet-link",
                  ),
                  hidden("csrf", csrf),
                  hidden("version", version),
                  input("Başlık", "title", "text", title, True),
                  input(
                    "Kısa açıklama / SEO açıklaması",
                    "summary",
                    "text",
                    summary,
                    False,
                  ),
                  el("label", "field", [
                    text("İçerik"),
                    element.element(
                      "textarea",
                      [a.name("body"), a.attribute("rows", "7")],
                      [text(body)],
                    ),
                  ]),
                  element.element("button", [a.class("button primary")], [
                    text("Taslağı kaydet"),
                  ]),
                ],
              ),
              case
                s.role == "owner"
                && slug != "home"
                && slug != "program"
                && slug != "tedarikci"
                && slug != "acente"
                && slug != "hakkimizda"
                && slug != "iletisim"
              {
                True ->
                  element.element(
                    "form",
                    [
                      a.attribute("method", "post"),
                      a.attribute("action", "/admin/site/" <> slug <> "/delete"),
                      a.class("form-actions"),
                    ],
                    [
                      hidden("csrf", csrf),
                      element.element("button", [a.class("button danger")], [
                        text("Sayfayı sil"),
                      ]),
                    ],
                  )
                False -> text("")
              },
              case s.role == "owner" {
                True ->
                  element.element(
                    "form",
                    [
                      a.class("form-actions editor-form"),
                      a.attribute("method", "post"),
                      a.attribute(
                        "action",
                        "/admin/site/" <> slug <> "/publish",
                      ),
                    ],
                    [
                      hidden("csrf", csrf),
                      hidden("version", version),
                      element.element(
                        "button",
                        [
                          a.class("button primary"),
                          a.name("publish"),
                          a.value("true"),
                        ],
                        [text("Kaydedilmiş taslağı yayınla")],
                      ),
                      element.element(
                        "button",
                        [a.class("button"), a.name("publish"), a.value("false")],
                        [text("Yayından kaldır")],
                      ),
                    ],
                  )
                False -> text("")
              },
              element.element(
                "form",
                [
                  a.class("form-actions editor-form"),
                  a.attribute("method", "post"),
                  a.attribute("action", "/admin/site/" <> slug <> "/translate"),
                ],
                [
                  hidden("csrf", csrf),
                  element.element("select", [a.name("source_locale")], [
                    element.element("option", [a.value("tr")], [
                      text("Türkçe kaynak"),
                    ]),
                    element.element("option", [a.value("en")], [
                      text("English kaynak"),
                    ]),
                    element.element("option", [a.value("de")], [
                      text("Deutsch kaynak"),
                    ]),
                    element.element("option", [a.value("ru")], [
                      text("Русский kaynak"),
                    ]),
                    element.element("option", [a.value("ar")], [
                      text("العربية kaynak"),
                    ]),
                    element.element("option", [a.value("fr")], [
                      text("Français kaynak"),
                    ]),
                  ]),
                  element.element("button", [a.class("button")], [
                    text("Diğer dillere AI ile çevir"),
                  ]),
                ],
              ),
            ])
          _ -> text("")
        }
      })
    ]),
  )
}

fn blog_post_card(
  icon: Element(Nil),
  title: String,
  desc: String,
  url: String,
  category: String,
  read_time: String,
) {
  el("div", "blog-card", [
    el("div", "blog-card-header", [
      el("span", "blog-card-icon", [icon]),
      el("span", "blog-card-category", [text(category)]),
    ]),
    el("h3", "blog-card-title", [
      element.element("a", [a.href(url)], [text(title)]),
    ]),
    el("p", "blog-card-desc", [text(desc)]),
    el("div", "blog-card-footer", [
      el("span", "blog-read-time", [icons.clock(), text(" " <> read_time)]),
      element.element("a", [a.href(url), a.class("blog-read-link")], [
        text("Devamını Oku ➔"),
      ]),
    ]),
  ])
}

pub fn render_blog(rows: List(List(String))) -> String {
  let content =
    el("div", "blog-container", [
      el("div", "blog-hero", [
        el("span", "hero-badge", [text("NEXUS INSIGHTS & TEKNOLOJİ")]),
        el("h1", "blog-title", [text("Turizm Teknolojileri ve Sektörel Rehber")]),
        el("p", "blog-subtitle", [
          text(
            "Otel PMS, kanal yöneticisi, B2B acente ağları ve turizmde yapay zeka alanındaki en güncel gelişmeler.",
          ),
        ]),
      ]),
      el("div", "blog-categories-bar", [
        element.element(
          "a",
          [a.href("/blog"), a.class("blog-cat-filter active")],
          [
            icons.categories(),
            text("Tüm Makaleler"),
          ],
        ),
        element.element(
          "a",
          [
            a.href("/blog/2026-turizmde-yapay-zeka-ve-dinamik-fiyatlama"),
            a.class("blog-cat-filter"),
          ],
          [
            icons.sparkles(),
            text("Yapay Zeka & Yield"),
          ],
        ),
        element.element(
          "a",
          [
            a.href("/blog/7464-sayili-konut-izinleri-ve-villa-turizmi"),
            a.class("blog-cat-filter"),
          ],
          [
            icons.villa(),
            text("Mevzuat & Hukuk"),
          ],
        ),
        element.element(
          "a",
          [
            a.href("/blog/kanal-yoneticisi-ve-overbooking-onleme"),
            a.class("blog-cat-filter"),
          ],
          [
            icons.channel_manager(),
            text("Kanal Dağıtımı"),
          ],
        ),
        element.element(
          "a",
          [
            a.href("/blog/pms-pos-restoran-entegrasyonu"),
            a.class("blog-cat-filter"),
          ],
          [
            icons.pms(),
            text("PMS & Ön Büro"),
          ],
        ),
        element.element(
          "a",
          [
            a.href("/blog/turizm-e-fatura-ve-konaklama-vergisi"),
            a.class("blog-cat-filter"),
          ],
          [
            icons.accounting(),
            text("Finans & Muhasebe"),
          ],
        ),
        element.element(
          "a",
          [
            a.href("/blog/kat-hizmetleri-ve-oda-temizlik-matrisi"),
            a.class("blog-cat-filter"),
          ],
          [
            icons.housekeeping(),
            text("Operasyon & Tesis"),
          ],
        ),
      ]),
      el("div", "blog-featured-card", [
        el("div", "featured-badge", [text("Öne Çıkan Makale")]),
        el("h2", "featured-title", [
          element.element(
            "a",
            [a.href("/blog/2026-turizmde-yapay-zeka-ve-dinamik-fiyatlama")],
            [
              text(
                "2026 Turizminde Yapay Zeka: Dinamik Fiyatlama ve Otomatik Gelir Yönetimi (Yield Management)",
              ),
            ],
          ),
        ]),
        el("p", "featured-excerpt", [
          text(
            "Geleneksel sabit fiyatlama dönemi sona eriyor. Talebe, hava durumuna, yerel etkinliklere ve rakip doluluk oranlarına göre anlık fiyat güncelleyen AI algoritmaları ile gelirinizi nasıl %34'e kadar artırabilirsiniz?",
          ),
        ]),
        el("div", "featured-meta", [
          el("span", "meta-tag", [text("Yapay Zeka & Yield")]),
          el("span", "meta-read", [icons.clock(), text(" 6 dk okuma")]),
          el("span", "meta-date", [text("11 Eylül 2026")]),
        ]),
      ]),
      el("div", "blog-grid", [
        blog_post_card(
          icons.villa(),
          "7464 Sayılı Konut İzinleri ve Villa Kiralama Mevzuatı",
          "Müstakil villa ve tatil evi işletmeciliğinde Kültür ve Turizm Bakanlığı izin belgesi alma, plaket ve denetim süreçlerinin tüm detayları.",
          "/blog/7464-sayili-konut-izinleri-ve-villa-turizmi",
          "Mevzuat & Hukuk",
          "5 dk",
        ),
        blog_post_card(
          icons.channel_manager(),
          "Kanal Yöneticisi (Channel Manager) ile Çift Rezervasyona Son",
          "Global ve yerli tüm satış kanallarını milisaniyelik iki yönlü senkronizasyonla yöneterek çift rezervasyon (overbooking) riskini sıfıra indirin.",
          "/blog/kanal-yoneticisi-ve-overbooking-onleme",
          "Kanal Dağıtımı",
          "4 dk",
        ),
        blog_post_card(
          icons.security(),
          "KBS Emniyet & Jandarma Otomatik Kimlik Bildirimi",
          "Misafirlerinizin kimlik ve pasaport kayıtlarını PMS üzerinden resmi kolluk kuvvetleri sistemlerine otomatik aktarmanın hukuki ve teknik adımları.",
          "/blog/kbs-kimlik-bildirimi-entegrasyonu",
          "Güvenlik & KBS",
          "4 dk",
        ),
        blog_post_card(
          icons.corporate(),
          "B2B Envanter Dağıtımı: Acenteler ile Tedarikçilerin Buluşması",
          "Tedarikçilerin toptan fiyat ve net kotalarını yetkili seyahat acentelerine anlık açarak satış ağını büyütme ve komisyon mutabakatı stratejileri.",
          "/blog/b2b-acente-tedarikci-ag-yonetimi",
          "B2B & Dağıtım",
          "6 dk",
        ),
        blog_post_card(
          icons.pos(),
          "Ön Büro (PMS) ve Restoran POS Entegrasyonunun Faydaları",
          "Otel misafirlerinin plaj, restoran veya spa harcamalarını doğrudan oda folyosuna aktararak operasyonel kaçakları ve manuel hesap hatalarını ortadan kaldırın.",
          "/blog/pms-pos-restoran-entegrasyonu",
          "PMS & Ön Büro",
          "5 dk",
        ),
        blog_post_card(
          icons.yacht(),
          "Lüks Yat ve Marina Kiralama Operasyonlarında Dijital Dönüşüm",
          "Mavi yolculuk, gulet ve motoryat kiralamalarında mürettebat yönetimi, liman izinleri, kumanya takibi ve sefer bazlı takvim optimizasyonu.",
          "/blog/yat-ve-marina-dijital-yonetim",
          "Yat & Marina",
          "5 dk",
        ),
        blog_post_card(
          icons.accounting(),
          "Turizmde e-Fatura, Tevkifat ve %2 Konaklama Vergisi Rehberi",
          "GİB ve Özel Entegratör altyapısıyla oda folyolarından tek tıkla e-Arşiv/e-Fatura kesme, KDV tevkifatı hesaplama ve Konaklama Vergisi beyan yönetimi.",
          "/blog/turizm-e-fatura-ve-konaklama-vergisi",
          "Finans & Muhasebe",
          "5 dk",
        ),
        blog_post_card(
          icons.housekeeping(),
          "Kat Hizmetleri (Housekeeping) ve Canlı Oda Temizlik Matrisi",
          "Oda temizlik durumlarını (Kirli, Temiz, Denetleniyor, DND) mobil tabletler üzerinden gerçek zamanlı izleyerek erken check-in süreçlerini hızlandırın.",
          "/blog/kat-hizmetleri-ve-oda-temizlik-matrisi",
          "Operasyon & Tesis",
          "4 dk",
        ),
        blog_post_card(
          icons.tour(),
          "Tur & Aktivite Operasyonlarında Rehber ve Araç Kontenjan Yönetimi",
          "Kapadokya balon turları, dalış paketleri ve günübirlik gezilerde rehber ataması, koltuk kapasitesi kontrolü ve acente bilet kesim otomasyonu.",
          "/blog/tur-aktivite-ve-rehber-kontenjan-yonetimi",
          "Tur & Operasyon",
          "5 dk",
        ),
        blog_post_card(
          icons.whatsapp(),
          "WhatsApp CRM ve Otomatik Kapı PIN Kodu İletişimi",
          "Rezervasyon anında akıllı kapı şifresini, karşılama rehberini ve konum bilgisini WhatsApp API üzerinden misafire anında ve çok dilli iletin.",
          "/blog/whatsapp-crm-ile-otomatik-misafir-iletisimi",
          "CRM & İletişim",
          "4 dk",
        ),
        blog_post_card(
          icons.globe(),
          "Google Hotel Ads ve Metasearch ile Doğrudan Rezervasyon Artışı",
          "OTA komisyonlarına bağımlılığı azaltarak kendi web siteniz üzerinden komisyonsuz doğrudan rezervasyon oranını %40'ın üzerine çıkarma formülü.",
          "/blog/metasearch-google-hotel-ads-ve-dogrudan-satis",
          "Pazarlama & Gelir",
          "6 dk",
        ),
        blog_post_card(
          icons.sparkles(),
          "Çok Dilli Turizm İçerik Üretiminde Üretken Yapay Zeka",
          "Otel ve villa açıklamalarını İngilizce, Almanca, Rusça ve Arapça pazarlara saniyeler içinde yerelleştirerek global dönüşüm oranını katlayın.",
          "/blog/cok-dilli-icerik-uretiminde-yapay-zeka",
          "Yapay Zeka & Pazarlama",
          "4 dk",
        ),
      ]),
    ])

  render_custom_page(
    rows,
    "NEXUS Blog & Sektörel Rehber",
    "Turizm teknolojileri, kanal yöneticisi, PMS ve seyahat yazılımları rehberi.",
    content,
  )
}

pub fn render_blog_detail(rows: List(List(String)), slug: String) -> String {
  let #(title, category, date, read_time, paragraphs) = case slug {
    "2026-turizmde-yapay-zeka-ve-dinamik-fiyatlama" -> #(
      "2026 Turizminde Yapay Zeka: Dinamik Fiyatlama ve Otomatik Gelir Yönetimi (Yield Management)",
      "Yapay Zeka & Yield",
      "11 Eylül 2026",
      "6 dk okuma",
      [
        "Geleneksel turizm işletmeciliğinde sezonluk sabit fiyatlar belirlemek artık rekabette geride kalmaya neden oluyor. 2026 yılında gelişmiş otel ve konaklama işletmeleri, anlık piyasa talebine ve rakip doluluklarına göre fiyatlarını optimize eden dinamik yield algoritmalarını kullanıyor.",
        "NEXUS Dinamik Fiyatlama Motoru, uçuş yoğunluğu, hava durumu tahminleri, bölgesel tatiller ve geçmiş rezervasyon trendlerini analiz ederek en yüksek doluluk ve en yüksek RevPAR (Mevcut Oda Başına Gelir) oranını yakalamanızı sağlar.",
        "Özellikle son dakika rezervasyonlarında ve erken rezervasyon dönemlerinde marjinal geliri maksimize eden yapay zeka modülü, kanal yöneticisi ile entegre çalışarak tüm OTA kanallarındaki fiyatları tek tuşla günceller.",
        "Sistem, belirlenen minimum taban ve maksimum tavan sınırları içerisinde güvenli fiyat aralıkları tanımlamanıza olanak tanır. Böylece otelinizin marka değerini zedelemeden doluluk oranınızı optimize edebilirsiniz.",
      ],
    )
    "7464-sayili-konut-izinleri-ve-villa-turizmi" -> #(
      "7464 Sayılı Konut İzinleri ve Villa Kiralama Mevzuatı",
      "Mevzuat & Hukuk",
      "05 Eylül 2026",
      "5 dk okuma",
      [
        "Türkiye'de turizm amaçlı kiralanan konutlara ilişkin 7464 sayılı kanun yürürlüğe girdiğinden bu yana, villa ve müstakil tatil evi işletmecilerinin Kültür ve Turizm Bakanlığı'ndan izin belgesi alması zorunlu hale gelmiştir.",
        "İzin belgesi bulunan konutların girişine Bakanlık onaylı plaket asılması ve konaklayan misafirlerin kimliklerinin Emniyet/Jandarma KBS sistemine bildirilmesi yasal bir yükümlülüktür.",
        "NEXUS platformu, ilanların izin belgesi numaralarını ve denetim kayıtlarını entegre ederek hem yasal uyumluluğu garanti altına alır hem de kayıt dışı kiralamaların önüne geçer.",
        "İzin belgesi başvuru sürecinde kat malikleri muvafakatnameleri, yangın tüpü ve tahliye planı zorunlulukları gibi teknik gereklilikler platformumuzun mevzuat kontrol listesinde adım adım takip edilebilmektedir.",
      ],
    )
    "kanal-yoneticisi-ve-overbooking-onleme" -> #(
      "Kanal Yöneticisi (Channel Manager) ile Çift Rezervasyona Son",
      "Kanal Dağıtımı",
      "28 Ağustos 2026",
      "4 dk okuma",
      [
        "Farklı online seyahat portallarında ve pazar yerlerinde aynı anda oda satan işletmelerin en büyük operasyonel riski çift rezervasyon (overbooking) durumudur.",
        "Modern bir Channel Manager, bir kanaldan rezervasyon düştüğü anda milisaniyeler içinde diğer tüm platformlardaki müsaitliği kapatır. Aynı şekilde iptal durumunda odayı anında tekrar satışa sunar.",
        "NEXUS Kanal Yöneticisi, OTA API ve iCal senkronizasyon protokolleriyle entegre olarak kesintisiz bir envanter akışı sağlar.",
        "Çift yönlü fiyat ve kısıtlama (minimum konaklama, kapalı varış) senkronizasyonu sayesinde farklı platformlarda tek tek fiyat güncelleme zahmetinden kurtulursunuz.",
      ],
    )
    "kbs-kimlik-bildirimi-entegrasyonu" -> #(
      "KBS Emniyet & Jandarma Otomatik Kimlik Bildirimi",
      "Güvenlik & KBS",
      "20 Ağustos 2026",
      "4 dk okuma",
      [
        "1774 sayılı Kimlik Bildirme Kanunu gereğince, Türkiye sınırları içerisinde ticari konaklama hizmeti veren tüm tesisler konaklayan misafirlerin bilgilerini resmi kolluk kuvvetleri sistemlerine bildirmek zorundadır.",
        "NEXUS KBS Entegratörü, misafirin online check-in aşamasında veya resepsiyonda okutulan pasaport/T.C. kimlik kartı verilerini doğrudan Emniyet ve Jandarma AKBS sunucularına şifreli olarak iletir.",
        "Manuel giriş hatalarını sıfıra indiren bu sistem, cezai yaptırımların önüne geçerken resepsiyon kuyruklarını dakikalardan saniyelere indirir.",
      ],
    )
    "b2b-acente-tedarikci-ag-yonetimi" -> #(
      "B2B Envanter Dağıtımı: Acenteler ile Tedarikçilerin Buluşması",
      "B2B & Dağıtım",
      "14 Ağustos 2026",
      "6 dk okuma",
      [
        "Turizm ekosisteminde bağımsız acenteler ile konaklama veya tur tedarikçileri arasındaki en büyük zorluk, anlık müsaitlik sorgulama ve komisyon mutabakatı süreçleridir.",
        "NEXUS B2B Dağıtım Modülü sayesinde tedarikçiler, toptan net fiyatlarını diledikleri yetkili acente gruplarına anında açabilir ve dinamik komisyon oranları tanımlayabilir.",
        "Acenteler ise tek bir ekran üzerinden binlerce onaylı ilanı filtreleyebilir, kendi müşterileri için anında voucher üretebilir ve cari hesaplarını şeffaf biçimde takip edebilir.",
      ],
    )
    "pms-pos-restoran-entegrasyonu" -> #(
      "Ön Büro (PMS) ve Restoran POS Entegrasyonunun Faydaları",
      "PMS & Ön Büro",
      "08 Ağustos 2026",
      "5 dk okuma",
      [
        "Konaklama işletmelerinde misafirin havuz bar, alakart restoran, plaj veya spa harcamalarının resepsiyon folyosuna aktarılması geleneksel yöntemlerle yapıldığında ciddi kaçaklara yol açar.",
        "NEXUS PMS ile Restoran ve Bar POS sistemleri entegrasyonu sayesinde garson siparişi aldığı anda oda numarası teyidi yapılır ve adisyon tutarı misafirin dijital folyosuna tek tıkla işlenir.",
        "Check-out anında sürpriz masraf itirazlarını ortadan kaldıran sistem, detaylı harcama dökümünü misafirin faturasına ve WhatsApp özetine otomatik yansıtır.",
      ],
    )
    "yat-ve-marina-dijital-yonetim" -> #(
      "Lüks Yat ve Marina Kiralama Operasyonlarında Dijital Dönüşüm",
      "Yat & Marina",
      "01 Ağustos 2026",
      "5 dk okuma",
      [
        "Mavi yolculuk, motoryat ve katamaran kiralama sektörü, standart otelcilikten farklı olarak transitlog, liman çıkış izinleri, yakıt tüketimi ve kumanya planlaması gibi karmaşık süreçler içerir.",
        "NEXUS Yat & Marina Modülü; gulet, motoryat ve yelkenli filonuzun bakım takvimlerini, mürettebat yeterlilik belgelerini ve rota bazlı rezervasyon takvimini tek merkezde birleştirir.",
        "Liman başkanlıklarına ibraz edilecek mürettebat ve yolcu manifestoları sistem tarafından otomatik formatlanır ve acente satış ağında anlık yayınlanır.",
      ],
    )
    "turizm-e-fatura-ve-konaklama-vergisi" -> #(
      "Turizmde e-Fatura, Tevkifat ve %2 Konaklama Vergisi Rehberi",
      "Finans & Muhasebe",
      "25 Temmuz 2026",
      "5 dk okuma",
      [
        "Gelir İdaresi Başkanlığı (GİB) mevzuatına göre konaklama tesislerinde verilen geceleme hizmetleri %2 Konaklama Vergisi'ne tabidir. Ayrıca acente faturalaşmalarında KDV tevkifatı kuralları titizlikle uygulanmalıdır.",
        "NEXUS Ön Muhasebe ve GİB Özel Entegratör altyapısı, resepsiyonda kapatılan folyoları tek bir tuşla resmi e-Arşiv veya e-Faturaya dönüştürür.",
        "Konaklama vergisi matrahı, KDV oranları ve varsa acente komisyonu sistem tarafından otomatik ayrıştırılarak mali müşavirinize hazır Excel/XML raporları sunulur.",
      ],
    )
    "kat-hizmetleri-ve-oda-temizlik-matrisi" -> #(
      "Kat Hizmetleri (Housekeeping) ve Canlı Oda Temizlik Matrisi",
      "Operasyon & Tesis",
      "18 Temmuz 2026",
      "4 dk okuma",
      [
        "Check-out yapan misafirin odasının hızla temizlenip yeni misafire teslim edilmesi, otelin operasyonel verimliliğinin en temel göstergesidir.",
        "NEXUS Canlı Oda Matrisi (Room Rack); Kirli, Temizleniyor, Denetim Bekliyor, Arızalı (OOO) ve Hazır durumlarını resepsiyon ile kat şefleri arasında anlık senkronize eder.",
        "Kat görevlileri cep telefonu veya tablet üzerinden temizliği bitirdiklerini bildirdikleri anda resepsiyon ekranında yeşil ışık yanar ve misafir erken check-in yapabilir.",
      ],
    )
    "tur-aktivite-ve-rehber-kontenjan-yonetimi" -> #(
      "Tur & Aktivite Operasyonlarında Rehber ve Araç Kontenjan Yönetimi",
      "Tur & Operasyon",
      "10 Temmuz 2026",
      "5 dk okuma",
      [
        "Kapadokya sıcak hava balonu, Fethiye yamaç paraşütü, rafting ve günübirlik tekne turlarında kapasite yönetimi hava şartlarına ve rehber uygunluğuna göre anlık değişkenlik gösterir.",
        "NEXUS Tur Operasyon Motoru, araç koltuk kontenjanlarını ve kokartlı rehber atamalarını anlık olarak yönetmenizi sağlar.",
        "Acentelerinize açtığınız kota dolduğunda sistem otomatik olarak bekleme listesine geçer ve iptal durumlarında sıradaki misafire otomatik bildirim gönderir.",
      ],
    )
    "whatsapp-crm-ile-otomatik-misafir-iletisimi" -> #(
      "WhatsApp CRM ve Otomatik Kapı PIN Kodu İletişimi",
      "CRM & İletişim",
      "02 Temmuz 2026",
      "4 dk okuma",
      [
        "Modern seyahat severler resepsiyon bekleme sürelerinden ve ev sahibiyle anahtar teslim buluşmalarından kaçınmak istemektedir.",
        "NEXUS WhatsApp Entegrasyonu; rezervasyon onaylandığı anda misafire konum pinini, Wi-Fi şifresini ve akıllı dijital kapı kilidi PIN kodunu misafirin kendi anadilinde otomatik iletir.",
        "Konaklama süresince misafirin restoran rezervasyonu veya temizlik talepleri tek bir WhatsApp penceresinden yapay zeka destekli sanal konsiyerj tarafından yanıtlanır.",
      ],
    )
    "metasearch-google-hotel-ads-ve-dogrudan-satis" -> #(
      "Google Hotel Ads ve Metasearch ile Doğrudan Rezervasyon Artışı",
      "Pazarlama & Gelir",
      "24 Haziran 2026",
      "6 dk okuma",
      [
        "Otel ve tatil köyleri için OTA komisyonları cironun %15 ila %25'ini eritebilmektedir. Bu durumdan kurtulmanın en etkili yolu metasearch ve Google Free Booking Links entegrasyonudur.",
        "NEXUS Doğrudan Rezervasyon Motoru, web sitenizdeki anlık müsaitlik ve fiyatları doğrudan Google Haritalar ve Google Arama sonuçlarında listeler.",
        "Komisyonsuz doğrudan rezervasyon oranını artıran bu strateji, misafir veritabanının kendi mülkünüzde kalmasını sağlayarak sadakat programları geliştirmenize imkan tanır.",
      ],
    )
    "cok-dilli-icerik-uretiminde-yapay-zeka" -> #(
      "Çok Dilli Turizm İçerik Üretiminde Üretken Yapay Zeka",
      "Yapay Zeka & Pazarlama",
      "15 Haziran 2026",
      "4 dk okuma",
      [
        "Global turizm pazarında başarıya ulaşmak için tesis açıklamalarının, sosyal medya gönderilerinin ve karşılama rehberlerinin hedef kitle diline kusursuz uyarlanması gerekir.",
        "NEXUS AI İçerik Sihirbazı; villa ve otellerinizin özelliklerini girdiğinizde İngilizce, Almanca, Rusça ve Arapça pazarlara özel ilgi çekici tanıtım metinleri üretir.",
        "SEO uyumlu anahtar kelimelerle optimize edilen içerikler, uluslararası arama motorlarında sitenizin organik trafiğini katlar.",
      ],
    )
    _ -> #(
      "Turizm Teknolojilerinde Yeni Nesil Çözümler",
      "Teknoloji & İnovasyon",
      "11 Eylül 2026",
      "4 dk okuma",
      [
        "Turizm sektörü hızla dijitalleşirken, tedarikçiler ile acentelerin aynı çatı altında entegre çalıştığı bulut ekosistemleri ön plana çıkıyor.",
        "Operasyonel verimliliği artıran Ön Büro (PMS), KBS Kimlik Bildirimi, dinamik fiyatlama ve mobil check-in çözümleri, misafir memnuniyetini en üst seviyeye taşımaktadır.",
        "NEXUS TravelTech altyapısı ile işletmenizi geleceğin turizm teknolojisine hemen hazırlayabilirsiniz.",
      ],
    )
  }

  let content =
    el("article", "blog-article-container", [
      element.element("a", [a.href("/blog"), a.class("blog-back-btn")], [
        text("← Tüm Blog Yazılarına Dön"),
      ]),
      el("header", "article-header", [
        el("div", "article-meta-row", [
          el("span", "article-cat-badge", [text(category)]),
          el("span", "article-date", [icons.calendar(), text(" " <> date)]),
          el("span", "article-read", [icons.clock(), text(" " <> read_time)]),
        ]),
        el("h1", "article-title", [text(title)]),
      ]),
      el(
        "div",
        "article-content",
        list.map(paragraphs, fn(p) { el("p", "article-para", [text(p)]) }),
      ),
      el("div", "article-cta-box", [
        el("h3", "", [text("İşletmenizi NEXUS ile Büyütün")]),
        el("p", "", [
          text(
            "Otel, villa, tur veya acente operasyonlarınızı tek bir merkezden yönetmek için hemen ücretsiz inceleyin.",
          ),
        ]),
        element.element("a", [a.href("/login"), a.class("btn-nexus-login")], [
          text("Hemen Başlayın ➔"),
        ]),
      ]),
    ])

  render_custom_page(rows, title, title, content)
}
