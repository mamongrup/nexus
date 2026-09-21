. "$PSScriptRoot/env.ps1"
$appPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD=$env:PGOWNER_PASSWORD
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -c 'CREATE SCHEMA IF NOT EXISTS system; CREATE TABLE IF NOT EXISTS system.schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());'
  if ($LASTEXITCODE -ne 0) { throw 'Migration tablosu oluşturulamadı' }
  foreach($file in Get-ChildItem -LiteralPath "$ProjectRoot/db/migrations" -Filter '*.sql' | Sort-Object Name) {
    $version=$file.BaseName; $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $old = & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT checksum FROM system.schema_migrations WHERE version='$version'"
    if ($old) { if ($old -ne $hash) { throw "Uygulanmış migration değişmiş: $version" }; continue }
    $content=Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    $sql="BEGIN;`n$content`nINSERT INTO system.schema_migrations(version,checksum) VALUES ('$version','$hash');`nCOMMIT;"
    $temp=Join-Path $ProjectRoot '.local/migration.sql'
    $sql | Set-Content -LiteralPath $temp -Encoding utf8
    try { & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f $temp; if ($LASTEXITCODE -ne 0) { throw "Migration başarısız: $version" } }
    finally { Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue }
  }
} finally { $env:PGPASSWORD=$appPassword }

