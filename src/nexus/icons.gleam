import lustre/attribute as a
import lustre/element.{type Element}

fn svg_icon(class: String, elements: List(Element(Nil))) -> Element(Nil) {
  element.element(
    "svg",
    [
      a.attribute("viewBox", "0 0 24 24"),
      a.attribute("fill", "none"),
      a.attribute("stroke", "currentColor"),
      a.attribute("stroke-width", "1.65"),
      a.attribute("stroke-linecap", "round"),
      a.attribute("stroke-linejoin", "round"),
      a.class("huge-icon " <> class),
    ],
    elements,
  )
}

fn path(d: String) -> Element(Nil) {
  element.element("path", [a.attribute("d", d)], [])
}

fn circle(cx: String, cy: String, r: String) -> Element(Nil) {
  element.element(
    "circle",
    [a.attribute("cx", cx), a.attribute("cy", cy), a.attribute("r", r)],
    [],
  )
}

fn rect(
  x: String,
  y: String,
  width: String,
  height: String,
  rx: String,
) -> Element(Nil) {
  element.element(
    "rect",
    [
      a.attribute("x", x),
      a.attribute("y", y),
      a.attribute("width", width),
      a.attribute("height", height),
      a.attribute("rx", rx),
    ],
    [],
  )
}

fn polyline(points: String) -> Element(Nil) {
  element.element("polyline", [a.attribute("points", points)], [])
}

// ─── NAVBAR TRIGGERS (HUGEICONS) ───

// Building02Icon - Kurumsal
pub fn corporate() -> Element(Nil) {
  svg_icon("huge-corporate", [
    path("M15 2H9C5.69067 2 5 2.69067 5 6V22H19V6C19 2.69067 18.3093 2 15 2Z"),
    path("M3 22H21"),
    path(
      "M15 22V19C15 17.3453 14.6547 17 13 17H11C9.34533 17 9 17.3453 9 19V22",
    ),
    path("M13.5 6H10.5M13.5 9.5H10.5M13.5 13H10.5"),
  ])
}

// LayoutGridIcon - Kategoriler
pub fn categories() -> Element(Nil) {
  svg_icon("huge-categories", [
    path(
      "M20.1088 3.89124C21.5 5.28249 21.5 7.52166 21.5 12C21.5 16.4783 21.5 18.7175 20.1088 20.1088C18.7175 21.5 16.4783 21.5 12 21.5C7.52166 21.5 5.28249 21.5 3.89124 20.1088C2.5 18.7175 2.5 16.4783 2.5 12C2.5 7.52166 2.5 5.28249 3.89124 3.89124C5.28249 2.5 7.52166 2.5 12 2.5C16.4783 2.5 18.7175 2.5 20.1088 3.89124Z",
    ),
    path("M21.5 12L2.5 12"),
    path("M12 2.5L12 21.5"),
  ])
}

// Layers01Icon - Modüller
pub fn modules() -> Element(Nil) {
  svg_icon("huge-modules", [
    path(
      "M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z",
    ),
    path("m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"),
    path("m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"),
  ])
}

// GlobeIcon - Dil Seçimi
pub fn globe() -> Element(Nil) {
  svg_icon("huge-globe", [
    circle("12", "12", "9.5"),
    path(
      "M12 2.5C14.5 6 15.5 9 15.5 12C15.5 15 14.5 18 12 21.5C9.5 18 8.5 15 8.5 12C8.5 9 9.5 6 12 2.5Z",
    ),
    path("M2.8 9.5H21.2M2.8 14.5H21.2"),
  ])
}

