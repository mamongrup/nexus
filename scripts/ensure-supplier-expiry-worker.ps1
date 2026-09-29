$workerPath = Join-Path $PSScriptRoot 'supplier-expiry-worker.ps1'
$existing = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($workerPath) } |
  Select-Object -First 1
if (-not $existing) {
  Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$workerPath) `
    -WorkingDirectory $ProjectRoot -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $ProjectRoot '.local/supplier-expiry.log') `
    -RedirectStandardError (Join-Path $ProjectRoot '.local/supplier-expiry-stderr.log')
}
