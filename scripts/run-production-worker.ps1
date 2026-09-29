param([Parameter(Mandatory = $true)][ValidateSet('supplier-expiry','agency-booking-expiry')][string]$Name)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/check-production-gates.ps1" -EnvPath (Join-Path $root '.env')
if ($LASTEXITCODE -ne 0) { throw 'Production configuration failed.' }
New-Item -ItemType Directory -Path (Join-Path $root '.local') -Force | Out-Null
& (Join-Path $PSScriptRoot "$Name-worker.ps1")
if ($LASTEXITCODE -ne 0) { throw "NEXUS worker exited: $Name" }
