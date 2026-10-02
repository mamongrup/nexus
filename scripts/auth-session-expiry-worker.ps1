# Auth oturum bakim iscisi: suresi dolmus auth.sessions satirlarini siler.
# scripts/ensure-auth-session-expiry-worker.ps1 tek ornek garantisini saglar;
# start.ps1 her acilista onu cagirir. Kalip: supplier-expiry-worker.ps1 /
# agency-booking-expiry-worker.ps1. Bu dosya bilerek yalnizca ASCII yazar
# (Windows PowerShell 5.1 BOM'suz UTF-8'i ANSI okur).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$pg = (Get-Command psql -ErrorAction Stop).Source
$env:PGPASSWORD = $env:PGOWNER_PASSWORD
New-Item -ItemType Directory -Path (Join-Path $ProjectRoot '.local') -Force | Out-Null
$countLog = Join-Path $ProjectRoot '.local/auth-session-expiry.log'
$errorLog = Join-Path $ProjectRoot '.local/auth-session-expiry-error.log'

while ($true) {
  try {
    $deleted = & $pg -X -w -v ON_ERROR_STOP=1 -At -h $env:PGHOST -p $env:PGPORT `
      -U $env:PGOWNER -d $env:PGDATABASE `
      -c 'SELECT auth.purge_expired_sessions()' | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'auth session purge failed.' }
    $deleted = $deleted.Trim()
    if ($deleted -match '^\d+$' -and [int64]$deleted -gt 0) {
      Add-Content -LiteralPath $countLog -Value "$(Get-Date -Format o) purged=$deleted"
    }
  } catch {
    Add-Content -LiteralPath $errorLog -Value "$(Get-Date -Format o) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 300
}
