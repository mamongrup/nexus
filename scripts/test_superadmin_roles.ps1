# test_superadmin_roles.ps1
# End-to-end verification of Super Admin Sub-Users and Platform Staff Roles

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/env.ps1"
$BaseUrl = if ($env:APP_ORIGIN) { $env:APP_ORIGIN } else { "http://127.0.0.1:8081" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   TEST SUITE: SUPER ADMIN SUB-USERS & PLATFORM ROLES" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

function Csrf($html) {
  $match = [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"')
  if (-not $match.Success) {
    $match = [regex]::Match($html, 'value="([^"]+)"[^>]*name="csrf"')
  }
  return $match.Groups[1].Value
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

# ------------------------------------------------------------
# 1. Super Admin Owner Login
# ------------------------------------------------------------
Write-Host "`n--- 1. Login as Super Admin Owner (admin@nexus.local) ---" -ForegroundColor Yellow
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $adminSession
$csrf = Csrf $r.Content

$adminPass = if ($env:ADMIN_PASSWORD) { $env:ADMIN_PASSWORD } else { "password123" }
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $adminSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "admin@nexus.local"
  password = $adminPass
}
if ($r.StatusCode -ne 200) { throw "Super Admin login failed" }
Write-Host " [PASS] Super Admin Owner logged in successfully." -ForegroundColor Green

# ------------------------------------------------------------
# 2. Verify Platform Headquarters Cockpit & Sub-Users Listing
# ------------------------------------------------------------
Write-Host "`n--- 2. Verify Team Cockpit lists all Platform Sub-Roles ---" -ForegroundColor Yellow
$r = Http-Req "$BaseUrl/admin/users" -WebSession $adminSession
if ($r.StatusCode -ne 200) { throw "Cannot access /admin/users" }

$expectedSubUsers = @(
  "operasyon@nexus.local", "operations_director",
  "moderator@nexus.local", "content_moderator",
  "finans@nexus.local", "finance_manager",
  "onboarding@nexus.local", "onboarding_specialist",
  "ai-muhendis@nexus.local", "ai_pricing_specialist",
  "destek@nexus.local", "support_specialist"
)

foreach ($kw in $expectedSubUsers) {
  if ($r.Content -like "*$kw*") {
    Write-Host " [PASS] Found sub-user in cockpit: '$kw'" -ForegroundColor Green
  } else {
    throw "Missing expected platform sub-user keyword: '$kw'"
  }
}

# ------------------------------------------------------------
# 3. Super Admin Creates a New Custom Sub-User (Quality Inspector)
# ------------------------------------------------------------
Write-Host "`n--- 3. Super Admin creates a new Sub-User ---" -ForegroundColor Yellow
$csrf = Csrf $r.Content
# Extract nexus organization tenant id
$nexusOrgMatch = [regex]::Match($r.Content, '<option value="([a-f0-9\-]+)">NEXUS TravelTech')
if (-not $nexusOrgMatch.Success) {
  $nexusOrgMatch = [regex]::Match($r.Content, '<option value="([a-f0-9\-]+)">[^<]*nexus')
}
$nexusTenantId = $nexusOrgMatch.Groups[1].Value

$r = Http-Req "$BaseUrl/admin/users" -Method Post -WebSession $adminSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  tenant = $nexusTenantId
  name = "Gulsah Kalite Denetcisi"
  email = "kalite-denetim@nexus.local"
  role = "content_moderator"
  password = "password123"
}
if ($r.StatusCode -ne 200 -and $r.StatusCode -ne 302) { throw "Failed to create new sub-user" }
Write-Host " [PASS] Created new platform sub-user (kalite-denetim@nexus.local) as content_moderator." -ForegroundColor Green

# ------------------------------------------------------------
# 4. Role 1: Platform Operasyon Direktörü (operations_director)
# ------------------------------------------------------------
Write-Host "`n--- 4. Test Role: Operasyon Direktörü (operasyon@nexus.local) ---" -ForegroundColor Yellow
$opSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $opSession
$csrf = Csrf $r.Content
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $opSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "operasyon@nexus.local"
  password = "password123"
}
if ($r.StatusCode -ne 200) { throw "operasyon@nexus.local login failed" }
Write-Host " [PASS] Operasyon Direktörü logged in." -ForegroundColor Green

