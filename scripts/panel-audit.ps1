. "$PSScriptRoot/env.ps1"
$base=$env:APP_ORIGIN
$fixture=[guid]::NewGuid().ToString()
$supplier=[guid]::NewGuid().ToString()
$agency=[guid]::NewGuid().ToString()
$nexus=[guid]::NewGuid().ToString()
$bytes = New-Object byte[] 24
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:NEXUS_TEST_PASSWORD = [System.BitConverter]::ToString($bytes) -replace '-'
$sqlFile=Join-Path $ProjectRoot ".local/reservation-$fixture.sql"
function Assert($value,$name) { if (!$value) { throw "FAIL: $name" }; Write-Host "PASS: $name" }
function Sql($content) {
 $content | Set-Content -LiteralPath $sqlFile -Encoding utf8
 $appPassword=$env:PGPASSWORD
 try {
  $env:PGPASSWORD=$env:PGOWNER_PASSWORD
  $value=& "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -Atq -f $sqlFile
  if($LASTEXITCODE -ne 0) { throw 'Fixture SQL failed' }
  return $value
 } finally { $env:PGPASSWORD=$appPassword }
}
function Token($content) { [regex]::Match($content,'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value }
function Http-Req {
 param($Uri, $Method='GET', $WebSession, $Headers, $Body)
 $p = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true }
 if ($WebSession) { $p['WebSession'] = $WebSession }
 if ($Headers) { $p['Headers'] = $Headers }
 if ($Body) { $p['Body'] = $Body }
 try {
  Invoke-WebRequest @p
 } catch [System.Net.WebException] {
  $resp = $_.Exception.Response
  if ($resp) {
   $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
   $content = $reader.ReadToEnd()
   return [PSCustomObject]@{
    StatusCode = [int]$resp.StatusCode
    Content = $content
   }
  }
  throw $_
 }
}
function Login($id) {
 $page=Http-Req "$base/login"
 $browser = New-Object Microsoft.PowerShell.Commands.WebRequestSession
 $page=Http-Req "$base/login" -WebSession $browser
 $page=Http-Req "$base/login" -Method Post -WebSession $browser -Headers @{Origin=$base} -Body @{csrf=(Token $page.Content);email="$id@test.local";password=$env:NEXUS_TEST_PASSWORD}
 Assert ($page.StatusCode -eq 200) 'fixture login'
 return @{browser=$browser;csrf=(Token $page.Content)}
}
function Post($who,$path,$values) {
 $values.csrf=$who.csrf
 Http-Req "$base$path" -Method Post -WebSession $who.browser -Headers @{Origin=$base} -Body $values
}
try {
 Sql @"
\getenv test_password NEXUS_TEST_PASSWORD
BEGIN;
INSERT INTO core.organizations(id,legal_name,kind) VALUES('$supplier','HTTP test supplier','supplier'),('$agency','HTTP test agency','agency'),('$nexus','HTTP test nexus','nexus');
INSERT INTO auth.users(tenant_id,email,password_hash,display_name) SELECT id,id::text||'@test.local',crypt(:'test_password',gen_salt('bf',12)),'HTTP test' FROM core.organizations WHERE id IN ('$supplier','$agency','$nexus');
COMMIT;
"@ | Out-Null
 $s=Login $supplier; $a=Login $agency; $n=Login $nexus

 foreach($entry in @(@{role='nexus';who=$n},@{role='supplier';who=$s})) {
  foreach($path in @('/admin','/admin/application','/admin/listings','/admin/listings/new','/admin/modules','/admin/calendar','/admin/options','/admin/reservations','/admin/applications','/admin/category-fields','/admin/partners','/admin/ai','/admin/finance','/admin/pricing','/admin/departments','/admin/site','/admin/settings')) {
   try {
    $response=Invoke-WebRequest -Uri "$base$path" -WebSession $entry.who.browser -UseBasicParsing -SkipHttpErrorCheck
    $heading=[regex]::Match($response.Content,'<h1[^>]*>(.*?)</h1>').Groups[1].Value -replace '<[^>]+>',''
    Write-Output "$($entry.role) | $path | $($response.StatusCode) | $heading"
   } catch { Write-Output "$($entry.role) | $path | ERROR | $($_.Exception.Message)" }
  }
 }
} finally {
 Sql @"
BEGIN;
DELETE FROM booking.reservations WHERE tenant_id='$supplier';
DELETE FROM booking.option_requests WHERE supplier_id='$supplier';
DELETE FROM inventory.allocations WHERE tenant_id='$supplier';
DELETE FROM booking.holds WHERE tenant_id='$supplier';
DELETE FROM booking.quotes WHERE tenant_id='$supplier';
DELETE FROM inventory.days WHERE tenant_id='$supplier';
DELETE FROM inventory.resources WHERE tenant_id='$supplier';
DELETE FROM catalog.properties WHERE tenant_id='$supplier';
DELETE FROM partners.connections WHERE supplier_id='$supplier';
DELETE FROM events.audit WHERE tenant_id IN ('$supplier','$agency','$nexus');
DELETE FROM events.outbox WHERE tenant_id IN ('$supplier','$agency','$nexus');
DELETE FROM settings.values WHERE tenant_id IN ('$supplier','$agency','$nexus');
DELETE FROM cms.revisions WHERE slug='http-$fixture';
DELETE FROM cms.pages WHERE slug='http-$fixture';
DELETE FROM auth.users WHERE tenant_id IN ('$supplier','$agency','$nexus');
DELETE FROM core.organizations WHERE id IN ('$supplier','$agency','$nexus');
COMMIT;
"@ | Out-Null
 Remove-Item -LiteralPath $sqlFile -ErrorAction SilentlyContinue
 Remove-Item Env:NEXUS_TEST_PASSWORD -ErrorAction SilentlyContinue
}
