$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw 'Production .env is missing.' }
& "$PSScriptRoot/check-production-gates.ps1" -EnvPath $envFile
if ($LASTEXITCODE -ne 0) { throw 'Production configuration failed.' }
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim() }
}
$gleam = (Get-Command gleam -ErrorAction Stop).Source
Set-Location -LiteralPath $root
New-Item -ItemType Directory -Path (Join-Path $root '.local') -Force | Out-Null
& $gleam build
if ($LASTEXITCODE -ne 0) { throw 'NEXUS build failed.' }
# Keep database owner and bootstrap credentials out of the web process.
Remove-Item Env:PGOWNER_PASSWORD,Env:ADMIN_PASSWORD,Env:SUPPLIER_PASSWORD,Env:AGENCY_PASSWORD -ErrorAction SilentlyContinue
& $gleam run
if ($LASTEXITCODE -ne 0) { throw "NEXUS server exited: $LASTEXITCODE" }
