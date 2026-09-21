import gleam/int
import gleam/list
import gleam/string

pub type AiResult {
  AiResult(
    title: String,
    description: String,
    seo_title: String,
    seo_description: String,
  )
}

pub fn generate_all(
  category: String,
  locality: String,
  current_title: String,
  capacity: String,
) -> AiResult {
  let cat = case string.lowercase(string.trim(category)) {
    "" -> "villa"
    c -> c
  }
  let loc = case string.trim(locality) {
    "" -> "Türkiye Popüler Tatil Bölgesi"
    l -> l
  }
  let effective_title = case string.trim(current_title) {
    "" -> generate_title(cat, loc)
    t -> t
  }
  AiResult(
    title: effective_title,
    description: generate_description(cat, loc, effective_title, capacity),
    seo_title: generate_seo_title(cat, loc, effective_title),
    seo_description: generate_seo_description(cat, loc, effective_title),
  )
}

pub fn generate_title(category: String, locality: String) -> String {
  let loc = case string.trim(locality) {
    "" -> "Ege & Akdeniz"
    l -> l
  }
  case category {
    "hotel" ->
      loc <> " Merkezinde Boğaz / Deniz Manzaralı Lüks Konsept Suite Otel"
    "villa" ->
      loc <> "'da Özel Sonsuzluk Havuzlu & Panoramik Manzaralı Lüks Villa"
    "car" ->
      loc
      <> " Havalimanı / Merkez Teslimatlı Yeni Kasa & Full Kaskolu Kiralık Araç"
    "tour" ->
      loc <> " Profesyonel Rehberli Butik Deneyim & Kültür / Macera Turu"
    "transfer" ->
      loc <> " VIP Havalimanı Karşılama, Şoförlü Lüks Minibüs Transferi"
    "yacht" -> loc <> " Çıkışlı Özel Gulet & Lüks Mavi Yolculuk Yat Kiralama"
    "restaurant" -> loc <> "'da Şef Menülü Gurme Lezzetler & Özel Rezervasyon"
    "spa" -> loc <> " Termal & Masaj Terapili Lüks Wellness Spa Paketi"
    _ -> loc <> " Ayrıcalıklı & Seçkin Seyahat Hizmeti - NEXUS TravelTech"
  }
}

