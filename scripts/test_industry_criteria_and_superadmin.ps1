# test_industry_criteria_and_superadmin.ps1
# Comprehensive validation for Super Admin Listing Criteria Management
# Benchmarked against ETS Tur, Tatilbudur, Tatil Sepeti, Rezervasyonyap.com.tr, Airbnb, Booking.com

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/env.ps1"
$BaseUrl = if ($env:APP_ORIGIN) { $env:APP_ORIGIN } else { "http://127.0.0.1:8081" }
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   TEST SUITE: SUPER ADMIN CRITERIA & INDUSTRY SCHEMAS" -ForegroundColor Cyan
Write-Host "   ETS, Tatilbudur, Tatil Sepeti, Rezervasyonyap, Airbnb, Booking" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

function CsrfToken($html) {
  $match = [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"')
  if (-not $match.Success) {
    $match = [regex]::Match($html, 'value="([^"]+)"[^>]*name="csrf"')
  }
  if ($match.Success) {
    return $match.Groups[1].Value
  }
  throw "CSRF token could not be extracted from page HTML."
}

# ------------------------------------------------------------
# STEP 1: Super Admin Login
# ------------------------------------------------------------
Write-Host "`n--- STEP 1: Super Admin Authentication ---" -ForegroundColor Yellow
$loginPage = Invoke-WebRequest -Uri "$BaseUrl/login" -WebSession $Session -Method Get -UseBasicParsing
$csrf = CsrfToken $loginPage.Content

$adminPass = if ($env:ADMIN_PASSWORD) { $env:ADMIN_PASSWORD } else { "password123" }
$loginResp = Invoke-WebRequest -Uri "$BaseUrl/login" -WebSession $Session -Method Post -UseBasicParsing -Headers @{ Origin = $BaseUrl } -Body @{
  csrf = $csrf
  email = "admin@nexus.local"
  password = $adminPass
}

if ($loginResp.StatusCode -eq 200 -and ($loginResp.Content -like "*Çıkış*" -or $loginResp.Content -like "*Oturumu kapat*" -or $loginResp.Content -like "*nexus*")) {
  Write-Host " [PASS] Logged in as Super Admin (admin@nexus.local)" -ForegroundColor Green
} else {
  throw "Super Admin login failed."
}

# ------------------------------------------------------------
# STEP 2: Verify Hotel Criteria (ETS Tur, Tatilbudur, Tatil Sepeti, Booking)
# ------------------------------------------------------------
Write-Host "`n--- STEP 2: Otel Kriterleri (ETS Tur, Tatilbudur, Tatil Sepeti, Booking) ---" -ForegroundColor Yellow
$hotelFields = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/hotel" -WebSession $Session -Method Get -UseBasicParsing
$csrf = CsrfToken $hotelFields.Content

$expectedHotel = @(
  "meal_plan", "Pansiyon",
  "beach_distance", "Mesafe",
  "beach_features", "Plaj",
  "pool_types", "Havuz",
  "concept_themes", "Konsept",
  "spa_wellness", "Spa",
  "child_policy", "Politika",
  "ministry_license_no", "Belge No"
)

foreach ($keyword in $expectedHotel) {
  if ($hotelFields.Content -like "*$keyword*") {
    Write-Host " [PASS] Hotel criterion present: '$keyword'" -ForegroundColor Green
  } else {
    throw "Missing expected hotel criterion keyword: '$keyword'"
  }
}

# ------------------------------------------------------------
# STEP 3: Verify Holiday Home / Villa Criteria (Airbnb & Booking.com)
# ------------------------------------------------------------
Write-Host "`n--- STEP 3: Tatil Evi & Villa Kriterleri (Airbnb & Booking.com) ---" -ForegroundColor Yellow
$villaFields = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/villa" -WebSession $Session -Method Get -UseBasicParsing

$expectedVilla = @(
  "place_type", "pool_type",
  "indoor_luxury", "Jakuzi",
  "kitchen_equipment", "Mutfak",
  "connectivity_work", "Wi-Fi",
  "checkin_method", "Check-in",
  "ministry_permit_no", "7464",
  "qrcode_plaque_no"
)

foreach ($keyword in $expectedVilla) {
  if ($villaFields.Content -like "*$keyword*") {
    Write-Host " [PASS] Villa / Holiday Home criterion present: '$keyword'" -ForegroundColor Green
  } else {
    throw "Missing expected villa criterion keyword: '$keyword'"
  }
}

# ------------------------------------------------------------
# STEP 4: Verify Tour Criteria (Tatil Sepeti, ETS Tur, Acente2)
# ------------------------------------------------------------
Write-Host "`n--- STEP 4: Tur & Gezi Kriterleri (Tatil Sepeti, ETS, Acente2) ---" -ForegroundColor Yellow
$tourFields = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/tour" -WebSession $Session -Method Get -UseBasicParsing

$expectedTour = @(
  "tour_type", "transportation_mode",
  "guide_languages", "Rehber",
  "included_meals", "museum_entrance",
  "guaranteed_departure", "tursab_licence_no"
)

foreach ($keyword in $expectedTour) {
  if ($tourFields.Content -like "*$keyword*") {
    Write-Host " [PASS] Tour criterion present: '$keyword'" -ForegroundColor Green
  } else {
    throw "Missing expected tour criterion keyword: '$keyword'"
  }
}

# ------------------------------------------------------------
# STEP 5: Verify Activity & Adventure Criteria (Rezervasyonyap, Airbnb Exp, GetYourGuide)
# ------------------------------------------------------------
Write-Host "`n--- STEP 5: Aktivite & Macera Kriterleri (Rezervasyonyap, Airbnb Exp) ---" -ForegroundColor Yellow
$activityFields = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/activity" -WebSession $Session -Method Get -UseBasicParsing

$expectedActivity = @(
  "activity_category", "hotel_transfer",
  "equipment_included", "photo_video_service", "GoPro",
  "health_requirements", "insurance_coverage",
  "weather_policy", "instructor_certifications"
)

foreach ($keyword in $expectedActivity) {
  if ($activityFields.Content -like "*$keyword*") {
    Write-Host " [PASS] Activity criterion present: '$keyword'" -ForegroundColor Green
  } else {
    throw "Missing expected activity criterion keyword: '$keyword'"
  }
}

# ------------------------------------------------------------
# STEP 6: Verify Event Criteria (Biletix, Passo)
# ------------------------------------------------------------
Write-Host "`n--- STEP 6: Etkinlik & Festival Kriterleri (Biletix, Passo) ---" -ForegroundColor Yellow
$eventFields = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/event" -WebSession $Session -Method Get -UseBasicParsing

$expectedEvent = @(
  "event_category", "seating_type", "VIP",
  "age_limit", "doors_open_time",
  "ticket_policy", "venue_facilities"
)

foreach ($keyword in $expectedEvent) {
  if ($eventFields.Content -like "*$keyword*") {
    Write-Host " [PASS] Event criterion present: '$keyword'" -ForegroundColor Green
  } else {
    throw "Missing expected event criterion keyword: '$keyword'"
  }
}

# ------------------------------------------------------------
# STEP 7: Super Admin Adds a New Custom Criterion
# ------------------------------------------------------------
Write-Host "`n--- STEP 7: Super Admin Adds New Custom Criterion ---" -ForegroundColor Yellow
$customCode = "gstc_green_cert"
$customLabel = "GSTC Sustainable Green Certificate"

$addResp = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/hotel" -WebSession $Session -Method Post -UseBasicParsing -Headers @{ Origin = $BaseUrl } -Body @{
  csrf = $csrf
  id = ""
  code = $customCode
  label = $customLabel
  kind = "select"
  choices = "Stage 1,Stage 2,Full Green Certified,None"
  required = "false"
  active = "true"
  position = "110"
}

