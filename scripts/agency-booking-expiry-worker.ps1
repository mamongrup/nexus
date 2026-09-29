$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$pg = (Get-Command psql -ErrorAction Stop).Source
$env:PGPASSWORD = $env:PGOWNER_PASSWORD

while ($true) {
  try {
    & $pg -X -w -v ON_ERROR_STOP=1 -At -h $env:PGHOST -p $env:PGPORT `
      -U $env:PGOWNER -d $env:PGDATABASE `
      -c 'select partners.expire_unpaid_agency_bookings(100)' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Agency booking expiry failed.' }
    & $pg -X -w -v ON_ERROR_STOP=1 -At -h $env:PGHOST -p $env:PGPORT `
      -U $env:PGOWNER -d $env:PGDATABASE `
      -c "delete from partners.agency_booking_failures where last_at<now()-interval '90 days'" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Agency booking failure retention failed.' }
  } catch {
    Add-Content -LiteralPath (Join-Path $ProjectRoot '.local/agency-booking-expiry-error.log') `
      -Value "$(Get-Date -Format o) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 300
}
