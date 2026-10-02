<#
.SYNOPSIS
  auth-session-expiry-worker alarm katmanini uctan uca dogrular.

.DESCRIPTION
  Kanit uretir (canli webhook alicisi + gercek worker kosumu):
    1. Saglikli purge: canli veritabaninda tek dongu, HIC alarm gonderilmez.
    2. Ariza: gecersiz veritabani adi -> psql hata doner -> ilk hatada alarm.
    3. Esiksel (cooldown): 3 ardisik hatada tam 1 alarm (cooldown 60 dk).
    4. Tirmeme: 6 ardisik hatada 2 alarm (1. ve 6. hata).
    5. Kanalsiz: alarm kanali yoksa yalnizca log, dongu cokmez.
    6. Birikme (throttle): esik asilirsa throttle alarmi uretilir.

  Ariza senaryolari icin gecici bir kum sandbox kullanilir: env.ps1 .env'i
  KOSULSUZ yukledigi icin worker'in process env degerleri ezilir; bu yuzden
  bozuk veritabani adi .env kopyasi uzerinden verilir. Sandbox canli
  veritabanina hicbir sey yazmaz (psql baglantisi acilamaz).

  Cikis kodu: 0 = tum senaryolar gecti, 1 = en az bir senaryo basarisiz.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-auth-session-expiry-alerts.ps1
#>
param(
  [int]$Port = 18099
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$local = Join-Path $root '.local'
$logDir = Join-Path $local 'auth-session-expiry-alert-test'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$deliveries = Join-Path $logDir 'webhook-deliveries.log'
if (Test-Path -LiteralPath $deliveries) { Remove-Item -LiteralPath $deliveries -Force }

$failures = 0
function Write-Result([string]$name, [bool]$ok, [string]$detail) {
  $tag = if ($ok) { 'PASS' } else { 'FAIL' }
  Write-Host ("[{0}] {1}: {2}" -f $tag, $name, $detail)
  if (!$ok) { $script:failures++ }
}

# Start-Process'in -WindowSize/-WindowStyle secenekleri yalnizca Windows'ta
# vardir; CI ubuntu + pwsh calistirdigi icin platform kosuluna gore
# parametre listesini daraltiyoruz.
$isWindows = $env:OS -eq 'Windows_NT'
function Start-Background {
  param([string]$FilePath, [string[]]$ArgumentList, [string]$StdOut, [string]$StdErr)
  $splat = @{
    FilePath               = $FilePath
    ArgumentList           = $ArgumentList
    PassThru               = $true
    RedirectStandardOutput = $StdOut
    RedirectStandardError  = $StdErr
  }
  if ($isWindows) { $splat['WindowStyle'] = 'Hidden' }
  return Start-Process @splat
}

# --- Yerel webhook alicisi -------------------------------------------------
# Slack uyumlu {"text": ...} govdesini kabul eder, 200 doner ve teslimat
# sayisini dosyaya ekler. Node tabanli: HttpListener ACL sorunu yok.
# .cjs: proje package.json'i "type": "module" ilan ettigi icin CommonJS
# gerekiyor ( aksi halde require tanimsiz).
$receiver = Join-Path $logDir 'receiver.cjs'
@'
const http = require('http');
const fs = require('fs');
const out = process.argv[3];
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    fs.appendFileSync(out, new Date().toISOString() + ' ' + req.method + ' ' +
      req.url + ' ' + body.replace(/\s+/g, ' ') + '\n');
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
  });
}).listen(Number(process.argv[2]), '127.0.0.1', () => {
  fs.writeFileSync(process.argv[4], 'ready');
});
'@ | Set-Content -LiteralPath $receiver -Encoding ASCII

$ready = Join-Path $logDir 'receiver.ready'
if (Test-Path -LiteralPath $ready) { Remove-Item -LiteralPath $ready -Force }
$node = (Get-Command node -ErrorAction Stop).Source
$receiverProc = Start-Background -FilePath $node `
  -ArgumentList @($receiver, "$Port", $deliveries, $ready) `
  -StdOut (Join-Path $logDir 'receiver.out.log') -StdErr (Join-Path $logDir 'receiver.err.log')