// UserCircleIcon - Giriş / Üye Ol
pub fn user() -> Element(Nil) {
  svg_icon("huge-user", [
    path(
      "M18.4984 19.1511C17.3377 17.4018 15.2947 16.2009 12.9313 16.0569L11.9984 16C11.6652 16.0083 11.3547 16.0194 11.0617 16.0325C8.71722 16.1376 6.66598 17.3796 5.5 19.1511",
    ),
    path(
      "M14.9961 10C14.9961 11.6569 13.6529 13 11.9961 13C10.3392 13 8.99609 11.6569 8.99609 10C8.99609 8.34315 10.3392 7 11.9961 7C13.6529 7 14.9961 8.34315 14.9961 10Z",
    ),
    path(
      "M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12Z",
    ),
  ])
}

// Key01Icon - Panoya Giriş
pub fn key() -> Element(Nil) {
  svg_icon("huge-key", [
    path(
      "M15.5 14.5C18.8137 14.5 21.5 11.8137 21.5 8.5C21.5 5.18629 18.8137 2.5 15.5 2.5C12.1863 2.5 9.5 5.18629 9.5 8.5C9.5 9.38041 9.68962 10.2165 10.0303 10.9697L2.5 18.5V21.5H5.5V19.5H7.5V17.5H9.5L13.0303 13.9697C13.7835 14.3104 14.6196 14.5 15.5 14.5Z",
    ),
    path("M17.5 6.5L16.5 7.5"),
  ])
}

// ArrowUpRight01Icon - Dış Link ↗
pub fn arrow_up_right() -> Element(Nil) {
  svg_icon("huge-arrow", [
    path(
      "M9 6.65032C9 6.65032 15.9383 6.10759 16.9154 7.08463C17.8924 8.06167 17.3496 15 17.3496 15M16.5 7.5L6.5 17.5",
    ),
  ])
}

// ─── TOURISM PRODUCT CATEGORIES (HUGEICONS) ───

// Building05Icon - Otel & Konaklama
pub fn hotel() -> Element(Nil) {
  svg_icon("huge-hotel", [
    path("M2 22H22"),
    path("M18 9H14C11.518 9 11 9.518 11 12V22H21V12C21 9.518 20.482 9 18 9Z"),
    path("M15 22H3V5C3 2.518 3.518 2 6 2H12C14.482 2 15 2.518 15 5V9"),
    path("M3 6H6M3 10H6M3 14H6"),
    path("M15 13H17M15 16H17"),
    path("M16 22L16 19"),
  ])
}

// Home01Icon - Villa & Tatil Evi
pub fn villa() -> Element(Nil) {
  svg_icon("huge-villa", [
    path(
      "M3 11.9896V14.5C3 17.7998 3 19.4497 4.02513 20.4749C5.05025 21.5 6.70017 21.5 10 21.5H14C17.2998 21.5 18.9497 21.5 19.9749 20.4749C21 19.4497 21 17.7998 21 14.5V11.9896C21 10.3083 21 9.46773 20.6441 8.74005C20.2882 8.01237 19.6247 7.49628 18.2976 6.46411L16.2976 4.90855C14.2331 3.30285 13.2009 2.5 12 2.5C10.7991 2.5 9.76689 3.30285 7.70242 4.90855L5.70241 6.46411C4.37533 7.49628 3.71179 8.01237 3.3559 8.74005C3 9.46773 3 10.3083 3 11.9896Z",
    ),
  ])
}

// Compass01Icon - Tur & Deneyim
pub fn tour() -> Element(Nil) {
  svg_icon("huge-tour", [
    path("M10 10L5 22M14 10L19 22"),
    path("M12 4L12 2"),
    circle("12", "7", "3"),
    path(
      "M3 13C4.99073 16.0242 8.27968 18 12 18C15.7203 18 19.0093 16.0242 21 13",
    ),
    path("M12 17V19"),
  ])
}

