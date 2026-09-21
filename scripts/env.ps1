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
$PgBin = 'C:/laragon/bin/postgresql/postgresql/bin'
$PgData = 'C:/laragon/data/nexustraveltech-postgresql'
$env:Path = 'C:/laragon/bin/gleam;C:/laragon/bin/erlang/bin;' + $PgBin + ';' + $env:Path

