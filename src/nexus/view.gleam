import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Property, type Session, role_title}
import nexus/icons

pub fn el(
  tag: String,
  cls: String,
  children: List(Element(Nil)),
) -> Element(Nil) {
  element.element(tag, [a.class(cls)], children)
}

fn link(url: String, label: String, cls: String) {
  element.element("a", [a.href(url), a.class(cls)], [text(label)])
}

fn nav_link(url: String, label: String, icon: Element(Nil)) {
  element.element("a", [a.href(url)], [
    el("span", "nav-icon", [icon]),
    text(label),
  ])
}

pub fn hidden(name: String, value: String) {
  element.element(
    "input",
    [a.attribute("type", "hidden"), a.name(name), a.value(value)],
    [],
  )
}

pub fn doc(title: String, body: Element(Nil)) -> String {
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
          [a.name("robots"), a.attribute("content", "noindex,nofollow")],
          [],
        ),
        element.element("title", [], [text(title <> " · NEXUS TravelTech")]),
        element.element(
          "link",
          [
            a.attribute("rel", "stylesheet"),
            a.href("/static/app.css?v=20260910-4"),
          ],
          [],
        ),
        element.element(
          "link",
          [
            a.attribute("rel", "stylesheet"),
            a.href("/static/admin-modern.css?v=20260916-mobile-layout"),
          ],
          [],
        ),
        element.element(
          "script",
          [
            a.attribute("src", "/static/admin-ui.js?v=20260910-5"),
            a.attribute("defer", "defer"),
          ],
          [],
        ),
        element.element(
          "script",
          [
            a.attribute("src", "/static/editor.js?v=20260911-1"),
            a.attribute("defer", "defer"),
          ],
          [],
        ),
        element.element(
          "link",
          [
            a.attribute("rel", "stylesheet"),
            a.href("/static/cockpit.css?v=20260910-1"),
          ],
          [],
        ),
      ]),
      el("body", "", [body]),
    ]),
  )
}

fn brand() {
  el("div", "brand", [
    el("span", "brand-mark", [text("N")]),
    el("div", "", [
      el("strong", "", [text("NEXUS")]),
      el("small", "", [text("TRAVELTECH")]),
    ]),
  ])
}

fn notice(message: String) {
  case message {
    "" -> text("")
    _ ->
      element.element("div", [a.class("notice"), a.attribute("role", "alert")], [
        text(message),
      ])
  }
}

pub fn login(csrf: String, error: String) -> String {
  doc(
    "Yönetici girişi",
    el("main", "login-wrap", [
      el("section", "login-story", [
        brand(),
        el("div", "", [
          el("p", "eyebrow", [text("İŞİNİN KONTROLÜ SENDE")]),
          el("h1", "", [text("Seyahatin arkasındaki tüm işler.")]),
          el("p", "", [
            text(
              "Ürünlerini düzenle. Yayınını yönet. NEXUS çalışma alanına hoş geldin.",
            ),
          ]),
        ]),
      ]),
      el("section", "login-card", [
        el("span", "badge", [text("YEREL GELİŞTİRME")]),
        el("h2", "", [text("Tekrar hoş geldin")]),
        el("p", "muted", [text("Yönetici hesabınla çalışma alanına giriş yap.")]),
        notice(error),
        element.element(
          "form",
          [
            a.attribute("method", "post"),
            a.attribute("action", "/login"),
            a.class("form"),
          ],
          [
            hidden("csrf", csrf),
            input("E-posta", "email", "email", "", True),
            input("Parola", "password", "password", "", True),
            element.element(
              "button",
              [a.class("button primary"), a.attribute("type", "submit")],
              [text("Çalışma alanına gir →")],
            ),
          ],
        ),
        link("/", "Ön yüzü görüntüle ↗", "quiet-link"),
      ]),
    ]),
  )
}

pub fn input(
  label: String,
  name: String,
  kind: String,
  value: String,
  required: Bool,
) {
  el("label", "field", [
    el("span", "", [text(label)]),
    element.element(
      "input",
      [
        a.name(name),
        a.attribute("type", kind),
        a.value(value),
        a.attribute("maxlength", case name {
          "password" -> "72"
          _ -> "120"
        }),
        ..case required {
          True -> [a.attribute("required", "")]
          False -> []
        }
      ],
      [],
    ),
  ])
}

