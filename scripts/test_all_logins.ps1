. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

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

Test-Login 'admin@nexus.local' 'password123' 'Admin'
Test-Login 'supplier@nexus.local' 'password123' 'Tedarikci'
Test-Login 'agency@nexus.local' 'password123' 'Acente'