// Activity01Icon - Aktivite & Macera
pub fn activity() -> Element(Nil) {
  svg_icon("huge-activity", [
    path(
      "M4.31802 19.682C3 18.364 3 16.2426 3 12C3 7.75736 3 5.63604 4.31802 4.31802C5.63604 3 7.75736 3 12 3C16.2426 3 18.364 3 19.682 4.31802C21 5.63604 21 7.75736 21 12C21 16.2426 21 18.364 19.682 19.682C18.364 21 16.2426 21 12 21C7.75736 21 5.63604 21 4.31802 19.682Z",
    ),
    path(
      "M7 14L9.79289 11.2071C10.1834 10.8166 10.8166 10.8166 11.2071 11.2071L12.7929 12.7929C13.1834 13.1834 13.8166 13.1834 14.2071 12.7929L17 10",
    ),
  ])
}

// BoatIcon - Yat & Marina
pub fn yacht() -> Element(Nil) {
  svg_icon("huge-yacht", [
    path(
      "M2 21.1932C2.68524 22.2443 3.57104 22.2443 4.27299 21.1932C6.52985 17.7408 8.67954 23.6764 10.273 21.2321C12.703 17.5694 14.4508 23.9218 16.273 21.1932C18.6492 17.5582 20.1295 23.5776 22 21.5842",
    ),
    path(
      "M3.57228 17L2.07481 12.6457C1.80373 11.8574 2.30283 11 3.03273 11H20.8582C23.9522 11 19.9943 17 17.9966 17",
    ),
    path(
      "M18 11L15.201 7.50122C14.4419 6.55236 13.2926 6 12.0775 6H8C6.89543 6 6 6.89543 6 8V11",
    ),
    path("M10 6V3C10 2.44772 9.55228 2 9 2H8"),
  ])
}

// Bus01Icon - VIP Transfer
pub fn transfer() -> Element(Nil) {
  svg_icon("huge-transfer", [
    path("M17 20.5V22"),
    path("M7 20.5V22"),
    path(
      "M4 6.78186C4 6.14251 4 5.82283 4.17387 5.43355C4.34773 5.04428 4.52427 4.88606 4.87736 4.56964C6.03437 3.53277 8.36029 2 12 2C15.6397 2 17.9656 3.53277 19.1226 4.56964C19.4757 4.88606 19.6523 5.04428 19.8261 5.43355C20 5.82283 20 6.14251 20 6.78186V14C20 16.8284 20 18.2426 19.1213 19.1213C18.2426 20 16.8284 20 14 20H10C7.17157 20 5.75736 20 4.87868 19.1213C4 18.2426 4 16.8284 4 14V6.78186Z",
    ),
    path("M4 14C4 14 7.73333 15 12 15C16.2667 15 20 14 20 14"),
    path("M4.5 17.5H6"),
    path("M18 17.5H19.5"),
    path("M11 17.5L13 17.5"),
    path("M4 6H20"),
  ])
}

// Car01Icon - Araç Kiralama
pub fn car() -> Element(Nil) {
  svg_icon("huge-car", [
    circle("6.5", "15.5", "1.5"),
    circle("17.5", "15.5", "1.5"),
    path(
      "M8 17.5L8.24567 16.8858C8.61101 15.9725 8.79368 15.5158 9.17461 15.2579C9.55553 15 10.0474 15 11.0311 15H12.9689C13.9526 15 14.4445 15 14.8254 15.2579C15.2063 15.5158 15.389 15.9725 15.7543 16.8858L16 17.5",
    ),
    path(
      "M4.5 9L5.5883 5.73509C6.02832 4.41505 6.24832 3.75503 6.7721 3.37752C7.29587 3 7.99159 3 9.38304 3H14.617C16.0084 3 16.7041 3 17.2279 3.37752C17.7517 3.75503 17.9717 4.41505 18.4117 5.73509L19.5 9",
    ),
    path(
      "M4.5 9H19.5C20.4572 10.0135 22 11.4249 22 12.9996V16.4702C22 17.0407 21.6205 17.5208 21.1168 17.5875L18 18H6L2.88316 17.5875C2.37955 17.5208 2 17.0407 2 16.4702V12.9996C2 11.4249 3.54279 10.0135 4.5 9Z",
    ),
  ])
}

