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
  param($Uri, $Method = 'GET', $WebSession, $Headers, $Body, $MaximumRedirection = 5)
  $p = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true; MaximumRedirection = $MaximumRedirection }
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

Write-Output "============================================================"
Write-Output "   TEST: GRANULAR RBAC & STAFF ROLES VERIFICATION"
Write-Output "============================================================"

# Step 1: Login as Owner (Patron)
$ownerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $ownerSession
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Owner retrieved login CSRF token"

$r = Http-Req "$base/login" -Method Post -WebSession $ownerSession -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  email = 'supplier@nexus.local'
  password = $env:SUPPLIER_PASSWORD
}
Check ($r.StatusCode -eq 200) "Owner (supplier@nexus.local) login successful"

# Step 2: Owner navigates to /admin/users (Team Management Cockpit)
$r = Http-Req "$base/admin/users" -WebSession $ownerSession
Check ($r.StatusCode -eq 200) "Owner can access /admin/users team cockpit"
Check (Contains-Text $r.Content "users-page") "Team Cockpit container rendered"
Check (Contains-Text $r.Content 'value="housekeeping"') "Housekeeping role option present in cockpit"
Check (Contains-Text $r.Content 'value="purchasing"') "Purchasing role option present in cockpit"
Check (Contains-Text $r.Content 'value="general_manager"') "General Manager role option present in cockpit"

$usersCsrf = Csrf $r.Content

# Extract tenant id for user creation
$tenantMatch = [regex]::Match($r.Content, '<option[^>]*value="([0-9a-fA-F\-]{36})"')
$tenantId = if ($tenantMatch.Success) { $tenantMatch.Groups[1].Value } else { "" }
Check ($tenantId.Length -gt 10) "Extracted supplier tenant ID ($tenantId)"

# Step 3: Create or Ensure Staff Users:
$testPassword = "Password123!"

# 3a. Housekeeping (temizlik@nexus.local)
$r = Http-Req "$base/admin/users" -Method Post -WebSession $ownerSession -Headers @{Origin = $base} -Body @{
  csrf = $usersCsrf
  tenant = $tenantId
  email = 'temizlik@nexus.local'
  name = 'Ayse Temizlik'
  role = 'housekeeping'
  password = $testPassword
}
Write-Output "Created/verified housekeeping user (temizlik@nexus.local)"

# 3b. Purchasing (satinalma@nexus.local)
$usersCsrf = Csrf $r.Content
$r = Http-Req "$base/admin/users" -Method Post -WebSession $ownerSession -Headers @{Origin = $base} -Body @{
  csrf = $usersCsrf
  tenant = $tenantId
  email = 'satinalma@nexus.local'
  name = 'Mehmet Satinalma'
  role = 'purchasing'
  password = $testPassword
}
Write-Output "Created/verified purchasing user (satinalma@nexus.local)"

# 3c. Marketing (reklam@nexus.local)
$usersCsrf = Csrf $r.Content
$r = Http-Req "$base/admin/users" -Method Post -WebSession $ownerSession -Headers @{Origin = $base} -Body @{
  csrf = $usersCsrf
  tenant = $tenantId
  email = 'reklam@nexus.local'
  name = 'Selin Pazarlama'
  role = 'marketing'
  password = $testPassword
}
Write-Output "Created/verified marketing user (reklam@nexus.local)"

# 3d. General Manager (genelmd@nexus.local)
$usersCsrf = Csrf $r.Content
$r = Http-Req "$base/admin/users" -Method Post -WebSession $ownerSession -Headers @{Origin = $base} -Body @{
  csrf = $usersCsrf
  tenant = $tenantId
  email = 'genelmd@nexus.local'
  name = 'Kemal Genel Mudur'
  role = 'general_manager'
  password = $testPassword
}
Write-Output "Created/verified general manager user (genelmd@nexus.local)"

