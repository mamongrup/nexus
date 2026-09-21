. "$PSScriptRoot/env.ps1"
$appPassword = $env:PGPASSWORD

try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  $sqlFile = "$PSScriptRoot/fix_marketplace_images.sql"
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -d $env:PGDATABASE -f $sqlFile
  Write-Output "Successfully executed fix_marketplace_images.sql."
} finally {
  $env:PGPASSWORD = $appPassword
}
