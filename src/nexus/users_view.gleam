import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden}

pub fn page(
  s: Session,
  csrf: String,
  users: List(List(String)),
  organizations: List(List(String)),
  message: String,
) {
  let total_users = list.length(users)
  let active_users =
    list.count(users, fn(r) {
      case r {
        [_, _, _, _, _, _, "true"] -> True
        _ -> False
      }
    })
  let total_orgs = list.length(organizations)

  view.shell(
    s,
    csrf,
    "Üye yönetimi",
    el("div", "users-page", [
      // 1. Sayfa Başlığı
      el("div", "page-heading mb-4", [
        el("div", "", [
          el("p", "eyebrow", [text("KURUMSAL KADROLAŞMA & YETKİ MATRİSİ")]),
          el("h1", "section-title-with-icon", [
            icons.user(),
            text("Ekip & Personel Yetki Yönetimi"),
          ]),
          el("p", "muted", [
            text(
              "Tesisinizin ve platformun kadro ihtiyaçlarına göre personelleri tanımlayın; departman rollerini dağıtın ve her üyenin yetki sınırlarını güvenle belirleyin.",
            ),
          ]),
        ]),
      ]),

      case message {
        "" -> text("")
        _ -> el("div", "notice success mb-4", [text(message)])
      },

      // 2. Aktif Kadro & Güvenlik Hero Kartı (Executive KPI)
      el("div", "panel active-category-hero mb-4", [
        el("div", "hero-header-bar", [
          el("div", "hero-main-info", [
            el("div", "active-cat-icon-box", [icons.user()]),
            el("div", "hero-text-wrap", [
              el("div", "hero-title-row", [
                el("h2", "active-cat-title mb-0", [
                  text("Kadro & Yetki Dağıtım Merkezi"),
                ]),
                el("span", "badge-code", [text("RBAC")]),
                el("span", "badge primary", [text("KVKK Uyumlu")]),
              ]),
              el("p", "muted text-sm mb-0", [
                el("strong", "", [text("Güvenlik İlkesi: ")]),
                text(
                  "Tüm kullanıcı oturumları kriptografik çerezler ve rol bazlı erişim denetimi (RBAC) ile sıkı şekilde izole edilmiştir.",
                ),
              ]),
            ]),
          ]),
          el("div", "hero-stats-group", [
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-primary", [
                text(int.to_string(total_users)),
              ]),
              el("span", "kpi-mini-label", [text("Toplam Üye")]),
            ]),
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-success", [
                text(int.to_string(active_users)),
              ]),
              el("span", "kpi-mini-label", [text("Aktif Personel")]),
            ]),
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-warning", [
                text(int.to_string(total_orgs)),
              ]),
              el("span", "kpi-mini-label", [text("Çalışma Alanı")]),
            ]),
          ]),
        ]),
      ]),

      // 3. Sektörel Yetki & Güvenlik Standartları Çip Paneli
      el("div", "panel benchmark-sync-banner mb-4", [
        el("div", "benchmark-header-row", [
          el("span", "badge primary", [text("Yetki Standartları")]),
          el("strong", "text-md", [
            text("Kurumsal Güvenlik & Kadro Yapılanması İlkeleri"),
          ]),
        ]),
        el("p", "muted text-sm mb-2", [
          text(
            "Veri güvenliği ve KVKK uyumu için personellere yalnızca kendi görev alanındaki işlem yetkileri tanımlanmalıdır:",
          ),
        ]),
        el("div", "benchmark-tag-chips", [
          el("span", "benchmark-tag-chip", [text("En Az Yetki İlkesi (PoLP)")]),
          el("span", "benchmark-tag-chip", [
            text("Rol Tabanlı Yetkilendirme (RBAC)"),
          ]),
          el("span", "benchmark-tag-chip", [text("Kriptolu Oturum Çerezleri")]),
          el("span", "benchmark-tag-chip", [
            text("İşlem Denetim İzi (Audit Log)"),
          ]),
          el("span", "benchmark-tag-chip", [text("Şifreli Kimlik Doğrulama")]),
        ]),
      ]),

      // 4. Kadro Yapılanması & Departman Yetki Rehberi
      el("div", "panel role-guide-panel mb-4", [
        el("div", "category-section-title mb-3", [
          el("h3", "section-title-with-icon", [
            icons.security(),
            text(case s.workspace {
              "nexus" -> "Süper Yönetici & Platform Merkezi Kadro Yapılanması"
              _ -> "Departman Yetki Sınırları & Görev Dağılımı"
            }),
          ]),
          el("p", "muted text-sm", [
            text(
              "Sistemdeki her bir rolün erişim yetki sınırları, modül izinleri ve operasyonel sorumlulukları aşağıda detaylandırılmıştır.",
            ),
          ]),
        ]),
        el("div", "role-cards-grid", case s.workspace {
          "nexus" -> [
            role_card(
              icons.user(),
              "Merkez Yönetim",
              "Süper Yetki",
              "Tüm platform yönetimi, tedarikçi başvuru onayları, kadro ve sistem yetki dağıtımı.",
              "bg-navy",
            ),
            role_card(
              icons.search(),
              "Kalite & Onay",
              "İçerik & Denetim",
              "İlan inceleme, kalite puanlama, onay/ret süreçleri, kriter şemaları ve turizm mevzuatı.",
              "bg-teal",
            ),
            role_card(
              icons.accounting(),
              "Gelir & Hakediş",
              "Mali Operasyon",
              "Platform komisyonları, cari hesap mutabakatları, e-Fatura, e-Arşiv ve banka ödemeleri.",
              "bg-emerald",
            ),
            role_card(
              icons.supplier(),
              "İş Ortakları",
              "Onboarding",
              "Tedarikçi evrak doğrulama, acente talep ilişkileri ve iş ortağı sözleşme süreçleri.",
              "bg-amber",
            ),
            role_card(
              icons.sparkles(),
              "Zeka & Operasyon",
              "AI & Fiyat",
              "AI Hub yapay zeka komutları, Rate Shopper rakip analizi ve telemetri verileri.",
              "bg-blue",
            ),
          ]
          _ -> [
            role_card(
              icons.corporate(),
              "Tam Yetki (Genel Müdür)",
              "Tesis Yönetimi",
              "Kadro kurma, personellere yetki dağıtma, finans ve tüm operasyonel modüller.",
              "bg-navy",
            ),
            role_card(
              icons.housekeeping(),
              "Kat Hizmetleri (Housekeeping)",
              "Oda & Hijyen",
              "Canlı oda temizlik durumu, temizlendi onayı, arıza bildirme ve minibar takibi.",
              "bg-teal",
            ),
            role_card(
              icons.shopping(),
              "Satın Alma & Stok",
              "Tedarik & Gider",
              "Ürün fiyatı, fiş/fatura numarası, mutfak alım giderleri ve stok reçeteleri.",
              "bg-amber",
            ),
            role_card(
              icons.accounting(),
              "Finans & Ön Muhasebe",
              "Kasa & Gelir",
              "Gelir/gider kaydı, günlük kasa, folyo tahsilatı, personel bordroları ve POS.",
              "bg-emerald",
            ),
            role_card(
              icons.trending_up(),
              "Pazarlama & Ön Büro",
              "Satış & Kanal",
              "İlanlar, takvim, kanal yöneticisi, dinamik fiyat kuralları ve sosyal medya.",
              "bg-blue",
            ),
          ]
        }),
      ]),

      // 5. Yeni Ekip Üyesi / Personel Tanımla Formu
      el("section", "panel form editor-form new-field-card mb-4", [
        el("div", "category-section-title mb-3", [
          el("div", "flex-between align-center flex-wrap gap-2", [
            el("h3", "section-title-with-icon mb-0", [
              icons.user_add(),
              text("Yeni Ekip Üyesi / Personel Tanımla"),
            ]),
            el("span", "badge success", [text("Güvenli Kayıt")]),
          ]),
          el("p", "muted text-sm", [
            text(
              "Personelin sisteme erişebilmesi için e-posta, departman rolü ve güvenli geçici şifre belirleyiniz.",
            ),
          ]),
        ]),
        element.element(
          "form",
          [
            a.class("form"),
            a.attribute("method", "post"),
            a.attribute("action", "/admin/users"),
          ],
          [
            hidden("csrf", csrf),
            el("div", "form-grid grid-3 mb-3", [
              el("label", "field", [
                text("Çalışma Alanı (Tesis / Acente)"),
                element.element(
                  "select",
                  [a.name("tenant"), a.class("input-select")],
                  list.map(organizations, fn(r) {
                    case r {
                      [id, name, kind] ->
                        element.element("option", [a.value(id)], [
                          text(name <> " · " <> kind),
                        ])
                      _ -> text("")
                    }
                  }),
                ),
              ]),
              field("Personel Adı Soyadı", "name", "text"),
              field("Giriş E-postası", "email", "email"),
            ]),
            el("div", "form-grid grid-2 mb-3", [
              el("label", "field", [
                text("Yetki / Departman Rolü *"),
                element.element(
                  "select",
                  [a.name("role"), a.class("input-select")],
                  role_select_options(""),
                ),
              ]),
              field("Geçici Şifre (en az 10 karakter)", "password", "password"),
            ]),
            el("div", "form-actions flex-between", [
              el("span", "muted text-xs", [
                text("Personel ilk girişinde şifresini değiştirebilir."),
              ]),
              element.element("button", [a.class("button primary")], [
                icons.save(),
                text("Ekip Üyesini Kaydet & Yetkilendir"),
              ]),
            ]),
          ],
        ),
      ]),

      // 6. Tanımlı Kullanıcılar
      el("div", "mb-4", [
        el("div", "category-section-title mb-3", [
          el("h3", "section-title-with-icon", [
            icons.user(),
            text(
              "Tanımlı Ekip Üyeleri & Yetkiler ("
              <> int.to_string(total_users)
              <> " Personel)",
            ),
          ]),
          el("p", "muted text-sm", [
            text(
              "Kullanıcıların erişim yetkilerini güncelleyebilir, şifrelerini sıfırlayabilir veya hesaplarını dondurabilirsiniz.",
            ),
          ]),
        ]),
        el(
          "div",
          "user-card-grid",
          list.map(users, fn(r) {
            case r {
              [id, _tenant, org, email, name, role, active] ->
                user_card(csrf, id, org, email, name, role, active)
              _ -> text("")
            }
          }),
        ),
      ]),
    ]),
  )
}

