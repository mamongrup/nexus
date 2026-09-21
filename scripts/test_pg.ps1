. "$PSScriptRoot/env.ps1"
$pidFile = Join-Path $PgData 'postmaster.pid'
Write-Output "pidFile exists: $(Test-Path $pidFile)"
if (Test-Path $pidFile) {
    Get-Content $pidFile
}
& "$PgBin/pg_ctl.exe" status -D $PgData
Write-Output "pg_ctl status exit code: $LASTEXITCODE"