pub fn generate_description(
  category: String,
  locality: String,
  title: String,
  capacity: String,
) -> String {
  let loc = case string.trim(locality) {
    "" -> "Seçkin Tatil Lokasyonu"
    l -> l
  }
  let cap_str = case string.trim(capacity) {
    "" | "0" -> "4"
    c -> c
  }

  case category {
    "hotel" ->
      "## Genel Bakış & Ayrıcalıklar\n"
      <> "NEXUS kalitesiyle sunulan tesisimiz, "
      <> loc
      <> " bölgesinin en seçkin noktasında kusursuz konfor ve üst düzey misafirperverlik sunmaktadır. "
      <> "İster iş seyahati ister dinlendirici bir tatil olsun, modern mimari ve lüks süitlerimizle unutulmaz anlar vadediyoruz.\n\n"
      <> "## Konaklama & Donanım Detayları\n"
      <> "- Ortopedik lüks yataklar ve ses yalıtımlı özel süit odalar\n"
      <> "- Zengin açık büfe gurme kahvaltı ve 24 saat oda servisi\n"
      <> "- Yüksek hızlı fiber Wi-Fi ve ergonomik çalışma alanı\n"
      <> "- 24 saat kesintisiz vale ve ücretsiz güvenli kapalı otopark\n"
      <> "- Emniyet Genel Müdürlüğü (AKBS/KBS) resmi kimlik bildirimi tam entegre\n"
      <> "- Resmi GİB onaylı e-Arşiv / e-Fatura güvencesi\n\n"
      <> "## Konum & Ulaşım\n"
      <> "Tesisimiz "
      <> loc
      <> " merkezine, popüler kafelere, alışveriş caddelerine ve sahil şeridine yürüyüş mesafesinde konumlanmıştır.\n\n"
      <> "## Giriş & Rezervasyon Kuralları\n"
      <> "- Giriş (Check-In): 14:00 | Çıkış (Check-Out): 12:00\n"
      <> "- Resepsiyonumuz 7/24 kesintisiz hizmet vermektedir.\n"
      <> "- İptal ve değişiklik talepleri seçilen rezervasyon tarifesi koşullarına tabidir."

    "villa" ->
      "## Genel Bakış & Ayrıcalıklar\n"
      <> loc
      <> " bölgesinin eşsiz doğası ve panoramik manzarası eşliğinde, "
      <> cap_str
      <> " misafir kapasiteli tamamen korunaklı ve müstakil bir tatil deneyimi sizi bekliyor. "
      <> "Gözlerden uzak, aileniz ve sevdiklerinizle huzurlu anlar yaşamanız için her detay en ince ayrıntısına kadar tasarlandı.\n\n"
      <> "## Villa Donanımı & Yaşam Alanları\n"
      <> "- Müstakil özel yüzme havuzu ve şezlonglu geniş güneşlenme terası\n"
      <> "- Korunaklı geniş bahçe, açık hava yemek masası ve taş barbekü\n"
      <> "- Ankastre ocak, fırın, bulaşık makinesi ve kahve makinesi ile tam donanımlı ada mutfak\n"
      <> "- Tüm odalarda bağımsız inverter klima ve yerden ısıtma\n"
      <> "- 7464 Sayılı Konutların Turizm Amaçlı Kiralanması İzin Belgeli ve Karekodlu Plaket güvencesi\n"
      <> "- Akıllı kapı şifresi ve WhatsApp üzerinden 7/24 karşılama asistanı\n\n"
      <> "## Konum & Plajlara Erişim\n"
      <> "Villamız "
      <> loc
      <> " merkezine ve en gözde plajlara kısa sürüş mesafesindedir. Sessiz, nezih ve elit bir çevrede yer almaktadır.\n\n"
      <> "## Giriş & Rezervasyon Kuralları\n"
      <> "- Giriş Saati: 16:00 | Çıkış Saati: 10:00\n"
      <> "- Girişte hasar depozitosu alınır ve çıkışta kontroller tamamlandıktan sonra anında iade edilir.\n"
      <> "- Villa girişi öncesinde yasal KBS kimlik bildirimi zorunludur."

    "car" ->
      "## Araç Bilgileri & Standartlar\n"
      <> loc
      <> " noktasında sorunsuz, hızlı ve konforlu ulaşım için hazırlanan aracımız periyodik yetkili servis bakımlı ve yüksek donanımlıdır.\n\n"
      <> "## Öne Çıkan Özellikler & Kiralama Avantajları\n"
      <> "- Yeni model yılı, düşük kilometre ve tertemiz dezenfekte edilmiş iç mekan\n"
      <> "- Tam Kapsamlı Muafiyetsiz Kasko (CDW) ve 7/24 Yol Yardım Hizmeti\n"
      <> "- Havalimanı terminal çıkışında veya otelinizde ücretsiz karşılama ve teslimat\n"
      <> "- HGS entegre geçiş sistemi ve şeffaf yakıt politikası\n"
      <> "- Emniyet KABİS araç kiralama resmi kolluk kaydı anında onaylı\n\n"
      <> "## Kiralama Koşulları\n"
      <> "- Asgari 2 yıllık geçerli sürücü belgesi ve kredi kartı provizyonu gereklidir.\n"
      <> "- Sözleşme teslimat anında dijital olarak onaylanır."

    "tour" ->
      "## Tur & Deneyim Detayları\n"
      <> loc
      <> " bölgesinin gizli kalmış güzelliklerini, tarihi ve kültürel zenginliklerini uzman rehberler eşliğinde keşfedin.\n\n"
      <> "## Tura Dahil Olan Hizmetler\n"
      <> "- TURSAB kokartlı profesyonel rehberlik hizmeti (Türkçe & İngilizce)\n"
      <> "- Klimalı lüks araçlarla otelden gidiş-dönüş konforlu transfer\n"
      <> "- Yöresel lezzetlerden oluşan zengin öğle yemeği\n"
      <> "- Müze ve ören yerleri resmi giriş biletleri\n"
      <> "- Zorunlu seyahat sağlık ve ferdi kaza sigortası\n\n"
      <> "## Yanınızda Bulundurmanız Önerilenler\n"
      <> "- Rahat yürüyüş ayakkabısı, güneş gözlüğü, şapka ve fotoğraf makinesi."

    "transfer" ->
      "## VIP Transfer Hizmeti Özellikleri\n"
      <> loc
      <> " havalimanı ve oteller arası VIP yolcu taşımacılığında dakiklik, güvenlik ve konforu bir arada sunuyoruz.\n\n"
      <> "## Standartlarımız & Ayrıcalıklarımız\n"
      <> "- Canlı uçuş takip sistemi: Uçağınız rötarlı inse dahi ücretsiz bekleme garantisi\n"
      <> "- Terminal kapısında isim yazılı karşılama tabelası ve bagaj asistanı\n"
      <> "- Deri koltuklu, minibarlı, Wi-Fi ve TV donanımlı Mercedes VIP araç filosu\n"
      <> "- T.C. Ulaştırma Bakanlığı D2 Yetki Belgesi ve U-ETDS resmi yolcu bildirimi tam entegre\n"
      <> "- Sabit fiyat garantisi; köprü, otoyol ve otopark ücretleri fiyata dahildir."

    _ ->
      "## Hizmet Özellikleri & Kalite Standartları\n"
      <> loc
      <> " lokasyonunda sunulan "
      <> title
      <> ", misafirlerimize en yüksek konfor ve memnuniyeti sağlamak üzere profesyonel ekibimiz tarafından organize edilmektedir.\n\n"
      <> "## Ayrıcalıklar\n"
      <> "- NEXUS güvencesi ile anında onay ve 7/24 müşteri desteği\n"
      <> "- Tüm yasal mevzuata ve resmi izinlere tam uyumluluk\n"
      <> "- Şeffaf fiyatlandırma ve resmi e-belge dökümü\n\n"
      <> "Sorularınız ve özel talepleriniz için lütfen iletişime geçiniz."
  }
}

