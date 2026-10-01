param([string]$EnvPath = '.env')

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$resolved = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolved)) { throw "Environment file missing: $resolved" }
$values = @{}
Get-Content -LiteralPath $resolved | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $separator = $line.IndexOf('=')
  if ($separator -gt 0) { $values[$line.Substring(0, $separator).Trim()] = $line.Substring($separator + 1).Trim() }
}
if ($values['APP_ENV'] -ne 'production') { throw 'APP_ENV=production is required for a NEXUS production release.' }
foreach ($key in @('APP_ORIGIN','APP_PUBLIC_HOST','APP_PORT','PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOWNER','PGOWNER_PASSWORD','SECRET_KEY_BASE','NEXUS_CONFIG_KEY')) {
  if ([string]::IsNullOrWhiteSpace([string]$values[$key])) { throw "$key is required." }
}
$origin = $null
if (![uri]::TryCreate([string]$values['APP_ORIGIN'], [UriKind]::Absolute, [ref]$origin) -or $origin.Scheme -ne 'https') {
  throw 'APP_ORIGIN must be an absolute HTTPS URL.'
}
if ($origin.Host -ne $values['APP_PUBLIC_HOST']) { throw 'APP_PUBLIC_HOST must equal the APP_ORIGIN host.' }
if ($origin.Host -in @('localhost','127.0.0.1','::1')) { throw 'Public origin must not be loopback.' }
if ($origin.Host -match '(^|\.)example\.(com|org|net)$') { throw 'APP_ORIGIN still uses an example domain.' }
foreach ($key in @('SECRET_KEY_BASE','NEXUS_CONFIG_KEY')) {
  if (([string]$values[$key]).Length -lt 64) { throw "$key must contain at least 64 characters." }
}
# Rotasyon penceresi sirri opsiyoneldir; ancak set edildiyse mevcut sirrin
# kopyasi olamaz ve ayni 64 karakter standardina uymak zorundadir.
# (Pencere yasi/kapanma denetimi ayrica scripts/check-secret-hygiene.ps1'de.)
$previousSecret = [string]$values['SECRET_KEY_BASE_PREVIOUS']
if (![string]::IsNullOrWhiteSpace($previousSecret)) {
  if ($previousSecret -eq [string]$values['SECRET_KEY_BASE']) { throw 'SECRET_KEY_BASE_PREVIOUS must differ from SECRET_KEY_BASE.' }
  if ($previousSecret.Length -lt 64) { throw 'SECRET_KEY_BASE_PREVIOUS must contain at least 64 characters.' }
}
if ($values['PGUSER'] -eq $values['PGOWNER']) { throw 'Runtime and migration database users must differ.' }
foreach ($key in @('PGPASSWORD','PGOWNER_PASSWORD')) {
  if ([string]$values[$key] -match 'CHANGE_ME|generated-by-setup|change-this|^dummy$') { throw "$key contains a placeholder." }
}
Write-Host 'NEXUS production configuration passed.'