pub fn shell(s: Session, csrf: String, page: String, body: Element(Nil)) {
  doc(
    page,
    el("div", "workspace", [
      el("aside", "sidebar", [
        el("div", "sidebar-header", [
          brand(),
          el("p", "nav-label", [
            text(case s.workspace {
              "nexus" -> "NEXUS MERKEZ"
              "agency" -> "ACENTE"
              _ -> "TEDARİKÇİ"
            }),
          ]),
        ]),
        el("nav", "navigation", case s.workspace {
          "nexus" -> {
            case s.role {
              "content_moderator" -> [
                nav_link(
                  "/admin/listings/procedures",
                  "İlan Prosedürleri & Onay",
                  icons.document(),
                ),
                nav_link(
                  "/admin/category-fields",
                  "Kategori Kriter Şemaları",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/ai-hub",
                  "Yapay Zeka Merkezi",
                  icons.sparkles(),
                ),
                nav_link("/admin/site", "Site İçerik Yönetimi", icons.globe()),
                nav_link("/admin", "Program Yönetimi", icons.modules()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "finance_manager" -> [
                nav_link(
                  "/admin/finance",
                  "Finans & Cari Mutabakat",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/accounting",
                  "Platform Kasa Defteri",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/einvoice",
                  "e-Fatura & Mali Entegrasyon",
                  icons.document(),
                ),
                nav_link(
                  "/admin/partners",
                  "İş Ortakları & Hakediş",
                  icons.corporate(),
                ),
                nav_link("/admin", "Program Yönetimi", icons.modules()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "onboarding_specialist" -> [
                nav_link(
                  "/admin/applications",
                  "Tedarikçi Başvuruları",
                  icons.supplier(),
                ),
                nav_link(
                  "/admin/partners",
                  "İş Ortakları & Puanlama",
                  icons.corporate(),
                ),
                nav_link("/admin/modules", "Ürün Modülleri", icons.modules()),
                nav_link(
                  "/admin/requests",
                  "Acente Talep Takibi",
                  icons.transfer(),
                ),
                nav_link("/admin", "Program Yönetimi", icons.modules()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "ai_pricing_specialist" -> [
                nav_link(
                  "/admin/ai-hub",
                  "Yapay Zeka Merkezi",
                  icons.sparkles(),
                ),
                nav_link(
                  "/admin/rate-shopper",
                  "Piyasa & Rakip Fiyat Analizi",
                  icons.dynamic_pricing(),
                ),
                nav_link(
                  "/admin/pricing",
                  "Fiyatlama & Kural Motoru",
                  icons.trending_up(),
                ),
                nav_link(
                  "/admin/campaigns",
                  "İndirimler & Kampanyalar",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/digital-twin",
                  "İş Dijital İkizi",
                  icons.sparkles(),
                ),
                nav_link("/admin", "Program Yönetimi", icons.modules()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "support_specialist" -> [
                nav_link(
                  "/admin/messages",
                  "İletişim Mesajları & Destek",
                  icons.chat(),
                ),
                nav_link("/admin/crm", "CRM & WhatsApp", icons.whatsapp()),
                nav_link(
                  "/admin/reservations",
                  "Canlı Rezervasyonlar",
                  icons.hotel(),
                ),
                nav_link("/admin/requests", "Talep Takibi", icons.transfer()),
                nav_link("/admin", "Program Yönetimi", icons.modules()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              _ -> [
                nav_link("/admin", "Program Yönetimi", icons.modules()),
                nav_link(
                  "/admin/ai-hub",
                  "Yapay Zeka Merkezi",
                  icons.sparkles(),
                ),
                nav_link(
                  "/admin/crm",
                  "Misafir CRM & WhatsApp",
                  icons.whatsapp(),
                ),
                nav_link(
                  "/admin/rate-shopper",
                  "Piyasa & Rakip Fiyat Analizi",
                  icons.dynamic_pricing(),
                ),
                nav_link(
                  "/admin/tours",
                  "Tur Operasyonu & Paketler",
                  icons.tour(),
                ),
                nav_link("/admin/fleet", "Araç Kiralama & Filo", icons.car()),
                nav_link(
                  "/admin/einvoice",
                  "e-Fatura & Mali Entegrasyon",
                  icons.document(),
                ),
                nav_link(
                  "/admin/accounting",
                  "Gelir & Gider (Muhasebe)",
                  icons.accounting(),
                ),
                nav_link("/admin/social-media", "Sosyal Medya", icons.share()),
                nav_link("/admin/hr", "Personel & İK", icons.user()),
                nav_link(
                  "/admin/housekeeping",
                  "Oda Takibi & Temizlik",
                  icons.housekeeping(),
                ),
                nav_link("/admin/ai", "AI Komuta & Onay", icons.sparkles()),
                nav_link(
                  "/admin/finance",
                  "Finans & Muhasebe",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/pricing",
                  "Fiyatlama & Kural Motoru",
                  icons.trending_up(),
                ),
                nav_link(
                  "/admin/campaigns",
                  "İndirimler & Kampanyalar",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/digital-twin",
                  "İş Dijital İkizi",
                  icons.sparkles(),
                ),
                nav_link("/admin/site", "Site İçerik Yönetimi", icons.globe()),
                nav_link("/admin/messages", "İletişim Mesajları", icons.chat()),
                nav_link("/admin/partners", "İş Ortakları", icons.corporate()),
                nav_link(
                  "/admin/partners/connection-requests",
                  "Acente bağlantı onayları",
                  icons.transfer(),
                ),
                nav_link(
                  "/admin/applications",
                  "Tedarikçi Başvuruları",
                  icons.supplier(),
                ),
                nav_link(
                  "/admin/users",
                  "Ekip & Yetki Dağıtımı",
                  icons.user_add(),
                ),
                nav_link("/admin/modules", "Ürün Modülleri", icons.modules()),
                nav_link(
                  "/admin/category-fields",
                  "Kategori Kriterleri",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/listings/procedures",
                  "İlan Prosedürleri",
                  icons.document(),
                ),
                nav_link(
                  "/admin/departments",
                  "Departmanlar",
                  icons.corporate(),
                ),
                nav_link("/admin/requests", "Talep Takibi", icons.transfer()),
                case s.role == "owner" {
                  True ->
                    el("div", "", [
                      nav_link(
                        "/admin/control-center",
                        "Platform denetimleri",
                        icons.security(),
                      ),
                      nav_link(
                        "/admin/settings",
                        "Sistem Ayarları",
                        icons.security(),
                      ),
                    ])
                  False -> text("")
                },
                nav_link("/admin/reservations", "Rezervasyonlar", icons.hotel()),
                nav_link(
                  "/admin/commerce-operations",
                  "Kanal operasyonları",
                  icons.categories(),
                ),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
            }
          }
          "agency" -> [
            nav_link("/admin", "Ürünler ve Talep", icons.modules()),
            nav_link("/admin/ai-hub", "Yapay Zeka Merkezi", icons.sparkles()),
            nav_link("/admin/crm", "CRM & WhatsApp", icons.whatsapp()),
            nav_link(
              "/admin/rate-shopper",
              "Rate Shopper",
              icons.dynamic_pricing(),
            ),
            nav_link("/admin/tours", "Turlar & Paketler", icons.tour()),
            nav_link("/admin/fleet", "Araç Kiralama & Filo", icons.car()),
            nav_link(
              "/admin/einvoice",
              "e-Fatura & Mali Entegrasyon",
              icons.document(),
            ),
            nav_link("/admin/accounting", "Kasa & Giderler", icons.accounting()),
            nav_link("/admin/social-media", "Sosyal Medya", icons.share()),
            nav_link("/admin/hr", "Personel & İK", icons.user()),
            nav_link("/admin/requests", "Opsiyon Taleplerim", icons.transfer()),
            nav_link("/admin/pricing", "Fiyat & Komisyon", icons.trending_up()),
            nav_link("/admin/finance", "Finans & Cari", icons.accounting()),
            nav_link("/admin/profile", "Profilim & Şifre", icons.user()),
            case s.role == "owner" {
              True ->
                nav_link(
                  "/admin/users",
                  "Ekip & Kullanıcılar",
                  icons.user_add(),
                )
              False -> text("")
            },
            nav_link(
              "/admin/digital-twin",
              "İş Dijital İkizi",
              icons.sparkles(),
            ),
            case s.role == "owner" {
              True ->
                nav_link("/admin/settings", "POS Ayarları", icons.security())
              False -> text("")
            },
            nav_link("/admin/reservations", "Rezervasyonlar", icons.hotel()),
            nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
          ]
          _ -> {
            case s.role {
              "housekeeping" -> [
                nav_link(
                  "/admin/housekeeping",
                  "Oda Takibi & Temizlik",
                  icons.housekeeping(),
                ),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "purchasing" -> [
                nav_link(
                  "/admin/accounting",
                  "Satın Alma & Malzeme Gideri",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/einvoice",
                  "Gelen e-Faturalar",
                  icons.document(),
                ),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "accounting" -> [
                nav_link(
                  "/admin/accounting",
                  "Gelir & Gider (Muhasebe)",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/einvoice",
                  "e-Fatura & Mali Entegrasyon",
                  icons.document(),
                ),
                nav_link("/admin/hr", "Personel & Bordro", icons.user()),
                nav_link(
                  "/admin/finance",
                  "Finans & Hakediş",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/supplier-performance",
                  "Performans Raporu",
                  icons.trending_up(),
                ),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "frontdesk" -> [
                nav_link(
                  "/admin/housekeeping",
                  "Canlı Oda Takibi",
                  icons.housekeeping(),
                ),
                nav_link(
                  "/admin/crm",
                  "Misafir CRM & WhatsApp",
                  icons.whatsapp(),
                ),
                nav_link("/admin/fleet", "Araç Filo & Kiralama", icons.car()),
                nav_link("/admin/reservations", "Rezervasyonlar", icons.hotel()),
                nav_link(
                  "/admin/calendar",
                  "Takvim & Doluluk",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/finance",
                  "Finans & Folyolar",
                  icons.accounting(),
                ),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "sales" -> [
                nav_link("/admin/listings", "İlanlar", icons.hotel()),
                nav_link("/admin/crm", "Misafir CRM", icons.whatsapp()),
                nav_link(
                  "/admin/rate-shopper",
                  "Piyasa & Rakip Fiyat Analizi",
                  icons.dynamic_pricing(),
                ),
                nav_link(
                  "/admin/tours",
                  "Tur Operasyonu & Paketler",
                  icons.tour(),
                ),
                nav_link(
                  "/admin/calendar",
                  "Takvim ve Fiyat",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/campaigns",
                  "İndirimler & Kampanyalar",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/pricing",
                  "Fiyat & Komisyon",
                  icons.trending_up(),
                ),
                nav_link(
                  "/admin/requests",
                  "Acente Talepleri",
                  icons.transfer(),
                ),
                nav_link("/admin/options", "Aktif Opsiyonlar", icons.check()),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "marketing" -> [
                nav_link("/admin/social-media", "Sosyal Medya", icons.share()),
                nav_link("/admin/crm", "CRM & WhatsApp", icons.whatsapp()),
                nav_link(
                  "/admin/rate-shopper",
                  "Piyasa & Rakip Fiyat Analizi",
                  icons.dynamic_pricing(),
                ),
                nav_link(
                  "/admin/ai-hub",
                  "Yapay Zeka Merkezi",
                  icons.sparkles(),
                ),
                nav_link(
                  "/admin/campaigns",
                  "İndirimler & Kampanyalar",
                  icons.categories(),
                ),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              "viewer" -> [
                nav_link("/admin", "Genel Bakış", icons.modules()),
                nav_link("/admin/listings", "İlanlar (İnceleme)", icons.hotel()),
                nav_link(
                  "/admin/housekeeping",
                  "Oda Durumları",
                  icons.housekeeping(),
                ),
                nav_link("/admin/profile", "Profilim", icons.user()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
              _ -> [
                nav_link("/admin", "Genel Bakış", icons.modules()),
                nav_link(
                  "/admin/crm",
                  "Misafir CRM & WhatsApp",
                  icons.whatsapp(),
                ),
                nav_link(
                  "/admin/rate-shopper",
                  "Piyasa & Rakip Fiyat Analizi",
                  icons.dynamic_pricing(),
                ),
                nav_link(
                  "/admin/tours",
                  "Tur Operasyonu & Paketler",
                  icons.tour(),
                ),
                nav_link("/admin/fleet", "Araç Kiralama & Filo", icons.car()),
                nav_link(
                  "/admin/einvoice",
                  "e-Fatura & Mali Entegrasyon",
                  icons.document(),
                ),
                nav_link(
                  "/admin/housekeeping",
                  "Oda Takibi & Temizlik",
                  icons.housekeeping(),
                ),
                nav_link(
                  "/admin/accounting",
                  "Gelir & Gider (Muhasebe)",
                  icons.accounting(),
                ),
                nav_link("/admin/social-media", "Sosyal Medya", icons.share()),
                nav_link(
                  "/admin/ai-hub",
                  "Yapay Zeka Merkezi",
                  icons.sparkles(),
                ),
                nav_link("/admin/hr", "Personel & İK", icons.user()),
                nav_link(
                  "/admin/application",
                  "Başvuru ve Belgeler",
                  icons.document(),
                ),
                nav_link("/admin/listings", "İlanlar", icons.hotel()),
                nav_link(
                  "/admin/listings/procedures",
                  "İlan Prosedürleri",
                  icons.document(),
                ),
                nav_link(
                  "/admin/calendar",
                  "Takvim ve Fiyat",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/campaigns",
                  "İndirimler & Kampanyalar",
                  icons.categories(),
                ),
                nav_link(
                  "/admin/pricing",
                  "Fiyat & Komisyon",
                  icons.trending_up(),
                ),
                nav_link(
                  "/admin/finance",
                  "Finans & Hakediş",
                  icons.accounting(),
                ),
                nav_link(
                  "/admin/digital-twin",
                  "İş Dijital İkizi",
                  icons.sparkles(),
                ),
                nav_link(
                  "/admin/requests",
                  "Acente Talepleri",
                  icons.transfer(),
                ),
                nav_link("/admin/options", "Aktif Opsiyonlar", icons.check()),
                nav_link("/admin/modules", "Atanan Modüller", icons.modules()),
                case s.role == "owner" || s.role == "general_manager" {
                  True ->
                    nav_link(
                      "/admin/users",
                      "Ekip & Yetki Dağıtımı",
                      icons.user_add(),
                    )
                  False -> text("")
                },
                nav_link(
                  "/admin/departments",
                  "Departmanlar",
                  icons.corporate(),
                ),
                nav_link("/admin/reservations", "Rezervasyonlar", icons.hotel()),
                nav_link("/", "Ön Yüz ↗", icons.arrow_up_right()),
              ]
            }
          }
        }),
        el("div", "sidebar-bottom", [
          el("span", "badge dark", [text(workspace_badge(s.workspace))]),
          el("p", "", [text(workspace_caption(s.workspace))]),
          element.element(
            "form",
            [a.attribute("method", "post"), a.attribute("action", "/logout")],
            [
              hidden("csrf", csrf),
              element.element("button", [a.class("logout")], [
                text("Oturumu kapat"),
              ]),
            ],
          ),
        ]),
      ]),
      el("div", "main-area", [
        el("header", "topbar", [
          el("span", "breadcrumb", [text("NEXUS  /  " <> page)]),
          element.element("a", [a.class("user"), a.href("/admin/profile")], [
            el("span", "avatar", [text(workspace_code(s.workspace))]),
            el("span", "", [
              text(s.name),
              el("small", "text-muted ml-1", [text(" · " <> role_title(s.role))]),
            ]),
          ]),
        ]),
        el("main", "content", [body]),
      ]),
    ]),
  )
}

fn workspace_code(workspace: String) -> String {
  case workspace {
    "nexus" -> "NX"
    "agency" -> "AC"
    _ -> "TD"
  }
}

fn workspace_badge(workspace: String) -> String {
  case workspace {
    "nexus" -> "NEXUS · KONTROL MERKEZİ"
    "agency" -> "ACENTE · SATIŞ ALANI"
    _ -> "TEDARİKÇİ · OPERASYON"
  }
}

fn workspace_caption(workspace: String) -> String {
  case workspace {
    "nexus" -> "Onay, dağıtım ve platform yönetimi."
    "agency" -> "Talep, rezervasyon ve satış yönetimi."
    _ -> "İlan, stok, fiyat ve kanal yönetimi."
  }
}

pub fn dashboard(
  s: Session,
  csrf: String,
  properties: List(Property),
) -> String {
  let count = list.length(properties)
  let published =
    list.length(list.filter(properties, fn(p) { p.status == "published" }))
  shell(
    s,
    csrf,
    "Genel bakış",
    el("div", "", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [text("SUPPLIER WORKSPACE")]),
          el("h1", "", [text("İşine genel bakış")]),
          el("p", "muted", [
            text(
              "İlk ilanından başlayalım. Yayınladığın ürünler ön yüzde görünecek.",
            ),
          ]),
        ]),
        case s.workspace {
          "supplier" ->
            link("/admin/listings/new", "+ Yeni ilan", "button primary")
          _ -> text("")
        },
      ]),
      el("div", "stats", [
        stat("Toplam ilan", count, "Çalışma alanındaki ürünler"),
        stat("Yayında", published, "Ön yüzde görünen"),
        stat("Taslak", count - published, "Hazırlığı devam eden"),
      ]),
      el("section", "panel", [
        el("div", "panel-head", [
          el("h2", "", [text("İlanların")]),
          link("/admin/listings", "Tümünü gör →", "quiet-link"),
        ]),
        property_table(s, properties, csrf),
      ]),
      el("div", "next-grid", [
        el("section", "panel next", [
          el("span", "badge", [text("ŞİMDİ")]),
          el("h2", "", [text("Ürününü tanımla")]),
          el("p", "muted", [
            text(
              "Başlık, konum, kapasite ve başlangıç fiyatını kaydet. Önce taslak oluştur, sonra yayınla.",
            ),
          ]),
          link("/admin/listings/new", "İlk adımı at →", "quiet-link"),
        ]),
        el("section", "panel next", [
          el("span", "badge neutral", [text("SONRAKİ GELİŞTİRME")]),
          el("h2", "", [text("Takvim ve opsiyon")]),
          el("p", "muted", [
            text(
              "Tarih bazlı stok, kontratlı fiyat ve güvenli opsiyon akışı sonraki çalışma paketi. Henüz rezervasyon veya ödeme alınmıyor.",
            ),
          ]),
        ]),
      ]),
    ]),
  )
}

pub fn stat(title: String, value: Int, caption: String) {
  el("section", "stat", [
    el("p", "muted", [text(title)]),
    el("strong", "number", [text(int.to_string(value))]),
    el("span", "caption", [text(caption)]),
  ])
}

pub fn listings(s: Session, csrf: String, items: List(Property)) -> String {
  shell(
    s,
    csrf,
    "İlanlar",
    el("div", "", [
      el("div", "page-heading", [
        el("div", "", [
          el("p", "eyebrow", [text("ÜRÜN YÖNETİMİ")]),
          el("h1", "", [text("İlanlar")]),
          el("p", "muted", [
            text(
              "Tesis, villa, oda ve tur ilanlarınızı listeleyin; fotoğrafları, teknik kriterleri, yayın durumunu ve doluluk takvimini yönetin.",
            ),
          ]),
        ]),
        el("div", "form-actions", [
          element.element(
            "a",
            [a.href("/admin/listings/procedures"), a.class("button")],
            [icons.document(), text("Kategori Prosedürleri Rehberi")],
          ),
          element.element(
            "a",
            [a.href("/admin/listings/new"), a.class("button primary")],
            [icons.plus(), text("Yeni İlan")],
          ),
        ]),
      ]),
      el("section", "panel", [property_table(s, items, csrf)]),
    ]),
  )
}

fn property_table(s: Session, items: List(Property), csrf: String) {
  case items {
    [] ->
      el("div", "empty", [
        el("div", "empty-icon", [icons.plus()]),
        el("h2", "", [text("İlk ilanın için hazır")]),
        el("p", "muted", [
          text(
            "Henüz kayıt yok. Bir villa ekleyerek çalışma alanını oluşturmaya başla.",
          ),
        ]),
        element.element(
          "a",
          [a.href("/admin/listings/new"), a.class("button primary")],
          [icons.plus(), text("İlan Oluştur")],
        ),
      ])
    _ ->
      el("div", "table-scroll", [
        el("table", "", [
          el("thead", "", [
            el(
              "tr",
              "",
              list.map(
                [
                  "İlan / konum",
                  "Kapasite",
                  "Başlangıç fiyatı",
                  "Durum",
                  "İşlem",
                ],
                fn(x) { el("th", "", [text(x)]) },
              ),
            ),
          ]),
          el(
            "tbody",
            "",
            list.map(items, fn(p) {
              el("tr", "", [
                el("td", "", [
                  link(
                    "/admin/listings/" <> p.id <> "/edit",
                    p.title,
                    "quiet-link",
                  ),
                  el("small", "muted", [text(p.locality)]),
                  link(
                    "/admin/listings/" <> p.id <> "/quality",
                    "Gereksinimleri kontrol et",
                    "button small",
                  ),
                  element.element(
                    "a",
                    [
                      a.href("/admin/listings/" <> p.id <> "/modules"),
                      a.class("button small primary"),
                    ],
                    [icons.sparkles(), text("Modül Operasyonları")],
                  ),
                ]),
                el("td", "", [text(int.to_string(p.capacity) <> " kişi")]),
                el("td", "", [text(domain.money(p.nightly_minor, p.currency))]),
                el("td", "", [
                  el("span", "badge " <> listing_badge_class(p), [
                    text(listing_status(p)),
                  ]),
                  case p.review_note {
                    "" -> text("")
                    note -> el("small", "muted", [text(note)])
                  },
                ]),
                el("td", "", [
                  listing_actions(s, csrf, p),
                ]),
              ])
            }),
          ),
        ]),
      ])
  }
}

fn listing_status(p: Property) -> String {
  case p.moderation_status {
    "in_review" -> "NEXUS incelemesinde"
    "changes_requested" -> "Düzeltme istendi"
    "suspended" -> "Yayın durduruldu"
    "approved" ->
      case p.freshness {
        "stale" -> "Güncellik süresi doldu"
        _ -> "Yayında ve onaylı"
      }
    _ -> "Taslak"
  }
}

fn listing_badge_class(p: Property) -> String {
  case p.moderation_status {
    "approved" ->
      case p.freshness {
        "stale" -> "badge-warning"
        _ -> "badge-success"
      }
    "in_review" -> "badge-info"
    "changes_requested" -> "badge-warning"
    "suspended" -> "badge-danger"
    _ -> "badge-neutral"
  }
}

fn listing_actions(s: Session, csrf: String, p: Property) {
  case s.workspace {
    "nexus" ->
      el("div", "form-actions", [
        case domain.can_moderate_listings(s.role) {
          False -> el("span", "badge muted", [text("Moderasyon yetkisi yok")])
          True ->
            case p.moderation_status {
              "in_review" ->
                el("div", "review-actions", [
                  status_form(csrf, p, "approved", "Onayla ve yayınla", ""),
                  review_note_form(
                    csrf,
                    p,
                    "changes_requested",
                    "Düzeltme iste",
                  ),
                ])
              "approved" ->
                review_note_form(csrf, p, "suspended", "Yayını durdur")
              _ -> text("Tedarikçi gönderimi bekleniyor")
            }
        },
      ])
    _ ->
      case p.moderation_status {
        "in_review" -> text("İnceleme sonucu bekleniyor")
        "approved" ->
          case domain.can_manage_catalog(s.role) {
            True ->
              status_form(csrf, p, "confirm_current", "Bilgiler güncel", "")
            False -> text("Bilgiler güncel")
          }
        _ ->
          case domain.can_submit_listing_review(s.role) {
            True -> status_form(csrf, p, "submit", "NEXUS onayına gönder", "")
            False ->
              el("span", "badge muted", [text("Onaya gönderme yetkisi yok")])
          }
      }
  }
}

fn review_note_form(csrf: String, p: Property, status: String, label: String) {
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute("action", "/admin/listings/" <> p.id <> "/status"),
      a.class("review-note-form"),
    ],
    [
      hidden("csrf", csrf),
      hidden("version", int.to_string(p.version)),
      hidden("status", status),
      element.element(
        "textarea",
        [
          a.name("note"),
          a.required(True),
          a.attribute("rows", "3"),
          a.placeholder(
            "Kararın gerekçesini ve tedarikçinin yapacağı düzeltmeyi açıkça yazın",
          ),
        ],
        [],
      ),
      element.element("button", [a.class("button small")], [text(label)]),
    ],
  )
}

fn status_form(
  csrf: String,
  p: Property,
  status: String,
  label: String,
  note: String,
) {
  element.element(
    "form",
    [
      a.attribute("method", "post"),
      a.attribute("action", "/admin/listings/" <> p.id <> "/status"),
    ],
    [
      hidden("csrf", csrf),
      hidden("version", int.to_string(p.version)),
      hidden("status", status),
      hidden("note", note),
      element.element("button", [a.class("button small")], [text(label)]),
    ],
  )
}

pub fn new_listing(
  s: Session,
  csrf: String,
  error: String,
  values: List(#(String, String)),
) -> String {
  category_listing(s, csrf, error, values, [], [], [], [])
}

pub fn category_title(cat: String) -> String {
  case cat {
    "hotel" -> "Otel & Konaklama"
    "holiday_home" -> "Tatil Evi & Müstakil Villa"
    "villa" -> "Tatil Evi & Müstakil Villa"
    "tour" -> "Tur & Gezi Paketleri"
    "activity" -> "Aktivite & Doğa Macera"
    "event" -> "Etkinlik, Konser & Festival"
    "yacht" -> "Yat, Gulet & Tekne"
    "beach" -> "Plaj & Beach Club"
    "car" -> "Araç Kiralama (Filo)"
    "transfer" -> "VIP Transfer"
    "package" -> "Dinamik Paket"
    "cruise" -> "Kruvaziyer & Gemi Seyahati"
    "ferry" -> "Feribot & Deniz Ulaşımı"
    "flight" -> "Uçak & Havayolu Bilet"
    "bus" -> "Otobüs & Karayolu Ulaşım"
    "cinema" -> "Sinema & Kültür Sanat"
    "spa" -> "SPA, Wellness & Termal"
    "restaurant" -> "Restoran & Gastronomi"
    "hajj" -> "Hac & Umre Organizasyonu"
    "umrah" -> "Hac & Umre Organizasyonu"
    "pilgrimage" -> "Hac & Umre Organizasyonu"
    "visa" -> "Vize Danışmanlığı & Başvuru"
    _ -> cat
  }
}

pub fn procedures_hub(
  s: Session,
  csrf: String,
  procedures: List(List(String)),
) -> String {
  shell(
    s,
    csrf,
    "İlan Prosedürleri",
    el("div", "procedures-hub-wrap", [
      link("/admin/listings", "← İlanlara dön", "quiet-link"),
      el("div", "page-heading mb-4", [
        el("div", "", [
          el("p", "eyebrow", [text("YASAL & OPERASYONEL MEVZUAT · 18 KATEGORİ")]),
          el("h1", "section-title-with-icon", [
            icons.document(),
            text("Kategori İlan Ekleme Prosedürleri & Mevzuat Rehberi"),
          ]),
          el("p", "muted", [
            text(
              "NEXUS TravelTech platformundaki 18 seyahat kategorisinin yasal gereksinimleri, zorunlu ruhsatları ve 5 adımlı ilan onay standartları.",
            ),
          ]),
        ]),
        el("div", "form-actions", [
          element.element(
            "a",
            [a.href("/admin/category-fields"), a.class("button quiet")],
            [icons.categories(), text("Kriter Şemalarını Yönet ⚙")],
          ),
          link("/admin/listings/new", "+ Yeni İlan Oluştur", "button primary"),
        ]),
      ]),

      // Sektörel Mevzuat Standartları Özeti
      el("div", "panel benchmark-sync-banner mb-4", [
        el("div", "flex-between align-center flex-wrap gap-3", [
          el("div", "", [
            el("div", "flex align-center gap-2 mb-1", [
              el("span", "badge primary", [text("Türkiye Turizm Mevzuatı")]),
              el("strong", "text-md", [text("18 Kategori Yasal Uyum Çerçevesi")]),
            ]),
            el("p", "muted text-sm mb-2", [
              text(
                "Platformda ilan yayınlamak için zorunlu kılınan resmi izin belgeleri, federasyon talimatları ve bakanlık standartları:",
              ),
            ]),
            el("div", "benchmark-tag-chips", [
              el("span", "benchmark-tag-chip", [text("7464 Konut İzin Belgesi")]),
              el("span", "benchmark-tag-chip", [text("Turizm İşletme Belgesi")]),
              el("span", "benchmark-tag-chip", [text("TÜRSAB A Grubu Ruhsatı")]),
              el("span", "benchmark-tag-chip", [
                text("EGM KABİS Polis Bildirimi"),
              ]),
              el("span", "benchmark-tag-chip", [
                text("Mali Sorumluluk Sigortası"),
              ]),
            ]),
          ]),
        ]),
      ]),

      el(
        "div",
        "procedures-hub-grid",
        list.map(procedures, fn(r) {
          case r {
            [
              cat_code,
              cat_name,
              title,
              legal,
              badge,
              steps_count,
              guidelines,
              ..
            ] ->
              el("article", "procedure-hub-card", [
                el("div", "card-header", [
                  el("div", "flex align-center gap-2", [
                    el("div", "cat-icon-badge", [icons.for_category(cat_code)]),
                    el("div", "cat-title-wrap", [
                      el("h2", "cat-title", [text(cat_name)]),
                      el("span", "cat-tag", [text("kod: " <> cat_code)]),
                    ]),
                  ]),
                  el("span", "procedure-badge", [text(badge)]),
                ]),
                el("h3", "proc-title", [text(title)]),
                el("div", "legal-note", [
                  el("strong", "", [text("Yasal Mevzuat: ")]),
                  text(legal),
                ]),
                el("p", "guidelines-preview", [text(guidelines)]),
                el("div", "card-footer", [
                  el("span", "steps-badge", [text(steps_count <> " Onay Adımı")]),
                  el("div", "flex gap-2 align-center", [
                    link(
                      "/admin/category-fields/" <> cat_code,
                      "Kriterler ⚙",
                      "button small quiet",
                    ),
                    link(
                      "/admin/listings/new/" <> cat_code,
                      "İlan Ver →",
                      "button small primary",
                    ),
                  ]),
                ]),
              ])
            _ -> text("")
          }
        }),
      ),
    ]),
  )
}

pub fn category_listing(
  s: Session,
  csrf: String,
  error: String,
  values: List(#(String, String)),
  categories: List(List(String)),
  schema: List(List(String)),
  procedure: List(String),
  procedure_steps: List(List(String)),
) -> String {
  let value = fn(key) { list.key_find(values, key) |> result.unwrap("") }
  let editor_title = case value("id") {
    "" -> "Yeni İlan Oluştur"
    _ -> "İlanı Düzenle"
  }
  let active_category = case value("category_code") {
    "" -> "hotel"
    c -> c
  }
  let #(
    proc_title,
    proc_legal,
    proc_badge,
    proc_guidelines,
    proc_req_docs,
    proc_rules,
  ) = case procedure {
    [title, legal, badge, _steps, guides, docs, rules, ..] -> #(
      title,
      legal,
      badge,
      guides,
      docs,
      rules,
    )
    _ -> #(
      category_title(active_category) <> " İlan Ekleme Prosedürü",
      "İlgili sektörel mevzuat ve platform standartlarına uygunluk gereklidir.",
      "Yasal Prosedür",
      "",
      "",
      "",
    )
  }
  shell(
    s,
    csrf,
    editor_title,
    el("div", "editor", [
      link("/admin/listings", "← İlanlara dön", "quiet-link"),
      el("div", "page-heading mb-4", [
        el("div", "", [
          el("p", "eyebrow", [text("ÜRÜN & HİZMET ENVANTERİ")]),
          el("h1", "", [text(editor_title)]),
          el("p", "muted", [
            text(
              "Aşağıdaki kategori sekmesinden ilan tipini belirleyin; sektörel mevzuata ve zorunlu alanlara göre ilanınızı oluşturun.",
            ),
          ]),
        ]),
        el("div", "form-actions", [
          element.element(
            "a",
            [
              a.href("/admin/category-fields/" <> active_category),
              a.class("button quiet small"),
            ],
            [icons.categories(), text("Kriter Şemasını Gör ↗")],
          ),
          element.element(
            "a",
            [
              a.href("/admin/listings/procedures"),
              a.class("button quiet small"),
            ],
            [icons.document(), text("Tüm Prosedürler Rehberi ↗")],
          ),
        ]),
      ]),

      // 1. Kategori Seçici Navigasyon Paneli (Modern Segmented Grid)
      el("div", "panel category-selector-card mb-4", [
        el("div", "category-nav-header mb-3", [
          el("div", "flex-between align-center flex-wrap gap-2", [
            el("div", "flex align-center gap-2", [
              el("span", "cat-nav-dot", []),
              el(
                "h3",
                "text-sm font-bold uppercase tracking-wider text-muted mb-0",
                [
                  text(
                    "İlan Kategorisi Seçimi ("
                    <> int.to_string(list.length(categories))
                    <> " Kategori)",
                  ),
                ],
              ),
            ]),
            el("span", "badge dark text-xs", [
              text("Seçili: " <> category_title(active_category)),
            ]),
          ]),
        ]),
        el(
          "nav",
          "category-tabs-grid",
          list.map(categories, fn(r) {
            case r {
              [code, name, ..] -> {
                let is_active = code == active_category
                let cls = case is_active {
                  True -> "category-tab-btn active"
                  False -> "category-tab-btn"
                }
                element.element(
                  "a",
                  [a.href("/admin/listings/new/" <> code), a.class(cls)],
                  [
                    el("span", "category-tab-icon", [icons.for_category(code)]),
                    el("span", "category-tab-label", [text(name)]),
                  ],
                )
              }
              _ -> text("")
            }
          }),
        ),
      ]),

      // 2. Aktif Kategori & Yasal Prosedür Hero Kartı
      el("div", "panel active-category-hero mb-4", [
        el("div", "flex-between align-center flex-wrap gap-3 mb-3", [
          el("div", "flex align-center gap-3", [
            el("div", "active-cat-icon-box", [
              icons.for_category(active_category),
            ]),
            el("div", "", [
              el("div", "flex align-center gap-2 mb-1", [
                el("h2", "active-cat-title mb-0", [text(proc_title)]),
                el("span", "badge-code", [text("kod: " <> active_category)]),
                el("span", "badge primary", [text(proc_badge)]),
              ]),
              el("p", "muted text-sm mb-0", [
                el("strong", "", [text("Yasal Dayanak: ")]),
                text(proc_legal),
              ]),
            ]),
          ]),
          el("div", "flex gap-2 align-center flex-wrap", [
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-primary", [
                text(case procedure_steps {
                  [] -> "5"
                  steps -> int.to_string(list.length(steps))
                }),
              ]),
              el("span", "kpi-mini-label", [text("Onay Adımı")]),
            ]),
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-success", [
                text(int.to_string(list.length(schema))),
              ]),
              el("span", "kpi-mini-label", [text("Kriter Alanı")]),
            ]),
          ]),
        ]),

        // Prosedür Adımları & Belgeler (Açılır Detay Kartı)
        element.element("details", [a.class("procedure-guide-card mt-3")], [
          element.element("summary", [a.class("procedure-summary")], [
            icons.sparkles(),
            el("strong", "", [
              text("5 Aşamalı Doğrulama Süreci ve Zorunlu Belgeleri Görüntüle"),
            ]),
            el("span", "muted", [text("Detayları aç / kapat")]),
          ]),
          case procedure_steps {
            [] -> text("")
            steps ->
              el("div", "procedure-steps-container", [
                el("h3", "procedure-subtitle", [
                  text("5 Aşamalı İlan Doğrulama & Onay Prosedürü"),
                ]),
                el(
                  "div",
                  "procedure-steps-grid",
                  list.map(steps, fn(s_row) {
                    case s_row {
                      [step_num, step_name, step_detail, ..] ->
                        el("div", "procedure-step-card", [
                          el("div", "procedure-step-badge", [
                            text("Adım " <> step_num),
                          ]),
                          el("strong", "procedure-step-title", [text(step_name)]),
                          el("p", "procedure-step-desc", [text(step_detail)]),
                        ])
                      _ -> text("")
                    }
                  }),
                ),
              ])
          },
          el("div", "procedure-info-grid", [
            case proc_req_docs {
              "" -> text("")
              docs ->
                el("div", "procedure-info-box req-docs", [
                  el("h4", "", [text("Zorunlu Resmi Belgeler & Ruhsatlar")]),
                  el("p", "", [text(docs)]),
                ])
            },
            case proc_rules {
              "" -> text("")
              rules ->
                el("div", "procedure-info-box rules", [
                  el("h4", "", [
                    text("Operasyonel Kurallar & Cezai Yaptırımlar"),
                  ]),
                  el("p", "", [text(rules)]),
                ])
            },
          ]),
          case proc_guidelines {
            "" -> text("")
            guides ->
              el("div", "procedure-guidelines-box", [
                el("h4", "", [text("İlan Başarı Kılavuzu & Öneriler")]),
                el("p", "", [text(guides)]),
              ])
          },
        ]),
      ]),
      el("p", "muted", [
        text(
          "Temel bilgileri kaydet. İlanın taslak olarak oluşturulacak ve yukarıdaki prosedüre göre incelenecektir.",
        ),
      ]),
      notice(error),
      el("div", "listing-progress", [
        el("div", "listing-progress-item active", [
          el("span", "", [text("1")]),
          text("Kategori alanları"),
        ]),
        el("div", "listing-progress-item", [
          el("span", "", [text("2")]),
          text("Satış bilgileri"),
        ]),
        el("div", "listing-progress-item", [
          el("span", "", [text("3")]),
          text("Görseller & Video (AVIF)"),
        ]),
        el("div", "listing-progress-item", [
          el("span", "", [text("4")]),
          text("İçerik ve SEO"),
        ]),
        el("div", "listing-progress-item", [
          el("span", "", [text("5")]),
          text("NEXUS kontrolü"),
        ]),
      ]),
      element.element(
        "form",
        [
          a.attribute("method", "post"),
          a.attribute("action", case value("id") {
            "" -> "/admin/listings"
            id -> "/admin/listings/" <> id <> "/edit"
          }),
          a.class("panel form editor-form guided-listing-form"),
        ],
        [
          hidden("csrf", csrf),
          hidden("category_code", value("category_code")),
          hidden("id", value("id")),
          hidden("version", value("version")),
          el("div", "panel notice field-header-ai", [
            el("div", "", [
              el("strong", "", [text("NEXUS Akıllı İlan & İçerik Asistanı: ")]),
              text(
                "Başlık, detaylı açıklama ve arama/SEO alanlarını yapay zeka ile anında otomatik oluşturabilirsiniz.",
              ),
            ]),
            element.element(
              "button",
              [
                a.attribute("type", "button"),
                a.class("button-ai"),
                a.attribute("data-ai-trigger", "all"),
              ],
              [icons.sparkles(), text("Tümünü AI ile Doldur")],
            ),
          ]),
          el("div", "form-section-heading", [
            el("span", "form-step-number", [text("1")]),
            el("div", "", [
              el("h2", "", [text("Kategoriye özgü bilgiler")]),
              el("p", "muted", [
                text(
                  "Yalnızca "
                  <> active_category
                  <> " ürünü için gereken alanlar gösteriliyor. * işaretli alanlar zorunludur.",
                ),
              ]),
            ]),
          ]),
          el("div", "inventory-hint", [
            text(category_inventory_hint(active_category)),
          ]),
          el(
            "section",
            "category-fields",
            list.map(schema, fn(r) {
              case r {
                [_, code, label, kind, choices, required, _, _] ->
                  el("label", "field", [
                    text(
                      label
                      <> case required {
                        "true" -> " *"
                        _ -> ""
                      },
                    ),
                    case kind {
                      "select" | "boolean" ->
                        element.element(
                          "select",
                          [
                            a.name("attr_" <> code),
                            ..list.append(
                              managed_filter_attrs(active_category, code),
                              case required {
                                "true" -> [a.attribute("required", "")]
                                _ -> []
                              },
                            )
                          ],
                          [
                            element.element("option", [a.value("")], [
                              text("Seçiniz"),
                            ]),
                            ..list.map(
                              case kind {
                                "boolean" -> ["true", "false"]
                                _ -> string.split(choices, ",")
                              },
                              fn(option) {
                                let option = string.trim(option)
                                element.element(
                                  "option",
                                  [
                                    a.value(option),
                                    ..case option == value("attr_" <> code) {
                                      True -> [a.attribute("selected", "")]
                                      False -> []
                                    }
                                  ],
                                  [text(option)],
                                )
                              },
                            )
                          ],
                        )
                      "document" ->
                        el("div", "document-input-wrap", [
                          element.element(
                            "input",
                            [
                              a.name("attr_" <> code),
                              a.value(value("attr_" <> code)),
                              a.attribute("type", "text"),
                              a.attribute(
                                "placeholder",
                                "Resmi Belge No, İzin Kodu veya Belge Bağlantısı (URL)",
                              ),
                              ..case required {
                                "true" -> [a.attribute("required", "")]
                                _ -> []
                              }
                            ],
                            [],
                          ),
                          el("span", "doc-hint flex align-center gap-1", [
                            icons.document(),
                            text(
                              " 7464 İzin Belge No, Turizm İşletme Belgesi veya TURSAB/D2 Sicil No giriniz.",
                            ),
                          ]),
                        ])
                      _ ->
                        element.element(
                          "input",
                          [
                            a.name("attr_" <> code),
                            a.value(value("attr_" <> code)),
                            a.attribute("type", case kind {
                              "number" -> "number"
                              _ -> "text"
                            }),
                            a.attribute("step", "any"),
                            ..case required {
                              "true" -> [a.attribute("required", "")]
                              _ -> []
                            }
                          ],
                          [],
                        )
                    },
                  ])
                _ -> text("")
              }
            }),
          ),
          el("div", "form-section-heading", [
            el("span", "form-step-number", [text("2")]),
            el("div", "", [
              el("h2", "", [text("Satış ve kapasite bilgileri")]),
              el("p", "muted", [
                text(
                  "Müşterinin satın alma kararında göreceği temel ticari bilgiler.",
                ),
              ]),
            ]),
          ]),
          el("div", "field-header-ai", [
            el("label", "field-label", [text("İlan başlığı *")]),
            element.element(
              "button",
              [
                a.attribute("type", "button"),
                a.class("button-ai"),
                a.attribute("data-ai-trigger", "title"),
              ],
              [icons.sparkles(), text("AI ile Başlık Üret")],
            ),
          ]),
          input("", "title", "text", value("title"), True),
          input(
            "Konum, buluşma veya teslim noktası",
            "locality",
            "text",
            value("locality"),
            True,
          ),
          el("div", "form-grid", [
            input(
              category_capacity_label(active_category),
              "capacity",
              "number",
              value("capacity"),
              True,
            ),
            input(
              category_price_label(active_category),
              "price",
              "text",
              value("price"),
              True,
            ),
          ]),
          el("label", "field", [
            text("Para birimi"),
            element.element(
              "select",
              [a.name("currency")],
              list.map(["TRY", "EUR", "USD", "GBP", "CHF", "AED", "CNY"], fn(c) {
                element.element(
                  "option",
                  [
                    a.value(c),
                    ..case value("currency") == c {
                      True -> [a.attribute("selected", "")]
                      False -> []
                    }
                  ],
                  [text(c)],
                )
              }),
            ),
          ]),
          el("div", "form-section-heading", [
            el("span", "form-step-number", [text("3")]),
            el("div", "field-header-ai", [
              el("div", "", [
                el("h2", "", [text("Görseller & Video Tanıtımı")]),
                el("p", "muted", [
                  text(
                    "İlanınızın kapak fotoğrafını, çoklu galeri fotoğraflarını ve video bağlantısını ekleyin. Yüklenen fotoğraflar otomatik olarak yeni nesil AVIF formatına dönüştürülür.",
                  ),
                ]),
              ]),
              el("div", "media-step-actions", [
                element.element(
                  "button",
                  [
                    a.attribute("type", "button"),
                    a.class("button-ai ai-sort-btn"),
                    a.attribute("id", "btn-ai-sort-photos"),
                  ],
                  [
                    icons.sparkles(),
                    text("Yapay Zeka ile Akıllı Sırala (AI Smart Sort)"),
                  ],
                ),
                element.element(
                  "button",
                  [
                    a.attribute("type", "button"),
                    a.class("button-secondary"),
                    a.attribute("id", "btn-preset-photos"),
                    a.attribute("data-category", active_category),
                  ],
                  [icons.image(), text("Örnek Fotoğraflar")],
                ),
                el("label", "auto-sort-toggle-label", [
                  element.element(
                    "input",
                    [
                      a.attribute("type", "checkbox"),
                      a.attribute("id", "chk-auto-ai-sort"),
                      a.attribute("checked", "true"),
                    ],
                    [],
                  ),
                  el("span", "", [text("Otomatik AI Sıralama Aktif")]),
                ]),
              ]),
            ]),
          ]),
          el("div", "media-upload-section", [
            el("div", "media-card hero-media-card", [
              el("div", "media-card-header", [
                el("strong", "", [
                  text("Ana Vitrin Görseli (Kapak Fotoğrafı)"),
                ]),
                el("div", "media-badges-group", [
                  el("span", "badge cdn-badge", [text("BunnyCDN & Lokal")]),
                  el("span", "badge avif-badge", [text("Otomatik AVIF")]),
                ]),
              ]),
              el("p", "muted small", [
                text(
                  "Cihazınızdan JPG, PNG veya WebP görsel seçin; tarayıcınızda anında ultra sıkıştırılmış AVIF formatına dönüştürülür.",
                ),
              ]),
              el("div", "media-dropzone", [
                element.element(
                  "input",
                  [
                    a.attribute("type", "file"),
                    a.attribute("accept", "image/*"),
                    a.class("media-file-input"),
                    a.attribute("id", "hero_file_input"),
                    a.attribute("data-target", "hero"),
                  ],
                  [],
                ),
                el("label", "dropzone-label", [
                  el("span", "dropzone-icon", [icons.image()]),
                  el("span", "dropzone-text", [
                    text(
                      "Fotoğraf Seç veya Buraya Sürükle (Otomatik AVIF Dönüşümü)",
                    ),
                  ]),
                ]),
              ]),
              el("div", "media-input-url-wrap", [
                element.element(
                  "input",
                  [
                    a.name("hero_image"),
                    a.attribute("id", "hero_image_input"),
                    a.attribute("type", "text"),
                    a.value(value("hero_image")),
                    a.attribute(
                      "placeholder",
                      "Kapak görsel bağlantısı (/static/uploads/... veya https://...)",
                    ),
                  ],
                  [],
                ),
              ]),
              el(
                "div",
                "hero-preview-container"
                  <> case value("hero_image") {
                  "" -> " hidden"
                  _ -> ""
                },
                [
                  element.element(
                    "img",
                    [
                      a.attribute("id", "hero_preview_img"),
                      a.attribute("src", value("hero_image")),
                      a.attribute("alt", "Kapak Önizleme"),
                      a.attribute(
                        "onerror",
                        "this.onerror=null;this.src='https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80';",
                      ),
                    ],
                    [],
                  ),
                  el("div", "preview-badge-row", [
                    el("span", "preview-status-badge", [
                      text("✓ Kapak Görseli Aktif (AVIF)"),
                    ]),
                  ]),
                ],
              ),
            ]),
            el("div", "media-card gallery-media-card", [
              el("div", "media-card-header", [
                el("strong", "", [text("Çoklu Galeri Fotoğrafları")]),
                el("div", "media-badges-group", [
                  el("span", "badge cdn-badge", [text("BunnyCDN & Lokal")]),
                  el("span", "badge avif-badge", [text("Toplu AVIF")]),
                ]),
              ]),
              el("p", "muted small", [
                text(
                  "Birden fazla fotoğraf seçerek toplu yükleyebilirsiniz. Fotoğraflar otomatik olarak 1920x1080 boyutuna ölçeklenip AVIF olarak kaydedilir.",
                ),
              ]),
              el("div", "media-dropzone", [
                element.element(
                  "input",
                  [
                    a.attribute("type", "file"),
                    a.attribute("accept", "image/*"),
                    a.attribute("multiple", "true"),
                    a.class("media-file-input"),
                    a.attribute("id", "gallery_file_input"),
                    a.attribute("data-target", "gallery"),
                  ],
                  [],
                ),
                el("label", "dropzone-label", [
                  el("span", "dropzone-icon", [icons.image()]),
                  el("span", "dropzone-text", [
                    text("Çoklu Fotoğraf Seçin (Toplu AVIF Yükle)"),
                  ]),
                ]),
              ]),
              element.element(
                "textarea",
                [
                  a.name("gallery_images"),
                  a.attribute("id", "gallery_images_input"),
                  a.attribute("rows", "3"),
                  a.attribute(
                    "placeholder",
                    "Galeri fotoğrafları (Her satıra bir görsel bağlantısı veya yukarıdan yükleyin)",
                  ),
                ],
                [text(value("gallery_images"))],
              ),
              el("div", "ai-sort-banner hidden", [
                el("div", "ai-sort-banner-content", [
                  el("span", "ai-sort-icon", [icons.sparkles()]),
                  el("div", "ai-sort-text", [
                    el("strong", "", [
                      text("Yapay Zeka Sıralaması Uygulandı"),
                    ]),
                    el("p", "ai-sort-desc", [
                      text(
                        "Fotoğraflarınız rezervasyon dönüşümünü artırmak için vitrin hikayesine göre otomatik dizildi.",
                      ),
                    ]),
                  ]),
                ]),
              ]),
              el("div", "gallery-preview-grid", [
                el("div", "gallery-grid-items", []),
              ]),
            ]),
            el("div", "media-card video-media-card", [
              el("div", "media-card-header", [
                el("strong", "", [
                  text("Video Tanıtımı & Sanal Tur (Opsiyonel)"),
                ]),
                el("span", "badge primary", [text("YouTube / Vimeo / MP4")]),
              ]),
              el("p", "muted small", [
                text(
                  "İlanınıza ait YouTube, Vimeo veya MP4 video bağlantısını yapıştırın. Ziyaretçiler ilan detay sayfasında doğrudan izleyebilir.",
                ),
              ]),
              element.element(
                "input",
                [
                  a.name("video_url"),
                  a.attribute("id", "video_url_input"),
                  a.attribute("type", "text"),
                  a.value(value("video_url")),
                  a.attribute(
                    "placeholder",
                    "Örn: https://www.youtube.com/watch?v=... veya https://vimeo.com/...",
                  ),
                ],
                [],
              ),
              el(
                "div",
                "video-preview-box"
                  <> case value("video_url") {
                  "" -> " hidden"
                  _ -> ""
                },
                [el("div", "video-preview-frame", [])],
              ),
            ]),
          ]),
          el("div", "form-section-heading", [
            el("span", "form-step-number", [text("4")]),
            el("div", "", [
              el("h2", "", [text("Müşteriye gösterilecek içerik")]),
              el("p", "muted", [
                text(
                  "Ürünü açık, doğrulanabilir ve kategoriye uygun biçimde anlatın.",
                ),
              ]),
            ]),
          ]),
          el("div", "field", [
            el("div", "field-header-ai", [
              el("label", "field-label", [text("Detaylı açıklama *")]),
              element.element(
                "button",
                [
                  a.attribute("type", "button"),
                  a.class("button-ai"),
                  a.attribute("data-ai-trigger", "description"),
                ],
                [icons.sparkles(), text("AI ile Açıklama Yaz")],
              ),
            ]),
            el("div", "rich-editor-container", [
              el("div", "editor-toolbar", [
                el("div", "editor-btn-group", [
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "bold"),
                      a.attribute("title", "Kalın"),
                    ],
                    [el("strong", "", [text("B")])],
                  ),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "italic"),
                      a.attribute("title", "İtalik"),
                    ],
                    [el("em", "", [text("I")])],
                  ),
                  el("span", "editor-btn-sep", []),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "h2"),
                      a.attribute("title", "Bölüm Başlığı"),
                    ],
                    [text("H2")],
                  ),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "h3"),
                      a.attribute("title", "Alt Başlık"),
                    ],
                    [text("H3")],
                  ),
                  el("span", "editor-btn-sep", []),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "bullet"),
                      a.attribute("title", "Madde İmleri"),
                    ],
                    [text("• Liste")],
                  ),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "number"),
                      a.attribute("title", "Numaralı Liste"),
                    ],
                    [text("1. Liste")],
                  ),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "quote"),
                      a.attribute("title", "Alıntı Kutusu"),
                    ],
                    [text("” Alıntı")],
                  ),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "link"),
                      a.attribute("title", "Bağlantı Ekle"),
                    ],
                    [text("Link")],
                  ),
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "template"),
                      a.attribute("title", "Hazır Şablon"),
                    ],
                    [icons.document(), text("Şablon")],
                  ),
                ]),
                el("div", "editor-btn-group", [
                  element.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("editor-btn"),
                      a.attribute("data-edit-action", "toggle-preview"),
                    ],
                    [icons.eye(), text("Önizleme")],
                  ),
                ]),
              ]),
              element.element(
                "textarea",
                [
                  a.name("description"),
                  a.attribute("rows", "10"),
                  a.attribute("maxlength", "5000"),
                  a.attribute("required", ""),
                  a.attribute(
                    "placeholder",
                    category_description_hint(active_category),
                  ),
                ],
                [text(value("description"))],
              ),
              el("div", "editor-preview", []),
              el("div", "editor-footer", [
                el("span", "", [text("Markdown formatı desteklenir")]),
                el("span", "char-counter-desc", [text("0 / 5000 karakter")]),
              ]),
            ]),
          ]),
          el("div", "form-section-heading", [
            el("span", "form-step-number", [text("5")]),
            el("div", "field-header-ai", [
              el("div", "", [
                el("h2", "", [text("Arama ve SEO")]),
                el("p", "muted", [
                  text(
                    "Arama sonuçlarında anlaşılır görünmek için kısa ve özgün metinler kullanın.",
                  ),
                ]),
              ]),
              element.element(
                "button",
                [
                  a.attribute("type", "button"),
                  a.class("button-ai"),
                  a.attribute("data-ai-trigger", "seo"),
                ],
                [icons.sparkles(), text("AI ile SEO ve Meta Açıklama Oluştur")],
              ),
            ]),
          ]),
          el("div", "field", [
            input(
              "SEO başlığı (en fazla 160 karakter)",
              "seo_title",
              "text",
              value("seo_title"),
              True,
            ),
            el("span", "char-counter-seo-title", [text("0 / 160 karakter")]),
          ]),
          el("div", "field", [
            input(
              "SEO açıklaması (en fazla 320 karakter)",
              "seo_description",
              "text",
              value("seo_description"),
              True,
            ),
            el("span", "char-counter-seo-desc", [text("0 / 320 karakter")]),
          ]),
          el("div", "review-callout", [
            el("strong", "", [text("Sonraki adım: ")]),
            text(
              "Kaydettiğiniz ilan taslak olur. Gereksinim kontrolünden sonra NEXUS onayına gönderirsiniz; NEXUS onaylamadan yayınlanmaz.",
            ),
          ]),
          el("div", "form-actions", [
            link("/admin/listings", "Vazgeç", "button"),
            element.element(
              "button",
              [a.class("button primary"), a.attribute("type", "submit")],
              [
                text(case value("id") {
                  "" -> "Taslağı oluştur"
                  _ -> "Değişiklikleri kaydet"
                }),
              ],
            ),
          ]),
        ],
      ),
    ]),
  )
}