fn role_card(
  icon: Element(Nil),
  title: String,
  badge: String,
  desc: String,
  icon_bg: String,
) {
  el("div", "role-definition-card", [
    el("div", "role-card-top flex-between align-center mb-2", [
      el("div", "role-icon-box " <> icon_bg, [icon]),
      el("span", "role-badge", [text(badge)]),
    ]),
    el("h4", "role-card-title mb-1", [text(title)]),
    el("p", "role-card-desc mb-0", [text(desc)]),
  ])
}

pub fn role_select_options(selected: String) -> List(element.Element(Nil)) {
  [
    // Süper Yönetici / Platform Rolleri
    selected_option(
      "owner",
      "Platform Sahibi / Süper Yönetici (Tam Yetki)",
      selected,
    ),
    selected_option(
      "operations_director",
      "Platform Operasyon Direktörü (Başvuru & İlan Onay)",
      selected,
    ),
    selected_option(
      "content_moderator",
      "İlan & İçerik Moderatörü (İlan İnceleme & Kalite)",
      selected,
    ),
    selected_option(
      "finance_manager",
      "Finans & Mutabakat Müdürü (Komisyon, Hakediş & e-Fatura)",
      selected,
    ),
    selected_option(
      "onboarding_specialist",
      "Tedarikçi İlişkileri & Onboarding (Evrak & Puanlama)",
      selected,
    ),
    selected_option(
      "ai_pricing_specialist",
      "AI & Fiyatlama Mühendisi (AI Hub, Yield & Rate Shopper)",
      selected,
    ),
    selected_option(
      "support_specialist",
      "Platform Destek Sorumlusu (İletişim & Telemetri)",
      selected,
    ),

    // Tedarikçi / Tesis Rolleri
    selected_option(
      "general_manager",
      "Tesis Genel Müdürü (Tesis Yetki Dağıtımı & Tüm Modüller)",
      selected,
    ),
    selected_option(
      "housekeeping",
      "Kat Hizmetleri / Temizlikçi (Oda Temizliği & Arıza)",
      selected,
    ),
    selected_option(
      "purchasing",
      "Satın Alma Sorumlusu (Ürün, Fiş No & Gider Girişi)",
      selected,
    ),
    selected_option(
      "accounting",
      "Muhasebe & Finans (Gelir, Gider, Kasa, Bordro)",
      selected,
    ),
    selected_option(
      "frontdesk",
      "Ön Büro & Resepsiyon (Oda Takibi, Rezervasyon)",
      selected,
    ),
    selected_option(
      "sales",
      "Satış Departmanı (İlanlar, Fiyatlar, Kampanyalar)",
      selected,
    ),
    selected_option(
      "marketing",
      "Reklam & Tanıtım (Sosyal Medya, AI Hub)",
      selected,
    ),
    selected_option("editor", "Editör (İçerik Düzenleme)", selected),
    selected_option("viewer", "Görüntüleyici (Salt Okunur)", selected),
  ]
}

