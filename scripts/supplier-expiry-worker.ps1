$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$pg = (Get-Command psql -ErrorAction Stop).Source
$env:PGPASSWORD = $env:PGOWNER_PASSWORD
while ($true) {
  try {
    & $pg -X -w -v ON_ERROR_STOP=1 -At -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $env:PGDATABASE -c 'select onboarding.reopen_expired_applications()' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Tedarikçi belge süre denetimi başarısız.' }
  } catch {
    Add-Content -LiteralPath (Join-Path $ProjectRoot '.local/supplier-expiry-error.log') -Value "$(Get-Date -Format o) $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 3600
}