# Operasyon Direktörü can manage team (/admin/users)
$r = Http-Req "$BaseUrl/admin/users" -WebSession $opSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] Operasyon Direktörü can access /admin/users team cockpit." -ForegroundColor Green
} else {
  throw "Operasyon Direktörü should have access to /admin/users"
}

# Operasyon Direktörü CANNOT access system settings (/admin/settings - restricted to master owner)
$r = Http-Req "$BaseUrl/admin/settings" -WebSession $opSession
if ($r.StatusCode -eq 403) {
  Write-Host " [PASS] Operasyon Direktörü CANNOT access /admin/settings (Restricted to Super Owner - 403 Forbidden)." -ForegroundColor Green
} else {
  throw "Operasyon Direktörü should not access core /admin/settings"
}

# ------------------------------------------------------------
# 5. Role 2: İlan & İçerik Moderatörü (content_moderator)
# ------------------------------------------------------------
Write-Host "`n--- 5. Test Role: İlan Moderatörü (moderator@nexus.local) ---" -ForegroundColor Yellow
$modSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $modSession
$csrf = Csrf $r.Content
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $modSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "moderator@nexus.local"
  password = "password123"
}
if ($r.StatusCode -ne 200) { throw "moderator@nexus.local login failed" }
Write-Host " [PASS] İlan Moderatörü logged in." -ForegroundColor Green

# Moderatör can access category fields (/admin/category-fields/hotel)
$r = Http-Req "$BaseUrl/admin/category-fields/hotel" -WebSession $modSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] İlan Moderatörü can access /admin/category-fields/hotel." -ForegroundColor Green
} else {
  throw "Moderatör should access category-fields"
}

# Moderatör CANNOT access /admin/users (403 Forbidden)
$r = Http-Req "$BaseUrl/admin/users" -WebSession $modSession
if ($r.StatusCode -eq 403) {
  Write-Host " [PASS] İlan Moderatörü CANNOT access /admin/users (403 Forbidden)." -ForegroundColor Green
} else {
  throw "Moderatör should be 403 on /admin/users"
}

# Moderatör CANNOT access /admin/accounting (403 Forbidden)
$r = Http-Req "$BaseUrl/admin/accounting" -WebSession $modSession
if ($r.StatusCode -eq 403) {
  Write-Host " [PASS] İlan Moderatörü CANNOT access accounting/finance (403 Forbidden)." -ForegroundColor Green
} else {
  throw "Moderatör should be 403 on /admin/accounting"
}

# ------------------------------------------------------------
# 6. Role 3: Finans & Mutabakat Müdürü (finance_manager)
# ------------------------------------------------------------
Write-Host "`n--- 6. Test Role: Finans Müdürü (finans@nexus.local) ---" -ForegroundColor Yellow
$finSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $finSession
$csrf = Csrf $r.Content
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $finSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "finans@nexus.local"
  password = "password123"
}
if ($r.StatusCode -ne 200) { throw "finans@nexus.local login failed" }
Write-Host " [PASS] Finans Müdürü logged in." -ForegroundColor Green

# Finans Müdürü can access /admin/accounting and /admin/einvoice
$r = Http-Req "$BaseUrl/admin/accounting" -WebSession $finSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] Finans Müdürü can access /admin/accounting." -ForegroundColor Green
} else {
  throw "Finans Müdürü should access accounting"
}

$r = Http-Req "$BaseUrl/admin/einvoice" -WebSession $finSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] Finans Müdürü can access /admin/einvoice (Uyumsoft)." -ForegroundColor Green
} else {
  throw "Finans Müdürü should access einvoice"
}

# Finans Müdürü CANNOT access /admin/users
$r = Http-Req "$BaseUrl/admin/users" -WebSession $finSession
if ($r.StatusCode -eq 403) {
  Write-Host " [PASS] Finans Müdürü CANNOT access /admin/users (403 Forbidden)." -ForegroundColor Green
} else {
  throw "Finans Müdürü should be 403 on /admin/users"
}

