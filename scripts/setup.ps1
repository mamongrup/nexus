$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $ProjectRoot
New-Item -ItemType Directory -Force -Path '.local' | Out-Null
function New-Secret {
  # RandomNumberGenerator::GetBytes(int) only exists on .NET Core, and this
  # project must also run on the Windows PowerShell 5.1 that ships with Windows.
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  (($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join '').ToLowerInvariant()
}
if (!(Test-Path -LiteralPath '.env')) {
  $owner = New-Secret; $app = New-Secret; $secret = New-Secret; $admin = New-Secret
  $supplier = New-Secret; $agency = New-Secret; $quality = New-Secret; $nexusApi = New-Secret
  @(
    "APP_ENV=development","APP_PORT=8081","APP_ORIGIN=http://127.0.0.1:8081",
    "PGHOST=127.0.0.1","PGPORT=5433","PGDATABASE=nexustraveltech","PGUSER=nexus_app",
    "PGPASSWORD=$app","PGOWNER=nexus_owner","PGOWNER_PASSWORD=$owner","SECRET_KEY_BASE=$secret",
    "ADMIN_EMAIL=admin@nexus.local","ADMIN_PASSWORD=$admin",
    "SUPPLIER_PASSWORD=$supplier","AGENCY_PASSWORD=$agency","QUALITY_PASSWORD=$quality",
    "NEXUS_API_KEY=$nexusApi",
    "# Leave empty to ignore X-Forwarded-For and rate limit on the socket peer.",
    "TRUSTED_PROXY_CIDRS="
  ) | Set-Content -LiteralPath '.env' -Encoding utf8
}
# Older checkouts predate the integration key and the proxy trust list. Append
# whatever is missing so re-running setup repairs an existing .env.
$existing = @{}
[IO.File]::ReadAllLines((Join-Path $ProjectRoot '.env')) | ForEach-Object {
  if ($_ -match '^([^=]+)=') { $existing[$Matches[1].Trim()] = $true }
}
$missing = @()
if (!$existing['NEXUS_API_KEY']) { $missing += "NEXUS_API_KEY=$(New-Secret)" }
if (!$existing['TRUSTED_PROXY_CIDRS']) { $missing += 'TRUSTED_PROXY_CIDRS=' }
if ($missing.Count -gt 0) {
  Add-Content -LiteralPath '.env' -Value $missing -Encoding utf8
}
. "$PSScriptRoot/env.ps1"
gleam deps download
if ($LASTEXITCODE -ne 0) { throw 'Paketler indirilemedi' }
& "$PSScriptRoot/prepare-build.ps1"
if (!(Test-Path -LiteralPath "$PgData/PG_VERSION")) {
  if (Test-Path -LiteralPath $PgData) { throw 'Veri klasörü var fakat geçerli küme değil; otomatik üzerine yazılmadı.' }
  $env:PGOWNER_PASSWORD | Set-Content -LiteralPath '.local/init-password' -NoNewline
  try {
    & "$PgBin/initdb.exe" -D $PgData -U $env:PGOWNER --pwfile='.local/init-password' --encoding=UTF8 --locale=C --auth-host=scram-sha-256 --auth-local=scram-sha-256
    if ($LASTEXITCODE -ne 0) { throw 'initdb başarısız' }
  } finally { Remove-Item -LiteralPath '.local/init-password' -ErrorAction SilentlyContinue }
  @("listen_addresses = '127.0.0.1'","port = 5433","password_encryption = 'scram-sha-256'","timezone = 'UTC'","log_timezone = 'UTC'","log_min_duration_statement = 1000") | Add-Content -LiteralPath "$PgData/postgresql.conf"
}
& "$PSScriptRoot/start-db.ps1"
$appPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  $env:NEXUS_APP_PASSWORD=$appPassword
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -d postgres -v ON_ERROR_STOP=1 -f 'db/bootstrap.sql'
  if ($LASTEXITCODE -ne 0) { throw 'Rol oluşturulamadı' }
  $exists = & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='nexustraveltech'"
  if ($exists -ne '1') {
    & "$PgBin/createdb.exe" -w -U $env:PGOWNER -O $env:PGOWNER -T template0 -E UTF8 nexustraveltech
    if ($LASTEXITCODE -ne 0) { throw 'Veritabanı oluşturulamadı' }
  }
} finally { $env:PGPASSWORD = $appPassword; Remove-Item Env:NEXUS_APP_PASSWORD -ErrorAction SilentlyContinue }
& "$PSScriptRoot/migrate.ps1"
& "$PSScriptRoot/seed.ps1"
& "$PSScriptRoot/workspaces.ps1"
Write-Output 'NEXUS veritabanı hazır. Giriş bilgileri yalnızca .env dosyasındadır.'
