# Tek-ornek garantisi: isci zaten calisiyorsa yeni kopya baslatmaz.
# ensure-supplier-expiry-worker.ps1 ile ayni kalip; ek olarak kendi
# ortamini yukler (env.ps1), boylece bagimsiz cagrimda da calisir.
. "$PSScriptRoot/env.ps1"
New-Item -ItemType Directory -Path (Join-Path $ProjectRoot '.local') -Force | Out-Null
$workerPath = Join-Path $PSScriptRoot 'auth-session-expiry-worker.ps1'
$existing = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($workerPath) } |
  Select-Object -First 1
if (-not $existing) {
  Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$workerPath) `
    -WorkingDirectory $ProjectRoot -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $ProjectRoot '.local/auth-session-expiry-worker.out.log') `
    -RedirectStandardError (Join-Path $ProjectRoot '.local/auth-session-expiry-worker.err.log')
}