pub fn generate_seo_title(
  category: String,
  locality: String,
  title: String,
) -> String {
  let loc = case string.trim(locality) {
    "" -> "Türkiye"
    l -> l
  }
  let base = case category {
    "hotel" -> loc <> " Lüks Otel & Butik Suite Konaklama - NEXUS"
    "villa" -> loc <> " Kiralık Lüks Villa & Özel Havuzlu Tatil Evi - NEXUS"
    "car" -> loc <> " Havalimanı Araç Kiralama & Rent a Car - NEXUS"
    "tour" -> loc <> " Günübirlik Turlar & Özel Deneyimler - NEXUS"
    "transfer" -> loc <> " VIP Havalimanı Transferi | Güvenli & Konforlu"
    "yacht" -> loc <> " Mavi Tur Yat & Gulet Kiralama - NEXUS"
    _ -> loc <> " " <> string.slice(title, 0, 45) <> " - NEXUS"
  }
  string.slice(base, 0, 160)
}

pub fn generate_seo_description(
  category: String,
  locality: String,
  title: String,
) -> String {
  let loc = case string.trim(locality) {
    "" -> "popüler tatil bölgesinde"
    l -> l
  }
  let base = case category {
    "hotel" ->
      loc
      <> " bölgesinde en seçkin otel konaklaması. Anında onay, e-fatura ve resmi Emniyet KBS güvencesiyle en iyi fiyata rezervasyon yapın."
    "villa" ->
      loc
      <> " bölgesinde özel havuzlu ve korunaklı kiralık villa. 7464 izin belgeli, güvenli ödeme ve 7/24 misafir desteğiyle yerinizi ayırtın."
    "car" ->
      loc
      <> " havalimanı ve merkez teslim kiralık araçlar. Full kaskolu, KABİS onaylı ve uygun fiyatlı son model araç kiralama."
    "tour" ->
      loc
      <> " çıkışlı en popüler turlar ve eşsiz deneyimler. TURSAB güvenceli rehberlik, transfer dahil avantajlı fiyatlar."
    "transfer" ->
      loc
      <> " VIP transfer hizmeti. Uçuş takibi, tabelalı karşılama ve D2/U-ETDS belgeli lüks araçlarla güvenli yolculuk."
    _ ->
      loc
      <> " lokasyonunda "
      <> string.slice(title, 0, 50)
      <> " için en iyi fiyat garantisi ve güvenli rezervasyon NEXUS TravelTech'te."
  }
  string.slice(base, 0, 320)
}

pub type PhotoRankItem {
  PhotoRankItem(
    url: String,
    rank: Int,
    tag: String,
    score: Int,
    reason: String,
    is_hero: Bool,
  )
}

type RawRanked {
  RawRanked(url: String, tag: String, score: Int, reason: String)
}

pub fn rank_photos(
  category: String,
  photo_urls: List(String),
) -> List(PhotoRankItem) {
  let cat = string.lowercase(string.trim(category))
  let cleaned_urls = list.filter(photo_urls, fn(u) { string.trim(u) != "" })

  let raw_scored =
    list.index_map(cleaned_urls, fn(url, idx) { classify_photo(cat, url, idx) })

  let sorted = list.sort(raw_scored, fn(a, b) { int.compare(b.score, a.score) })

  list.index_map(sorted, fn(item, idx) {
    let rank = idx + 1
    let is_hero = rank == 1
    let updated_tag = case is_hero {
      True ->
        case string.contains(item.tag, "Kapak") {
          True -> item.tag
          False -> item.tag <> " (Kapak)"
        }
      False -> item.tag
    }
    PhotoRankItem(
      url: item.url,
      rank: rank,
      tag: updated_tag,
      score: item.score,
      reason: item.reason,
      is_hero: is_hero,
    )
  })
}

