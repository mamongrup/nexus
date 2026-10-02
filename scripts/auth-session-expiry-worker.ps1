# Auth oturum bakim iscisi: suresi dolmus auth.sessions satirlarini siler.
# scripts/ensure-auth-session-expiry-worker.ps1 tek ornek garantisini saglar;
# start.ps1 her acilista onu cagirir. Kalip: supplier-expiry-worker.ps1 /
# agency-booking-expiry-worker.ps1. Bu dosya bilerek yalnizca ASCII yazar
# (Windows PowerShell 5.1 BOM'suz UTF-8'i ANSI okur).
#
# Alarm kanallari (kalip: notify-rotation-overdue.ps1 Send-Alert): isci
# purge adimini calistiramadiginda webhook/e-posta uyarisi uretir. Kanallar
# varsayilan olarak .env'den okunur (parametrelerle ezilebilir):
#   ALERT_WEBHOOK_URL        Slack uyumlu {"text": ...} POST hedefi.
#   ALERT_MAIL_TO            alici; SMTP ayarlari notify betigiyle ayni
#                            anahtarlari kullanir (MAIL_HOST, MAIL_PORT,
#                            MAIL_FROM, MAIL_USER, MAIL_PASSWORD).
#   ALERT_COOLDOWN_MINUTES   ayni arizanin tekrar uyari araligi (60).
# Kisilmalar (throttling) da alarm konusudur: purge hatasiz calissalar bile
# olen oturum satirlari esik uzerinde birikiyorsa uyari uretilir. Ilk
# basarisizlikta uyarilir; ardindan her 6. ardisik basarisizlikte (~30 dk)
# durum bilgisiyle tekrar uyarilir. Kanal tanimli degilse olay yalnizca
# loga yazilir (kanal eklenmesi mevcut davranisi degistiremez).
param(
  [string]$AlertWebhookUrl = '',
  [string]$AlertMailTo = '',
  [string]$AlertMailHost = '',
  [int]$AlertMailPort = 0,
  [string]$AlertMailFrom = '',
  [string]$AlertMailUser = '',
  [string]$AlertMailPassword = '',
  [int]$AlertCooldownMinutes = 60,
  # Diger iki parametre yalnizca denetim icindir: uretimde 0 (sinirsiz dongu)
  # ve 300 saniyelik bekleme kullanilir. Test kosucusu
  # (scripts/test-auth-session-expiry-alerts.ps1) kucuk degerlerle donguyu
  # deterministik olarak surer.
  [int]$MaxIterations = 0,
  [int]$IntervalSeconds = 300
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"
$pg = (Get-Command psql -ErrorAction Stop).Source
$env:PGPASSWORD = $env:PGOWNER_PASSWORD
New-Item -ItemType Directory -Path (Join-Path $ProjectRoot '.local') -Force | Out-Null
$countLog = Join-Path $ProjectRoot '.local/auth-session-expiry.log'
$errorLog = Join-Path $ProjectRoot '.local/auth-session-expiry-error.log'
$alertLog = Join-Path $ProjectRoot '.local/auth-session-expiry-alert.log'

# Kanal cozumlemesi: parametre > env (.env env.ps1 ile process'e yuklendi).
if (!$AlertWebhookUrl -and $env:ALERT_WEBHOOK_URL) { $AlertWebhookUrl = $env:ALERT_WEBHOOK_URL }
if (!$AlertMailTo -and $env:ALERT_MAIL_TO) { $AlertMailTo = $env:ALERT_MAIL_TO }
if (!$AlertMailHost -and $env:MAIL_HOST) { $AlertMailHost = $env:MAIL_HOST }
if ($AlertMailPort -eq 0 -and $env:MAIL_PORT) {
  try { $AlertMailPort = [int]$env:MAIL_PORT } catch { $AlertMailPort = 587 }
}
if (!$AlertMailPort) { $AlertMailPort = 587 }
if (!$AlertMailFrom -and $env:ALERT_MAIL_FROM) { $AlertMailFrom = $env:ALERT_MAIL_FROM }
if (!$AlertMailUser -and $env:MAIL_USER) { $AlertMailUser = $env:MAIL_USER }
if (!$AlertMailPassword -and $env:MAIL_PASSWORD) { $AlertMailPassword = $env:MAIL_PASSWORD }
if ($env:ALERT_COOLDOWN_MINUTES) {
  try { $AlertCooldownMinutes = [int]$env:ALERT_COOLDOWN_MINUTES } catch { }
}

$script:lastAlertAt = $null
$script:consecutiveFailures = 0
$script:pendingThreshold = 5000

function Write-AlertLog([string]$message) {
  $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
  Write-Host $line
  Add-Content -LiteralPath $alertLog -Value $line
}

function Send-Alert([string]$subject, [string]$body) {
  # Kanallar bagimsizdir; basarisiz kanal digerini engellemez ve isci
  # dongusunu asla durdurmaz.
  $delivered = @()
  if ($AlertWebhookUrl) {
    try {
      $payload = @{ text = "$subject`n$body" } | ConvertTo-Json -Compress
      Invoke-RestMethod -Method Post -Uri $AlertWebhookUrl -ContentType 'application/json' `
        -Body $payload -TimeoutSec 15 | Out-Null
      $delivered += 'webhook'
    } catch {
      Write-AlertLog "[WARN] Webhook gonderimi basarisiz: $($_.Exception.Message)"
    }
  }
  if ($AlertMailTo) {
    if (!$AlertMailHost) {
      Write-AlertLog '[WARN] ALERT_MAIL_TO verildi ama MAIL_HOST tanimli degil; e-posta atlandi.'
    } else {
      try {
        $mail = @{
          SmtpServer  = $AlertMailHost
          Port        = $AlertMailPort
          From        = $AlertMailFrom
          To          = $AlertMailTo
          Subject     = $subject
          Body        = $body
          UseSsl      = $true
          ErrorAction = 'Stop'
        }
        if ($AlertMailUser -and $AlertMailPassword) {
          $sec = ConvertTo-SecureString $AlertMailPassword -AsPlainText -Force
          $mail.Credential = New-Object System.Management.Automation.PSCredential($AlertMailUser, $sec)
        }
        Send-MailMessage @mail
        $delivered += 'mail'
      } catch {
        Write-AlertLog "[WARN] E-posta gonderimi basarisiz: $($_.Exception.Message)"
      }
    }
  }
  if (!$AlertWebhookUrl -and !$AlertMailTo) {
    Write-AlertLog '[WARN] Alarm kanali tanimli degil; uyari yalnizca loga yazildi.'
  }
  return ($delivered.Count -gt 0)
}

function Invoke-SessionExpiryAlert([string]$detail, [bool]$recovered, [long]$pendingCount) {
  # Cooldown: ayni arizanin spam'ini onler; kanal denemesi yapildiginda
  # pencere yenilenir (basarisiz deneme de penceri kapatir).
  $now = Get-Date
  if ($script:lastAlertAt -and ($now - $script:lastAlertAt).TotalMinutes -lt $AlertCooldownMinutes) {
    return
  }
  $script:lastAlertAt = $now
  $pending = ''
  if ($pendingCount -gt $script:pendingThreshold) {
    $pending = " bekleyen_suresi_dolmus_satir=$pendingCount (esik $($script:pendingThreshold))"
  }
  $stamp = $now.ToString('s')
  if ($recovered) {
    $subject = '[NEXUS] KURTARILDI: auth-session-expiry-worker'
    $body = "Purge 30 dakika sureyle basarisizdi, artik calisiyor.$pending`nZaman: $stamp"
  } else {
    $subject = '[NEXUS] ALARM: auth-session-expiry-worker purge basarisiz'
    $body = "Detay: $detail$pending`nZaman: $stamp"
  }
  Write-AlertLog "[ALERT] $subject"
  if (Send-Alert $subject $body) {
    Write-AlertLog '[ALERT] Alarm kanalina teslim edildi'
  }
}

$iteration = 0
while ($true) {
  $iteration++
  # Birikme olcer: purge basarili olsa bile esik uzeri birikme kisilmaya
  # isarettir; sorgu basarisiz olursa bildigi degeri (0) kullanir.
  $pendingCount = [int64]0
  try {
    $probe = & $pg -X -w -At -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER `
      -d $env:PGDATABASE `
      -c 'SELECT count(*) FROM auth.sessions WHERE expires_at < now() AND expires_at IS NOT NULL' 2>$null
    if ($LASTEXITCODE -eq 0 -and $probe -match '^\d+$') { $pendingCount = [int64]$probe }
  } catch { }
  try {
    $deleted = & $pg -X -w -v ON_ERROR_STOP=1 -At -h $env:PGHOST -p $env:PGPORT `
      -U $env:PGOWNER -d $env:PGDATABASE `
      -c 'SELECT auth.purge_expired_sessions()' | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'auth session purge failed.' }
    $deleted = $deleted.Trim()
    if ($deleted -match '^\d+$' -and [int64]$deleted -gt 0) {
      Add-Content -LiteralPath $countLog -Value "$(Get-Date -Format o) purged=$deleted"
    }
    if ($script:consecutiveFailures -ge 6) {
      $script:consecutiveFailures = 0
      Invoke-SessionExpiryAlert 'purge recovered' $true $pendingCount
    } elseif ($pendingCount -gt $script:pendingThreshold) {
      Invoke-SessionExpiryAlert 'throttle: purge calisiyor ama birikme esigi asti' $false $pendingCount
    }
    $script:consecutiveFailures = 0
  } catch {
    $script:consecutiveFailures++
    Add-Content -LiteralPath $errorLog -Value "$(Get-Date -Format o) $($_.Exception.Message)"
    if ($script:consecutiveFailures -eq 1 -or ($script:consecutiveFailures % 6) -eq 0) {
      Invoke-SessionExpiryAlert $_.Exception.Message $false $pendingCount
    }
  }
  if ($MaxIterations -gt 0 -and $iteration -ge $MaxIterations) { break }
  if ($IntervalSeconds -gt 0) { Start-Sleep -Seconds $IntervalSeconds }
}