// Sun01Icon - Plaj & Beach Club
pub fn beach() -> Element(Nil) {
  svg_icon("huge-beach", [
    path(
      "M16.9991 12C16.9991 14.7614 14.7605 17 11.9991 17C9.23766 17 6.99908 14.7614 6.99908 12C6.99908 9.23858 9.23766 7 11.9991 7C14.7605 7 16.9991 9.23858 16.9991 12Z",
    ),
    path(
      "M12 3v1.5M12 19.5v1.5M21 12h-1.5M4.5 12H3M18.36 5.64l-1.06 1.06M6.7 17.3l-1.06 1.06M17.3 17.3l1.06 1.06M5.64 5.64l1.06 1.06",
    ),
  ])
}

// Flight / Airplane - Uçak & Bilet
pub fn flight() -> Element(Nil) {
  svg_icon("huge-flight", [
    path(
      "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z",
    ),
  ])
}

// Bus - Otobüs
pub fn bus() -> Element(Nil) {
  svg_icon("huge-bus", [
    rect("4", "3", "16", "16", "2"),
    path("M4 11h16"),
    path("M8 15h.01M16 15h.01"),
    path("M6 19v2M18 19v2"),
  ])
}

// Ticket - Etkinlik & Bilet
pub fn ticket() -> Element(Nil) {
  svg_icon("huge-ticket", [
    path(
      "M2 9a3 3 0 0 1 0 6v3a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-3a3 3 0 0 1 0-6V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v3z",
    ),
    path("M13 5v2M13 11v2M13 17v2"),
  ])
}

// Cinema - Film & Sinema
pub fn cinema() -> Element(Nil) {
  svg_icon("huge-cinema", [
    rect("2", "3", "20", "18", "2"),
    path("M7 3v18M17 3v18M2 8h5M2 13h5M2 18h5M17 8h5M17 13h5M17 18h5"),
  ])
}

// Ferry / Ship - Feribot & Kruvaziyer
pub fn ferry() -> Element(Nil) {
  svg_icon("huge-ferry", [
    path("M4 18l1.5 3h13L20 18H4z"),
    path("M6 14h12l1 4H5l1-4z"),
    path("M8 10h8v4H8z"),
    path("M10 6h4v4h-4z"),
  ])
}

// Spa - Wellness & Sağlık
pub fn spa() -> Element(Nil) {
  svg_icon("huge-spa", [
    path("M12 2C9 7 4 9 4 14a8 8 0 0 0 16 0c0-5-5-7-8-12z"),
    path("M12 12c-2 2-2 4 0 6"),
  ])
}

// Package - Dinamik Paket
pub fn package() -> Element(Nil) {
  svg_icon("huge-package", [
    path("M12 2l9 4.9v9.8L12 22l-9-5.3V6.9L12 2z"),
    path("M12 12l9-4.9M12 12v10M12 12L3 7.1"),
  ])
}

// Hajj / Umrah - İnanç & Kültür
pub fn hajj() -> Element(Nil) {
  svg_icon("huge-hajj", [
    path("M12 3v18M3 12h18"),
    path("M6 6l12 12M18 6L6 18"),
  ])
}

// ─── OPERATIONAL MODULES (HUGEICONS) ───

// ComputerIcon - Ön Büro (PMS)
pub fn pms() -> Element(Nil) {
  svg_icon("huge-pms", [
    path(
      "M14 21H16M14 21C13.1716 21 12.5 20.3284 12.5 19.5V17L12 17M14 21H10M10 21H8M10 21C10.8284 21 11.5 20.3284 11.5 19.5V17L12 17M12 17V21",
    ),
    path(
      "M16 3H8C5.17157 3 3.75736 3 2.87868 3.87868C2 4.75736 2 6.17157 2 9V11C2 13.8284 2 15.2426 2.87868 16.1213C3.75736 17 5.17157 17 8 17H16C18.8284 17 20.2426 17 21.1213 16.1213C22 15.2426 22 13.8284 22 11V9C22 6.17157 22 4.75736 21.1213 3.87868C20.2426 3 18.8284 3 16 3Z",
    ),
  ])
}

