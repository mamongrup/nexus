. "$PSScriptRoot/env.ps1"
$appPassword=$env:PGPASSWORD
try {
  $env:PGPASSWORD=$env:PGOWNER_PASSWORD
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/seed.sql"
  if ($LASTEXITCODE -ne 0) { throw 'Seed başarısız' }
} finally { $env:PGPASSWORD=$appPassword }
