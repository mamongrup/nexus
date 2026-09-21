import gleam/int
import gleam/list
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element, text}
import nexus/domain.{type Session}
import nexus/icons
import nexus/view.{el, hidden, input}

pub fn page(
  s: Session,
  csrf: String,
  category: String,
  categories: List(List(String)),
  rows: List(List(String)),
  message: String,
) {
  let fields_count = list.length(rows)
  let required_count =
    list.filter(rows, fn(r) {
      case r {
        [_, _, _, _, _, "true", _, _] -> True
        _ -> False
      }
    })
    |> list.length

  view.shell(
    s,
    csrf,
    "İlan Kriterleri & Şema Yönetimi",
    el("div", "category-admin-hub", [
      // Üst Başlık & Süper Admin Kontrol Başlığı
      el("div", "content-header mb-4", [
        el("div", "eyebrow", [text("SÜPER ADMİN · SEKTÖREL KRİTER YÖNETİMİ")]),
        el("h1", "section-title-with-icon", [
          icons.modules(),
          text("İlan Kriterleri & Dinamik Şema Havuzu"),
        ]),
        el("p", "muted", [
          text(
            "Tedarikçilerin ilan eklerken doldurması gereken teknik ve sektörel kriterleri belirleyin. Sistem; konaklama, villa, tur, transfer ve filo operasyonları için önceden yapılandırılmış dinamik kriter havuzunu destekler.",
          ),
        ]),
      ]),

      // Sektörel Benchmark ve Senkronizasyon Aksiyon Barı
      el("div", "panel benchmark-sync-banner mb-4", [
        el("div", "flex-between align-center flex-wrap gap-3", [
          el("div", "", [
            el("div", "flex align-center gap-2 mb-1", [
              el("span", "badge primary", [text("Sektörel Standartlar")]),
              el("strong", "text-md", [
                text("Dinamik Kategori Kriter Şablonları"),
              ]),
            ]),
            el("p", "muted text-sm mb-2", [
              text(
                "Türkiye turizm mevzuatı (7464 izin), acente dağıtım kuralları ve doğrudan rezervasyon parametrelerini içeren şablonlar:",
              ),
            ]),
            el("div", "benchmark-tag-chips", [
              el("span", "benchmark-tag-chip", [
                text("Otel: Pansiyon / Plaj / Havuz / Spa"),
              ]),
              el("span", "benchmark-tag-chip", [
                text("Villa: Korunaklı / Akıllı Kilit / 7464 İzin Belgesi"),
              ]),
              el("span", "benchmark-tag-chip", [
                text("Tur & Transfer: Kokartlı Rehber / VIP / Güvenlik"),
              ]),
            ]),
          ]),
          element.element(
            "form",
            [
              a.attribute("method", "post"),
              a.attribute("action", "/admin/category-fields/sync-presets"),
            ],
            [
              hidden("csrf", csrf),
              hidden("category", category),
              element.element(
                "button",
                [a.class("button dark btn-sync-standards")],
                [
                  icons.sparkles(),
                  text(" Sektör Standartlarını Senkronize Et"),
                ],
              ),
            ],
          ),
        ]),
      ]),

      // Kategori Seçici Navigasyon Paneli (Modern Segmented Grid)
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
                    "Ürün & Hizmet Kategorileri ("
                    <> int.to_string(list.length(categories))
                    <> " Kategori)",
                  ),
                ],
              ),
            ]),
            el("span", "badge dark text-xs", [
              text("Seçili: " <> category_title(category)),
            ]),
          ]),
        ]),
        el(
          "nav",
          "category-tabs-grid",
          list.map(categories, fn(row) {
            case row {
              [code, name, ..] -> {
                let is_active = code == category
                let cls = case is_active {
                  True -> "category-tab-btn active"
                  False -> "category-tab-btn"
                }
                element.element(
                  "a",
                  [a.href("/admin/category-fields/" <> code), a.class(cls)],
                  [
                    el("span", "category-tab-icon", [category_huge_icon(code)]),
                    el("span", "category-tab-label", [text(name)]),
                  ],
                )
              }
              _ -> text("")
            }
          }),
        ),
      ]),

      case message {
        "" -> text("")
        _ -> el("p", "notice success mb-4", [text(message)])
      },

      // Aktif Kategori Özeti ve Sektörel Kaynak Kartı
      el("div", "panel active-category-hero mb-4", [
        el("div", "flex-between align-center flex-wrap gap-3 mb-3", [
          el("div", "flex align-center gap-3", [
            el("div", "active-cat-icon-box", [category_huge_icon(category)]),
            el("div", "", [
              el("div", "flex align-center gap-2 mb-1", [
                el("h2", "active-cat-title mb-0", [
                  text(category_title(category) <> " İlan Kriterleri"),
                ]),
                el("span", "badge-code", [text("kod: " <> category)]),
              ]),
              el("p", "muted text-sm mb-0", [
                text(
                  "Bu kategoriye ait tedarikçi ilan formunda ve filtre motorunda geçerli olan dinamik veri alanları.",
                ),
              ]),
            ]),
          ]),
          el("div", "flex gap-2 align-center flex-wrap", [
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-primary", [
                text(int.to_string(fields_count)),
              ]),
              el("span", "kpi-mini-label", [text("Toplam Kriter")]),
            ]),
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-warning", [
                text(int.to_string(required_count)),
              ]),
              el("span", "kpi-mini-label", [text("Zorunlu Kriter")]),
            ]),
            el("div", "kpi-mini-stat", [
              el("span", "kpi-mini-num text-success", [
                text(int.to_string(fields_count - required_count)),
              ]),
              el("span", "kpi-mini-label", [text("İsteğe Bağlı")]),
            ]),
          ]),
        ]),
        el("div", "category-benchmark-box", [
          el("span", "benchmark-badge", [
            icons.sparkles(),
            text("Sektörel Standart Rehberi:"),
          ]),
          el("p", "benchmark-text", [
            text(category_benchmark_description(category)),
          ]),
        ]),
      ]),

      // 1. Form: Yeni Kriter Ekle
      el("div", "panel-card mb-4", [
        el("div", "category-section-title mb-3", [
          el("h3", "section-title-with-icon", [
            icons.plus(),
            text("Bu Kategoriye Yeni Kriter Ekle"),
          ]),
          el("p", "muted text-sm", [
            text(
              "Tedarikçinin ilan eklerken görmesini istediğiniz yeni bir veri alanını tanımlayın. Seçenekli alanlar için seçenekleri virgülle ayırın.",
            ),
          ]),
        ]),
        field_form(csrf, category, [
          "",
          "",
          "",
          "select",
          "",
          "false",
          "true",
          "10",
        ]),
      ]),

      // Yönetilebilir filtre grupları: storefront ve ilan formu aynı sözleşmeden beslensin
      el("div", "panel-card mb-4", [
        element.element(
          "div",
          [
            a.class("category-section-title mb-3"),
            a.id("managed-filters"),
            a.attribute("data-category-filter-admin", category),
          ],
          [
            el("h3", "section-title-with-icon", [
              icons.filter(),
              text("Filtre Grupları, Alt Tipler ve Seçenekler"),
            ]),
            el("p", "muted text-sm", [
              text(
                "Kategori altında görünen alt tip, öznitelik ve filtre seçeneklerini buradan yönetin. Başlıklar ve maddeler merkezi sözleşmeye yazılır; çeviri kuyruğu otomatik oluşturulur.",
              ),
            ]),
          ],
        ),
        el("div", "form-grid grid-2 mb-4", [
          managed_filter_group_form(csrf, category),
          managed_filter_item_form(csrf, category),
        ]),
        el("div", "table-card", [
          el("div", "flex-between align-center mb-2", [
            el("strong", "", [text("Tanımlı filtre grupları")]),
            el("span", "badge neutral", [text("Admin yönetimli")]),
          ]),
          element.element(
            "div",
            [
              a.id("nexus-category-filter-table"),
              a.class("category-filter-admin-list"),
            ],
            [
              el("p", "muted text-sm", [
                text("Filtreler yükleniyor veya bu kategori için henüz tanım yok."),
              ]),
            ],
          ),
        ]),
      ]),

      // 2. Form Listesi: Mevcut Kriterler
      case fields_count {
        0 ->
          el("div", "empty-state-box text-center p-5 panel-card", [
            el("p", "muted", [
              text(
                "Bu kategori için henüz özel kriter tanımlanmamış. Yukarıdaki 'Sektör Standartlarını Senkronize Et' butonuna tıklayarak veya yeni kriter ekleyerek başlayabilirsiniz.",
              ),
            ]),
          ])
        count ->
          el("div", "", [
            el("div", "category-section-title mb-3", [
              el("h3", "section-title-with-icon", [
                icons.document(),
                text(
                  "Tanımlı Kriterler & Form Alanları ("
                  <> int.to_string(count)
                  <> ")",
                ),
              ]),
              el("p", "muted text-sm", [
                text(
                  "Aşağıdaki kriterler ilan ekleme ve düzenleme ekranında tedarikçiye gösterilir. Zorunlu işaretlenen kriterler doldurulmadan ilan onaya gönderilemez.",
                ),
              ]),
            ]),
            el(
              "div",
              "fields-list-grid",
              list.map(rows, fn(row) { field_form(csrf, category, row) }),
            ),
          ])
      },
    ]),
  )
}

