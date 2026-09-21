. "$PSScriptRoot/env.ps1"
foreach($key in @('SUPPLIER_PASSWORD','AGENCY_PASSWORD')) {
 if (![Environment]::GetEnvironmentVariable($key,'Process')) {
  $bytes = New-Object byte[] 16
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $secret = (($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join '').ToLowerInvariant()
  Add-Content -LiteralPath "$ProjectRoot/.env" -Value "$key=$secret" -Encoding utf8
  [Environment]::SetEnvironmentVariable($key,$secret,'Process')
 }
}
$saved=$env:PGPASSWORD
try {
 $env:PGPASSWORD=$env:PGOWNER_PASSWORD
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/workspaces.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Çalışma alanları kurulamadı' }
} finally { $env:PGPASSWORD=$saved }
