. "$PSScriptRoot/env.ps1"
Set-Location -LiteralPath $ProjectRoot
& "$PSScriptRoot/start-db.ps1"
& "$PSScriptRoot/config-key.ps1"
try {
 $health=Invoke-RestMethod "$env:APP_ORIGIN/v1/health" -TimeoutSec 2
 if ($health.service -eq 'nexustraveltech' -and $health.database -eq 'ready') { Write-Output "NEXUS ve PostgreSQL hazır: $env:APP_ORIGIN/admin"; return }
} catch {}
$occupied=Get-NetTCPConnection -LocalPort ([int]$env:APP_PORT) -State Listen -ErrorAction SilentlyContinue
if ($occupied) { throw "Port $env:APP_PORT başka bir uygulama tarafından kullanılıyor." }
& "$PSScriptRoot/prepare-build.ps1"
gleam build
if ($LASTEXITCODE -ne 0) { throw 'Derleme başarısız' }
# Only the runtime DB password and session secret are inherited by the web process.
Remove-Item Env:PGOWNER_PASSWORD,Env:ADMIN_PASSWORD,Env:SUPPLIER_PASSWORD,Env:AGENCY_PASSWORD -ErrorAction SilentlyContinue
$p=Start-Process -FilePath 'C:/laragon/bin/gleam/gleam.exe' -ArgumentList @('run') -WorkingDirectory $ProjectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput "$ProjectRoot/.local/server.log" -RedirectStandardError "$ProjectRoot/.local/server-error.log"
@{pid=$p.Id;started=$p.StartTime.ToUniversalTime().ToString('o');root=$ProjectRoot} | ConvertTo-Json | Set-Content -LiteralPath "$ProjectRoot/.local/server-process.json"
$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
 try {
  $health = Invoke-RestMethod "$env:APP_ORIGIN/v1/health" -TimeoutSec 1
  if ($health.service -eq 'nexustraveltech' -and $health.database -eq 'ready') { $ready = $true; break }
 } catch {}
 Start-Sleep -Milliseconds 500
}
if (!$ready) { throw 'NEXUS hazır duruma gelemedi. .local/server-error.log dosyasını kontrol edin.' }
Write-Output "NEXUS ve PostgreSQL hazır: $env:APP_ORIGIN/admin"
