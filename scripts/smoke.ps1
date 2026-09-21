. "$PSScriptRoot/env.ps1"
$base=$env:APP_ORIGIN
function Check($condition,$name) { if (!$condition) { throw "FAIL: $name" }; Write-Output "PASS: $name" }
function Csrf($html) { [regex]::Match($html,'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value }
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
$r=Http-Req "$base/v1/health"; Check ($r.StatusCode -eq 200 -and $r.Content.Contains('ready')) 'database health'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r=Http-Req "$base/login" -WebSession $session
$csrf=Csrf $r.Content
Check ($csrf.Length -gt 20) 'CSRF token'
$r=Http-Req "$base/login" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;email='supplier@nexus.local';password=$env:SUPPLIER_PASSWORD}
Check ($r.StatusCode -eq 200 -and ($r.Content.Contains('Genel bak') -or $r.Content.Contains('SUPPLIER WORKSPACE'))) 'supplier login'
$r=Http-Req "$base/admin/listings/new" -WebSession $session
$csrf=Csrf $r.Content
$r=Http-Req "$base/admin/listings" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf='invalid';title='Wrong token'}
Check ($r.StatusCode -eq 403) 'CSRF rejection'
$r=Http-Req "$base/admin/listings" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;title='x';locality='Test';capacity='0';price='-1';currency='TRY'}
Check ($r.StatusCode -eq 422) 'invalid listing rejection'
$title='Smoke-' + [Guid]::NewGuid().ToString('N')
$propertyId=$null
try {
 $r=Http-Req "$base/admin/listings" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;title=$title;locality='Test';capacity='4';price='4500.10';currency='TRY';description='<script>alert(1)</script>'}
  if ($r.StatusCode -eq 303 -or $r.StatusCode -eq 302) {
    $r=Http-Req "$base/admin/listings" -WebSession $session
  }
 Check ($r.StatusCode -eq 200 -and $r.Content.Contains($title)) 'persistent draft creation'
 $form=[regex]::Match($r.Content,'action="/admin/listings/([^"]+)/status"[^>]*>.*?name="version"[^>]*value="([0-9]+)"')
 # Resolve only the exact fixture from the database, independent of existing user listings.
 $appPassword=$env:PGPASSWORD
 try {
   $env:PGPASSWORD=$env:PGOWNER_PASSWORD
   $propertyId= & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT id FROM catalog.properties WHERE title='$title'"
 } finally { $env:PGPASSWORD=$appPassword }
 Check ($propertyId -match '^[a-f0-9-]{36}$') 'fixture persisted in PostgreSQL'
 $public=Http-Req "$base/"
 Check (!$public.Content.Contains($title)) 'draft excluded from public catalog'
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version='1';status='published'}
 Check ($r.StatusCode -eq 200) 'publish command'
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version='1';status='draft'}
 Check ($r.StatusCode -eq 409) 'stale version rejected'
 $public=Http-Req "$base/?q=$title"
 Check (!$public.Content.Contains($title) -and $public.Content.Contains('NEXUS')) 'corporate homepage excludes travel listings'
 $r=Http-Req "$base/admin/listings" -WebSession $session
 Check ($r.Content.Contains($title) -and $r.Content.Contains('4500.10')) 'listing and exact money remain in program'
 Check (!$public.Content.Contains('<script>alert(1)</script>')) 'HTML injection escaped'
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version='2';status='draft'}
 Check ($r.StatusCode -eq 200) 'unpublish command'
 $public=Http-Req "$base/?q=$title"
 Check (!$public.Content.Contains('<h2>'+ $title)) 'unpublished item removed'
 $r=Http-Req "$base/logout" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf}
 $r=Http-Req "$base/admin" -WebSession $session
 Check ($r.Content.Contains('Tekrar') -or $r.Content.Contains('login')) 'logout revokes session'
} finally {
 # Only this script's GUID-named fixture and its own events are removed.
 if ($propertyId -match '^[a-f0-9-]{36}$') {
  $appPassword=$env:PGPASSWORD
  try {
   $env:PGPASSWORD=$env:PGOWNER_PASSWORD
   & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -c "BEGIN; DELETE FROM events.audit WHERE resource_id='$propertyId'; DELETE FROM events.outbox WHERE aggregate_id='$propertyId'; DELETE FROM catalog.properties WHERE id='$propertyId' AND title='$title'; COMMIT;" | Out-Null
  } finally { $env:PGPASSWORD=$appPassword }
 }
}
