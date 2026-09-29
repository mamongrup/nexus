$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $projectRoot '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw '.env bulunamadı.' }
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  $index = $line.IndexOf('=')
  if ($index -gt 0 -and !$line.StartsWith('#')) {
    Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim()
  }
}
. (Join-Path $PSScriptRoot 'env.ps1')
$savedPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  & "$PgBin/psql.exe" -X -w -v ON_ERROR_STOP=1 -U $env:PGOWNER `
    -f (Join-Path $projectRoot 'test/reservation_status_requires_booking.sql')
  if ($LASTEXITCODE -ne 0) { throw 'NEXUS reservation status contract failed.' }
} finally {
  $env:PGPASSWORD = $savedPassword
}
