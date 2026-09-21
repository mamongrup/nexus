# scripts/test_procedures.ps1
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

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginPage = Invoke-WebRequest "$base/login" -WebSession $session -UseBasicParsing
$csrf = Csrf $loginPage.Content

$loginBody = @{
  csrf = $csrf
  email = "supplier@nexus.local"
  password = $env:SUPPLIER_PASSWORD
}
$loginResp = Invoke-WebRequest "$base/login" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $loginBody -UseBasicParsing
Check ($loginResp.StatusCode -eq 200) "Supplier logged in successfully"

# 1. Procedures Directory Hub
$procResp = Invoke-WebRequest "$base/admin/listings/procedures" -WebSession $session -UseBasicParsing
Check ($procResp.StatusCode -eq 200) "/admin/listings/procedures accessible"
Check ($procResp.Content -match 'Prosed' -and $procResp.Content -match 'Rehber') "Procedures Hub title rendered"
Check ($procResp.Content.Contains("villa") -and $procResp.Content -match 'Villa') "Villa category present in Procedures Hub"
Check ($procResp.Content.Contains("yacht") -and $procResp.Content -match 'Yat') "Yacht category present in Procedures Hub"
Check ($procResp.Content.Contains("hotel") -and $procResp.Content -match 'Otel') "Hotel category present in Procedures Hub"
Check ($procResp.Content.Contains("car")) "Car rental present in Procedures Hub"
Check ($procResp.Content.Contains("transfer")) "Airport transfer present in Procedures Hub"
Check ($procResp.Content -match 'Ad.m') "Step badges rendered in Procedures Hub"

# 2. Villa Listing Form & Procedure
$villaResp = Invoke-WebRequest "$base/admin/listings/new/villa" -WebSession $session -UseBasicParsing
Check ($villaResp.StatusCode -eq 200) "/admin/listings/new/villa accessible"
Check ($villaResp.Content.Contains("7464")) "Villa 7464 Kanun legal basis displayed"
Check ($villaResp.Content -match 'Ad.m 1') "Villa Step 1 badge rendered"
Check ($villaResp.Content -match 'Ad.m 5') "Villa Step 5 badge rendered"
Check ($villaResp.Content.Contains("AKBS")) "AKBS police notification requirement mentioned"
Check ($villaResp.Content -match 'Belge') "Required documents section rendered"
Check ($villaResp.Content -match 'Kural') "Operational rules rendered"

# 3. Yacht Listing Form & Procedure
$yachtResp = Invoke-WebRequest "$base/admin/listings/new/yacht" -WebSession $session -UseBasicParsing
Check ($yachtResp.StatusCode -eq 200) "/admin/listings/new/yacht accessible"
Check ($yachtResp.Content -match 'Deniz Turizmi') "Yacht Deniz Turizmi legal basis displayed"
Check ($yachtResp.Content -match 'Elveri.lilik') "Yacht seaworthiness certificate listed"
Check ($yachtResp.Content -match 'Ad.m 1') "Yacht Step 1 badge rendered"

# 4. Hotel Listing Form & Procedure
$hotelResp = Invoke-WebRequest "$base/admin/listings/new/hotel" -WebSession $session -UseBasicParsing
Check ($hotelResp.StatusCode -eq 200) "/admin/listings/new/hotel accessible"
Check ($hotelResp.Content -match 'Turizm Tesisleri') "Hotel regulation basis displayed"
Check ($hotelResp.Content -match 'Ad.m 1') "Hotel Step 1 rendered"

# 5. Car Rental Listing Form & Procedure
$carResp = Invoke-WebRequest "$base/admin/listings/new/car" -WebSession $session -UseBasicParsing
Check ($carResp.StatusCode -eq 200) "/admin/listings/new/car accessible"
Check ($carResp.Content.Contains("KAB")) "Car rental KABIS regulation displayed"
Check ($carResp.Content -match 'Ad.m 1') "Car Step 1 rendered"

# 6. Admin Access to Listings and Procedures
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminLoginPage = Invoke-WebRequest "$base/login" -WebSession $adminSession -UseBasicParsing
$adminCsrf = Csrf $adminLoginPage.Content
$adminLoginResp = Invoke-WebRequest "$base/login" -Method Post -WebSession $adminSession -Headers @{Origin=$base} -Body @{
  csrf = $adminCsrf
  email = "admin@nexus.local"
  password = $env:ADMIN_PASSWORD
} -UseBasicParsing
Check ($adminLoginResp.StatusCode -eq 200) "Admin logged in successfully"

$adminProcResp = Invoke-WebRequest "$base/admin/listings/procedures" -WebSession $adminSession -UseBasicParsing
Check ($adminProcResp.StatusCode -eq 200) "Admin has access to /admin/listings/procedures"

$adminNewResp = Invoke-WebRequest "$base/admin/listings/new/villa" -WebSession $adminSession -UseBasicParsing
Check ($adminNewResp.StatusCode -eq 200) "Admin has access to /admin/listings/new/villa"

Write-Host "ALL 24 CATEGORY PROCEDURE CHECKS PASSED WITH FLYING COLORS!" -ForegroundColor Cyan