fn role_badge_tag(role: String) -> element.Element(Nil) {
  let #(label, class) = case role {
    // Platform rolleri
    "owner" -> #("Süper Yönetici", "badge primary font-bold")
    "operations_director" -> #("Operasyon Direktörü", "badge primary")
    "content_moderator" -> #("İlan Moderatörü", "badge warning font-bold")
    "finance_manager" -> #("Finans Müdürü", "badge success")
    "onboarding_specialist" -> #("Onboarding Uzmanı", "badge info")
    "ai_pricing_specialist" -> #("AI Mühendisi", "badge primary")
    "support_specialist" -> #("Destek Sorumlusu", "badge dark")

    // Tedarikçi rolleri
    "general_manager" -> #("Genel Müdür", "badge dark font-bold")
    "housekeeping" -> #("Kat Hizmetleri", "badge warning")
    "purchasing" -> #("Satın Alma", "badge info")
    "accounting" -> #("Muhasebe", "badge success")
    "frontdesk" -> #("Ön Büro", "badge primary")
    "sales" -> #("Satış", "badge success")
    "marketing" -> #("Reklam", "badge warning")
    "editor" -> #("Editör", "badge dark")
    _ -> #("Görüntüleyici", "badge dark")
  }
  el("span", class, [text(label)])
}