fn classify_photo(category: String, url: String, index: Int) -> RawRanked {
  let lower_url = string.lowercase(url)

  case category {
    "car" -> classify_car_photo(lower_url, url, index)
    "hotel" -> classify_hotel_photo(lower_url, url, index)
    _ -> classify_villa_photo(lower_url, url, index)
  }
}

fn classify_villa_photo(
  lower_url: String,
  original_url: String,
  index: Int,
) -> RawRanked {
  let has_pool =
    string.contains(lower_url, "pool")
    || string.contains(lower_url, "havuz")
    || string.contains(lower_url, "facade")
    || string.contains(lower_url, "dis")
    || string.contains(lower_url, "manzara")
    || string.contains(lower_url, "view")
    || string.contains(lower_url, "hero")

  let has_bed =
    string.contains(lower_url, "bed")
    || string.contains(lower_url, "yatak")
    || string.contains(lower_url, "oda")
    || string.contains(lower_url, "room")
    || string.contains(lower_url, "master")
    || string.contains(lower_url, "suite")

  let has_terrace =
    string.contains(lower_url, "terrace")
    || string.contains(lower_url, "teras")
    || string.contains(lower_url, "garden")
    || string.contains(lower_url, "bahce")
    || string.contains(lower_url, "bbq")
    || string.contains(lower_url, "jakuzi")

  let has_kitchen =
    string.contains(lower_url, "kitchen")
    || string.contains(lower_url, "mutfak")
    || string.contains(lower_url, "salon")
    || string.contains(lower_url, "living")
    || string.contains(lower_url, "dining")

  let has_bath =
    string.contains(lower_url, "bath")
    || string.contains(lower_url, "banyo")
    || string.contains(lower_url, "shower")
    || string.contains(lower_url, "wc")

  case True {
    _ if has_pool ->
      RawRanked(
        url: original_url,
        tag: "Özel Havuz & Manzara",
        score: 99 - index,
        reason: "Rezervasyon platformlarında ve vitrinde en yüksek tıklama oranına sahip ana dış cephe/havuz açısı.",
      )
    _ if has_bed ->
      RawRanked(
        url: original_url,
        tag: "Master Yatak Odası",
        score: 94 - index,
        reason: "Konfor ve genişlik algısını pekiştiren ana dinlenme alanı.",
      )
    _ if has_terrace ->
      RawRanked(
        url: original_url,
        tag: "Güneşlenme Terası & Bahçe",
        score: 90 - index,
        reason: "Açık hava yaşam ve tatil deneyimini öne çıkaran müstakil alan.",
      )
    _ if has_kitchen ->
      RawRanked(
        url: original_url,
        tag: "Ada Mutfak & Ferah Salon",
        score: 86 - index,
        reason: "Ev konforunda tatil ve yaşam alanı sunumu.",
      )
    _ if has_bath ->
      RawRanked(
        url: original_url,
        tag: "Lüks Banyo & Jakuzi",
        score: 82 - index,
        reason: "Hijyen standartları ve lüks banyo konforu güvencesi.",
      )
    _ -> {
      let default_score = case 97 - index * 4 {
        s if s < 60 -> 60
        s -> s
      }
      let default_tag = case index {
        0 -> "Özel Havuz & Dış Cephe"
        1 -> "Master Yatak Odası"
        2 -> "Teras & Açık Alan"
        3 -> "Mutfak & Salon"
        4 -> "Banyo & Hijyen"
        _ -> "Tesis Detay Görünümü"
      }
      RawRanked(
        url: original_url,
        tag: default_tag,
        score: default_score,
        reason: "Yapay zeka hikaye kurgusuna göre optimize edilmiş vitrin açısı.",
      )
    }
  }
}

