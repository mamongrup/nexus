. "$PSScriptRoot/env.ps1"
$env:PGPASSWORD = $env:PGOWNER_PASSWORD
& "$PgBin/psql.exe" -p $env:PGPORT -U $env:PGOWNER -d $env:PGDATABASE -c "SELECT * FROM cms.public_pages();"