fn category_huge_icon(cat: String) -> Element(Nil) {
  icons.for_category(cat)
}

fn category_title(cat: String) -> String {
  view.category_title(cat)
}

fn category_benchmark_description(cat: String) -> String {
  case cat {
    "hotel" ->
      "Otel & Konaklama Kriterleri: Pansiyon/yemek konsepti (UAI/AI/HB), denize mesafe, plaj tipi, havuz/aquapark, balayı/yetişkin konsepti, çocuk olanakları, spa, evcil hayvan kabulü ve Bakanlık Turizm İşletme Belgesi."
    "holiday_home" | "villa" ->
      "Lüks Villa & Tatil Evi Kriterleri: Mülk tipi (villa/bungalov/dağ evi/apart/residence), havuz korunaklılığı (muhafazakar), havuz ısıtması, jakuzi, şömine, ankastre donanımı, fiber Wi-Fi, akıllı şifreli kilit (self check-in), 7464 sayılı resmi izin belgesi ve karekodlu konut plaketi."
    "yacht" ->
      "Yat & Mavi Yolculuk Kriterleri: Ahşap gulet / motoryat / yelkenli / katamaran, tekne boyu, kabin sayısı, mürettebat durumu (kaptan/aşçı), APA kumanya depozitosu, seyir yakıtı durumu, su sporları ve popüler seyir rotaları."
    "tour" ->
      "Tur Operatörü & Paket Tur Kriterleri: Kültür turu / doğa / günübirlik, ulaşım modu (otobüs/uçak), kokartlı profesyonel rehber dilleri, dahil olan yemekler ve müze girişleri, kalkış/buluşma durakları, kesin hareket garantisi ve TÜRSAB A grubu ruhsatı."
    "activity" ->
      "Aktivite & Macera Kriterleri: Balon uçuşu, yamaç paraşütü, rafting, tüplü dalış, safari turları, çift yönlü otel transferi, güvenlik ekipmanları, GoPro 4K çekimi, sağlık/kilo kriterleri, tam kapsamlı ekstrem spor sigortası ve lisanslar."
    "flight" ->
      "Uçuş & Havayolu Kriterleri: Bilet sınıfı (ekonomi/business/first), bagaj hakkı, uçak tipi, direkt/aktarmalı uçuş, PNR opsiyonu, havalimanı check-in ve iptal/iade kuralları."
    "car" ->
      "Araç Kiralama & Filo Kriterleri: Vites türü, yakıt türü, araç segmenti, sınırsız kilometre, muafiyetsiz tam kasko, kredi kartı provizyon blokesi, EGM KABİS polis bildirimi ve havalimanı/vale teslimat şekli."
    "cruise" ->
      "Kruvaziyer & Gemi Seyahati Kriterleri: Kabin kategorisi (iç/dış/balkonlu/süit), liman vergileri dahil durumu, tek kişi kabin farkı, erken rezervasyon indirimi, gemi olanakları ve liman uğrak programı."
    "pilgrimage" ->
      "Hac & Umre Programı Kriterleri: Paket tipi, Mekke ve Medine otel sınıfları, Harem'e mesafe/servis, oda paylaşım türleri, Diyanet vize/işlem onayı, rehber hocalar ve kurban/ziyaret organizasyonu."
    "visa" ->
      "Vize Danışmanlık Kriterleri: Başvuru ülkesi, vize türü (turistik/ticari/aile), başvuru hızı (standart/VIP), konsolosluk randevu ve harç dahil durumu, yeminli tercüme ve dosya takip garantisi."
    "ferry" ->
      "Feribot & Deniz Otobüsü Kriterleri: Hat güzergahı, sefer saatleri, araçlı/yolcu geçişi, bilet sınıfı, iskele check-in süresi ve uluslararası seferlerde pasaport/vize kontrolü."
    "transfer" ->
      "Havalimanı & Şehirlerarası Transfer Kriterleri: Araç modeli (VIP Vito/Sprinter/binek), ücretsiz havalimanı karşılama/bekleme süresi, bebek koltuğu, bagaj kapasitesi ve güzergah sabit fiyat garantisi."
    "beach" ->
      "Beach Club & Günübirlik Giriş Kriterleri: Plaj yapısı (iskele/kum/çakıl), şezlong/loca/cabana hizmeti, kişi başı minimum harcama limiti, havlu depozitosu, canlı performans ve su sporları."
    "cinema" ->
      "Sinema & Gösterim Kriterleri: Salon teknolojisi (IMAX/3D/Gold Class), ses sistemi (Dolby Atmos), seans saatleri, koltuk düzeni, dublaj/altyazı seçeneği ve yaş sınırı."
    "event" ->
      "Etkinlik & Organizasyon Kriterleri: Konser, festival, tiyatro, atölye, oturma düzeni (numaralı/bistro/ayakta/VIP), yaş sınırı kuralları, kapı açılış saati, QR kodlu e-bilet kontrolü ve yeme-içme alanları."
    "restaurant" ->
      "Restoran & Gastronomi Kriterleri: Mutfak türü (Akdeniz/Ege/Dünya/Ocakbaşı), menü konsepti (alakart/fix/tadım), masa rezervasyon depozitosu, masa tutma süresi, servis bedeli ve çocuk olanakları."
    "bus" ->
      "Şehirlerarası Otobüs Kriterleri: Sefer güzergahı, koltuk düzeni (2+1 rahat hat), ikram servisi, priz/Wi-Fi donanımı, bagaj limiti, mola yerleri ve bilet iptal/açığa alma kuralları."
    _ ->
      "Sektör standartlarına uygun dinamik ürün parametreleri ve doğrulanmış alan şeması."
  }
}

