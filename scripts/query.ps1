param([string]$sql = "SELECT id, title, locality, capacity, nightly_minor, currency, status FROM catalog.properties;")
. "$PSScriptRoot/env.ps1"
$appPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -d $env:PGDATABASE -c $sql
} finally {
  $env:PGPASSWORD = $appPassword
}