fn classify_hotel_photo(
  lower_url: String,
  original_url: String,
  index: Int,
) -> RawRanked {
  let has_facade =
    string.contains(lower_url, "facade")
    || string.contains(lower_url, "exterior")
    || string.contains(lower_url, "dis")
    || string.contains(lower_url, "lobby")
    || string.contains(lower_url, "lobi")
    || string.contains(lower_url, "giris")
    || string.contains(lower_url, "front")
    || string.contains(lower_url, "hero")

  let has_bed =
    string.contains(lower_url, "bed")
    || string.contains(lower_url, "yatak")
    || string.contains(lower_url, "oda")
    || string.contains(lower_url, "room")
    || string.contains(lower_url, "suite")
    || string.contains(lower_url, "suit")

  let has_pool_spa =
    string.contains(lower_url, "pool")
    || string.contains(lower_url, "havuz")
    || string.contains(lower_url, "spa")
    || string.contains(lower_url, "roof")
    || string.contains(lower_url, "wellness")

  let has_dining =
    string.contains(lower_url, "restaurant")
    || string.contains(lower_url, "restoran")
    || string.contains(lower_url, "kahvalti")
    || string.contains(lower_url, "breakfast")
    || string.contains(lower_url, "bar")

  let has_bath =
    string.contains(lower_url, "bath")
    || string.contains(lower_url, "banyo")
    || string.contains(lower_url, "shower")

  case True {
    _ if has_facade ->
      RawRanked(
        url: original_url,
        tag: "Dış Cephe & Prestijli Giriş",
        score: 99 - index,
        reason: "Otel misafirlerinin ilk izlenimini oluşturan prestijli vitrin pozu.",
      )
    _ if has_bed ->
      RawRanked(
        url: original_url,
        tag: "Lüks Süit & Konforlu Yatak",
        score: 95 - index,
        reason: "Rezervasyon kararında en etkili faktör olan oda konforu sunumu.",
      )
    _ if has_pool_spa ->
      RawRanked(
        url: original_url,
        tag: "Havuz & Spa Olanakları",
        score: 91 - index,
        reason: "Tesisin sunduğu lüks dinlenme ve aktivite imkânları.",
      )
    _ if has_dining ->
      RawRanked(
        url: original_url,
        tag: "Gurme Restoran & Açık Büfe",
        score: 87 - index,
        reason: "Zengin kahvaltı ve gastronomi deneyimi vurgusu.",
      )
    _ if has_bath ->
      RawRanked(
        url: original_url,
        tag: "Modern Banyo & Buklet",
        score: 83 - index,
        reason: "Yüksek hijyen ve donanım standartları güvencesi.",
      )
    _ -> {
      let default_score = case 98 - index * 4 {
        s if s < 60 -> 60
        s -> s
      }
      let default_tag = case index {
        0 -> "Dış Cephe & Lobi"
        1 -> "Lüks Süit Oda"
        2 -> "Havuz & Dinlenme Alanı"
        3 -> "Restoran & Kahvaltı"
        4 -> "Banyo & Hijyen"
        _ -> "Otel Olanakları & Detay"
      }
      RawRanked(
        url: original_url,
        tag: default_tag,
        score: default_score,
        reason: "Otelcilik standartlarına göre sıralanmış vitrin açısı.",
      )
    }
  }
}

fn classify_car_photo(
  lower_url: String,
  original_url: String,
  index: Int,
) -> RawRanked {
  let has_front =
    string.contains(lower_url, "front")
    || string.contains(lower_url, "on")
    || string.contains(lower_url, "hero")
    || string.contains(lower_url, "exterior")
    || string.contains(lower_url, "dis")

  let has_side =
    string.contains(lower_url, "side")
    || string.contains(lower_url, "yan")
    || string.contains(lower_url, "rim")
    || string.contains(lower_url, "jant")
    || string.contains(lower_url, "profil")

  let has_cockpit =
    string.contains(lower_url, "cockpit")
    || string.contains(lower_url, "kokpit")
    || string.contains(lower_url, "steering")
    || string.contains(lower_url, "wheel")
    || string.contains(lower_url, "direksiyon")
    || string.contains(lower_url, "dash")
    || string.contains(lower_url, "ekran")

  let has_seats =
    string.contains(lower_url, "seat")
    || string.contains(lower_url, "koltuk")
    || string.contains(lower_url, "interior")
    || string.contains(lower_url, "ic")

  let has_trunk =
    string.contains(lower_url, "trunk")
    || string.contains(lower_url, "bagaj")
    || string.contains(lower_url, "luggage")
    || string.contains(lower_url, "rear")
    || string.contains(lower_url, "arka")

  case True {
    _ if has_front ->
      RawRanked(
        url: original_url,
        tag: "Ön 3/4 Açı Dinamik Görünüm",
        score: 99 - index,
        reason: "Rent a car platformlarında en yüksek kiralama dönüşümü sağlayan ana açı.",
      )
    _ if has_side ->
      RawRanked(
        url: original_url,
        tag: "Yan Profil & Alaşımlı Jantlar",
        score: 94 - index,
        reason: "Gövde formu ve estetik tasarımı sergileyen yan görünüm.",
      )
    _ if has_cockpit ->
      RawRanked(
        url: original_url,
        tag: "Dijital Kokpit & Direksiyon",
        score: 90 - index,
        reason: "Sürüş konforu, multimedya ve teknolojik donanım detayı.",
      )
    _ if has_seats ->
      RawRanked(
        url: original_url,
        tag: "Deri Koltuklar & İç Hacim",
        score: 85 - index,
        reason: "Yolcu konforu ve temiz ferah iç mekan algısı.",
      )
    _ if has_trunk ->
      RawRanked(
        url: original_url,
        tag: "Geniş Bagaj Hacmi",
        score: 81 - index,
        reason: "Havalimanı ve tatil valizleri için pratik kullanım güvencesi.",
      )
    _ -> {
      let default_score = case 98 - index * 4 {
        s if s < 60 -> 60
        s -> s
      }
      let default_tag = case index {
        0 -> "Ön 3/4 Dış Görünüm"
        1 -> "Yan Profil"
        2 -> "Kokpit & Ekran"
        3 -> "İç Mekan & Koltuklar"
        4 -> "Bagaj Hacmi"
        _ -> "Araç Donanım Detayı"
      }
      RawRanked(
        url: original_url,
        tag: default_tag,
        score: default_score,
        reason: "Araç kiralama standartlarına göre optimize edilmiş açı.",
      )
    }
  }
}