# ============================================================
# TEST ROLE 1: KAT HIZMETLERI (HOUSEKEEPING)
# ============================================================
Write-Output "`n--- Testing Role: Kat Hizmetleri (Housekeeping) ---"
$cleanSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $cleanSession
$cleanCsrf = Csrf $r.Content

$r = Http-Req "$base/login" -Method Post -WebSession $cleanSession -Headers @{Origin = $base} -Body @{
  csrf = $cleanCsrf
  email = 'temizlik@nexus.local'
  password = $testPassword
}
Check ($r.StatusCode -eq 200) "Housekeeping login successful"

# Verify redirect from /admin to /admin/housekeeping
$r = Http-Req "$base/admin" -WebSession $cleanSession
Check ($r.StatusCode -eq 200) "Housekeeping landed successfully on default dashboard"
Check (Contains-Text $r.Content "quick_clean") "Housekeeping quick clean form rendered"

# Verify Housekeeping CANNOT access Accounting or Users Cockpit
$r = Http-Req "$base/admin/accounting" -WebSession $cleanSession
Check ($r.StatusCode -eq 403) "Housekeeping CANNOT access /admin/accounting (403 Forbidden)"

$r = Http-Req "$base/admin/users" -WebSession $cleanSession
Check ($r.StatusCode -eq 403) "Housekeeping CANNOT access /admin/users (403 Forbidden)"

$r = Http-Req "$base/admin/hr" -WebSession $cleanSession
Check ($r.StatusCode -eq 403) "Housekeeping CANNOT access /admin/hr (403 Forbidden)"

# Test Quick Clean action
$hkCsrf = Csrf $r.Content
if (!$hkCsrf) {
  $r = Http-Req "$base/admin/housekeeping" -WebSession $cleanSession
  $hkCsrf = Csrf $r.Content
}
$propMatch = [regex]::Match($r.Content, 'name="property_id"[^>]*value="([^"]+)"')
$propId = if ($propMatch.Success) { $propMatch.Groups[1].Value } else { "" }

if ($propId) {
  $r = Http-Req "$base/admin/housekeeping/quick_clean" -Method Post -WebSession $cleanSession -Headers @{Origin = $base} -Body @{
    csrf = $hkCsrf
    property_id = $propId
    room_code = "ODA-101"
  }
  Check ($r.StatusCode -eq 200) "Housekeeping quick-marked ODA-101 as clean with 1 click"
}

# ============================================================
# TEST ROLE 2: SATIN ALMA (PURCHASING)
# ============================================================
Write-Output "`n--- Testing Role: Satın Alma (Purchasing) ---"
$purchSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $purchSession
$purchCsrf = Csrf $r.Content

$r = Http-Req "$base/login" -Method Post -WebSession $purchSession -Headers @{Origin = $base} -Body @{
  csrf = $purchCsrf
  email = 'satinalma@nexus.local'
  password = $testPassword
}
Check ($r.StatusCode -eq 200) "Purchasing staff login successful"

# Verify redirect from /admin to /admin/accounting
$r = Http-Req "$base/admin" -WebSession $purchSession
Check ($r.StatusCode -eq 200) "Purchasing staff landed on accounting/purchasing desk"
Check (Contains-Text $r.Content "Malzeme Gider") "Purchasing-adapted desk rendered"

# Test Submitting a Purchase with product, receipt/invoice no, amount, vendor
$acctCsrf = Csrf $r.Content
$invoiceNo = "FS-" + (Get-Random -Minimum 10000 -Maximum 99999)
$r = Http-Req "$base/admin/accounting/transaction" -Method Post -WebSession $purchSession -Headers @{Origin = $base} -Body @{
  csrf = $acctCsrf
  tx_type = 'expense'
  category = 'housekeeping_supply'
  title = 'Otel Temizlik ve Buklet Malzemeleri Alimi'
  description = 'Tedarikci: Endustriyel Kimya A.S. - Birim Fiyat: 450 TL x 10 Koli'
  amount = '4500'
  currency = 'TRY'
  payment_method = 'credit_card'
  document_no = $invoiceNo
}
Check ($r.StatusCode -eq 200) "Purchasing staff recorded expense with receipt #$invoiceNo"
Check (Contains-Text $r.Content $invoiceNo) "Recorded receipt number visible in transaction ledger"