// RefreshIcon - Kanal Yöneticisi
pub fn channel_manager() -> Element(Nil) {
  svg_icon("huge-channel", [
    path(
      "M20.0092 2V5.13219C20.0092 5.42605 19.6418 5.55908 19.4537 5.33333C17.6226 3.2875 14.9617 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22C17.5228 22 22 17.5228 22 12",
    ),
    path("M17 2v3.5h3.5"),
  ])
}

// ShieldCheckIcon - KBS Kimlik Bildirimi
pub fn kbs() -> Element(Nil) {
  svg_icon("huge-kbs", [
    path(
      "M20.9922 11.1833V8.28029C20.9922 6.64029 20.9922 5.82028 20.5881 5.28529C20.184 4.75029 19.2703 4.49056 17.4429 3.9711C16.1944 3.6162 15.0938 3.18863 14.2145 2.79829C13.0156 2.2661 12.4161 2 11.9922 2C11.5682 2 10.9688 2.2661 9.7699 2.79829C8.89057 3.18863 7.79002 3.61619 6.54152 3.9711C4.71411 4.49056 3.80041 4.75029 3.3963 5.28529C2.99219 5.82028 2.99219 6.64029 2.99219 8.28029V11.1833C2.99219 16.8085 8.05496 20.1835 10.5861 21.5194C11.1932 21.8398 11.4968 22 11.9922 22C12.4876 22 12.7911 21.8398 13.3982 21.5194C15.9294 20.1835 20.9922 16.8085 20.9922 11.1833Z",
    ),
    path(
      "M8.49219 11.8333C8.49219 11.8333 9.36719 11.8333 10.2422 13.5C10.2422 13.5 13.0216 9.33333 15.4922 8.5",
    ),
  ])
}

// AiSparklesIcon - Dinamik Fiyatlama AI
pub fn dynamic_pricing() -> Element(Nil) {
  svg_icon("huge-pricing", [
    path(
      "M11.9826 10.879L13.5745 11.4096C14.1418 11.5987 14.1418 12.4013 13.5745 12.5904L11.9826 13.121C10.8676 13.4927 9.99268 14.3676 9.62102 15.4826L9.0904 17.0745C8.90127 17.6418 8.09873 17.6418 7.9096 17.0745L7.37898 15.4826C7.00732 14.3676 6.13239 13.4927 5.0174 13.121L3.42553 12.5904C2.85815 12.4013 2.85816 11.5987 3.42553 11.4096L5.0174 10.879C6.13239 10.5073 7.00732 9.63239 7.37898 8.5174L7.9096 6.92553C8.09873 6.35815 8.90127 6.35816 9.0904 6.92553L9.62102 8.5174C9.99268 9.63239 10.8676 10.5073 11.9826 10.879Z",
    ),
    path(
      "M18.083 4.99045L18.8066 5.23164C19.0645 5.3176 19.0645 5.6824 18.8066 5.76836L18.083 6.00955C17.5762 6.17849 17.1785 6.57619 17.0096 7.083L16.7684 7.80658C16.6824 8.06448 16.3176 8.06447 16.2316 7.80658L15.9904 7.083C15.8215 6.57619 15.4238 6.17849 14.917 6.00955L14.1934 5.76836C13.9355 5.6824 13.9355 5.3176 14.1934 5.23164L14.917 4.99045C15.4238 4.82151 15.8215 4.42381 15.9904 3.917L16.2316 3.19342C16.3176 2.93552 16.6824 2.93553 16.7684 3.19342L17.0096 3.917C17.1785 4.42381 17.5762 4.82151 18.083 4.99045Z",
    ),
  ])
}

