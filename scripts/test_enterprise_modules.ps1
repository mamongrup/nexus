. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

function Check($condition, $name) {
  if (!$condition) {
    throw "FAIL: $name"
  }
  Write-Output "PASS: $name"
}

function Contains-Text($haystack, $needle) {
  return $haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
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

Write-Output "=== Testing 5 Enterprise Modules ==="

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

# ══════════════════════════════════════════════════════════════════
# MODULE 1: MUHASEBE & KASA MODÜLÜ (/admin/accounting)
# ══════════════════════════════════════════════════════════════════
Write-Output "`n--- Module 1: Accounting & Cash Flow ---"
$r = Http-Req "$base/admin/accounting" -WebSession $session
Check ($r.StatusCode -eq 200) "GET /admin/accounting status 200"
Check (Contains-Text $r.Content 'Muhasebe') "Accounting page loaded"
Check (Contains-Text $r.Content 'Kasa') "KPI Net Balance exists"

$accCsrf = Csrf $r.Content
Check ($accCsrf.Length -gt 20) "Got Accounting CSRF token"

# Post an Income transaction
$txTitle1 = "Oda 101 Konaklama Tahsilati #" + (Get-Random -Minimum 1000 -Maximum 9999)
$r = Http-Req "$base/admin/accounting/transaction" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $accCsrf
  type = 'income'
  category = 'room_sales'
  title = $txTitle1
  amount = '4500'
  currency = 'TRY'
  payment_method = 'credit_card'
  description = 'E2E Test Rezervasyon Geliri'
  document_no = 'FTR-2026-001'
}
Write-Output "POST income response code: $($r.StatusCode)"
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST income transaction success"

# Refresh CSRF from redirected page
$accCsrf = Csrf $r.Content
if (!$accCsrf) {
  $r = Http-Req "$base/admin/accounting" -WebSession $session
  $accCsrf = Csrf $r.Content
}

# Post an Expense transaction
$txTitle2 = "Mutfak Gideri #" + (Get-Random -Minimum 1000 -Maximum 9999)
$r = Http-Req "$base/admin/accounting/transaction" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $accCsrf
  type = 'expense'
  category = 'fnb_supply'
  title = $txTitle2
  amount = '1250'
  currency = 'TRY'
  payment_method = 'bank_transfer'
  description = 'E2E Test Haftalik Gida Alimi'
  document_no = 'GDR-2026-088'
}
Write-Output "POST expense response code: $($r.StatusCode)"
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST expense transaction success"

# Verify transactions appear on page
$r = Http-Req "$base/admin/accounting" -WebSession $session
Check (Contains-Text $r.Content $txTitle1) "Income transaction displayed in history"
Check (Contains-Text $r.Content $txTitle2) "Expense transaction displayed in history"

# ══════════════════════════════════════════════════════════════════
# MODULE 2: SOSYAL MEDYA MODÜLÜ (/admin/social-media)
# ══════════════════════════════════════════════════════════════════
Write-Output "`n--- Module 2: Social Media Marketing ---"
$r = Http-Req "$base/admin/social-media" -WebSession $session
Check ($r.StatusCode -eq 200) "GET /admin/social-media status 200"
Check (Contains-Text $r.Content 'Sosyal Medya') "Social media page loaded"
Check (Contains-Text $r.Content 'Instagram') "Contains Instagram account card"

$smCsrf = Csrf $r.Content
Check ($smCsrf.Length -gt 20) "Got Social Media CSRF token"

# Schedule a social post
$postTitle = "Hafta Sonu Ozel %20 Indirim #" + (Get-Random -Minimum 100 -Maximum 999)
$r = Http-Req "$base/admin/social-media/post" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $smCsrf
  platform = 'instagram'
  title = $postTitle
  caption = 'Deniz manzarali odalarimizda unutulmaz bir hafta sonu sizi bekliyor! #Tatil #NexusTravel'
  media_url = 'https://images.unsplash.com/photo-1566073771259-6a8506099945'
  link_url = 'https://nexustravel.com/villa'
  status = 'published'
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST social post success"

$r = Http-Req "$base/admin/social-media" -WebSession $session
Check (Contains-Text $r.Content $postTitle) "Social post visible in scheduled/feed table"