// ─── AI Pricing Research & Competitor Analysis Engine ─────

pub type PricingVerdict {
  Underpriced
  Overpriced
  Competitive
  Optimal
  InsufficientData
}

pub type PricingAnalysis {
  PricingAnalysis(
    comparable_count: Int,
    avg_price: Int,
    min_price: Int,
    max_price: Int,
    median_price: Int,
    recommended_min: Int,
    recommended_max: Int,
    optimal_price: Int,
    confidence_pct: Int,
    verdict: PricingVerdict,
    reasoning: String,
  )
}

pub fn verdict_to_string(v: PricingVerdict) -> String {
  case v {
    Underpriced -> "underpriced"
    Overpriced -> "overpriced"
    Competitive -> "competitive"
    Optimal -> "optimal"
    InsufficientData -> "insufficient_data"
  }
}

pub fn verdict_label(v: PricingVerdict) -> String {
  case v {
    Underpriced -> "Düşük Fiyatlı"
    Overpriced -> "Yüksek Fiyatlı"
    Competitive -> "Rekabetçi"
    Optimal -> "Optimal"
    InsufficientData -> "Yetersiz Veri"
  }
}

pub fn verdict_description(v: PricingVerdict, category: String) -> String {
  let cat_label = case category {
    "hotel" -> "otel"
    "villa" -> "villa"
    "car" -> "araç kiralama"
    "yacht" -> "yat"
    "transfer" -> "transfer"
    "tour" -> "tur"
    _ -> "ilan"
  }
  case v {
    Underpriced ->
      "Mevcut fiyatınız, benzer "
      <> cat_label
      <> " ilanlarının ortalamasının önemli ölçüde altında. "
      <> "Gelirinizi artırmak için fiyatı AI'ın önerdiği aralığa yükseltmeniz tavsiye edilir. "
      <> "Düşük fiyat, kalite algısını olumsuz etkileyebilir ve müşteri beklentilerini düşürebilir."
    Overpriced ->
      "Mevcut fiyatınız, emsal "
      <> cat_label
      <> " ilanlarının ortalamasının üzerinde. "
      <> "Yüksek fiyat, dönüşüm oranını düşürebilir ve potansiyel müşterileri rakiplere yönlendirebilir. "
      <> "AI'ın önerdiği aralığa göre fiyat düzenlemeniz önerilir."
    Competitive ->
      "Mevcut fiyatınız, piyasadaki emsal "
      <> cat_label
      <> " ilanlarıyla rekabetçi bir seviyede. "
      <> "Bu fiyat aralığında kalmaya devam ederek sağlıklı bir doluluk/dönüşüm oranı sürdürebilirsiniz."
    Optimal ->
      "Tebrikler! Fiyatınız, emsal "
      <> cat_label
      <> " ilanlarının medyanına çok yakın ve optimal seviyede. "
      <> "Bu fiyat seviyesi hem rekabetçiliği hem de kârlılığı en iyi şekilde dengeler."
    InsufficientData ->
      "Yeterli sayıda emsal "
      <> cat_label
      <> " ilanı bulunamadı. "
      <> "Daha doğru bir analiz için en az 3 benzer ilan gereklidir. "
      <> "Sistem daha fazla veri topladıkça analizler daha güvenilir hale gelecektir."
  }
}

