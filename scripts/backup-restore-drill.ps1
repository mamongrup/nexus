param(
  [string]$OutputDirectory = '.local/backups',
  [switch]$RestoreTest
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/env.ps1"

$database = $env:PGDATABASE
if ([string]::IsNullOrWhiteSpace($database)) { throw 'PGDATABASE is required.' }
$dumpTool = (Get-Command pg_dump -ErrorAction Stop).Source
$restoreTool = (Get-Command pg_restore -ErrorAction Stop).Source
$createTool = (Get-Command createdb -ErrorAction Stop).Source
$dropTool = (Get-Command dropdb -ErrorAction Stop).Source
$queryTool = (Get-Command psql -ErrorAction Stop).Source
foreach ($tool in @($dumpTool, $restoreTool, $createTool, $dropTool, $queryTool)) {
  if (!(Test-Path -LiteralPath $tool)) { throw "PostgreSQL tool missing: $tool" }
}

$backupDirectory = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
  $OutputDirectory
} else {
  Join-Path $ProjectRoot $OutputDirectory
}
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$dumpPath = Join-Path $backupDirectory ("$database-$(Get-Date -Format 'yyyyMMdd-HHmmss').dump")
$originalPassword = $env:PGPASSWORD
$env:PGPASSWORD = $env:PGOWNER_PASSWORD
try {
  & $dumpTool -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $database -Fc -f $dumpPath
  if ($LASTEXITCODE -ne 0) { throw "NEXUS backup failed: $LASTEXITCODE" }
  Write-Host "Backup created: $dumpPath"
  if (!$RestoreTest) { return }

  $temporaryDatabase = "${database}_restore_$([guid]::NewGuid().ToString('N').Substring(0, 8))"
  $created = $false
  try {
    & $createTool -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER $temporaryDatabase
    if ($LASTEXITCODE -ne 0) { throw 'Could not create temporary restore database.' }
    $created = $true

    & $restoreTool -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $temporaryDatabase --no-owner --no-privileges $dumpPath
    if ($LASTEXITCODE -ne 0) { throw 'NEXUS restore failed.' }
    $result = & $queryTool -X -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $temporaryDatabase -At -c 'SELECT count(*) FROM core.organizations;'
    if ($LASTEXITCODE -ne 0 -or $result -notmatch '^\d+$') { throw 'NEXUS restore verification failed.' }
    Write-Host "Restore drill passed. Organizations: $result"
  } finally {
    if ($created) {
      & $dropTool -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER --if-exists $temporaryDatabase
      if ($LASTEXITCODE -ne 0) { throw "Temporary restore database cleanup failed: $temporaryDatabase" }
    }
  }
} finally {
  $env:PGPASSWORD = $originalPassword
}
