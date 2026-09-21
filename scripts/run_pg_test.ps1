. "$PSScriptRoot/env.ps1"
Remove-Item -LiteralPath "$PgData/postmaster.pid" -Force -ErrorAction SilentlyContinue
& "$PgBin/postgres.exe" -D $PgData
