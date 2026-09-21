. "$PSScriptRoot/env.ps1"
if (!$env:NEXUS_CONFIG_KEY) {
 $appPassword=$env:PGPASSWORD
 try {
  $env:PGPASSWORD=$env:PGOWNER_PASSWORD
  $exists=& "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT to_regclass('settings.values') IS NOT NULL"
  if ($LASTEXITCODE -ne 0) { throw 'Şifreleme anahtarı ön kontrolü başarısız' }
  if ($exists -eq 't') {
   $count=& "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT count(*) FROM settings.values v JOIN settings.fields f USING(key) WHERE f.kind='secret' AND v.value<>''"
   if ($LASTEXITCODE -ne 0) { throw 'Şifreli ayarlar kontrol edilemedi' }
   if ([int]$count -gt 0) { throw 'Şifreli kayıtlar var ancak NEXUS_CONFIG_KEY yok. Mevcut anahtarı yedekten geri yükleyin.' }
  }
 } finally { $env:PGPASSWORD=$appPassword }
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $env:NEXUS_CONFIG_KEY = ($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join ''
  Add-Content -LiteralPath (Join-Path $ProjectRoot '.env') -Value "NEXUS_CONFIG_KEY=$env:NEXUS_CONFIG_KEY" -Encoding utf8
}
if ($env:NEXUS_CONFIG_KEY.Length -lt 64) { throw 'NEXUS_CONFIG_KEY geçersiz; kayıtlı anahtarı değiştirmeden yedeğini kontrol edin.' }
