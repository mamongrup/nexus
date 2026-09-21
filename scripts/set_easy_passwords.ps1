. "$PSScriptRoot/env.ps1"
$saved = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -c "UPDATE auth.users SET password_hash = crypt('password123', gen_salt('bf', 12)) WHERE email IN ('admin@nexus.local', 'supplier@nexus.local', 'agency@nexus.local');"
  Write-Host "Passwords updated in DB."
} finally {
  $env:PGPASSWORD = $saved
}