/// Emsal fiyat istatistiklerinden kapsamlı analiz üretir
pub fn generate_pricing_analysis(
  category: String,
  target_price: Int,
  comparable_count: Int,
  avg_price: Int,
  min_price: Int,
  max_price: Int,
  median_price: Int,
) -> PricingAnalysis {
  // Yetersiz veri kontrolü
  case comparable_count < 3 {
    True ->
      PricingAnalysis(
        comparable_count: comparable_count,
        avg_price: avg_price,
        min_price: min_price,
        max_price: max_price,
        median_price: median_price,
        recommended_min: case target_price > 0 {
          True -> target_price * 85 / 100
          False -> 0
        },
        recommended_max: case target_price > 0 {
          True -> target_price * 115 / 100
          False -> 0
        },
        optimal_price: target_price,
        confidence_pct: case comparable_count {
          0 -> 0
          1 -> 15
          _ -> 30
        },
        verdict: InsufficientData,
        reasoning: verdict_description(InsufficientData, category),
      )
    False -> {
      // Kâr marjı korumalı optimal fiyat hesaplama
      let sweet_spot = { median_price * 60 + avg_price * 40 } / 100

      // Önerilen aralık: median etrafında ±%15
      let rec_min = median_price * 85 / 100
      let rec_max = median_price * 120 / 100

      // Optimal fiyat: sweet_spot'u sınırlar içinde tut
      let optimal = case True {
        _ if sweet_spot < rec_min -> rec_min
        _ if sweet_spot > rec_max -> rec_max
        _ -> sweet_spot
      }

      // Fark yüzdesi hesapla
      let diff_pct = case median_price > 0 {
        True -> { target_price - median_price } * 100 / median_price
        False -> 0
      }

      // Verdict (karar) belirleme
      let verdict = case True {
        _ if diff_pct < -20 -> Underpriced
        _ if diff_pct > 25 -> Overpriced
        _ if diff_pct >= -5 && diff_pct <= 5 -> Optimal
        _ -> Competitive
      }

      // Güven skoru: emsal sayısına bağlı
      let confidence = case True {
        _ if comparable_count >= 15 -> 95
        _ if comparable_count >= 10 -> 85
        _ if comparable_count >= 7 -> 75
        _ if comparable_count >= 5 -> 65
        _ -> 50
      }

      // Detaylı reasoning
      let diff_direction = case diff_pct >= 0 {
        True -> "%" <> int.to_string(diff_pct) <> " üzerinde"
        False ->
          "%" <> int.to_string(int.absolute_value(diff_pct)) <> " altında"
      }

      let price_context =
        "Mevcut gecelik fiyatınız, emsal ilanların medyan fiyatının "
        <> diff_direction
        <> ". "
        <> int.to_string(comparable_count)
        <> " adet benzer ilan analiz edildi. "

      let reasoning = price_context <> verdict_description(verdict, category)

      PricingAnalysis(
        comparable_count: comparable_count,
        avg_price: avg_price,
        min_price: min_price,
        max_price: max_price,
        median_price: median_price,
        recommended_min: rec_min,
        recommended_max: rec_max,
        optimal_price: optimal,
        confidence_pct: confidence,
        verdict: verdict,
        reasoning: reasoning,
      )
    }
  }
}

// ─── Kurumsal AI Modülleri ────────────────────────────

/// Sosyal Medya Gönderi ve Kampanya Metni Üretici
pub fn generate_social_post_copy(
  property_title: String,
  category: String,
  promo_discount: String,
  tone: String,
) -> String {
  let discount_text = case promo_discount {
    "" | "0" -> "Özel sezon avantajlarıyla!"
    _ -> "Sınırlı süre için %" <> promo_discount <> " indirim fırsatıyla!"
  }

  let cat_hashtag = case category {
    "villa" -> "#VillaTatili #LuksVilla #KiralikVilla"
    "hotel" -> "#OtelRezervasyon #ButikOtel #TatilKeyfi"
    "gulet" -> "#MaviTur #YatKiralama #GuletCruise"
    _ -> "#TatilZamani #Seyahat #NexusTravel"
  }

  case tone {
    "energetic" ->
      "Unutulmaz bir kaçamak zamanı! "
      <> property_title
      <> " sizi bekliyor. "
      <> discount_text
      <> " Rezervasyonunuzu hemen yaptırın, en iyi fiyat garantisini yakalayın!\n\nProfildeki linkten inceleyin ve hemen ayırtın!\n\n"
      <> cat_hashtag
      <> " #NexusTravelTech #ErkenRezervasyon"
    "luxury" ->
      "Ayrıcalıklı bir konaklama deneyimi: "
      <> property_title
      <> ".\n\n"
      <> "Eşsiz konfor, seçkin detaylar ve huzur dolu anlar sizleri bekliyor. "
      <> discount_text
      <> "\n\nDoğrudan rezervasyon avantajı ve özel VIP hizmetlerle tanışın.\n\n"
      <> cat_hashtag
      <> " #LuxuryTravel #ExclusiveStay #TravelTurkey"
    _ ->
      "Harika bir tatil fırsatı: "
      <> property_title
      <> "!\n\n"
      <> "Konforlu alanları ve merkezi konumuyla mükemmel bir deneyim vadediyor. "
      <> discount_text
      <> "\n\nDetaylı bilgi ve hızlı rezervasyon için bağlantıya tıklayın.\n\n"
      <> cat_hashtag
      <> " #Tatil #GeziRehberi"
  }
}