fn managed_filter_group_form(csrf: String, category: String) {
  element.element(
    "form",
    [
      a.class("panel form editor-form bg-light border-dashed"),
      a.attribute("method", "post"),
      a.attribute("action", "/admin/category-filters/groups"),
    ],
    [
      hidden("csrf", csrf),
      hidden("category", category),
      el("h4", "field-card-title mb-2", [text("Yeni / Güncel Filtre Grubu")]),
      el("div", "form-grid grid-2 mb-3", [
        input("Grup kodu (örn: property_type)", "group_key", "text", "", True),
        input("Başlık (örn: Tatil Evi Tipi)", "title", "text", "", True),
      ]),
      input("Yardım metni", "help_text", "text", "", False),
      el("div", "form-grid grid-3 mb-3", [
        el("label", "field", [
          text("Gösterim tipi"),
          choice("display_type", "chip", ["chip", "select", "checkbox"]),
        ]),
        el("label", "field", [
          text("Çoklu seçim"),
          choice("multiple", "false", ["false", "true"]),
        ]),
        input("Sıra", "position", "number", "10", True),
      ]),
      element.element("button", [a.class("button primary")], [
        icons.save(),
        text("Filtre Grubunu Kaydet"),
      ]),
    ],
  )
}

fn managed_filter_item_form(csrf: String, category: String) {
  element.element(
    "form",
    [
      a.class("panel form editor-form bg-light border-dashed"),
      a.attribute("method", "post"),
      a.attribute("action", "/admin/category-filters/items"),
    ],
    [
      hidden("csrf", csrf),
      hidden("category", category),
      el("h4", "field-card-title mb-2", [text("Yeni / Güncel Filtre Maddesi")]),
      el("label", "field mb-3", [
        text("Bağlı grup"),
        element.element(
          "select",
          [
            a.name("group_id"),
            a.id("nexus-filter-item-group"),
            a.class("input-select"),
            a.attribute("required", ""),
          ],
          [
            element.element("option", [a.value("")], [
              text("Önce filtre grubu seçin"),
            ]),
          ],
        ),
      ]),
      el("div", "form-grid grid-2 mb-3", [
        input("Madde kodu (örn: villa)", "item_key", "text", "", True),
        input("Başlık (örn: Villa)", "title", "text", "", True),
      ]),
      input("Yardım metni", "help_text", "text", "", False),
      el("div", "form-grid grid-3 mb-3", [
        input(
          "Sözleşme alan kodu",
          "contract_field_code",
          "text",
          "",
          False,
        ),
        input("Sözleşme değeri", "contract_value", "text", "", False),
        input("Sıra", "position", "number", "10", True),
      ]),
      element.element("button", [a.class("button primary")], [
        icons.plus(),
        text("Filtre Maddesini Kaydet"),
      ]),
    ],
  )
}

