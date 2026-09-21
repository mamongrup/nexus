import gleam/result
import gleam/string
import gleeunit
import nexus/ai_generator
import nexus/domain

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn money_precision_test() {
  assert domain.minor_units("0.01") == Ok(1)
  assert domain.minor_units("4500.10") == Ok(450_010)
  assert domain.minor_units("5.5") == Ok(550)
  assert domain.money(550, "TRY") == "5.50 TRY"
}

pub fn money_rejects_invalid_input_test() {
  assert result.is_error(domain.minor_units("-1"))
  assert result.is_error(domain.minor_units("0"))
  assert result.is_error(domain.minor_units("1.999"))
  assert result.is_error(domain.minor_units("1e5"))
  assert result.is_error(domain.minor_units("NaN"))
  assert result.is_error(domain.minor_units("10000001"))
}

pub fn listing_validation_test() {
  assert result.is_ok(domain.validate(
    "Villa Lale",
    "Fethiye",
    "",
    "6",
    "4500.00",
    "TRY",
  ))
  assert result.is_error(domain.validate("x", "Fethiye", "", "6", "4500", "TRY"))
  assert result.is_error(domain.validate(
    "Villa Lale",
    "Fethiye",
    "",
    "51",
    "4500",
    "TRY",
  ))
  assert result.is_error(domain.validate(
    "Villa Lale",
    "Fethiye",
    "",
    "6",
    "4500",
    "BTC",
  ))
}

pub fn supplier_permission_contract_mapping_test() {
  assert domain.can_access_supplier_permission(
    "accounting",
    "supplier.accounting.manage",
  )
  assert !domain.can_access_supplier_permission(
    "housekeeping",
    "supplier.accounting.manage",
  )
  assert domain.can_access_supplier_permission(
    "editor",
    "supplier.catalog.submit_review",
  )
  assert domain.can_access_any_supplier_permission(
    "frontdesk",
    "supplier.reservations.view,supplier.reservations.manage",
  )
  assert !domain.can_access_any_supplier_permission(
    "viewer",
    "supplier.pricing.manage",
  )
}

pub fn ai_generator_hotel_test() {
  let res = ai_generator.generate_all("hotel", "İstanbul", "", "2")
  assert string.contains(res.title, "İstanbul")
  assert string.contains(res.description, "## Genel Bakış")
  assert string.contains(res.description, "KBS")
  assert string.contains(res.seo_title, "İstanbul")
  assert string.length(res.seo_title) <= 160
  assert string.length(res.seo_description) <= 320
}

pub fn ai_generator_villa_test() {
  let res = ai_generator.generate_all("villa", "Bodrum", "", "6")
  assert string.contains(res.title, "Bodrum")
  assert string.contains(res.description, "7464")
  assert string.contains(res.seo_title, "Bodrum")
  assert string.length(res.seo_title) <= 160
  assert string.length(res.seo_description) <= 320
}

pub fn ai_generator_car_test() {
  let res = ai_generator.generate_all("car", "Antalya", "", "5")
  assert string.contains(res.title, "Antalya")
  assert string.contains(res.description, "KABİS")
  assert string.length(res.seo_title) <= 160
  assert string.length(res.seo_description) <= 320
}

pub fn action_permissions_test() {
  // Module assignment: owner, general_manager, operations_director
  assert domain.can_assign_modules("owner")
  assert domain.can_assign_modules("general_manager")
  assert domain.can_assign_modules("operations_director")
  assert !domain.can_assign_modules("housekeeping")
  assert !domain.can_assign_modules("viewer")

  // Listing moderation: platform moderation roles only
  assert domain.can_moderate_listings("owner")
  assert domain.can_moderate_listings("operations_director")
  assert domain.can_moderate_listings("content_moderator")
  assert !domain.can_moderate_listings("sales")
  assert !domain.can_moderate_listings("accounting")

  // Listing submit review & catalog manage
  assert domain.can_manage_catalog("owner")
  assert domain.can_manage_catalog("sales")
  assert !domain.can_manage_catalog("housekeeping")
  assert domain.can_submit_listing_review("editor")
  assert !domain.can_submit_listing_review("viewer")

  // Pricing & availability & reservations
  assert domain.can_manage_pricing("owner")
  assert domain.can_manage_pricing("sales")
  assert !domain.can_manage_pricing("housekeeping")
  assert domain.can_manage_availability("frontdesk")
  assert domain.can_manage_reservations("frontdesk")
  assert !domain.can_manage_reservations("viewer")

  // Document management: onboarding_specialist, owner, operations_director
  assert domain.can_manage_documents("onboarding_specialist")
  assert domain.can_manage_documents("owner")
  assert !domain.can_manage_documents("housekeeping")
}