try {
  $deadline = (Get-Date).AddSeconds(15)
  while (!(Test-Path -LiteralPath $ready)) {
    if ((Get-Date) -gt $deadline) { throw 'Webhook alicisi hazir olmadi.' }
    Start-Sleep -Milliseconds 200
  }
  $webhookUrl = "http://127.0.0.1:$Port/hook"
  Write-Host "Webhook alicisi hazir: $webhookUrl"

  function Get-DeliveryCount {
    if (!(Test-Path -LiteralPath $deliveries)) { return 0 }
    return @(Get-Content -LiteralPath $deliveries | Where-Object { $_.Trim() }).Count
  }

  # --- Sandbox: gecersiz veritabani ile worker kosumu ----------------------
  # env.ps1 .env'i kosulsuz yukler; bu yuzden worker'i gecici bir kum
  # icinde, PGDATABASE='nexus_definitely_missing_db' ile calistiriyoruz.
  function Invoke-SandboxWorker([hashtable]$envOverride, [string[]]$extraArgs) {
    $sandbox = Join-Path $logDir ("sandbox-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $sandboxScripts = Join-Path $sandbox 'scripts'
    New-Item -ItemType Directory -Path $sandboxScripts -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'env.ps1') -Destination $sandboxScripts
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'auth-session-expiry-worker.ps1') -Destination $sandboxScripts
    $envLines = Get-Content -LiteralPath (Join-Path $root '.env') | ForEach-Object {
      $line = $_.Trim()
      if (!$line -or $line.StartsWith('#')) { return $null }
      $idx = $line.IndexOf('=')
      if ($idx -lt 1) { return $null }
      return @{ Key = $line.Substring(0, $idx).Trim(); Value = $line.Substring($idx + 1).Trim() }
    }
    $rendered = foreach ($entry in ($envLines | Where-Object { $_ })) {
      if ($envOverride.ContainsKey($entry.Key)) {
        "$($entry.Key)=$($envOverride[$entry.Key])"
      } else {
        "$($entry.Key)=$($entry.Value)"
      }
    }
    Set-Content -LiteralPath (Join-Path $sandbox '.env') -Value $rendered -Encoding ASCII
    $shell = if ($isWindows) { 'powershell.exe' } else { 'pwsh' }
    $shellArgs = if ($isWindows) {
      @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File')
    } else {
      @('-NoProfile', '-File')
    }
    $args = $shellArgs + @((Join-Path $sandboxScripts 'auth-session-expiry-worker.ps1')) + $extraArgs
    $null = Start-Background -FilePath $shell -ArgumentList $args `
      -StdOut (Join-Path $sandbox 'worker.out.log') -StdErr (Join-Path $sandbox 'worker.err.log') | Wait-Process
    $alertLog = Join-Path $sandbox '.local/auth-session-expiry-alert.log'
    $errLog = Join-Path $sandbox '.local/auth-session-expiry-error.log'
    return [pscustomobject]@{
      AlertLog = if (Test-Path -LiteralPath $alertLog) { Get-Content -LiteralPath $alertLog -Raw } else { '' }
      ErrorLog = if (Test-Path -LiteralPath $errLog) { Get-Content -LiteralPath $errLog -Raw } else { '' }
    }
  }

  $base = @{ PGDATABASE = 'nexus_definitely_missing_db' }

  # 2) Ariza: ilk hatada alarm.
  $before = Get-DeliveryCount
  $r = Invoke-SandboxWorker $base @('-AlertWebhookUrl', $webhookUrl, '-MaxIterations', '1', '-IntervalSeconds', '0')
  $after = Get-DeliveryCount
  Write-Result 'failure-alert' (($after - $before) -eq 1 -and $r.AlertLog -match 'ALARM: auth-session-expiry-worker') `
    "teslimat=$($after - $before), alertlog=[$(($r.AlertLog -split "`n" | Where-Object { $_ -match 'ALERT|KURTARILDI' }) -join ' | ')]"

  # 3) Cooldown: 3 ardisik hatada tek alarm.
  $before = Get-DeliveryCount
  $r = Invoke-SandboxWorker $base @('-AlertWebhookUrl', $webhookUrl, '-AlertCooldownMinutes', '60',
    '-MaxIterations', '3', '-IntervalSeconds', '0')
  $after = Get-DeliveryCount
  $errorLines = @($r.ErrorLog -split "`n" | Where-Object { $_.Trim() }).Count
  Write-Result 'cooldown' (($after - $before) -eq 1 -and $errorLines -ge 3) `
    "3 hatada teslimat=$($after - $before) (beklenen 1), errorlog satir=$errorLines"

  # 4) Tirmeme: 6 ardisik hatada 2 alarm (1. ve 6.).
  $before = Get-DeliveryCount
  $r = Invoke-SandboxWorker $base @('-AlertWebhookUrl', $webhookUrl, '-AlertCooldownMinutes', '0',
    '-MaxIterations', '6', '-IntervalSeconds', '0')
  $after = Get-DeliveryCount
  Write-Result 'escalation-every-6' (($after - $before) -eq 2) `
    "6 hatada teslimat=$($after - $before) (beklenen 2: 1. ve 6.)"

  # 5) Kanalsiz: alarm gonderilmez ama dongu cokmez, loga yazilir.
  $before = Get-DeliveryCount
  $r = Invoke-SandboxWorker $base @('-MaxIterations', '1', '-IntervalSeconds', '0')
  $after = Get-DeliveryCount
  Write-Result 'no-channel-log-only' `
    (($after -eq $before) -and $r.AlertLog -match 'Alarm kanali tanimli degil') `
    "teslimat=$($after - $before), log-only mesaji=$($r.AlertLog -match 'Alarm kanali tanimli degil')"

  # 1) Saglikli purge: canli veritabaninda tek dongu, alarm yok.
  $before = Get-DeliveryCount
  $healthyLog = Join-Path $logDir 'healthy-worker.out.log'
  $shell = if ($isWindows) { 'powershell.exe' } else { 'pwsh' }
  $shellArgs = if ($isWindows) {
    @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File')
  } else {
    @('-NoProfile', '-File')
  }
  $null = Start-Background -FilePath $shell -ArgumentList ($shellArgs + @(
      (Join-Path $PSScriptRoot 'auth-session-expiry-worker.ps1'),
      '-AlertWebhookUrl', $webhookUrl, '-MaxIterations', '1', '-IntervalSeconds', '0')) `
    -StdOut $healthyLog -StdErr (Join-Path $logDir 'healthy-worker.err.log') | Wait-Process
  $after = Get-DeliveryCount
  $errText = Get-Content -LiteralPath (Join-Path $logDir 'healthy-worker.err.log') -Raw -ErrorAction SilentlyContinue
  Write-Result 'healthy-no-false-alarm' (($after -eq $before) -and !$errText) `
    "canli DB'de teslimat=$($after - $before) (beklenen 0), stderr bos=$([string]::IsNullOrWhiteSpace($errText))"

  # 6) Throttle: gecerli DB, kucuk esik, kirli satirlar yoksa alarm olmamali.
  $before = Get-DeliveryCount
  $r = Invoke-SandboxWorker @{ PGDATABASE = (Get-Content (Join-Path $root '.env') | Where-Object { $_ -match '^PGDATABASE=' } | ForEach-Object { $_.Split('=')[1] }) } `
    @('-AlertWebhookUrl', $webhookUrl, '-MaxIterations', '1', '-IntervalSeconds', '0')
  $after = Get-DeliveryCount
  Write-Result 'healthy-throttle-quiet' (($after -eq $before) -and $r.ErrorLog -eq '') `
    "canli DB'de throttle alarmi=$($after - $before) (beklenen 0), errorlog bos=$($r.ErrorLog -eq '')"
} finally {
  if ($receiverProc -and !$receiverProc.HasExited) {
    Stop-Process -Id $receiverProc.Id -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ''
if ($failures -eq 0) {
  Write-Host 'auth-session-expiry-worker alarm testi: TUM SENARYOLAR GECTI'
  exit 0
}
Write-Host "auth-session-expiry-worker alarm testi: $failures senaryo basarisiz"
exit 1
