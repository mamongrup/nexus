<#
.SYNOPSIS
  Haftalik rotasyon penceresi denetimi; overdue durumunda webhook/e-posta uyarisi.

.DESCRIPTION
  events.rotation_window_state('SECRET_KEY_BASE') durumunu okur (migration 187
  sozlesmesi; check-secret-hygiene.ps1 ile ayni kaynak):
    - open    -> bilgilendirme, cikis 0.
    - expired -> SECRET_KEY_BASE_PREVIOUS pencereyi doldurdu; webhook/e-posta
                 ile uyarilir, cikis 1.
    - unknown -> rotasyon kaydi yok (fail-closed); uyarilir, cikis 1.
  DB'ye ulasilamazsa uyarilamaz; konsol + log, cikis 2.

  Uyari kanallari opsiyoneldir ve birbirinden bagimsizdir:
    -WebhookUrl : Slack uyumlu {"text": ...} govdesiyle POST (Teams/Slack/Discord
                  benzeri webhook'lar kabul eder).
    -MailTo     : Send-MailMessage ile e-posta; SMTP ayarlari .env'den okunur
                  (MAIL_HOST, MAIL_PORT, MAIL_FROM, MAIL_USER, MAIL_PASSWORD),
                  parametrelerle ezilebilir.

  Cikis dosyasi: .local/rotation-check.log (her kosum kaydedilir).

.EXAMPLE
  pwsh scripts/notify-rotation-overdue.ps1
  pwsh scripts/notify-rotation-overdue.ps1 -WebhookUrl https://hooks.slack.com/services/X/Y/Z -MailTo ops@acme.test
#>
param(
  [string]$WebhookUrl = '',
  [string]$MailTo = '',
  [string]$MailHost = '',
  [int]$MailPort = 0,
  [string]$MailFrom = '',
  [string]$MailUser = '',
  [string]$MailPassword = '',
  [string]$EnvPath = '.env',
  [string]$SecretName = 'SECRET_KEY_BASE'
)

$ErrorActionPreference = 'Stop'

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

# SMTP varsayilanlari: .env -> parametre ezmesi.
if (!$MailHost -and $values.ContainsKey('MAIL_HOST')) { $MailHost = [string]$values['MAIL_HOST'] }
if ($MailPort -eq 0 -and $values.ContainsKey('MAIL_PORT')) { $MailPort = [int]$values['MAIL_PORT'] }
if (!$MailPort) { $MailPort = 587 }
if (!$MailFrom -and $values.ContainsKey('MAIL_FROM')) { $MailFrom = [string]$values['MAIL_FROM'] }
if (!$MailUser -and $values.ContainsKey('MAIL_USER')) { $MailUser = [string]$values['MAIL_USER'] }
if (!$MailPassword -and $values.ContainsKey('MAIL_PASSWORD')) { $MailPassword = [string]$values['MAIL_PASSWORD'] }

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (!$psql) {
  $psql = Get-ChildItem 'C:\laragon\bin\postgresql\*\bin\psql.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
}
if (!$psql) { throw 'psql executable not found.' }

$logPath = Join-Path $root '.local/rotation-check.log'
function Write-CheckLog([string]$message) {
  $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
  Write-Host $line
  New-Item -ItemType Directory -Path (Split-Path $logPath -Parent) -Force | Out-Null
  Add-Content -LiteralPath $logPath -Value $line
}

function Send-Alert([string]$subject, [string]$body) {
  $delivered = @()
  if ($WebhookUrl) {
    try {
      $payload = @{ text = "$subject`n$body" } | ConvertTo-Json -Compress
      Invoke-RestMethod -Method Post -Uri $WebhookUrl -ContentType 'application/json' `
        -Body $payload -TimeoutSec 15 | Out-Null
      $delivered += 'webhook'
    } catch {
      Write-CheckLog "[WARN] Webhook gonderimi basarisiz: $($_.Exception.Message)"
    }
  }
  if ($MailTo) {
    if (!$MailHost) {
      Write-CheckLog '[WARN] MailTo verildi ama MAIL_HOST tanimli degil; e-posta atlandi.'
    } else {
      try {
        $mail = @{
          SmtpServer = $MailHost
          Port       = $MailPort
          From       = $MailFrom
          To         = $MailTo
          Subject    = $subject
          Body       = $body
          UseSsl     = $true
          ErrorAction = 'Stop'
        }
        if ($MailUser -and $MailPassword) {
          $sec = ConvertTo-SecureString $MailPassword -AsPlainText -Force
          $mail.Credential = New-Object System.Management.Automation.PSCredential($MailUser, $sec)
        }
        Send-MailMessage @mail
        $delivered += 'mail'
      } catch {
        Write-CheckLog "[WARN] E-posta gonderimi basarisiz: $($_.Exception.Message)"
      }
    }
  }
  if ($delivered.Count -eq 0) { $delivered = @('console-only') }
  return ($delivered -join '+')
}

$nameEscaped = $SecretName -replace "'", "''"
$sql = @"
SELECT events.rotation_window_state('$nameEscaped') || '|' ||
       COALESCE(events.latest_rotation_age_hours('$nameEscaped')::text, '-') || '|' ||
       events.rotation_window_hours('$nameEscaped')::text;
"@

$state = $null
try {
  $env:PGPASSWORD = [string]$values['PGOWNER_PASSWORD']
  $state = & $psql.Source -X -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
    -U $values['PGOWNER'] -d $values['PGDATABASE'] -Atc $sql
} catch {
  Write-CheckLog "[ERROR] Rotasyon penceresi okunamadi: $($_.Exception.Message)"
  exit 2
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
if ($LASTEXITCODE -ne 0 -or !$state) {
  Write-CheckLog '[ERROR] Rotasyon penceresi sorgusu basarisiz.'
  exit 2
}

$parts = "$state" -split '\|'
$windowState = $parts[0]
$ageHours = $parts[1]
$windowHours = $parts[2]
$host_ = $env:COMPUTERNAME

switch ($windowState) {
  'open' {
    Write-CheckLog "[OK] $SecretName penceresi acik (yas=${ageHours}h / pencere=${windowHours}h)."
    exit 0
  }
  'expired' {
    $subject = "[NEXUS] SIR ROTASYONU GECIKTI: $SecretName penceresi doldu ($host_)"
    $body = @"
SECRET_KEY_BASE rotasyon penceresi doldu.
Bilgisayar : $host_
Sır        : $SecretName
Durum      : expired
Yaş        : $ageHours saat
Pencere    : $windowHours saat
Eylem      : SECRET_KEY_BASE_PREVIOUS degerini .env dosyasindan kaldirin ve
             uygulamayi yeniden baslatin. Detay: docs/security-2026-10-01.md
Kontrol    : scripts/check-secret-hygiene.ps1
"@
    $via = Send-Alert -subject $subject -body $body
    Write-CheckLog "[ALERT] Pencere doldu (yas=${ageHours}h > ${windowHours}h). Uyari: $via"
    exit 1
  }
  'unknown' {
    $subject = "[NEXUS] SIR ROTASYONU KAYDI YOK: $SecretName denetlenemiyor ($host_)"
    $body = @"
SECRET_KEY_BASE icin rotasyon kaydi bulunamadi (fail-closed).
Bilgisayar : $host_
Sır        : $SecretName
Durum      : unknown
Eylem      : scripts/record-secret-rotation.ps1 ile mevcut sirrin baseline
             kaydini olusturun. Kayitsiz sir denetlenemez.
Kontrol    : scripts/check-secret-hygiene.ps1
"@
    $via = Send-Alert -subject $subject -body $body
    Write-CheckLog "[ALERT] Rotasyon kaydi yok (fail-closed). Uyari: $via"
    exit 1
  }
  default {
    Write-CheckLog "[ERROR] Beklenmeyen pencere durumu: $windowState"
    exit 2
  }
}
