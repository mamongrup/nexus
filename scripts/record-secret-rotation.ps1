param(
  # Rotasyonu kaydedilen sır. ALL -> hem SECRET_KEY_BASE hem
  # NEXUS_CONFIG_KEY icin kayit (iki sır da ayni operasyonda döndürülür).
  [ValidateSet("SECRET_KEY_BASE", "NEXUS_CONFIG_KEY", "ALL")]
  [string]$Name = "SECRET_KEY_BASE",
  # Rotasyon kaydına eklenen kaynak etiketi (ör. "planned", "emergency").
  [string]$Source = "manual",
  [string]$EnvPath = ".env"
)

# Rotasyon tarihini events.secret_rotations tablosuna yazar (migration 187).
# -Name ALL ile iki sır (SECRET_KEY_BASE + NEXUS_CONFIG_KEY) tek komutta
# kaydedilir ve iki sirrin yasi yan yana raporlanir.
#
# Pencere geçiş kontrolü: rotasyon sonrasi SECRET_KEY_BASE_PREVIOUS en fazla
# events.rotation_window_hours('SECRET_KEY_BASE') (varsayilan 48 saat)
# sureyle env'de kalabilir. scripts/check-secret-hygiene.ps1 pencere
# durumunu bu tablodan hesaplar; kayit yoksa kontrol "bilinmiyor" der ve
# basarisiz sayilir (fail-closed). Bu yuzden SECRET_KEY_BASE ilk kez
# degistirilmeden once mevcut sirrin devreye alinma tarihi baseline olarak
# kaydedilmelidir.
#
# Tablo kalici DDL ile db/migrations/187_secret_rotation_window.sql icinde
# tasınır; bu betik yalnizca tablo henuz yoksa idempotent olusturur ve ayni
# sirri 5 dakika icinde tekrar kaydetmez (idempotent kayit).

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

$values = @{}
Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) { $values[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim() }
}

foreach ($key in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGOWNER', 'PGOWNER_PASSWORD')) {
  if (!$values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$values[$key])) {
    throw "$key is required."
  }
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (!$psql) {
  $psql = Get-ChildItem 'C:\laragon\bin\postgresql\*\bin\psql.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
}
if (!$psql) { throw 'psql executable not found.' }

$names = if ($Name -eq 'ALL') { @('SECRET_KEY_BASE', 'NEXUS_CONFIG_KEY') } else { @($Name) }
$sourceEscaped = $Source -replace "'", "''"

$env:PGPASSWORD = [string]$values['PGOWNER_PASSWORD']
try {
  foreach ($secretName in $names) {
    $nameEscaped = $secretName -replace "'", "''"

    $sql = @"
CREATE TABLE IF NOT EXISTS events.secret_rotations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  secret_name varchar(64) NOT NULL,
  rotated_at timestamptz NOT NULL DEFAULT now(),
  source varchar(64) NOT NULL DEFAULT 'manual'
);
CREATE INDEX IF NOT EXISTS events_secret_rotations_name_time_idx
  ON events.secret_rotations(secret_name, rotated_at DESC);
INSERT INTO events.secret_rotations(secret_name, source)
SELECT '$nameEscaped', left('$sourceEscaped', 64)
WHERE NOT EXISTS (
  SELECT 1 FROM events.secret_rotations
   WHERE secret_name = '$nameEscaped'
     AND rotated_at > now() - interval '5 minutes'
);
"@
    & $psql.Source -X -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
      -U $values['PGOWNER'] -d $values['PGDATABASE'] `
      -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Rotation record failed for $secretName with exit code $LASTEXITCODE" }

    # Pencere durumu: 48 saat (sir bazli ayar) sonunda pencere kapanir.
    # NEXUS_CONFIG_KEY icin de ayni sozlesme isler (pencere su an
    # enformatiftir: PREVIOUS karsiligi yoktur; yas izleme amacli raporlanir).
    $stateSql = @"
SELECT events.rotation_window_state('$nameEscaped') || '|' ||
       COALESCE(events.latest_rotation_age_hours('$nameEscaped')::text, '-') || '|' ||
       events.rotation_window_hours('$nameEscaped')::text;
"@
    $state = & $psql.Source -X -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
      -U $values['PGOWNER'] -d $values['PGDATABASE'] `
      -Atc $stateSql
    $parts = "$state" -split '\|'
    $windowState = $parts[0]
    $ageHours = $parts[1]
    $windowHours = $parts[2]

    Write-Host "Rotasyon kaydedildi: $secretName (source=$Source)."
    Write-Host "Pencere durumu: $windowState (yas=${ageHours}h, pencere=${windowHours}h)."
    if ($secretName -eq 'SECRET_KEY_BASE') {
      if ($windowState -eq 'expired') {
        Write-Warning "Pencere doldu (${windowHours}h): SECRET_KEY_BASE_PREVIOUS artik .env'den kaldirilmalidir. Once yeni sirrin istemcilerde cache'ten ciktigindan emin olun."
      } else {
        Write-Host "Hatirlatma: SECRET_KEY_BASE_PREVIOUS ${windowHours} saat sonra kaldirilmalidir (scripts/check-secret-hygiene.ps1 denetler)."
      }
    } else {
      Write-Host "Not: NEXUS_CONFIG_KEY simetrik sifreleme anahtaridir; PREVIOUS karsiligi yoktur. Yasi yalnizca izleme icin raporlanir. (config-key.ps1 anahtari kayipsiz degistiremez.)"
    }
  }

  # Iki sirrin yasi ayri satirlarda raporlanir (ALL modu ozeti).
  if ($names.Count -gt 1) {
    Write-Host '--- Yas raporu ---'
    foreach ($secretName in $names) {
      $nameEscaped = $secretName -replace "'", "''"
      $ageSql = @"
SELECT COALESCE(events.latest_rotation_age_hours('$nameEscaped')::text, 'kayit-yok') || '|' ||
       events.rotation_window_state('$nameEscaped') || '|' ||
       events.rotation_window_hours('$nameEscaped')::text;
"@
      $row = & $psql.Source -X -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
        -U $values['PGOWNER'] -d $values['PGDATABASE'] -Atc $ageSql
      $rp = "$row" -split '\|'
      Write-Host ("{0}: yas={1}h, durum={2}, pencere={3}h" -f $secretName, $rp[0], $rp[1], $rp[2])
    }
  }
  Write-Host "Not: gercek rotasyon tarihinden farkli bir baseline kaydediyorsaniz, rotasyon denetiminin dogru calismasi icin tarihi DB'den duzeltin."
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