# ══════════════════════════════════════════════════════════════════
# MODULE 3: YAPAY ZEKA MODÜLLERİ (/admin/ai-hub)
# ══════════════════════════════════════════════════════════════════
Write-Output "`n--- Module 3: AI Hub & Intelligent Wizards ---"
$r = Http-Req "$base/admin/ai-hub" -WebSession $session
Check ($r.StatusCode -eq 200) "GET /admin/ai-hub status 200"
Check (Contains-Text $r.Content 'Yapay Zeka') "AI Hub page loaded"

$aiCsrf = Csrf $r.Content
Check ($aiCsrf.Length -gt 20) "Got AI Hub CSRF token"

# AI Tool 1: Listing SEO generator
$r = Http-Req "$base/admin/ai-hub/generate" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $aiCsrf
  tool_type = 'listing_seo'
  title = 'Villa Ege Panoramik'
  category = 'villa'
  locality = 'Bodrum Yalikavak'
  amenities = 'Ozel Sonsuzluk Havuzu, Deniz Manzarasi, Jakuzi'
}
Check ($r.StatusCode -eq 200) "AI Tool 1 (Listing SEO) generation success"
Check (Contains-Text $r.Content 'SEO') "AI SEO Title output present"

$aiCsrf = Csrf $r.Content
if (!$aiCsrf) {
  $r = Http-Req "$base/admin/ai-hub" -WebSession $session
  $aiCsrf = Csrf $r.Content
}

# AI Tool 2: Social media caption generator
$r = Http-Req "$base/admin/ai-hub/generate" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $aiCsrf
  tool_type = 'social_post'
  title = 'Bodrum Suite Deluxe'
  category = 'hotel'
  promo_discount = '25'
  tone = 'luxury'
}
Check ($r.StatusCode -eq 200) "AI Tool 2 (Social Post) generation success"
Check ((Contains-Text $r.Content 'LuxuryTravel') -or (Contains-Text $r.Content 'NexusTravelTech') -or (Contains-Text $r.Content 'Bodrum')) "AI Hashtags generated"

$aiCsrf = Csrf $r.Content
if (!$aiCsrf) {
  $r = Http-Req "$base/admin/ai-hub" -WebSession $session
  $aiCsrf = Csrf $r.Content
}

# AI Tool 3: Guest review reply
$r = Http-Req "$base/admin/ai-hub/generate" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $aiCsrf
  tool_type = 'review_reply'
  guest_name = 'Ahmet Yilmaz'
  rating = '5'
  comment = 'Harika bir tatildi, personel son derece guler yuzlu ve temizlik kusursuzdu.'
}
Check ($r.StatusCode -eq 200) "AI Tool 3 (Review Reply) generation success"
Check (Contains-Text $r.Content 'Ahmet Yilmaz') "AI personalized guest greeting present"

$aiCsrf = Csrf $r.Content
if (!$aiCsrf) {
  $r = Http-Req "$base/admin/ai-hub" -WebSession $session
  $aiCsrf = Csrf $r.Content
}

# AI Tool 4: Demand forecast & dynamic pricing
$r = Http-Req "$base/admin/ai-hub/generate" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $aiCsrf
  tool_type = 'demand_forecast'
  category = 'Otel'
  locality = 'Antalya Kas'
  occupancy_pct = '90'
}
Check ($r.StatusCode -eq 200) "AI Tool 4 (Demand Forecast) generation success"
Check (Contains-Text $r.Content 'Talep') "AI Demand prediction generated"

# ══════════════════════════════════════════════════════════════════
# MODULE 4: PERSONEL, İŞE ALIM & BORDRO (/admin/hr)
# ══════════════════════════════════════════════════════════════════
Write-Output "`n--- Module 4: Human Resources, Recruiting & Payroll ---"
$r = Http-Req "$base/admin/hr" -WebSession $session
Check ($r.StatusCode -eq 200) "GET /admin/hr status 200"
Check (Contains-Text $r.Content 'Personel') "HR page loaded"
Check (Contains-Text $r.Content 'Toplam Personel') "KPI Total Employees present"

$hrCsrf = Csrf $r.Content
Check ($hrCsrf.Length -gt 20) "Got HR CSRF token"

