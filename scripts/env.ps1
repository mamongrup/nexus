$ErrorActionPreference = 'Stop'
$ProjectRoot = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } elseif ($MyInvocation.MyCommand.Path) { Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent } else { (Get-Location).Path }
if (!(Test-Path (Join-Path $ProjectRoot '.env')) -and (Test-Path './.env')) { $ProjectRoot = (Get-Location).Path }
$EnvFile = Join-Path $ProjectRoot '.env'
if (!(Test-Path -LiteralPath $EnvFile)) { throw 'Önce scripts/setup.ps1 çalıştırılmalı.' }
Get-Content -LiteralPath $EnvFile | ForEach-Object {
  $l = $_.Trim()
  $idx = $l.IndexOf('=')
  if ($idx -gt 0) {
    $k = $l.Substring(0, $idx).Trim()
    $v = $l.Substring($idx + 1).Trim()
    Set-Item "Env:$k" $v
    [Environment]::SetEnvironmentVariable($k, $v, 'Process')
  }
}
$PgBin = if ($env:NEXUS_PG_BIN) {
  $env:NEXUS_PG_BIN
} elseif (Test-Path -LiteralPath 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe') {
  'C:/laragon/bin/postgresql/postgresql/bin'
} else {
  Split-Path (Get-Command psql -ErrorAction Stop).Source -Parent
}
$PgData = if ($env:NEXUS_PG_DATA) { $env:NEXUS_PG_DATA } else { 'C:/laragon/data/nexustraveltech-postgresql' }
$env:Path = $PgBin + [IO.Path]::PathSeparator + $env:Path