# ------------------------------------------------------------
# 7. Role 4: Tedarikçi İlişkileri & Onboarding Uzmanı (onboarding_specialist)
# ------------------------------------------------------------
Write-Host "`n--- 7. Test Role: Onboarding Uzmanı (onboarding@nexus.local) ---" -ForegroundColor Yellow
$onbSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $onbSession
$csrf = Csrf $r.Content
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $onbSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "onboarding@nexus.local"
  password = "password123"
}
if ($r.StatusCode -ne 200) { throw "onboarding@nexus.local login failed" }
Write-Host " [PASS] Onboarding Uzmanı logged in." -ForegroundColor Green

$r = Http-Req "$BaseUrl/admin/applications" -WebSession $onbSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] Onboarding Uzmanı can access /admin/applications." -ForegroundColor Green
} else {
  throw "Onboarding Uzmanı should access applications"
}

# Onboarding Uzmanı CANNOT access /admin/users
$r = Http-Req "$BaseUrl/admin/users" -WebSession $onbSession
if ($r.StatusCode -eq 403) {
  Write-Host " [PASS] Onboarding Uzmanı CANNOT access /admin/users (403 Forbidden)." -ForegroundColor Green
} else {
  throw "Onboarding Uzmanı should be 403 on /admin/users"
}

# ------------------------------------------------------------
# 8. Role 5: AI & Fiyatlama Mühendisi (ai_pricing_specialist)
# ------------------------------------------------------------
Write-Host "`n--- 8. Test Role: AI & Fiyatlama Mühendisi (ai-muhendis@nexus.local) ---" -ForegroundColor Yellow
$aiSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $aiSession
$csrf = Csrf $r.Content
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $aiSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "ai-muhendis@nexus.local"
  password = "password123"
}
if ($r.StatusCode -ne 200) { throw "ai-muhendis@nexus.local login failed" }
Write-Host " [PASS] AI & Fiyatlama Mühendisi logged in." -ForegroundColor Green

$r = Http-Req "$BaseUrl/admin/ai-hub" -WebSession $aiSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] AI Mühendisi can access /admin/ai-hub." -ForegroundColor Green
} else {
  throw "AI Mühendisi should access ai-hub"
}

$r = Http-Req "$BaseUrl/admin/rate-shopper" -WebSession $aiSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] AI Mühendisi can access /admin/rate-shopper." -ForegroundColor Green
} else {
  throw "AI Mühendisi should access rate-shopper"
}

# ------------------------------------------------------------
# 9. Role 6: Platform Destek Sorumlusu (support_specialist)
# ------------------------------------------------------------
Write-Host "`n--- 9. Test Role: Platform Destek (destek@nexus.local) ---" -ForegroundColor Yellow
$supSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$BaseUrl/login" -WebSession $supSession
$csrf = Csrf $r.Content
$r = Http-Req "$BaseUrl/login" -Method Post -WebSession $supSession -Headers @{Origin = $BaseUrl} -Body @{
  csrf = $csrf
  email = "destek@nexus.local"
  password = "password123"
}
if ($r.StatusCode -ne 200) { throw "destek@nexus.local login failed" }
Write-Host " [PASS] Destek Sorumlusu logged in." -ForegroundColor Green

$r = Http-Req "$BaseUrl/admin/messages" -WebSession $supSession
if ($r.StatusCode -eq 200) {
  Write-Host " [PASS] Destek Sorumlusu can access /admin/messages (Inbox)." -ForegroundColor Green
} else {
  throw "Destek Sorumlusu should access messages"
}

# Destek Sorumlusu CANNOT access /admin/users (403 Forbidden)
$r = Http-Req "$BaseUrl/admin/users" -WebSession $supSession
if ($r.StatusCode -eq 403) {
  Write-Host " [PASS] Destek Sorumlusu CANNOT access /admin/users (403 Forbidden)." -ForegroundColor Green
} else {
  throw "Destek Sorumlusu should be 403 on /admin/users"
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "   ALL SUPER ADMIN SUB-USERS & ROLES TESTS PASSED (100%)!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