fn managed_filter_attrs(category: String, code: String) {
  [
    a.attribute("data-managed-filter-category", category),
    a.attribute("data-managed-filter-key", code),
  ]
}

fn category_price_label(category: String) -> String {
  case category {
    "hotel" | "holiday_home" | "villa" ->
      "Gecelik başlangıç fiyatı (ör. 4500.00)"
    "car" -> "Günlük kiralama başlangıç fiyatı"
    "yacht" -> "Kiralama başlangıç fiyatı"
    "restaurant" -> "Kişi başı / rezervasyon başlangıç fiyatı"
    "transfer" -> "Transfer başlangıç fiyatı"
    "flight" | "bus" | "ferry" -> "Kişi başı bilet başlangıç fiyatı"
    "event" | "cinema" -> "Bilet başlangıç fiyatı"
    "beach" -> "Şezlong / ünite başlangıç fiyatı"
    "spa" | "activity" -> "Seans / kişi başlangıç fiyatı"
    "cruise" -> "Kabin / kişi başlangıç fiyatı"
    "visa" -> "Başvuru danışmanlık başlangıç ücreti"
    "pilgrimage" -> "Kişi başı program başlangıç fiyatı"
    _ -> "Kişi / paket başlangıç fiyatı"
  }
}

fn category_capacity_label(category: String) -> String {
  case category {
    "hotel" -> "Oda için azami misafir"
    "holiday_home" | "villa" -> "Azami misafir kapasitesi"
    "car" -> "Araç yolcu kapasitesi"
    "restaurant" -> "Rezervasyon kişi kapasitesi"
    "event" | "cinema" | "bus" -> "Satılabilir koltuk kapasitesi"
    "ferry" | "cruise" | "yacht" -> "Azami yolcu kapasitesi"
    "flight" -> "Uçuş koltuk kontenjanı"
    "beach" -> "Şezlong / şemsiye kapasitesi"
    "visa" -> "Eşzamanlı başvuru işlem kapasitesi"
    "transfer" -> "Azami yolcu kapasitesi"
    "tour" | "activity" | "pilgrimage" -> "Katılımcı kontenjanı"
    _ -> "Katılımcı kapasitesi"
  }
}

