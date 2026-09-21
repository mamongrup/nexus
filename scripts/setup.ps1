$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $ProjectRoot
New-Item -ItemType Directory -Force -Path '.local' | Out-Null
function New-Secret { [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant() }
if (!(Test-Path -LiteralPath '.env')) {
  $owner = New-Secret; $app = New-Secret; $secret = New-Secret; $admin = (New-Secret).Substring(0,24)
  @("APP_ENV=development","APP_PORT=8081","APP_ORIGIN=http://127.0.0.1:8081","PGHOST=127.0.0.1","PGPORT=5433","PGDATABASE=nexustraveltech","PGUSER=nexus_app","PGPASSWORD=$app","PGOWNER=nexus_owner","PGOWNER_PASSWORD=$owner","SECRET_KEY_BASE=$secret","ADMIN_EMAIL=admin@nexus.local","ADMIN_PASSWORD=$admin") | Set-Content -LiteralPath '.env' -Encoding utf8
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
