. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN
$demoPassword = if ($env:ALLOW_DEMO_PASSWORDS -eq 'true') { 'password123' } else { $null }

function Test-Login($email, $pass, $roleName) {
  $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $r1 = Invoke-WebRequest -Uri "$base/login" -WebSession $session -UseBasicParsing
  $csrf = [regex]::Match($r1.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value
  
  $r2 = Invoke-WebRequest -Uri "$base/login" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
    csrf = $csrf
    email = $email
    password = $pass
  } -UseBasicParsing

  $r3 = Invoke-WebRequest -Uri "$base/admin" -WebSession $session -UseBasicParsing
  Write-Host ("Role: {0,-12} | Email: {1,-24} | Login: {2} | /admin: {3}" -f $roleName, $email, $r2.StatusCode, $r3.StatusCode)
}

Test-Login 'admin@nexus.local' $(if ($env:ADMIN_PASSWORD) { $env:ADMIN_PASSWORD } elseif ($demoPassword) { $demoPassword } else { throw 'ADMIN_PASSWORD is required. Set ALLOW_DEMO_PASSWORDS=true only for local demo accounts.' }) 'Admin'
Test-Login 'supplier@nexus.local' $(if ($env:SUPPLIER_PASSWORD) { $env:SUPPLIER_PASSWORD } elseif ($demoPassword) { $demoPassword } else { throw 'SUPPLIER_PASSWORD is required. Set ALLOW_DEMO_PASSWORDS=true only for local demo accounts.' }) 'Tedarikci'
Test-Login 'agency@nexus.local' $(if ($env:AGENCY_PASSWORD) { $env:AGENCY_PASSWORD } elseif ($demoPassword) { $demoPassword } else { throw 'AGENCY_PASSWORD is required. Set ALLOW_DEMO_PASSWORDS=true only for local demo accounts.' }) 'Acente'