if ($addResp.StatusCode -eq 200 -and $addResp.Content -like "*$customCode*") {
  Write-Host " [PASS] Super Admin created new custom criterion: '$customLabel'" -ForegroundColor Green
} else {
  throw "Failed to create custom criterion."
}

# ------------------------------------------------------------
# STEP 8: Super Admin Triggers Sektör Standartlarını Senkronize Et
# ------------------------------------------------------------
Write-Host "`n--- STEP 8: Super Admin Triggers Industry Standards Preset Sync ---" -ForegroundColor Yellow
$syncCsrf = CsrfToken $addResp.Content

$syncResp = Invoke-WebRequest -Uri "$BaseUrl/admin/category-fields/sync-presets" -WebSession $Session -Method Post -UseBasicParsing -Headers @{ Origin = $BaseUrl } -Body @{
  csrf = $syncCsrf
  category = "hotel"
}

if ($syncResp.StatusCode -eq 200) {
  Write-Host " [PASS] Industry standards preset sync executed successfully." -ForegroundColor Green
} else {
  throw "Preset sync failed."
}

# ------------------------------------------------------------
# STEP 9: Supplier Dynamic Listing Wizard Verification
# ------------------------------------------------------------
Write-Host "`n--- STEP 9: Supplier Listing Wizard Dynamic Criteria Rendering ---" -ForegroundColor Yellow
$supplierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$supplierLogin = Invoke-WebRequest -Uri "$BaseUrl/login" -WebSession $supplierSession -Method Get -UseBasicParsing
$sCsrf = CsrfToken $supplierLogin.Content

$suppPass = if ($env:SUPPLIER_PASSWORD) { $env:SUPPLIER_PASSWORD } else { "password123" }
$sLoginResp = Invoke-WebRequest -Uri "$BaseUrl/login" -WebSession $supplierSession -Method Post -UseBasicParsing -Headers @{ Origin = $BaseUrl } -Body @{
  csrf = $sCsrf
  email = "supplier@nexus.local"
  password = $suppPass
}

# Check Hotel listing creation wizard
$hotelWizard = Invoke-WebRequest -Uri "$BaseUrl/admin/listings/new/hotel" -WebSession $supplierSession -Method Get -UseBasicParsing
if ($hotelWizard.Content -like "*attr_meal_plan*" -and $hotelWizard.Content -like "*attr_beach_distance*" -and $hotelWizard.Content -like "*attr_ministry_license_no*") {
  Write-Host " [PASS] Hotel listing wizard rendered dynamic ETS/Tatilbudur criteria inputs." -ForegroundColor Green
} else {
  throw "Hotel listing wizard missing dynamic criteria inputs."
}

# Check Villa listing creation wizard
$villaWizard = Invoke-WebRequest -Uri "$BaseUrl/admin/listings/new/villa" -WebSession $supplierSession -Method Get -UseBasicParsing
if ($villaWizard.Content -like "*attr_place_type*" -and $villaWizard.Content -like "*attr_pool_type*" -and $villaWizard.Content -like "*attr_checkin_method*") {
  Write-Host " [PASS] Villa listing wizard rendered dynamic Airbnb/Booking criteria inputs." -ForegroundColor Green
} else {
  throw "Villa listing wizard missing dynamic criteria inputs."
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "   ALL TESTS PASSED! SUPER ADMIN LISTING CRITERIA FULLY VERIFIED!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
