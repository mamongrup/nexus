<#
.SYNOPSIS
  Haftalik sifre rotasyonu denetimini Windows Gorev Zamanlayici'ya kaydeder.

.DESCRIPTION
  notify-rotation-overdue.ps1'i haftalik olarak calistiran bir gorev olusturur
  veya ayni isimle var olan gorevi guncelidir (idempotent). Gorev gecerli
  kullanici altinda calisir; makine kapali kaldiginda kacan calisma
  (StartWhenAvailable) sonraki acilista telafi edilir.

  Uyari kanallari (webhook/e-posta) gorevin argumanlarina gomulur;
  degistirmek icin bu betigi yeniden calistirin.

.EXAMPLE
  pwsh scripts/register-rotation-check-task.ps1 -MailTo ops@acme.test
  pwsh scripts/register-rotation-check-task.ps1 -WebhookUrl https://hooks.slack.com/services/X/Y/Z -At 09:30 -DayOfWeek Friday
#>
param(
  [string]$WebhookUrl = '',
  [string]$MailTo = '',
  [string]$EnvPath = '.env',
  # Haftalik calisma saati (gg:dd).
  [string]$At = '08:00',
  [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
  [string]$DayOfWeek = 'Monday',
  [string]$TaskName = 'NEXUS Rotation Window Check'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $PSScriptRoot 'notify-rotation-overdue.ps1'
if (!(Test-Path -LiteralPath $scriptPath)) { throw 'notify-rotation-overdue.ps1 not found.' }
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -EnvPath `"$resolvedEnv`""
if ($WebhookUrl) { $argument += " -WebhookUrl `"$WebhookUrl`"" }
if ($MailTo) { $argument += " -MailTo `"$MailTo`"" }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
  Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings | Out-Null
  Write-Host "Gorev guncellendi: $TaskName ($DayOfWeek $At)"
} else {
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Description 'NEXUS: haftalik SECRET_KEY_BASE rotasyon penceresi denetimi (notify-rotation-overdue.ps1).' | Out-Null
  Write-Host "Gorev kaydedildi: $TaskName ($DayOfWeek $At)"
}

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Durum: $($task.State); Sonraki calisma: $($info.NextRunTime)"
Write-Host "Not: gorev gecerli kullanici ($env:USERNAME) oturumunda calisir; sunucuda oturum acik kalmali ya da gorev yogunlastirmasi (S4U/SYSTEM) tercih edilebilir."