fn user_card(
  csrf: String,
  id: String,
  org: String,
  email: String,
  name: String,
  role: String,
  active: String,
) {
  let is_active = active == "true"
  let card_status_cls = case is_active {
    True -> "user-card-active"
    False -> "user-card-inactive"
  }

  el("div", "panel user-management-card " <> card_status_cls, [
    // 1. Üst Bar: Avatar, İsim, E-posta, Çalışma Alanı, Rol ve Durum Rozeti
    el("div", "user-card-top-bar", [
      el("div", "user-card-user-info", [
        el("div", "user-avatar-circle", [text(initial(name))]),
        el("div", "user-identity-wrap", [
          el("div", "user-identity-head", [
            el("h4", "user-name-heading mb-0", [text(name)]),
            role_badge_tag(role),
          ]),
          el("div", "user-identity-meta", [
            el("span", "user-email-text muted text-xs", [text(email)]),
            el("span", "badge-code text-xs", [text(org)]),
          ]),
        ]),
      ]),
      el(
        "span",
        "user-status-pill "
          <> case is_active {
          True -> "status-active"
          False -> "status-inactive"
        },
        [
          el("span", "status-dot", []),
          text(case is_active {
            True -> "Aktif Hesap"
            False -> "Dondurulmuş"
          }),
        ],
      ),
    ]),

    // 2. Alt Form Gövdesi: Bilgileri Güncelle & Hızlı Şifre Sıfırlama
    el("div", "user-card-body-grid", [
      // Bilgi & Rol Güncelleme Formu
      element.element(
        "form",
        [
          a.class("user-edit-form"),
          a.attribute("method", "post"),
          a.attribute("action", "/admin/users/" <> id),
        ],
        [
          hidden("csrf", csrf),
          el("div", "form-grid grid-2 mb-3", [
            field_value("Ad Soyad", "name", "text", name),
            el("label", "field", [
              text("Departman Rolü"),
              element.element(
                "select",
                [a.name("role"), a.class("input-select")],
                role_select_options(role),
              ),
            ]),
          ]),
          el("div", "user-form-bottom-row", [
            el("label", "user-toggle-switch", [
              element.element(
                "input",
                [
                  a.name("active"),
                  a.attribute("type", "checkbox"),
                  a.value("true"),
                  ..case is_active {
                    True -> [a.attribute("checked", "checked")]
                    False -> []
                  }
                ],
                [],
              ),
              el("span", "toggle-label text-xs font-semibold", [
                text("Hesap Erişimi Aktif"),
              ]),
            ]),
            element.element("button", [a.class("button primary small")], [
              icons.save(),
              text("Bilgileri Güncelle"),
            ]),
          ]),
        ],
      ),

      // Şifre Sıfırlama Formu
      element.element(
        "form",
        [
          a.class("password-reset-form-box"),
          a.attribute("method", "post"),
          a.attribute("action", "/admin/users/" <> id <> "/password"),
        ],
        [
          hidden("csrf", csrf),
          el("div", "pwd-reset-header", [
            el("span", "pwd-box-icon", [icons.key()]),
            el("strong", "text-xs uppercase tracking-wider text-muted", [
              text("Hızlı Şifre Sıfırlama"),
            ]),
          ]),
          el("div", "pwd-reset-row", [
            el("div", "pwd-input-wrap", [
              field("Yeni Geçici Şifre", "password", "password"),
            ]),
            element.element(
              "button",
              [a.class("button secondary small reset-pwd-btn")],
              [
                icons.key(),
                text("Şifreyi Sıfırla"),
              ],
            ),
          ]),
        ],
      ),
    ]),
  ])
}

