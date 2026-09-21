# scripts/verify_admin_and_csp.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

function Csrf($html) {
  [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value
}

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginPage = Invoke-WebRequest "$base/login" -WebSession $session -UseBasicParsing
$csrf = Csrf $loginPage.Content

# Login as ADMIN (workspace: nexus)
$body = @{
  csrf = $csrf
  email = "admin@nexus.local"
  password = $env:ADMIN_PASSWORD
}
$loginResp = Invoke-WebRequest "$base/login" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $body -UseBasicParsing
Write-Host "Admin Login StatusCode:" $loginResp.StatusCode

# Check /admin/listings as ADMIN
$listings = Invoke-WebRequest "$base/admin/listings" -WebSession $session -UseBasicParsing
Write-Host "/admin/listings StatusCode:" $listings.StatusCode
Write-Host "Listings contains Bodrum Villa:" $listings.Content.Contains("Bodrum Sunset")
Write-Host "Listings contains /modules:" $listings.Content.Contains("/modules")

# Check /admin/listings/:id/modules as ADMIN
$cockpit = Invoke-WebRequest "$base/admin/listings/11111111-aaaa-4111-8111-111111111111/modules" -WebSession $session -UseBasicParsing
Write-Host "/admin/listings/.../modules StatusCode:" $cockpit.StatusCode
Write-Host "Cockpit contains PMS:" $cockpit.Content.Contains("PMS")
Write-Host "Cockpit contains KBS:" $cockpit.Content.Contains("KBS")
Write-Host "Cockpit contains WhatsApp:" $cockpit.Content.Contains("WhatsApp")
Write-Host "Cockpit contains e-Fatura:" $cockpit.Content.Contains("Fatura")

# Check CSP header on /ilanlar
$ilanlar = Invoke-WebRequest "$base/ilanlar" -UseBasicParsing
Write-Host "CSP header on /ilanlar:" $ilanlar.Headers['content-security-policy']
Write-Host "All Admin & CSP Verifications Complete!" -ForegroundColor Green
