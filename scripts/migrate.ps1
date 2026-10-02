param([string]$Database = '')
. "$PSScriptRoot/env.ps1"
# Optional explicit target (fresh-db-smoke.ps1). Empty = .env default.
if ($Database) { $env:PGDATABASE = $Database }
$Psql = (Get-Command psql -ErrorAction Stop).Source
New-Item -ItemType Directory -Path (Join-Path $ProjectRoot '.local') -Force | Out-Null
# Checksum is taken over the normalised text, never over raw file bytes.
# git is configured with core.autocrlf=true, so a checkout rewrites LF as CRLF
# and a commit rewrites it back. Hashing the raw file made every recorded
# checksum depend on when git last touched the file, which is not a property
# of the migration. Normalising to LF makes the checksum stable across
# platforms, checkouts and clones.
function Get-MigrationChecksum($path) {
  $text = [System.IO.File]::ReadAllText($path)
  $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
}
$appPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  # Wrong-database guard: the acente project's root schema is 'agency'. If it
  # exists in the target database, .env points at an agency database and the
  # platform migration chain must never touch it.
  $foreignSchema = ((& $Psql -X -w -U $env:PGOWNER -Atc "SELECT count(*) FROM pg_namespace WHERE nspname='agency'") | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Yanlış veritabanı kontrolü çalıştırılamadı' }
  if ($foreignSchema -ne '0') { throw "Hedef veritabanı bir acente veritabanı gibi görünüyor: 'agency' şeması mevcut ($($env:PGDATABASE)). Platform migration'ları uygulanmadı; .env içindeki PGDATABASE/PGPORT değerlerini kontrol edin." }
  & $Psql -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -c 'CREATE SCHEMA IF NOT EXISTS system; CREATE TABLE IF NOT EXISTS system.schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());'
  if ($LASTEXITCODE -ne 0) { throw 'Migration tablosu oluşturulamadı' }
  foreach($file in Get-ChildItem -LiteralPath "$ProjectRoot/db/migrations" -Filter '*.sql' | Sort-Object Name) {
    $version=$file.BaseName; $hash=Get-MigrationChecksum $file.FullName
    $old = & $Psql -X -w -U $env:PGOWNER -Atc "SELECT checksum FROM system.schema_migrations WHERE version='$version'"
    if ($old) { if ($old -ne $hash) { throw "Uygulanmış migration değişmiş: $version" }; continue }
    $content=[System.IO.File]::ReadAllText($file.FullName) -replace "`r`n","`n" -replace "`r","`n"
    $sql="BEGIN;`n$content`nINSERT INTO system.schema_migrations(version,checksum) VALUES ('$version','$hash');`nCOMMIT;"
    $temp=Join-Path $ProjectRoot '.local/migration.sql'
    [System.IO.File]::WriteAllText($temp,$sql,(New-Object System.Text.UTF8Encoding($false)))
    try { & $Psql -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f $temp; if ($LASTEXITCODE -ne 0) { throw "Migration başarısız: $version" } }
    finally { Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue }
  }
} finally { $env:PGPASSWORD=$appPassword }
