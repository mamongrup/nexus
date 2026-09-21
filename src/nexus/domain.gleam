import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type Property {
  Property(
    id: String,
    title: String,
    locality: String,
    description: String,
    capacity: Int,
    nightly_minor: Int,
    currency: String,
    status: String,
    version: Int,
    moderation_status: String,
    review_note: String,
    freshness: String,
  )
}

pub type Session {
  Session(
    tenant: String,
    user_id: String,
    name: String,
    role: String,
    workspace: String,
  )
}

pub type Draft {
  Draft(
    title: String,
    locality: String,
    description: String,
    capacity: Int,
    nightly_minor: Int,
    currency: String,
  )
}

pub fn minor_units(value: String) -> Result(Int, String) {
  let pieces = string.split(string.trim(value), ".")
  use #(whole, fraction) <- result.try(case pieces {
    [a] -> Ok(#(a, "00"))
    [a, b] ->
      case string.length(b) {
        1 -> Ok(#(a, b <> "0"))
        2 -> Ok(#(a, b))
        _ -> Error("Fiyat en fazla iki ondalık basamak içermeli.")
      }
    _ -> Error("Geçersiz fiyat.")
  })
  use _ <- result.try(case digits(whole) && digits(fraction) {
    True -> Ok(Nil)
    False -> Error("Fiyat pozitif bir sayı olmalı.")
  })
  use a <- result.try(
    int.parse(whole) |> result.replace_error("Geçersiz fiyat."),
  )
  use b <- result.try(
    int.parse(fraction) |> result.replace_error("Geçersiz fiyat."),
  )
  let amount = a * 100 + b
  case amount > 0 && amount <= 1_000_000_000 {
    True -> Ok(amount)
    False -> Error("Fiyat 0 ile 10.000.000 arasında olmalı.")
  }
}

fn digits(s: String) -> Bool {
  s != ""
  && list.all(string.to_graphemes(s), fn(c) { string.contains("0123456789", c) })
}

pub fn money(amount: Int, currency: String) -> String {
  let cents = int.to_string(amount % 100) |> string.pad_start(2, "0")
  int.to_string(amount / 100) <> "." <> cents <> " " <> currency
}

pub fn validate(
  title: String,
  locality: String,
  description: String,
  capacity: String,
  price: String,
  currency: String,
) -> Result(Draft, String) {
  let title = string.trim(title)
  let locality = string.trim(locality)
  use count <- result.try(
    int.parse(capacity) |> result.replace_error("Kapasite tam sayı olmalı."),
  )
  use amount <- result.try(minor_units(price))
  case
    string.length(title) >= 3
    && string.length(title) <= 120
    && string.length(locality) >= 2
    && string.length(locality) <= 80
    && string.length(description) <= 5000
    && count >= 1
    && count <= 50
    && list.contains(
      ["TRY", "EUR", "USD", "GBP", "CHF", "AED", "CNY"],
      currency,
    )
  {
    True -> Ok(Draft(title, locality, description, count, amount, currency))
    False ->
      Error(
        "Başlık 3-120 karakter, konum 2-80 karakter ve kapasite 1-50 kişi olmalı.",
      )
  }
}

pub fn role_title(role: String) -> String {
  case role {
    // Platform / Süper Yönetici Rolleri
    "owner" -> "Platform Sahibi (Süper Yönetici)"
    "operations_director" -> "Platform Operasyon Direktörü"
    "content_moderator" -> "İlan & İçerik Moderatörü"
    "finance_manager" -> "Finans & Mutabakat Müdürü"
    "onboarding_specialist" -> "Tedarikçi İlişkileri & Onboarding"
    "ai_pricing_specialist" -> "AI & Fiyatlama Mühendisi"
    "support_specialist" -> "Platform Destek Sorumlusu"

    // Tedarikçi / İşletme Rolleri
    "general_manager" -> "Tesis Genel Müdürü"
    "housekeeping" -> "Kat Hizmetleri / Temizlik"
    "purchasing" -> "Satın Alma Sorumlusu"
    "accounting" -> "Muhasebe & Finans"
    "frontdesk" -> "Ön Büro & Resepsiyon"
    "sales" -> "Satış Departmanı"
    "marketing" -> "Reklam & Tanıtım"
    "editor" -> "Editör"
    "viewer" -> "Görüntüleyici"
    _ -> role
  }
}

pub fn can_manage_team(role: String) -> Bool {
  role == "owner" || role == "general_manager" || role == "operations_director"
}

pub fn can_access_system_settings(role: String) -> Bool {
  role == "owner"
}

pub fn can_access_applications(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "onboarding_specialist"
}

pub fn can_access_category_fields(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "content_moderator"
}

pub fn can_access_messages(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "support_specialist"
}

pub fn can_access_housekeeping(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "general_manager"
  || role == "housekeeping"
  || role == "frontdesk"
  || role == "editor"
}

pub fn can_access_accounting(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "finance_manager"
  || role == "general_manager"
  || role == "accounting"
  || role == "purchasing"
  || role == "editor"
}

pub fn can_access_hr(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "general_manager"
  || role == "finance_manager"
  || role == "accounting"
}

pub fn can_access_social_media(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "content_moderator"
  || role == "ai_pricing_specialist"
  || role == "general_manager"
  || role == "marketing"
  || role == "sales"
  || role == "editor"
}

pub fn can_access_ai_hub(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "ai_pricing_specialist"
  || role == "general_manager"
  || role == "marketing"
  || role == "sales"
  || role == "editor"
}

pub fn can_access_listings(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "content_moderator"
  || role == "general_manager"
  || role == "sales"
  || role == "editor"
}

pub fn can_access_reservations(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "support_specialist"
  || role == "general_manager"
  || role == "frontdesk"
  || role == "sales"
  || role == "editor"
}

pub fn can_access_crm(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "support_specialist"
  || role == "general_manager"
  || role == "frontdesk"
  || role == "sales"
  || role == "marketing"
}

pub fn can_access_rate_shopper(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "ai_pricing_specialist"
  || role == "general_manager"
  || role == "sales"
  || role == "marketing"
}

pub fn can_access_tours(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "general_manager"
  || role == "frontdesk"
  || role == "sales"
}

pub fn can_access_fleet(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "general_manager"
  || role == "frontdesk"
  || role == "sales"
  || role == "accounting"
}

pub fn can_access_einvoice(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "finance_manager"
  || role == "general_manager"
  || role == "accounting"
  || role == "frontdesk"
}

pub fn can_access_supplier_permission(role: String, permission: String) -> Bool {
  case permission {
    "supplier.dashboard.view" -> can_access_listings(role)
    "supplier.company.view" -> can_manage_team(role)
    "supplier.company.manage" -> can_manage_team(role)
    "supplier.documents.view" -> can_access_applications(role)
    "supplier.documents.manage" -> can_access_applications(role)
    "supplier.catalog.view" -> can_access_listings(role)
    "supplier.catalog.manage" -> can_access_listings(role)
    "supplier.catalog.submit_review" -> can_access_listings(role)
    "supplier.availability.view" -> can_access_listings(role) || can_access_reservations(role)
    "supplier.availability.manage" -> can_access_listings(role) || can_access_reservations(role)
    "supplier.pricing.view" -> can_access_rate_shopper(role)
    "supplier.pricing.manage" -> can_access_rate_shopper(role)
    "supplier.reservations.view" -> can_access_reservations(role)
    "supplier.reservations.manage" -> can_access_reservations(role)
    "supplier.offers.view" -> can_access_crm(role) || can_access_listings(role)
    "supplier.offers.manage" -> can_access_crm(role) || can_access_listings(role)
    "supplier.customers.view" -> can_access_crm(role)
    "supplier.customers.manage" -> can_access_crm(role)
    "supplier.messages.view" -> can_access_messages(role) || can_access_crm(role)
    "supplier.messages.manage" -> can_access_messages(role) || can_access_crm(role)
    "supplier.tasks.view" -> can_access_housekeeping(role) || can_access_reservations(role)
    "supplier.tasks.manage" -> can_access_housekeeping(role) || can_access_reservations(role)
    "supplier.staff.view" -> can_manage_team(role) || can_access_hr(role)
    "supplier.staff.manage" -> can_manage_team(role)
    "supplier.accounting.view" -> can_access_accounting(role)
    "supplier.accounting.manage" -> can_access_accounting(role)
    "supplier.payments.view" -> can_access_accounting(role)
    "supplier.payments.manage" -> can_access_accounting(role)
    "supplier.reports.view" -> can_access_accounting(role) || can_access_listings(role) || can_access_reservations(role)
    "supplier.integrations.view" -> can_access_system_settings(role) || role == "operations_director" || role == "general_manager"
    "supplier.integrations.manage" -> can_access_system_settings(role) || role == "operations_director"
    "supplier.settings.view" -> can_manage_team(role)
    "supplier.settings.manage" -> can_access_system_settings(role) || role == "general_manager"
    _ -> role == "owner"
  }
}

pub fn can_access_any_supplier_permission(role: String, permissions_csv: String) -> Bool {
  let permissions =
    permissions_csv
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(permission) { permission != "" })

  case permissions {
    [] -> role == "owner" || role == "operations_director" || role == "general_manager"
    _ ->
      list.any(permissions, fn(permission) {
        can_access_supplier_permission(role, permission)
      })
  }
}