/// İlan için Akıllı SEO Başlık ve Açıklama Sihirbazı
pub fn generate_listing_seo_copy(
  title: String,
  category: String,
  locality: String,
  amenities: String,
) -> #(String, String) {
  let clean_loc = case locality {
    "" -> "Türkiye"
    _ -> locality
  }
  let seo_title =
    title
    <> " | "
    <> clean_loc
    <> " "
    <> case category {
      "villa" -> "Kiralık Lüks Villa"
      "hotel" -> "Otel & Konaklama"
      "gulet" -> "Mavi Yolculuk & Yat"
      _ -> "Rezervasyon & Tatil"
    }
    <> " - NEXUS"

  let seo_desc =
    clean_loc
    <> " bölgesinde yer alan "
    <> title
    <> "; "
    <> case amenities {
      "" -> "lüks olanakları ve benzersiz manzarasıyla "
      _ -> amenities <> " gibi zengin olanaklarıyla "
    }
    <> "kusursuz bir konaklama deneyimi sunuyor. En uygun fiyat ve doğrudan rezervasyon garantisiyle yerinizi hemen ayırtın."

  #(seo_title, seo_desc)
}

/// Misafir Yorumu Akıllı Yanıt Üretici
pub fn generate_guest_review_reply(
  guest_name: String,
  rating: String,
  comment: String,
) -> String {
  let greeting =
    "Sayın "
    <> case guest_name {
      "" -> "Misafirimiz"
      _ -> guest_name
    }
    <> ","

  case rating {
    "5" | "4" ->
      greeting
      <> "\n\nDeğerli vaktinizi ayırıp güzel geri bildiriminizi paylaştığınız için içtenlikle teşekkür ederiz. '"
      <> comment
      <> "' şeklindeki nazik değerlendirmeniz tüm ekibimizi son derece mutlu etti. Sizleri ve sevdiklerinizi bir sonraki tatilinizde tesisimizde yeniden ağırlamaktan büyük onur duyarız.\n\nSaygılarımızla,\nTesis Yönetimi"
    _ ->
      greeting
      <> "\n\nTesisimizde konakladığınız süre boyunca edindiğiniz deneyimleri bizimle paylaştığınız için teşekkür ederiz. Belirttiğiniz hususları ('"
      <> comment
      <> "') operasyon ekibimiz ve departman yöneticilerimizle derhal ele aldık. Hizmet kalitemizi sürekli geliştirmek en temel önceliğimizdir. Bir sonraki seyahatinizde beklentilerinizi tam olarak karşılayacak bir deneyim yaşatmak adına sizi tekrar ağırlamayı arzu ederiz.\n\nSaygılarımızla,\nTesis Yönetimi"
  }
}

/// Talep ve Doluluk Tahminleyici
pub fn generate_demand_forecast(
  category: String,
  locality: String,
  occupancy_pct: Int,
) -> #(String, String, Int) {
  let demand_level = case occupancy_pct {
    _ if occupancy_pct >= 85 -> "Çok Yüksek Talep (High Season Peak)"
    _ if occupancy_pct >= 65 -> "Yüksek & İstikrarlı Talep"
    _ if occupancy_pct >= 40 -> "Dengeli Sezon Talebi"
    _ -> "Düşük Talep Dönemi (Promosyon Önerilir)"
  }

  let strategy = case occupancy_pct {
    _ if occupancy_pct >= 85 ->
      locality
      <> " genelinde "
      <> category
      <> " kategorisinde doluluk %85 üzerine ulaştı. Kalan son odalar/günler için fiyat artışı (%10-15) ve minimum konaklama süresi kuralı (min 3 gece) önerilir."
    _ if occupancy_pct >= 65 ->
      "Doluluk oranı ideal kâr marjı seviyesindedir. Fiyat paritesini koruyarak erken rezervasyon avantajlarını sürdürmeniz tavsiye edilir."
    _ if occupancy_pct >= 40 ->
      "Hafta içi doluluklarını desteklemek için 'Hafta İçi Kaçamağı' veya 'Son Dakika %15 İndirim' kampanyası başlatılması önerilir."
    _ ->
      "Dönemsel talep durgunluğu tespit edildi. Fiyatları emsal medyanına çekip dinamik promosyon kodları ile görünürlüğü artırmanız önerilir."
  }

  let suggested_adjustment = case occupancy_pct {
    _ if occupancy_pct >= 85 -> 15
    _ if occupancy_pct >= 65 -> 5
    _ if occupancy_pct >= 40 -> 0
    _ -> -15
  }

  #(demand_level, strategy, suggested_adjustment)
}