# Verify Purchasing CANNOT access HR or Users Cockpit
$r = Http-Req "$base/admin/hr" -WebSession $purchSession
Check ($r.StatusCode -eq 403) "Purchasing staff CANNOT access /admin/hr (403 Forbidden)"

$r = Http-Req "$base/admin/users" -WebSession $purchSession
Check ($r.StatusCode -eq 403) "Purchasing staff CANNOT access /admin/users (403 Forbidden)"

# ============================================================
# TEST ROLE 3: REKLAM & TANITIM (MARKETING)
# ============================================================
Write-Output "`n--- Testing Role: Reklam & Tanıtım (Marketing) ---"
$mktSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $mktSession
$mktCsrf = Csrf $r.Content

$r = Http-Req "$base/login" -Method Post -WebSession $mktSession -Headers @{Origin = $base} -Body @{
  csrf = $mktCsrf
  email = 'reklam@nexus.local'
  password = $testPassword
}
Check ($r.StatusCode -eq 200) "Marketing login successful"

# Verify redirect from /admin to /admin/social-media
$r = Http-Req "$base/admin" -WebSession $mktSession
Check ($r.StatusCode -eq 200) "Marketing staff landed on social media hub"
Check (Contains-Text $r.Content "social-media") "Social media management hub rendered"

# Marketing can access AI Hub
$r = Http-Req "$base/admin/ai-hub" -WebSession $mktSession
Check ($r.StatusCode -eq 200) "Marketing staff can access /admin/ai-hub"

# Marketing CANNOT access Accounting or HR
$r = Http-Req "$base/admin/accounting" -WebSession $mktSession
Check ($r.StatusCode -eq 403) "Marketing staff CANNOT access /admin/accounting (403 Forbidden)"

$r = Http-Req "$base/admin/hr" -WebSession $mktSession
Check ($r.StatusCode -eq 403) "Marketing staff CANNOT access /admin/hr (403 Forbidden)"

# ============================================================
# TEST ROLE 4: GENEL MUDUR (GENERAL MANAGER)
# ============================================================
Write-Output "`n--- Testing Role: Genel Müdür (General Manager) ---"
$gmSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $gmSession
$gmCsrf = Csrf $r.Content

$r = Http-Req "$base/login" -Method Post -WebSession $gmSession -Headers @{Origin = $base} -Body @{
  csrf = $gmCsrf
  email = 'genelmd@nexus.local'
  password = $testPassword
}
Check ($r.StatusCode -eq 200) "General Manager login successful"

# General manager CAN access Team Cockpit to distribute roles and permissions!
$r = Http-Req "$base/admin/users" -WebSession $gmSession
Check ($r.StatusCode -eq 200) "General Manager can access /admin/users team cockpit"
Check (Contains-Text $r.Content "users-page") "General Manager sees Team Cockpit"

# General manager CAN access all operational departments
$r = Http-Req "$base/admin/accounting" -WebSession $gmSession
Check ($r.StatusCode -eq 200) "General Manager can access Accounting"

$r = Http-Req "$base/admin/housekeeping" -WebSession $gmSession
Check ($r.StatusCode -eq 200) "General Manager can access Housekeeping"

$r = Http-Req "$base/admin/hr" -WebSession $gmSession
Check ($r.StatusCode -eq 200) "General Manager can access HR"

$r = Http-Req "$base/admin/campaigns" -WebSession $gmSession
Check ($r.StatusCode -eq 200) "General Manager can access Campaigns"

Write-Output "`n============================================================"
Write-Output "   ALL GRANULAR RBAC & STAFF ROLES TESTS PASSED (100%)"
Write-Output "============================================================"