pub fn can_assign_modules(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.integrations.manage")
  || can_access_supplier_permission(role, "supplier.settings.manage")
  || role == "operations_director"
  || role == "general_manager"
  || role == "owner"
}

pub fn can_moderate_listings(role: String) -> Bool {
  role == "owner"
  || role == "operations_director"
  || role == "general_manager"
  || role == "content_moderator"
}

pub fn can_manage_catalog(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.catalog.manage")
  || can_access_listings(role)
}

pub fn can_submit_listing_review(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.catalog.submit_review")
  || can_access_listings(role)
}

pub fn can_manage_pricing(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.pricing.manage")
  || can_access_rate_shopper(role)
}

pub fn can_manage_availability(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.availability.manage")
  || can_access_reservations(role)
}

pub fn can_manage_reservations(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.reservations.manage")
  || can_access_reservations(role)
}

pub fn can_manage_documents(role: String) -> Bool {
  can_access_supplier_permission(role, "supplier.documents.manage")
  || can_access_applications(role)
}

pub fn default_dashboard(role: String) -> String {
  case role {
    // Platform Süper Yönetici Yönlendirmeleri
    "operations_director" -> "/admin"
    "content_moderator" -> "/admin/listings"
    "finance_manager" -> "/admin/finance"
    "onboarding_specialist" -> "/admin/applications"
    "ai_pricing_specialist" -> "/admin/ai-hub"
    "support_specialist" -> "/admin/messages"

    // Tedarikçi Yönlendirmeleri
    "housekeeping" -> "/admin/housekeeping"
    "purchasing" -> "/admin/accounting"
    "marketing" -> "/admin/social-media"
    "sales" -> "/admin/listings"
    "accounting" -> "/admin/accounting"
    _ -> "/admin"
  }
}
