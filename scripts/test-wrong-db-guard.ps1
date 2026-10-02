# Wrong-database guard rejection test (platform side, cross-platform pwsh).
#
# Kanit: hedef veritabaninda acente kok semasi ('agency') varsa
# scripts/migrate.ps1 TUM psql adimlarindan ONCE reddetmeli ve hicbir DDL
# uygulamamali. Bu betik bunu gercek bir migrate.ps1 cagrisiyle simule eder:
#   1) kontrol kumesinde scratch veritabani yarat (DROP IF EXISTS + CREATE,
#      ayri -c cagrilarlari; tek -c "transaction block" hatasi verir)
#   2) scratch icinde yabanci acente semasini yarat (CREATE SCHEMA agency)
#   3) migrate.ps1'i -Database parametresiyle scratch'e yonlendir
#   4) red bekle: migrate'in throw mesaji yabanci semayi adlandirmali
#      (baska bir hata reddetme kaniti degildir)
#   5) DDL-yok iddiasi: 'system' semasi (migrate'in ilk adimi) hic
#      yaratilmamis olmali; 'agency' semasi dokunulmamis kalmali
#   6) finally: scratch veritabanini dus (kume temiz kalir, kosum idempotent)
#
# CI (test.yml) bu betigi owner kimlikleriyle cagirir; yerelde:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-wrong-db-guard.ps1
#
# Not: Bu dosya bilerek yalnizca ASCII yazar. Windows PowerShell 5.1,
# BOM'suz UTF-8 betigi ANSI okur; ASCII disi karakterler betigi bozabilir.
param(
  [string]$ScratchDatabase = 'wrong_db_guard_sim'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$psql = (Get-Command psql -ErrorAction Stop).Source

if ($ScratchDatabase -notmatch '^[a-z_][a-z0-9_]{0,62}$') { throw "Gecersiz scratch veritabani adi: '$ScratchDatabase' (beklenen [a-z_][a-z0-9_]*)" }
foreach ($reserved in @('postgres', 'template0', 'template1')) {
  if ($ScratchDatabase -eq $reserved) { throw "Scratch veritabani adi sistem veritabani olamaz: $ScratchDatabase" }
}
if (!$env:PGDATABASE) { throw 'PGDATABASE eksik; once scripts/setup.ps1 kosulmali.' }
if ($ScratchDatabase -eq $env:PGDATABASE) { throw "Scratch veritabani canli veritabanindan farkli olmali: $($env:PGDATABASE)" }

# migrate.ps1 -Database ile hedefi ezer ama PGPASSWORD'u owner sifresiyle
# kurar; kontrol kumesi sorgulari icin de owner kimligi kullanilir.
$control = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $env:PGHOST, '-p', $env:PGPORT, '-U', $env:PGOWNER, '-d', 'postgres')
$target = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', $env:PGHOST, '-p', $env:PGPORT, '-U', $env:PGOWNER, '-d', $ScratchDatabase)

# env.ps1 .env'i koklu olarak yeniden yukler; sonunda eski degerlere geri koy.
$oldEnv = @{}
foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD', 'PGOWNER', 'PGOWNER_PASSWORD')) {
  $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD

  Write-Host "[wrong-db-guard] 1/5 scratch veritabani hazirlaniyor: $ScratchDatabase"
  & $psql @control -c "DROP DATABASE IF EXISTS $ScratchDatabase WITH (FORCE);" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani dustulemedi (DROP).' }
  & $psql @control -c "CREATE DATABASE $ScratchDatabase OWNER $env:PGOWNER;"
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani yaratilamadi (CREATE).' }

  Write-Host "[wrong-db-guard] 2/5 yabanci acente semasi yaratiliyor ('agency')"
  & $psql @target -c 'CREATE SCHEMA agency;'
  if ($LASTEXITCODE -ne 0) { throw 'Yabanci sema yaratilamadi.' }

  Write-Host "[wrong-db-guard] 3/5 migrate.ps1 scratch'e yonlendiriliyor (red bekleniyor)"
  $rejected = $true
  $reason = ''
  try {
    & "$PSScriptRoot/migrate.ps1" -Database $ScratchDatabase
    $rejected = $false
  } catch {
    $reason = "$_"
  }
  if (!$rejected) { throw 'Guard beklenmedik sekilde gecti: migrate.ps1 acente bicimli veritabanina DDL uygulamaya kalkti.' }
  if ($reason -notmatch 'agency') {
    throw "Migrate yabanci bir nedenle dustu (bu bir guard reddi degil): $reason"
  }
  # migrate.ps1 restores PGPASSWORD to the password it found on entry
  # (env.ps1 reloads .env unconditionally); re-assert the owner password
  # before touching the cluster again.
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  Write-Host "[wrong-db-guard] 4/5 red dogrulandi: $($reason.Trim())"

  Write-Host "[wrong-db-guard] 5/5 DDL-yok iddiasi ('system' semasi yaratilmamali)"
  $systemSchemas = ((& $psql @target -Atc "SELECT count(*) FROM pg_namespace WHERE nspname='system'") | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'DDL-yok sorgusu calistirilamadi.' }
  if ($systemSchemas -ne '0') { throw "Migration DDL sizdi: 'system' semasi mevcut (count=$systemSchemas)." }
  $agencySchemas = ((& $psql @target -Atc "SELECT count(*) FROM pg_namespace WHERE nspname='agency'") | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Sema dogrulama sorgusu calistirilamadi.' }
  if ($agencySchemas -ne '1') { throw "Yabanci sema beklenmedik sekilde degisti (count=$agencySchemas)." }

  Write-Host "[wrong-db-guard] YESIL: migrate.ps1 acente bicimli hedefi reddetti ve hicbir DDL uygulamadi."
} finally {
  # Temizlik: scratch'i dus ve env.ps1'in yukledigi .env degerlerini eski
  # haline getir; kontrol kumesi sorgulari icin sifreyi yeniden kur.
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  & $psql @control -c "DROP DATABASE IF EXISTS $ScratchDatabase WITH (FORCE);" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Scratch veritabani dustulemedi (temizlik DROP).' }
  foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD', 'PGOWNER', 'PGOWNER_PASSWORD')) {
    if ($null -ne $oldEnv[$name]) { [Environment]::SetEnvironmentVariable($name, $oldEnv[$name], 'Process') }
    else { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
  }
}
