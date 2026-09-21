. "$PSScriptRoot/env.ps1"
$pidFile = Join-Path $PgData 'postmaster.pid'
if (Test-Path -LiteralPath $pidFile) {
  $pidContent = Get-Content -LiteralPath $pidFile -TotalCount 1
  if ($pidContent -match '^\d+$') {
    $proc = Get-Process -Id ([int]$pidContent) -ErrorAction SilentlyContinue
    if (!$proc) {
      Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    }
  }
}
& "$PgBin/pg_ctl.exe" status -D $PgData *> $null
if ($LASTEXITCODE -ne 0) {
  $p = Start-Process -FilePath "$PgBin/pg_ctl.exe" -ArgumentList @('start','-D',$PgData,'-l',"$ProjectRoot/.local/postgresql.log",'-w') -WindowStyle Hidden -PassThru
  if (!$p.WaitForExit(30000)) { throw 'PostgreSQL başlatma zaman aşımı' }
  if ($p.ExitCode -ne 0) { throw 'PostgreSQL başlatılamadı; .local/postgresql.log dosyasını inceleyin.' }
}
