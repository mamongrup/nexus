# Fresh-database smoke: runs the whole platform chain end to end on a
# throwaway empty database, outside CI too.
#   1) DROP IF EXISTS + CREATE a scratch database on the .env cluster
#   2) scripts/migrate.ps1 -Database <scratch> applies the migration chain
#      (190+ migrations, wrong-database guard included)
#   3) scripts/run-db-tests.ps1 -Database <scratch> runs the db/tests fixture
#      chain + the test/*.sql acceptance layer on it
#   4) DROP the scratch database (kept for inspection with -Keep)
# Guard rails: the name must be a safe identifier and must differ from the
# live .env database and system databases. ASCII only (PowerShell 5.1 ANSI
# rule for BOM-less UTF-8).
#
# Ornek:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fresh-db-smoke.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fresh-db-smoke.ps1 -Keep -SmokeDatabase nexus_fresh_smoke_dev
param(
  [string]$SmokeDatabase = 'nexus_fresh_smoke',
  [switch]$Keep
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$psql = (Get-Command psql -ErrorAction Stop).Source

if ($SmokeDatabase -notmatch '^[a-z_][a-z0-9_]{0,62}$') {
  throw "Invalid smoke database name: '$SmokeDatabase' (expected [a-z_][a-z0-9_]*)."
}
foreach ($reserved in @('postgres', 'template0', 'template1')) {
  if ($SmokeDatabase -eq $reserved) { throw "Smoke database name is reserved: $SmokeDatabase" }
}
$liveDatabase = $env:PGDATABASE
if (!$liveDatabase) { throw 'PGDATABASE is missing; run scripts/setup.ps1 first.' }
if ($SmokeDatabase -eq $liveDatabase) {
  throw "Smoke database must differ from the live database '$liveDatabase'."
}

$env:PGPASSWORD = $env:PGOWNER_PASSWORD
$control = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $env:PGHOST, '-p', $env:PGPORT, '-U', $env:PGOWNER, '-d', 'postgres')

Write-Host "[fresh-db-smoke] 1/4 creating scratch database '$SmokeDatabase' (live: '$liveDatabase')"
& $psql @control -c "DROP DATABASE IF EXISTS $SmokeDatabase WITH (FORCE);" -c "CREATE DATABASE $SmokeDatabase OWNER $env:PGOWNER;"
if ($LASTEXITCODE -ne 0) { throw 'Scratch database could not be created.' }

try {
  Write-Host '[fresh-db-smoke] 2/4 applying the migration chain (scripts/migrate.ps1)'
  & "$PSScriptRoot/migrate.ps1" -Database $SmokeDatabase
  if ($LASTEXITCODE -ne 0) { throw 'Migration chain failed on the fresh database.' }

  Write-Host '[fresh-db-smoke] 3/4 running the SQL test chain (scripts/run-db-tests.ps1)'
  & "$PSScriptRoot/run-db-tests.ps1" -Database $SmokeDatabase
  if ($LASTEXITCODE -ne 0) { throw 'SQL test chain failed on the fresh database.' }
} finally {
  # migrate.ps1 restores PGPASSWORD to the app password it found on entry
  # (env.ps1 reloads .env unconditionally); re-assert the owner password
  # before touching the cluster again.
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  if (-not $Keep) {
    Write-Host "[fresh-db-smoke] 4/4 dropping scratch database '$SmokeDatabase'"
    & $psql @control -c "DROP DATABASE IF EXISTS $SmokeDatabase WITH (FORCE);" | Out-Null
  } else {
    Write-Host "[fresh-db-smoke] 4/4 kept scratch database '$SmokeDatabase' (-Keep)"
  }
}
Write-Host "[fresh-db-smoke] YESIL: migration chain + SQL test chain passed on an empty database."