fn category_inventory_hint(category: String) -> String {
  case category {
    "hotel" ->
      "Envanter modeli: oda tipi × gün; müsaitlik, kota, minimum konaklama ve satış kapatma kuralları takvimde yönetilir."
    "holiday_home" | "villa" ->
      "Envanter modeli: konut × gün; minimum konaklama, giriş/çıkış ve bloke tarihler takvimde yönetilir."
    "car" ->
      "Envanter modeli: filo aracı × teslim/iade aralığı; araç grubu ve teslim noktası birlikte izlenir."
    "restaurant" ->
      "Envanter modeli: masa/alan × zaman dilimi; kişi sayısı ve servis süresi dikkate alınır."
    "event" | "cinema" | "bus" ->
      "Envanter modeli: seans/sefer × bölüm/koltuk; opsiyon ve satış aynı kapasiteden düşer."
    "ferry" | "cruise" ->
      "Envanter modeli: sefer × yolcu/kabin/araç kotası; kalkış bazında fiyat ve müsaitlik tutulur."
    "flight" ->
      "Envanter modeli: uçuş seferi × kabin sınıfı/kontenjan; PNR, bagaj ve bilet kuralları izlenir."
    "activity" | "spa" ->
      "Envanter modeli: hizmet varyantı × zaman dilimi; kapasite ve kaynak uygunluğu birlikte kontrol edilir."
    "transfer" ->
      "Envanter modeli: araç sınıfı × zaman aralığı; güzergâh, bagaj ve sürücü kapasitesi izlenir."
    "tour" | "package" | "pilgrimage" ->
      "Envanter modeli: hareket tarihi × kontenjan; rehber, oda, ulaşım ve yolcu belgeleri birlikte izlenir."
    "yacht" ->
      "Envanter modeli: tekne × kiralama aralığı; marina, mürettebat ve süre birlikte kontrol edilir."
    "beach" ->
      "Envanter modeli: ünite (şezlong/loca) × gün/seans; konum, bölge ve güneşlenme dilimi izlenir."
    "visa" ->
      "Envanter modeli: başvuru kotası × randevu/işlem takvimi; ülke, vize tipi ve evrak kontrolü izlenir."
    _ ->
      "Kategoriye ait kapasite ve zaman bazlı müsaitlik, ilan kaydedildikten sonra takvimden yönetilir."
  }
}

