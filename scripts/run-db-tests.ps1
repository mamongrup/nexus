# SQL test zinciri kosucusu - tek kaynak, capraz platform (pwsh).
#
# Iki fazi sirayla hedef veritabaninda kosturur:
#   1) db/tests/*.sql fixture zinciri - sira kritik: izolasyon/yasam-dongusu
#      fixture'lari sonrakilerin on kosuludur. Kanonik sira asagidaki
#      $ChainOrder dizisidir; scripts/test.ps1 ve CI bu betigi cagirdigi
#      icin sira artik hicbir yere ikinci kez kopyalanmaz.
#   2) test/*.sql kabul katmani - zincir fixture'larina dayanir, ada gore
#      sirali kosturulur.
#
# Baglanti cozumlemesi: parametre > ortam degiskeni > .env (PGOWNER/
# PGOWNER_PASSWORD yoksa PGUSER/PGPASSWORD kullanilir). Boylece hem yerel
# .env hem CI ortam degiskenleri hem de acik parametreler calisir.
#
# Not: Bu dosya bilerek yalnizca ASCII yazar. Windows PowerShell 5.1, BOM'suz
# UTF-8 betigi ANSI okur; em-dash gibi karakterlerin son bayti tirnak bytesi
# olarak cozulup betigi bozar (orn. 0x94 -> '"'). Turkce mesajlar diger
# betiklerdeki gibi ANSI terminalde bozuk gorunebilir, islev etkilenmez.
param(
  [string]$EnvFile,
  [string]$DbHost,
  [string]$Port,
  [string]$Database,
  [string]$Owner,
  [string]$OwnerPassword,
  [string]$Psql
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$EnvFile) { $EnvFile = Join-Path $root '.env' }
if (Test-Path -LiteralPath $EnvFile) {
  # Ortamda zaten tanimli anahtarlari .env ezmez (CI ortami onceliklidir).
  Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim(); $i = $line.IndexOf('=')
    if ($i -gt 0) {
      $k = $line.Substring(0, $i).Trim()
      if (![Environment]::GetEnvironmentVariable($k)) {
        Set-Item "Env:$k" $line.Substring($i + 1).Trim()
      }
    }
  }
}
if (!$DbHost) { $DbHost = $env:PGHOST }
if (!$Port) { $Port = $env:PGPORT }
if (!$Database) { $Database = $env:PGDATABASE }
if (!$Owner) { $Owner = if ($env:PGOWNER) { $env:PGOWNER } else { $env:PGUSER } }
if (!$OwnerPassword) { $OwnerPassword = if ($env:PGOWNER_PASSWORD) { $env:PGOWNER_PASSWORD } else { $env:PGPASSWORD } }
foreach ($pair in @(@('PGHOST', $DbHost), @('PGPORT', $Port), @('PGDATABASE', $Database), @('PGOWNER', $Owner), @('PGOWNER_PASSWORD', $OwnerPassword))) {
  if (!$pair[1]) { throw "Baglanti bilgisi eksik: $($pair[0]) (parametre, ortam degiskeni veya .env ile verilmeli)" }
}
if (!$Psql) {
  $Psql = if ($env:PSQL_EXECUTABLE) { $env:PSQL_EXECUTABLE }
  elseif (Test-Path -LiteralPath 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe') { 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe' }
  else { (Get-Command psql -ErrorAction Stop).Source }
}

# Kanonik fixture zinciri sirasi - yalnizca burada tanimlanir.
$ChainOrder = @(
  'isolation.sql',
  'reservation_lifecycle.sql',
  'settings_isolation.sql',
  'cms.sql',
  'ai_scope.sql',
  'ai_governance_and_finance.sql',
  'external_operation_truth.sql',
  'external_operation_existing_listing.sql',
  'frozen_quote_ledger.sql',
  'operational_provider_truth.sql',
  'external_operation_queue.sql',
  'external_operation_worker.sql',
  'external_operation_retry.sql',
  'marketplace_feed_v2.sql',
  'cny_currency.sql',
  'listing_module_scope.sql',
  'listing_review.sql',
  'supplier_application.sql',
  'sector_benchmarking.sql',
  'elite_hospitality_suite.sql',
  'category_values.sql'
)

$oldPassword = $env:PGPASSWORD
$script:ran = 0
function Invoke-SqlFile([string]$Path, [string]$Label) {
  Write-Host "::group::$Label"
  & $Psql -X -w -h $DbHost -p $Port -U $Owner -d $Database -v ON_ERROR_STOP=1 -f $Path
  $ok = ($LASTEXITCODE -eq 0)
  Write-Host "::endgroup::"
  if (!$ok) { throw "SQL testi basarisiz: $Label" }
  $script:ran++
}
try {
  $env:PGPASSWORD = $OwnerPassword
  $testsDir = Join-Path $root 'db/tests'
  if (Test-Path -LiteralPath $testsDir) {
    # Drift tripwire: listede olmayan bir db/tests/*.sql dosyasi sessizce
    # atlanmasin - zincire eklenen her dosya $ChainOrder'a da eklenmelidir.
    $unlisted = Get-ChildItem -LiteralPath $testsDir -Filter '*.sql' |
      Where-Object { $ChainOrder -notcontains $_.Name }
    if ($unlisted) {
      throw ("ChainOrder listesinde olmayan db/tests dosyalari: " + (($unlisted | ForEach-Object Name) -join ', '))
    }
    foreach ($name in $ChainOrder) {
      Invoke-SqlFile -Path (Join-Path $testsDir $name) -Label "db/tests/$name"
    }
  }
  $acceptance = Get-ChildItem -LiteralPath (Join-Path $root 'test') -Filter '*.sql' | Sort-Object Name
  if (!$acceptance) { throw 'Kabul testi bulunamadi: test/*.sql bos' }
  foreach ($file in $acceptance) {
    Invoke-SqlFile -Path $file.FullName -Label "test/$($file.Name)"
  }
  Write-Host "run-db-tests: YESIL - $script:ran SQL dosyasi gecti."
} finally {
  $env:PGPASSWORD = $oldPassword
}
