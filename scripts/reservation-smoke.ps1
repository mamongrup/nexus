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
 $slug="http-$fixture"
 $page=Post $n '/admin/site' @{slug=$slug;title='Fixture page'}
 Assert ($page.Content.Contains('tamamland')) 'CMS creates draft page'
 $page=Post $n "/admin/site/$slug/save" @{title='CMS HTTP fixture';summary='Description';body='<script>test</script>';version='1'}
 Assert ($page.Content.Contains('tamamland')) 'CMS saves draft'
 $page=Http-Req "$base/admin/site/$slug/preview" -WebSession $n.browser
 Assert ($page.Content.Contains('CMS HTTP fixture')) 'authenticated draft preview'
 $page=Http-Req "$base/$slug"
 Assert ($page.StatusCode -eq 404) 'CMS draft not public'
 $page=Post $n "/admin/site/$slug/publish" @{version='2';publish='true'}
 Assert ($page.Content.Contains('tamamland')) 'CMS publishes saved draft'
 $page=Http-Req "$base/$slug"
 Assert ($page.Content.Contains('CMS HTTP fixture') -and !$page.Content.Contains('<script>test</script>')) 'published CMS page escapes HTML'
 $page=Post $a "/admin/site/$slug/save" @{title='Unauthorized';summary='';body='';version='3'}
 Assert ($page.StatusCode -eq 403) 'agency cannot edit corporate content'
 $page=Post $n "/admin/site/$slug/publish" @{version='3';publish='false'}
 Assert ($page.Content.Contains('tamamland')) 'CMS unpublishes'
 $page=Http-Req "$base/$slug"
 Assert ($page.StatusCode -eq 404) 'unpublished CMS page not public'
 $page=Http-Req "$base/admin/settings" -WebSession $s.browser
 Assert ($page.StatusCode -eq 403) 'supplier cannot access system settings'
 $page=Http-Req "$base/admin/settings" -WebSession $a.browser
 Assert ($page.Content.Contains('agency_pos.guid') -and !$page.Content.Contains('ai.openai_key')) 'agency sees only own POS fields'
 $page=Post $a '/admin/settings' @{key='ai.openai_key';value='unauthorized';version='0';action='save'}
 Assert (!$page.Content.Contains('tamamland')) 'agency cannot write NEXUS AI key'
 $secret="synthetic-$fixture"
 $page=Post $n '/admin/settings' @{key='ai.openai_key';value=$secret;version='0';action='save'}
 Assert ($page.Content.Contains('tamamland') -and !$page.Content.Contains($secret)) 'secret saved without HTML disclosure'
 $encrypted=Sql "SELECT value LIKE 'v1:%' AND value NOT LIKE '%$secret%' FROM settings.values WHERE tenant_id='$nexus' AND key='ai.openai_key';"
 Assert ($encrypted -eq 't') 'database contains encrypted secret'
 $page=Post $n '/admin/settings' @{key='ai.openai_key';value='';version='1';action='save'}
 Assert ($page.Content.Contains('korundu')) 'blank secret preserves stored value'
 $page=Post $n '/admin/settings' @{key='ai.openai_key';value='replacement';version='0';action='save'}
 Assert ($page.Content.Contains('oturumda')) 'stale setting update rejected'
 $leaked=Sql "SELECT count(*) FROM events.audit WHERE tenant_id='$nexus' AND payload::text LIKE '%$secret%';"
 Assert ($leaked -eq '0') 'audit excludes secret'
 $page=Post $n '/admin/settings' @{key='ai.openai_key';value='';version='1';action='clear'}
 Assert ($page.Content.Contains('tamamland')) 'secret can be explicitly cleared'
 Sql "UPDATE auth.users SET role='viewer' WHERE tenant_id='$nexus';" | Out-Null
 $page=Http-Req "$base/admin/settings" -WebSession $n.browser
 Assert ($page.StatusCode -eq 403) 'viewer cannot access settings'
 Sql "UPDATE auth.users SET role='owner' WHERE tenant_id='$nexus';" | Out-Null
 $page=Post $n '/admin/partners' @{supplier=$supplier;agency=$agency;status='active'}
 Assert ($page.Content.Contains('tamamland')) 'NEXUS connects supplier and agency'
 $title="HTTP-$fixture"
 $page=Post $s '/admin/listings' @{title=$title;locality='Test';capacity='2';price='100.00';currency='TRY';description='Temporary integration fixture'}
 Assert ($page.StatusCode -eq 200 -and $page.Content.Contains($title)) 'supplier creates listing'
 $property=Sql "SELECT id FROM catalog.properties WHERE tenant_id='$supplier';"
 $page=Post $s "/admin/listings/$property/status" @{version='1';status='published'}
 Assert ($page.StatusCode -eq 200) 'supplier publishes'
 $start=(Get-Date).AddDays(10).ToString('yyyy-MM-dd'); $end=(Get-Date).AddDays(12).ToString('yyyy-MM-dd')
 $page=Post $s '/admin/calendar' @{property=$property;start=$start;end=$end;price='100.00'}
 Assert ($page.Content.Contains('tamamland')) 'supplier configures calendar'
 $page=Http-Req "$base/admin" -WebSession $a.browser
 Assert ($page.Content.Contains($title)) 'agency sees connected catalog'
 $page=Post $a '/admin/requests' @{property=$property;start=$start;end=$end;minutes='30';request_key=$fixture}
 Assert ($page.Content.Contains('tamamland')) 'agency requests option'
 $request=Sql "SELECT id FROM booking.option_requests WHERE agency_id='$agency';"
 $page=Post $s "/admin/requests/$request/decide" @{decision='approved'}
 Assert ($page.Content.Contains('tamamland')) 'supplier approves option'
 $page=Http-Req "$base/admin/requests" -WebSession $a.browser
 Assert ($page.Content.Contains('200.00 TRY') -and $page.Content.Contains("/admin/requests/$request/confirm")) 'agency sees frozen total and confirmation action'
 $page=Post $a "/admin/requests/$request/confirm" @{}
 Assert ($page.Content.Contains('tamamland') -and $page.Content.Contains('denmedi')) 'agency confirms unpaid reservation'
 $page=Post $a "/admin/requests/$request/confirm" @{}
 Assert ($page.Content.Contains('rezervasyon')) 'duplicate submit is idempotent'
 $reservation=Sql "SELECT id FROM booking.reservations WHERE agency_id='$agency';"
 $page=Post $s "/admin/reservations/$reservation/cancel" @{}
 Assert ($page.Content.Contains('tamamland') -and $page.Content.Contains('cancelled')) 'supplier cancels unpaid reservation'
 $stock=Sql "SELECT coalesce(sum(held+sold),0) FROM inventory.days WHERE tenant_id='$supplier';"
 Assert ($stock -eq '0') 'stock returned after cancellation'
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
