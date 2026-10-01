param(
  [string]$EnvPath = ".env"
)

# Sır hijyeni + rotasyon penceresi denetimi (platform tarafı).
#
# Acente'deki scripts/check-secret-hygiene.ps1'in platform aynalaması.
# Dört kontrol:
#   1. .env'de zayıf/örnek sır yok (placeholder pattern'leri).
#   2. SECRET_KEY_BASE uzunlugu >= 64 karakter.
#   3. SECRET_KEY_BASE icin rotasyon kaydi VAR (fail-closed; kayit yoksa
#      "unknown" -> basarisiz). Kayit db/migrations/187 tablosunda;
#      scripts/record-secret-rotation.ps1 yazar.
#   4. Rotasyon penceresi: events.rotation_window_state('SECRET_KEY_BASE')
#      'expired' ise SECRET_KEY_BASE_PREVIOUS hala env'deyse basarisiz
#      (pencere kapandi; onceki sır kaldirilmali). 'open' ise bilgi mesaji.

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

$fail = 0
function Add-Fail { $script:fail++ }

# --- 1. Placeholder sir kontrolu --------------------------------------------
$weakPatterns = @(
  'changethis', 'change-me', 'changeme', 'replace_me', 'replacewith',
  'your_secret', 'your-secret', 'example', 'dummy', 'placeholder',
  'secret_here', 'xxx', 'dev_only', 'not_so_secret', 'lorem'
)
foreach ($secretKey in @('SECRET_KEY_BASE', 'SECRET_KEY_BASE_PREVIOUS')) {
  $present = $values.ContainsKey($secretKey) -and ![string]::IsNullOrWhiteSpace([string]$values[$secretKey])
  if (!$present) {
    if ($secretKey -eq 'SECRET_KEY_BASE') {
      Write-Host "[FAIL] $secretKey .env'de tanimli degil."
      Add-Fail
    } else {
      Write-Host "[OK]   $secretKey tanimli degil (rotasyon penceresi kapali)."
    }
    continue
  }
  $v = [string]$values[$secretKey]
  $weak = $false
  foreach ($p in $weakPatterns) {
    if ($v.ToLower().Contains($p)) { Write-Host "[FAIL] $secretKey zayif/ornek deger iceriyor ('$p')."; $weak = $true; Add-Fail; break }
  }
  if ($weak) { continue }

  # --- 2. Uzunluk kontrolu ---------------------------------------------------
  if ($v.Length -lt 64) {
    Write-Host "[FAIL] $secretKey cok kisa ($($v.Length) < 64 karakter)."
    Add-Fail
  } else {
    Write-Host "[OK]   $secretKey uzunluk $($v.Length) karakter."
  }
}

# --- 3 + 4. Rotasyon kaydi ve pencere durumu (DB) ---------------------------
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

$env:PGPASSWORD = [string]$values['PGOWNER_PASSWORD']
try {
  $sql = @"
SELECT events.rotation_window_state('SECRET_KEY_BASE') || '|' ||
       COALESCE(events.latest_rotation_age_hours('SECRET_KEY_BASE')::text, '-') || '|' ||
       events.rotation_window_hours('SECRET_KEY_BASE')::text;
"@
  $state = & $psql.Source -X -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
    -U $values['PGOWNER'] -d $values['PGDATABASE'] `
    -Atc $sql
  if ($LASTEXITCODE -ne 0) { throw "Rotation window query failed with exit code $LASTEXITCODE" }

  $parts = "$state" -split '\|'
  $windowState = $parts[0]
  $ageHours = $parts[1]
  $windowHours = $parts[2]

  switch ($windowState) {
    'unknown' {
      Write-Host "[FAIL] SECRET_KEY_BASE icin rotasyon kaydi yok (yas=unknown, fail-closed). scripts/record-secret-rotation.ps1 ile baseline kaydedin."
      Add-Fail
    }
    'open' {
      Write-Host "[OK]   Rotasyon penceresi acik (yas=${ageHours}h / pencere=${windowHours}h)."
      if ($values.ContainsKey('SECRET_KEY_BASE_PREVIOUS')) {
        Write-Host "[INFO] SECRET_KEY_BASE_PREVIOUS hala env'de; ${windowHours} saat icinde kaldirilmali."
      }
    }
    'expired' {
      if ($values.ContainsKey('SECRET_KEY_BASE_PREVIOUS') -and ![string]::IsNullOrWhiteSpace([string]$values['SECRET_KEY_BASE_PREVIOUS'])) {
        Write-Host "[FAIL] Rotasyon penceresi doldu (yas=${ageHours}h > ${windowHours}h) ama SECRET_KEY_BASE_PREVIOUS hala env'de. Kaldirin."
        Add-Fail
      } else {
        Write-Host "[OK]   Pencere doldu (${ageHours}h > ${windowHours}h) ve SECRET_KEY_BASE_PREVIOUS kaldirilmis."
      }
    }
    default {
      Write-Host "[FAIL] Beklenmeyen pencere durumu: $windowState"
      Add-Fail
    }
  }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

if ($fail -gt 0) { exit 1 }
Write-Host "Sır hijyeni denetimi temiz."
exit 0