fn category_description_hint(category: String) -> String {
  case category {
    "hotel" | "holiday_home" | "villa" ->
      "Konumu, konaklama düzenini, olanakları, dahil olan hizmetleri ve önemli kuralları açıklayın."
    "tour" | "activity" | "pilgrimage" ->
      "Programı, süreyi, buluşma noktasını, dahil olanları, güvenlik ve katılım koşullarını açıklayın."
    "transfer" | "car" ->
      "Teslim/buluşma noktasını, araç özelliklerini, bagajı, sigortayı ve iptal koşullarını açıklayın."
    "event" | "cinema" ->
      "Programı, mekânı, tarih-saat bilgisini, bilet kapsamını ve giriş koşullarını açıklayın."
    "flight" | "ferry" | "bus" | "cruise" ->
      "Sefer rotasını, kalkış/varış noktalarını, bagaj ve biletleme kurallarını açıklayın."
    "restaurant" ->
      "Mutfak konseptini, menü özetini, rezervasyon ve kıyafet kurallarını açıklayın."
    "beach" ->
      "Plaj konumunu, giriş imkanlarını, şezlong/loca tiplerini ve servis kurallarını açıklayın."
    "visa" ->
      "Hedef ülkeyi, vize tipini, başvuru süresini, gerekli evrakları ve danışmanlık kapsamını açıklayın."
    _ ->
      "Ürünün kapsamını, müşterinin alacağı hizmeti, istisnaları ve önemli kuralları açıkça yazın."
  }
}

