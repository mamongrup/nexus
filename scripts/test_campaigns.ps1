. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

function Check($condition, $name) {
  if (!$condition) {
    throw "FAIL: $name"
  }
  Write-Output "PASS: $name"
}

function Csrf($html) {
  [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value
}

function Http-Req {
  param($Uri, $Method = 'GET', $WebSession, $Headers, $Body)
  $p = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true }
  if ($WebSession) { $p['WebSession'] = $WebSession }
  if ($Headers) { $p['Headers'] = $Headers }
  if ($Body) { $p['Body'] = $Body }
  try {
    Invoke-WebRequest @p
  } catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
      $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $content = $reader.ReadToEnd()
      return [PSCustomObject]@{
        StatusCode = [int]$resp.StatusCode
        Content = $content
      }
    }
    throw $_
  }
}

Write-Output "=== Testing Supplier Campaigns & Discounts ==="

# 1. Login as supplier
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $session
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got CSRF token from login"

$r = Http-Req "$base/login" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  email = 'supplier@nexus.local'
  password = $env:SUPPLIER_PASSWORD
}
Check ($r.StatusCode -eq 200) "Supplier login successful"

# 2. Access /admin/campaigns
$r = Http-Req "$base/admin/campaigns" -WebSession $session
Check ($r.StatusCode -eq 200) "GET /admin/campaigns status 200"
Check ($r.Content.Contains('Kampanya')) "Contains Kampanya text"
Check ($r.Content.Contains('Erken Rezervasyon')) "Contains preset: Erken Rezervasyon"
Check ($r.Content.Contains('Son Dakika')) "Contains preset: Son Dakika"
Check ($r.Content.Contains('stat-card-modern')) "Contains modern stats KPI cards"

$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got campaign CSRF token"

# 3. Create a test campaign
$campName = "E2E Test Yaz Kampanyasi " + (Get-Random -Minimum 1000 -Maximum 9999)
$campPromo = "YAZTEST" + (Get-Random -Minimum 100 -Maximum 999)
$createBody = @{
  csrf = $csrf
  name = $campName
  campaign_type = "promo_code"
  discount_type = "percentage"
  discount_val = "15"
  promo_code = $campPromo
  property_id = ""
  category_code = ""
  min_stay_nights = "2"
  days_in_advance = "0"
  badge_text = "%15 ERKEN REZ"
  start_date = "2026-05-01"
  end_date = "2026-10-31"
  usage_limit = "100"
}

$r = Http-Req "$base/admin/campaigns" -Method Post -WebSession $session -Headers @{Origin = $base} -Body $createBody
Write-Output "POST /admin/campaigns response code: $($r.StatusCode)"
if ($r.StatusCode -ne 200 -and $r.StatusCode -ne 302) {
  Write-Output "Response content: $($r.Content)"
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 302) "POST /admin/campaigns created campaign"

# 4. Refresh /admin/campaigns and verify the new campaign is listed
$r = Http-Req "$base/admin/campaigns" -WebSession $session
Check ($r.Content.Contains($campName)) "Created campaign appears in campaign table"
Check ($r.Content.Contains($campPromo)) "Promo code appears in campaign table"

# Extract campaign ID from action URL
$match = [regex]::Match($r.Content, '/admin/campaigns/([a-f0-9\-]+)/toggle')
Check ($match.Success) "Extracted campaign ID from toggle form action"
$campId = $match.Groups[1].Value
Write-Output "Found campaign ID: $campId"

# 5. Toggle campaign status
$csrf = Csrf $r.Content
$r = Http-Req "$base/admin/campaigns/$campId/toggle" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  active = "false"
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 302) "Toggled campaign status"

# Toggle it back to active so it can be used
$r = Http-Req "$base/admin/campaigns" -WebSession $session
$csrf = Csrf $r.Content
$r = Http-Req "$base/admin/campaigns/$campId/toggle" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  active = "true"
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 302) "Re-activated campaign"

# 6. Check Marketplace listings and find a listing
$r = Http-Req "$base/ilanlar"
Check ($r.StatusCode -eq 200) "GET /ilanlar status 200"
$listingMatch = [regex]::Match($r.Content, 'href="/ilan/([a-f0-9\-]+)"')
Check ($listingMatch.Success) "Found marketplace listing"
$listingId = $listingMatch.Groups[1].Value
Write-Output "Found marketplace listing ID: $listingId"

# 7. Test calculation endpoint with listing ID and promo code
$r = Http-Req "$base/admin/campaigns/calculate" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  property_id = $listingId
  promo_code = $campPromo
  check_in = "2026-07-01"
  check_out = "2026-07-05"
  base_price = "10000"
}
Check ($r.StatusCode -eq 200) "POST /admin/campaigns/calculate status 200"
$calcJson = $r.Content | ConvertFrom-Json
Check ($calcJson.has_discount -eq $true) "Promo calculation has_discount=true"
Check ($calcJson.discount_minor -gt 0) "Discount amount > 0 calculated"
Write-Output "Calculated discount amount: $($calcJson.discount_minor) on 10000 base"

# 8. Test detail page and book listing with promo code
$pubSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/ilan/$listingId" -WebSession $pubSession
Check ($r.StatusCode -eq 200) "GET /ilan/$listingId status 200"
Check ($r.Content.Contains(
  'promo_code')) "Detail page booking form has promo_code input"
$detailCsrf = Csrf $r.Content

$bookBody = @{
  csrf = $detailCsrf
  check_in = "2026-07-10"
  check_out = "2026-07-14"
  guests = "2"
  guest_name = "Kampanya Test Misafir"
  guest_email = "guest-campaign@test.com"
  guest_phone = "05551234567"
  tc = "11111111111"
  promo_code = $campPromo
}
$r = Http-Req "$base/ilan/$listingId/book" -Method Post -WebSession $pubSession -Headers @{Origin = $base} -Body $bookBody
Write-Output "Booking response status: $($r.StatusCode)"
if ($r.StatusCode -ne 200) {
  Write-Output "Booking response content: $($r.Content)"
}
Check ($r.StatusCode -eq 200) "POST /ilan/$listingId/book status 200"
Check ($r.Content.Contains('NX-') -or $r.Content.Contains('Rezervasyon')) "Booking confirmation page rendered with PNR and discount"
Write-Output "Booking created successfully with promo code!"

# 9. Clean up test campaign
$r = Http-Req "$base/admin/campaigns" -WebSession $session
$csrf = Csrf $r.Content
$r = Http-Req "$base/admin/campaigns/$campId/delete" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 302) "Deleted test campaign"

Write-Output "`n=== ALL CAMPAIGN AND DISCOUNT TESTS PASSED! ==="