// CreditCardIcon - Muhasebe & Cari
pub fn accounting() -> Element(Nil) {
  svg_icon("huge-accounting", [
    path(
      "M2 12C2 8.46252 2 6.69377 3.0528 5.5129C3.22119 5.32403 3.40678 5.14935 3.60746 4.99087C4.86213 4 6.74142 4 10.5 4H13.5C17.2586 4 19.1379 4 20.3925 4.99087C20.5932 5.14935 20.7788 5.32403 20.9472 5.5129C22 6.69377 22 8.46252 22 12C22 15.5375 22 17.3062 20.9472 18.4871C20.7788 18.676 20.5932 18.8506 20.3925 19.0091C19.1379 20 17.2586 20 13.5 20H10.5C6.74142 20 4.86213 20 3.60746 19.0091C3.40678 18.8506 3.22119 18.676 3.0528 18.4871C2 17.3062 2 15.5375 2 12Z",
    ),
    path("M10 16H11.5"),
    path("M14.5 16L18 16"),
    path("M2 9H22"),
  ])
}

// RestaurantIcon - Restoran & POS
pub fn pos() -> Element(Nil) {
  svg_icon("huge-pos", [
    path(
      "M4 7L9.31672 4.08345C10.6334 3.36115 11.2918 3 12 3C12.7082 3 13.3666 3.36115 14.6833 4.08345L20 7",
    ),
    path("M18 6V10M6 6V10"),
    path("M7 14H12M17 14H12M12 14V21M12 21H11M12 21H13"),
  ])
}

// Sparkles / Bed - Kat Hizmetleri
pub fn housekeeping() -> Element(Nil) {
  svg_icon("huge-housekeeping", [
    path("M12 3L13.5 8.5L19 10L13.5 11.5L12 17L10.5 11.5L5 10L10.5 8.5L12 3Z"),
    path(
      "M19 15L19.75 17.5L22 18L19.75 18.5L19 21L18.25 18.5L16 18L18.25 17.5L19 15Z",
    ),
  ])
}

// SmartPhone01Icon - Mobil Check-in
pub fn mobile_checkin() -> Element(Nil) {
  svg_icon("huge-mobile", [
    path(
      "M13.5 2H10.5C8.14298 2 6.96447 2 6.23223 2.73223C5.5 3.46447 5.5 4.64298 5.5 7V17C5.5 19.357 5.5 20.5355 6.23223 21.2678C6.96447 22 8.14298 22 10.5 22H13.5C15.857 22 17.0355 22 17.7678 21.2678C18.5 20.5355 18.5 19.357 18.5 17V7C18.5 4.64298 18.5 3.46447 17.7678 2.73223C17.0355 2 15.857 2 13.5 2Z",
    ),
    circle("12", "19", "0.8"),
  ])
}

// ─── SUB DROPDOWN ITEMS (KURUMSAL / KULLANICILAR) ───

// UserAdd01Icon - Üye Ol
pub fn user_add() -> Element(Nil) {
  svg_icon("huge-user-add", [
    path(
      "M3 20.5002C3.28417 16.8058 6.3 13.7193 10.0008 13.5379C10.3134 13.5226 10.6446 13.5097 11 13.5L11.995 13.5663C12.6939 13.6129 13.3665 13.7543 14 13.9777",
    ),
    path("M18 15.5V21.5M21 18.5L15 18.5"),
    circle("11", "6.5", "4"),
  ])
}

// Store / Building - Tedarikçi Girişi
pub fn supplier() -> Element(Nil) {
  svg_icon("huge-supplier", [
    path("M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"),
    path("M9 22V12h6v10"),
  ])
}

// Compass / Globe - Acente Girişi
pub fn agency() -> Element(Nil) {
  svg_icon("huge-agency", [
    circle("12", "12", "10"),
    path("m16.24 7.76-2.12 6.36-6.36 2.12 2.12-6.36Z"),
  ])
}

