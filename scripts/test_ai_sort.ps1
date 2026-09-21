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

Write-Output "=== Testing AI Smart Image Ordering ==="

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

# 2. Get listing form CSRF and verify UI elements
$r = Http-Req "$base/admin/listings/new/villa" -WebSession $session
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got villa listing form CSRF"
Check ($r.Content.Contains('btn-ai-sort-photos')) "Form has 'btn-ai-sort-photos' AI Sort button"
Check ($r.Content.Contains('chk-auto-ai-sort')) "Form has 'chk-auto-ai-sort' auto-sort checkbox"
Check ($r.Content.Contains('ai-sort-banner')) "Form has 'ai-sort-banner' container"

# 3. Test Villa AI photo sorting
$villaMixedHero = "https://example.com/uploads/luxury_banyo_bath.avif"
$villaMixedGallery = "https://example.com/uploads/modern_kitchen_mutfak.avif`nhttps://example.com/uploads/panoramic_havuz_pool_facade.avif`nhttps://example.com/uploads/master_suite_yatak_odasi.avif`nhttps://example.com/uploads/guneslenme_teras_bbq.avif"

$r = Http-Req "$base/admin/ai/sort_photos" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  category_code = 'villa'
  hero_image = $villaMixedHero
  gallery_images = $villaMixedGallery
  ajax = '1'
}
Check ($r.StatusCode -eq 200) "Villa AI sort endpoint returned 200 OK"
$villaJson = $r.Content | ConvertFrom-Json
Check ($villaJson.success -eq $true) "Villa AI sort returned success=true"
Write-Output "Villa Recommended Hero: $($villaJson.recommended_hero)"
Check ($villaJson.recommended_hero.Contains("havuz_pool")) "Villa recommended hero is pool/facade"
Check ($villaJson.sorted_gallery[0].Contains("yatak_odasi")) "Villa gallery 1st position is master bedroom"
Check ($villaJson.ranked_items.Count -eq 5) "All 5 photos ranked with AI scores and tags"

# 4. Test Car AI photo sorting
$carMixedHero = "https://example.com/uploads/bagaj_trunk.avif"
$carMixedGallery = "https://example.com/uploads/deri_koltuk_seat.avif`nhttps://example.com/uploads/on_dinamik_front_hero.avif`nhttps://example.com/uploads/dijital_kokpit_wheel.avif`nhttps://example.com/uploads/yan_profil_side_jant.avif"

$r = Http-Req "$base/admin/ai/sort_photos" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  category_code = 'car'
  hero_image = $carMixedHero
  gallery_images = $carMixedGallery
  ajax = '1'
}
Check ($r.StatusCode -eq 200) "Car AI sort endpoint returned 200 OK"
$carJson = $r.Content | ConvertFrom-Json
Check ($carJson.success -eq $true) "Car AI sort returned success=true"
Write-Output "Car Recommended Hero: $($carJson.recommended_hero)"
Check ($carJson.recommended_hero.Contains("front_hero")) "Car recommended hero is front 3/4 dynamic view"
Check ($carJson.sorted_gallery[0].Contains("side_jant")) "Car gallery 1st position is side profile with wheels"

# 5. Test Hotel AI photo sorting
$hotelMixedHero = "https://example.com/uploads/otel_banyo.avif"
$hotelMixedGallery = "https://example.com/uploads/otel_restoran_kahvalti.avif`nhttps://example.com/uploads/otel_dis_cephe_lobby_facade.avif`nhttps://example.com/uploads/otel_suit_yatak_odasi.avif`nhttps://example.com/uploads/otel_havuz_spa.avif"

$r = Http-Req "$base/admin/ai/sort_photos" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  category_code = 'hotel'
  hero_image = $hotelMixedHero
  gallery_images = $hotelMixedGallery
  ajax = '1'
}
Check ($r.StatusCode -eq 200) "Hotel AI sort endpoint returned 200 OK"
$hotelJson = $r.Content | ConvertFrom-Json
Check ($hotelJson.success -eq $true) "Hotel AI sort returned success=true"
Write-Output "Hotel Recommended Hero: $($hotelJson.recommended_hero)"
Check ($hotelJson.recommended_hero.Contains("lobby_facade")) "Hotel recommended hero is exterior facade and lobby"
Check ($hotelJson.sorted_gallery[0].Contains("yatak_odasi")) "Hotel gallery 1st position is suite bedroom"

Write-Output "`n*** ALL AI SMART IMAGE SORTING TESTS PASSED (100% SUCCESS) ***"