pub fn marketplace(items: List(Property), query: String) -> String {
  doc(
    "Konaklama",
    el("div", "store", [
      el("header", "store-header", [
        brand(),
        link("/admin", "İşletme paneli ↗", "button"),
      ]),
      el("main", "store-main", [
        el("p", "eyebrow", [text("NEXUS KONAKLAMA")]),
        el("h1", "", [text("Bir sonraki yerin.")]),
        el("p", "muted", [text("Villa ve tatil evlerini keşfet.")]),
        element.element(
          "form",
          [
            a.attribute("method", "get"),
            a.attribute("action", "/"),
            a.class("search"),
          ],
          [
            element.element(
              "input",
              [
                a.name("q"),
                a.value(query),
                a.attribute("aria-label", "Konum veya ilan ara"),
                a.attribute("placeholder", "Konum veya ilan adı"),
              ],
              [],
            ),
            element.element("button", [a.class("button primary")], [text("Ara")]),
          ],
        ),
        case items {
          [] ->
            el("section", "panel empty", [
              el("span", "badge neutral", [text("KATALOG HAZIRLANIYOR")]),
              el("h2", "", [text("Henüz gösterilecek konaklama yok")]),
              el("p", "muted", [
                text(
                  "Yeni ürünler yayınlandığında burada görünecek. Bu yerel sürüm henüz rezervasyon almıyor.",
                ),
              ]),
            ])
          _ ->
            el(
              "div",
              "property-grid",
              list.map(items, fn(p) {
                el("article", "panel property-card", [
                  el("span", "badge", [text("VİLLA / TATİL EVİ")]),
                  el("h2", "", [text(p.title)]),
                  el("p", "muted", [
                    text(
                      p.locality
                      <> " · "
                      <> int.to_string(p.capacity)
                      <> " kişi",
                    ),
                  ]),
                  el("p", "description", [text(p.description)]),
                  el("div", "price", [
                    el("strong", "", [
                      text(domain.money(p.nightly_minor, p.currency)),
                    ]),
                    el("small", "muted", [
                      text("Gecelik başlangıç · tarih bazlı teklif değildir"),
                    ]),
                  ]),
                ])
              }),
            )
        },
      ]),
      el("footer", "store-footer", [
        text("NEXUS TravelTech · Yerel geliştirme sürümü"),
      ]),
    ]),
  )
}