// FileText / Legal - Belge & İzinler
pub fn document() -> Element(Nil) {
  svg_icon("huge-doc", [
    path("M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"),
    path("M14 2v6h6"),
    path("M16 13H8M16 17H8M10 9H8"),
  ])
}

// Shield - Güvenlik
pub fn security() -> Element(Nil) {
  svg_icon("huge-security", [
    path("M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"),
  ])
}

// Blog - BookOpen
pub fn blog() -> Element(Nil) {
  svg_icon("huge-blog", [
    path("M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"),
    path("M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"),
  ])
}

// Sparkles - AI Magic
pub fn sparkles() -> Element(Nil) {
  svg_icon("huge-sparkles", [
    path("M12 3l1.5 5.5L19 10l-5.5 1.5L12 17l-1.5-5.5L5 10l5.5-1.5L12 3z"),
    path("M19 15l.75 2.5L22 18l-2.25.5L19 21l-.75-2.5L16 18l2.25-.5L19 15z"),
  ])
}

// Copy - Pano Kopyalama
pub fn copy() -> Element(Nil) {
  svg_icon("huge-copy", [
    path(
      "M8 7h9a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z",
    ),
    path("M16 3H5a2 2 0 0 0-2 2v11"),
  ])
}

// Star - Puan / Yıldız
pub fn star() -> Element(Nil) {
  svg_icon("huge-star", [
    path(
      "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z",
    ),
  ])
}

// Chat - Misafir Mesajı / Yorum
pub fn chat() -> Element(Nil) {
  svg_icon("huge-chat", [
    path(
      "M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z",
    ),
  ])
}

// Check - Başarılı / Onay
pub fn check() -> Element(Nil) {
  svg_icon("huge-check", [
    path("M20 6L9 17l-5-5"),
  ])
}

// TrendingUp - Yield & Fiyat Artışı
pub fn trending_up() -> Element(Nil) {
  svg_icon("huge-trending-up", [
    path("M23 6L13.5 15.5L8.5 10.5L1 18"),
    path("M17 6H23V12"),
  ])
}

// Filter - Filtreleme
pub fn filter() -> Element(Nil) {
  svg_icon("huge-filter", [
    path("M22 3H2L10 12.46V19L14 21V12.46L22 3Z"),
  ])
}

// WhatsApp - İletişim & Mesajlaşma
pub fn whatsapp() -> Element(Nil) {
  svg_icon("huge-whatsapp", [
    path(
      "M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z",
    ),
  ])
}

// Trash - Silme
pub fn trash() -> Element(Nil) {
  svg_icon("huge-trash", [
    path(
      "M3 6H21M19 6V20C19 21.1046 18.1046 22 17 22H7C5.89543 22 5 21.1046 5 20V6M8 6V4C8 2.89543 8.89543 2 10 2H14C15.1046 2 16 2.89543 16 4V6",
    ),
  ])
}

// Lock - Kapı PIN & Güvenlik
pub fn lock() -> Element(Nil) {
  svg_icon("huge-lock", [
    path(
      "M5 11H19C20.1046 11 21 11.8954 21 13V20C21 21.1046 20.1046 22 19 22H5C3.89543 22 3 21.1046 3 20V13C3 11.8954 3.89543 11 5 11Z",
    ),
    path("M7 11V7C7 4.23858 9.23858 2 12 2C14.7614 2 17 4.23858 17 7V11"),
  ])
}

// Share - Sosyal Medya Paylaşımı
pub fn share() -> Element(Nil) {
  svg_icon("huge-share", [
    circle("18", "5", "3"),
    circle("6", "12", "3"),
    circle("18", "19", "3"),
    path("M8.59 13.51L15.42 17.49M15.41 6.51L8.59 10.49"),
  ])
}