# Add Employee
$empName = "Kemal Celik " + (Get-Random -Minimum 100 -Maximum 999)
$r = Http-Req "$base/admin/hr/employee" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $hrCsrf
  full_name = $empName
  department = 'Ön Büro & Resepsiyon'
  position_title = 'Resepsiyon Şefi'
  tc_kimlik = '12345678901'
  phone = '+90 532 111 2233'
  email = 'kemal.celik@hotel.local'
  salary = '38000'
  currency = 'TRY'
  start_date = '2026-03-01'
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST new employee success"

$hrCsrf = Csrf $r.Content
if (!$hrCsrf) {
  $r = Http-Req "$base/admin/hr" -WebSession $session
  $hrCsrf = Csrf $r.Content
}

# Add Recruitment Candidate
$candName = "Ayse Korkmaz " + (Get-Random -Minimum 100 -Maximum 999)
$r = Http-Req "$base/admin/hr/candidate" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $hrCsrf
  candidate_name = $candName
  position_applied = 'Kat Hizmetleri Şefi'
  phone = '+90 555 444 3322'
  email = 'ayse.korkmaz@hotel.local'
  stage = 'interview'
  interview_date = '2026-09-18'
  notes = '5 yillik 5 yildizli otel housekeeping tecrubesi var.'
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST candidate success"

# Verify Employee and Candidate appear
$r = Http-Req "$base/admin/hr" -WebSession $session
Check (Contains-Text $r.Content $empName) "Employee appears in employee table"
Check (Contains-Text $r.Content $candName) "Candidate appears in recruiting pipeline"

# ══════════════════════════════════════════════════════════════════
# MODULE 5: ODA TEMİZLİĞİ & KAT HİZMETLERİ (/admin/housekeeping)
# ══════════════════════════════════════════════════════════════════
Write-Output "`n--- Module 5: Housekeeping, Room Tracking & Maintenance ---"
$r = Http-Req "$base/admin/housekeeping" -WebSession $session
Check ($r.StatusCode -eq 200) "GET /admin/housekeeping status 200"
Check (Contains-Text $r.Content 'Housekeeping') "Housekeeping page loaded"
Check (Contains-Text $r.Content 'Temizlik') "Room Rack Matrix loaded"

$propMatch = [regex]::Match($r.Content, 'name="property_id"[^>]*value="([^"]*)"')
$activePropId = if ($propMatch.Success) { $propMatch.Groups[1].Value } else { '' }

$hkCsrf = Csrf $r.Content
Check ($hkCsrf.Length -gt 20) "Got Housekeeping CSRF token"

# Assign Housekeeping Task
$roomCode = "ODA-10" + (Get-Random -Minimum 1 -Maximum 9)
$r = Http-Req "$base/admin/housekeeping/task" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $hkCsrf
  property_id = $activePropId
  room_code = $roomCode
  assigned_staff = 'Fatma Yilmaz (Kat Gorevlisi)'
  task_type = 'daily_clean'
  notes = 'Cikis sonrasi detayli temizlik ve mini bar kontrolu.'
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST housekeeping task success"

$hkCsrf = Csrf $r.Content
if (!$hkCsrf) {
  $r = Http-Req "$base/admin/housekeeping" -WebSession $session
  $hkCsrf = Csrf $r.Content
}

# Open Maintenance Ticket
$r = Http-Req "$base/admin/housekeeping/maintenance" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $hkCsrf
  property_id = $activePropId
  room_code = $roomCode
  issue_title = 'Klima Sogutmuyor ve Ses Yapiyor'
  description = 'Oda klimasi calisiyor ancak ortam sogumuyor, fan kontrol edilmeli.'
  priority = 'urgent'
}
Check ($r.StatusCode -eq 200 -or $r.StatusCode -eq 303 -or $r.StatusCode -eq 302) "POST maintenance ticket success"

# Verify Task and Maintenance Ticket appear
$r = Http-Req "$base/admin/housekeeping" -WebSession $session
Check (Contains-Text $r.Content $roomCode) "Room task appears in tasks list"
Check (Contains-Text $r.Content 'Klima') "Maintenance ticket appears in tickets table"

Write-Output "`n========================================================"
Write-Output "ALL 5 ENTERPRISE EXPANSION MODULE TESTS PASSED 100%!"
Write-Output "========================================================"

