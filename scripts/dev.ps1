. "$PSScriptRoot/env.ps1"
Set-Location -LiteralPath $ProjectRoot
& "$PSScriptRoot/start-db.ps1"
& "$PSScriptRoot/config-key.ps1"
& "$PSScriptRoot/prepare-build.ps1"
Remove-Item Env:PGOWNER_PASSWORD,Env:ADMIN_PASSWORD,Env:SUPPLIER_PASSWORD,Env:AGENCY_PASSWORD -ErrorAction SilentlyContinue
gleam run
exit $LASTEXITCODE