pub fn profile(s: Session, csrf: String, message: String) {
  view.shell(
    s,
    csrf,
    "Profil ve şifre",
    el("div", "profile-page", [
      el("div", "page-heading mb-4", [
        el("div", "", [
          el("p", "eyebrow", [text("HESABIM & ERİŞİM GÜVENLİĞİ")]),
          el("h1", "section-title-with-icon", [
            icons.user(),
            text("Profil ve Güvenlik"),
          ]),
          el("p", "muted", [
            text(
              "Görünen adınızı, e-posta adresinizi ve oturum açma şifrenizi güvenle yönetin.",
            ),
          ]),
        ]),
      ]),
      case message {
        "" -> text("")
        _ -> el("div", "notice success mb-4", [text(message)])
      },
      el("div", "profile-grid grid-2col gap-4", [
        el("section", "panel editor-form new-field-card", [
          el("div", "category-section-title mb-3", [
            el("h3", "section-title-with-icon", [
              icons.user(),
              text("Profil Bilgileri"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Platformda diğer kullanıcılara görünen adınızı güncelleyin.",
              ),
            ]),
          ]),
          element.element(
            "form",
            [
              a.class("form"),
              a.attribute("method", "post"),
              a.attribute("action", "/admin/profile"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "mb-3", [
                field_value("Görünen Ad", "name", "text", s.name),
              ]),
              element.element("button", [a.class("button primary")], [
                icons.save(),
                text("Profili Güncelle"),
              ]),
            ],
          ),
        ]),
        el("section", "panel editor-form new-field-card", [
          el("div", "category-section-title mb-3", [
            el("h3", "section-title-with-icon", [
              icons.key(),
              text("Şifre Değiştir"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Hesap güvenliğiniz için güçlü ve benzersiz bir şifre kullanın.",
              ),
            ]),
          ]),
          element.element(
            "form",
            [
              a.class("form"),
              a.attribute("method", "post"),
              a.attribute("action", "/admin/profile/password"),
            ],
            [
              hidden("csrf", csrf),
              el("div", "form-grid grid-1 mb-3", [
                field("Mevcut Şifre", "current", "password"),
                field("Yeni Şifre (en az 10 karakter)", "password", "password"),
              ]),
              element.element("button", [a.class("button primary")], [
                icons.key(),
                text("Şifreyi Değiştir"),
              ]),
            ],
          ),
        ]),
      ]),
    ]),
  )
}

fn field(label: String, name: String, kind: String) {
  field_value(label, name, kind, "")
}

fn field_value(label: String, name: String, kind: String, value: String) {
  el("label", "field", [
    text(label),
    element.element(
      "input",
      [
        a.name(name),
        a.attribute("type", kind),
        a.value(value),
        a.attribute("required", ""),
      ],
      [],
    ),
  ])
}

fn selected_option(value: String, label: String, current: String) {
  element.element(
    "option",
    [
      a.value(value),
      ..case value == current {
        True -> [a.attribute("selected", "selected")]
        False -> []
      }
    ],
    [text(label)],
  )
}

fn initial(name: String) {
  case list.first(name |> string.to_graphemes) {
    Ok(x) -> x
    Error(_) -> "Ü"
  }
}
