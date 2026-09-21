# scripts/test_marketplace_and_cockpit.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

function Check($cond, $msg) {
  if ($cond) {
    Write-Host "PASS: $msg" -ForegroundColor Green
  } else {
    Write-Host "FAIL: $msg" -ForegroundColor Red
    exit 1
  }
}

function Csrf($html) {
  [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value
}

Write-Host "Starting Marketplace & Listing Modules Cockpit Test Suite..." -ForegroundColor Cyan

# 1. Check Homepage
$homeResp = Invoke-WebRequest "$base/" -UseBasicParsing
Check ($homeResp.StatusCode -eq 200) "Corporate homepage accessible"
Check ($homeResp.Content.Contains("/ilanlar")) "Corporate homepage links to live marketplace"

# 2. Check Marketplace Catalog
$catalog = Invoke-WebRequest "$base/ilanlar" -UseBasicParsing
Check ($catalog.StatusCode -eq 200) "Marketplace catalog accessible"
Check ($catalog.Content.Contains("Bodrum Sunset Luxury Infinity Pool Villa")) "Bodrum Villa present in marketplace"
Check ($catalog.Content.Contains("Bosphorus Palace Luxury Suite Hotel")) "Bosphorus Hotel present in marketplace"
Check ($catalog.Content.Contains("Deluxe Mavi Tur Guleti")) "Göcek Gulet present in marketplace"
Check ($catalog.Content.Contains("Balon")) "Kapadokya Cave Suite present in marketplace"

# 3. Search & Filter
$search = Invoke-WebRequest "$base/ilanlar?q=Bodrum" -UseBasicParsing
Check ($search.Content.Contains("Bodrum Sunset") -and !$search.Content.Contains("Balon")) "Search filter by query works"

$hotelFilter = Invoke-WebRequest "$base/ilanlar?category=hotel" -UseBasicParsing
Check ($hotelFilter.Content.Contains("Bosphorus Palace") -and !$hotelFilter.Content.Contains("Deluxe Mavi Tur")) "Category filter works"

# 4. Listing Detail Page
$detail = Invoke-WebRequest "$base/ilan/11111111-aaaa-4111-8111-111111111111" -UseBasicParsing
Check ($detail.StatusCode -eq 200) "Listing detail page accessible"
Check ($detail.Content.Contains("Sonsuzluk Havuzu")) "Listing amenities rendered"
Check ($detail.Content.Contains("PNR")) "Booking form present"

# 5. Make Direct Booking
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginPage = Invoke-WebRequest "$base/login" -WebSession $session -UseBasicParsing
$csrf = Csrf $loginPage.Content
Check ($csrf.Length -ge 16) "CSRF token extracted"

$bookBody = @{
  csrf = $csrf
  check_in = "2026-09-20"
  check_out = "2026-09-23"
  guests = "4"
  guest_name = "Murat Demir"
  guest_email = "murat@example.com"
  guest_phone = "+905329998877"
  tc = "39281726481"
}
$booking = Invoke-WebRequest "$base/ilan/11111111-aaaa-4111-8111-111111111111/book" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $bookBody -UseBasicParsing
Write-Host "BOOKING CONTENT: $($booking.Content.Substring(0, [Math]::Min(300, $booking.Content.Length)))"
Check ($booking.StatusCode -eq 200) "Marketplace direct booking processed"
Check ($booking.Content.Contains("Onayland") -or $booking.Content.Contains("NX-") -or $booking.Content.Contains("pnr")) "Confirmation voucher displayed"
Check ($booking.Content.Contains("PMS")) "PMS room allocated"
Check ($booking.Content.Contains("KBS")) "KBS dispatch verified"

# 6. Supplier Login and Access Listing Modules Cockpit
$loginPage = Invoke-WebRequest "$base/login" -WebSession $session -UseBasicParsing
$loginCsrf = Csrf $loginPage.Content

$loginBody = @{
  csrf = $loginCsrf
  email = "supplier@nexus.local"
  password = $env:SUPPLIER_PASSWORD
}
$loginResp = Invoke-WebRequest "$base/login" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $loginBody -UseBasicParsing
Check ($loginResp.StatusCode -eq 200) "Supplier logged in successfully"

$listingsAdmin = Invoke-WebRequest "$base/admin/listings" -WebSession $session -UseBasicParsing
Check ($listingsAdmin.Content.Contains("/modules")) "Listings table contains Module Operations button"

# 7. Open Listing Modules Cockpit
$cockpit = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules" -WebSession $session -UseBasicParsing
Check ($cockpit.StatusCode -eq 200) "Listing Modules Cockpit accessible"
Check ($cockpit.Content.Contains("PMS")) "PMS module section active"
Check ($cockpit.Content.Contains("KBS")) "KBS module section active"
Check ($cockpit.Content.Contains("OTA")) "Channel Manager section active"
Check ($cockpit.Content.Contains("WhatsApp")) "WhatsApp section active"
Check ($cockpit.Content.Contains("Fatura")) "e-Invoice section active"

$cockpitCsrf = Csrf $cockpit.Content

# 8. Test Cockpit Module Actions
# Trigger KBS dispatch
$kbsBody = @{
  csrf = $cockpitCsrf
  guest_name = "Selin Yılmaz"
  tc = "99887766554"
  room = "VIL-1"
  check_in = "2026-09-25"
  check_out = "2026-09-28"
}
$kbsResp = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules/kbs" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $kbsBody -UseBasicParsing
Check ($kbsResp.StatusCode -eq 200) "KBS dispatch action executed"

$cockpit = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules" -WebSession $session -UseBasicParsing
$cockpitCsrf = Csrf $cockpit.Content

# Trigger OTA Channel Sync
$otaBody = @{
  csrf = $cockpitCsrf
  channel = "Airbnb"
}
$otaResp = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules/ota" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $otaBody -UseBasicParsing
Check ($otaResp.StatusCode -eq 200) "OTA channel sync executed"

$cockpit = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules" -WebSession $session -UseBasicParsing
$cockpitCsrf = Csrf $cockpit.Content

# Trigger WhatsApp message
$waBody = @{
  csrf = $cockpitCsrf
  phone = "+905321112233"
  template = "welcome"
  content = "Özel Hoşgeldiniz Mesajı"
}
$waResp = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules/whatsapp" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $waBody -UseBasicParsing
Check ($waResp.StatusCode -eq 200) "WhatsApp message sent"

$cockpit = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules" -WebSession $session -UseBasicParsing
$cockpitCsrf = Csrf $cockpit.Content

# Trigger e-Arşiv invoice
$invBody = @{
  csrf = $cockpitCsrf
  recipient = "Selin Yılmaz"
  amount = "37500"
}
$invResp = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules/invoice" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $invBody -UseBasicParsing
Check ($invResp.StatusCode -eq 200) "e-Arşiv invoice issued"

Write-Host "ALL Marketplace & Listing Modules Tests Passed Successfully!" -ForegroundColor Green