fn choice(name: String, current: String, options: List(String)) {
  element.element(
    "select",
    [a.name(name), a.class("input-select")],
    list.map(options, fn(value) {
      element.element(
        "option",
        [
          a.value(value),
          ..case value == current {
            True -> [a.attribute("selected", "")]
            False -> []
          }
        ],
        [text(value)],
      )
    }),
  )
}

fn field_form(csrf: String, category: String, row: List(String)) {
  case row {
    [id, code, label, kind, choices, required, active, position] -> {
      let is_new = id == ""
      let title = case is_new {
        True -> "Yeni Kriter Parametreleri"
        False -> label <> " (" <> code <> ")"
      }
      let choice_items = case choices {
        "" -> []
        c -> string.split(c, ",")
      }
      let choice_count = list.length(choice_items)

      element.element(
        "form",
        [
          a.class(case is_new {
            True ->
              "panel form editor-form new-field-card bg-light border-dashed mb-4"
            False -> "panel form editor-form existing-field-card mb-3"
          }),
          a.attribute("method", "post"),
          a.attribute("action", "/admin/category-fields/" <> category),
        ],
        [
          el("div", "field-card-header mb-3", [
            el("div", "flex-between align-center flex-wrap gap-2", [
              el("h4", "field-card-title mb-0", [text(title)]),
              case is_new {
                True -> el("span", "badge neutral", [text("Yeni Tanım")])
                False ->
                  el("div", "field-meta-badges flex gap-1 flex-wrap", [
                    el("span", "badge dark", [
                      text(case kind {
                        "select" -> "Çoktan Seçmeli"
                        "text" -> "Metin"
                        "number" -> "Sayı"
                        "boolean" -> "Evet / Hayır"
                        "document" -> "Resmi Belge"
                        _ -> kind
                      }),
                    ]),
                    case choice_count > 0 {
                      True ->
                        el("span", "badge neutral", [
                          text(int.to_string(choice_count) <> " Seçenek"),
                        ])
                      False -> text("")
                    },
                    case required == "true" {
                      True ->
                        el("span", "badge warning font-bold", [text("Zorunlu")])
                      False ->
                        el("span", "badge neutral", [text("İsteğe Bağlı")])
                    },
                    case active == "true" {
                      True -> el("span", "badge success", [text("Aktif")])
                      False -> el("span", "badge neutral", [text("Pasif")])
                    },
                    el("span", "badge neutral", [text("Sıra: " <> position)]),
                  ])
              },
            ]),
          ]),
          hidden("csrf", csrf),
          hidden("id", id),
          el("div", "form-grid grid-3 mb-3", [
            input(
              "Alan Kodu (örn: meal_plan, pool_type)",
              "code",
              "text",
              code,
              True,
            ),
            input(
              "Kriter Etiketi (örn: Pansiyon Konsepti)",
              "label",
              "text",
              label,
              True,
            ),
            el("label", "field", [
              text("Veri Tipi"),
              choice("kind", kind, [
                "select",
                "text",
                "number",
                "boolean",
                "document",
                "json",
              ]),
            ]),
          ]),
          el("div", "form-grid grid-3 mb-3", [
            el("div", "span-2", [
              input(
                "Seçenekler (Çoktan seçmeli için virgülle ayırarak giriniz)",
                "choices",
                "text",
                choices,
                False,
              ),
            ]),
            input(
              "Görüntüleme Sırası (10, 20...)",
              "position",
              "number",
              position,
              True,
            ),
          ]),
          el("div", "form-grid grid-2 mb-3", [
            el("label", "field", [
              text("Zorunluluk Durumu"),
              choice("required", required, ["false", "true"]),
            ]),
            el("label", "field", [
              text("Aktiflik Durumu"),
              choice("active", active, ["true", "false"]),
            ]),
          ]),
          el("div", "form-actions flex-between", [
            case is_new {
              True -> text("")
              False ->
                element.element(
                  "button",
                  [
                    a.class("button danger small"),
                    a.name("delete"),
                    a.value("true"),
                  ],
                  [icons.trash(), text("Kriteri Sil")],
                )
            },
            element.element("button", [a.class("button primary")], [
              case is_new {
                True -> icons.plus()
                False -> icons.save()
              },
              text(case is_new {
                True -> "Yeni Kriteri Kaydet"
                False -> "Değişiklikleri Kaydet"
              }),
            ]),
          ]),
        ],
      )
    }
    _ -> text("")
  }
}