// Save - Kaydet (Disket)
pub fn save() -> Element(Nil) {
  svg_icon("huge-save", [
    path("M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"),
    path("M17 21v-8H7v8"),
    path("M7 3v5h8"),
  ])
}

// Briefcase - İşe Alım & Aday
pub fn briefcase() -> Element(Nil) {
  svg_icon("huge-briefcase", [
    rect("2", "7", "20", "14", "2"),
    path("M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"),
    path("M2 13a18.15 18.15 0 0 0 20 0"),
    path("M6 12v1M18 12v1"),
  ])
}

// Plus - Ekle / Yeni
pub fn plus() -> Element(Nil) {
  svg_icon("huge-plus", [
    path("M12 5v14M5 12h14"),
  ])
}

// Calendar - Takvim & Tarih
pub fn calendar() -> Element(Nil) {
  svg_icon("huge-calendar", [
    rect("3", "4", "18", "18", "2"),
    path("M16 2v4M8 2v4M3 10h18"),
  ])
}

// Search - Arama & Filtre
pub fn search() -> Element(Nil) {
  svg_icon("huge-search", [
    circle("11", "11", "8"),
    path("m21 21-4.35-4.35"),
  ])
}

// Edit - Düzenleme & Kalem
pub fn edit() -> Element(Nil) {
  svg_icon("huge-edit", [
    path("M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"),
    path("M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"),
  ])
}

// Image - Görsel & Fotoğraf
pub fn image() -> Element(Nil) {
  svg_icon("huge-image", [
    rect("3", "3", "18", "18", "2"),
    circle("8.5", "8.5", "1.5"),
    path("M21 15l-5-5L5 21"),
  ])
}

// Eye - Önizleme & Görüntüleme
pub fn eye() -> Element(Nil) {
  svg_icon("huge-eye", [
    path("M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"),
    circle("12", "12", "3"),
  ])
}

// Shopping - Satın Alma & Sepet
pub fn shopping() -> Element(Nil) {
  svg_icon("huge-shopping", [
    circle("9", "21", "1"),
    circle("20", "21", "1"),
    path("M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"),
  ])
}

// Tag - İndirim / Kupon Kodu
pub fn tag() -> Element(Nil) {
  svg_icon("huge-tag", [
    path(
      "M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z",
    ),
    path("M7 7h.01"),
  ])
}

// Warning - Uyarı & İkaz Üçgeni
pub fn warning() -> Element(Nil) {
  svg_icon("huge-warning", [
    path(
      "M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z",
    ),
    path("M12 9v4"),
    path("M12 17h.01"),
  ])
}

// Trending Down - Düşüş Trendi
pub fn trending_down() -> Element(Nil) {
  svg_icon("huge-trending-down", [
    path("M23 18l-9.5-9.5-5 5L1 6"),
    path("M17 18h6v-6"),
  ])
}

// Clock - Zaman & Saat & Gece Devri
pub fn clock() -> Element(Nil) {
  svg_icon("huge-clock", [
    circle("12", "12", "10"),
    polyline("12 6 12 12 16 14"),
  ])
}

// Category Icon Resolver - Tüm 18 Seyahat & Hizmet Kategorisi
pub fn for_category(cat: String) -> Element(Nil) {
  case cat {
    "hotel" -> hotel()
    "holiday_home" -> villa()
    "villa" -> villa()
    "tour" -> tour()
    "activity" -> activity()
    "event" -> ticket()
    "yacht" -> yacht()
    "beach" -> beach()
    "car" -> car()
    "transfer" -> transfer()
    "restaurant" -> pos()
    "cruise" -> ferry()
    "ferry" -> ferry()
    "flight" -> flight()
    "bus" -> bus()
    "cinema" -> cinema()
    "visa" -> document()
    "spa" -> spa()
    "package" -> package()
    "hajj" -> hajj()
    "umrah" -> hajj()
    "pilgrimage" -> hajj()
    _ -> categories()
  }
}
