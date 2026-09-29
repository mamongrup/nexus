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
# Owner connection for the read-only verification queries below.
function Owner-Sql {
  param([string]$Query)
  $appPassword=$env:PGPASSWORD
  try {
    $env:PGPASSWORD=$env:PGOWNER_PASSWORD
    return (& "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc $Query)
  } finally { $env:PGPASSWORD=$appPassword }
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
 # A listing can only be submitted once it satisfies the category contract, so
 # the fixture carries the required holiday_home fields plus description and SEO
 # text. submit_for_review rejects an incomplete listing by design.
 $r=Http-Req "$base/admin/listings" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{
   csrf=$csrf; title=$title; locality='Test'; capacity='4'; price='4500.10'; currency='TRY';
   description='<script>alert(1)</script> Smoke fixture description for the moderation chain.';
   category_code='holiday_home';
   seo_title='Smoke SEO title'; seo_description='Smoke fixture used by scripts/smoke.ps1 to verify the two layer publication contract.';
   hero_image='https://cdn.example.invalid/smoke-fixture.jpg';
   attr_property_type='Villa'; attr_bedroom_count='2'; attr_bathroom_count='1'; attr_guest_capacity='4'
 }
  if ($r.StatusCode -eq 303 -or $r.StatusCode -eq 302) {
    $r=Http-Req "$base/admin/listings" -WebSession $session
  }
 Check ($r.StatusCode -eq 200 -and $r.Content.Contains($title)) 'persistent draft creation'
 # Resolve only the exact fixture from the database, independent of existing user listings.
 $propertyId= Owner-Sql "SELECT id FROM catalog.properties WHERE title='$title'"
 Check ($propertyId -match '^[a-f0-9-]{36}$') 'fixture persisted in PostgreSQL'
 $public=Http-Req "$base/"
 Check (!$public.Content.Contains($title)) 'draft excluded from public catalog'

 # Contract 1.2.0: publication is a two layer state machine. The supplier may
 # only submit for review, moderation_status 'approved' is a platform decision,
 # and approval is what sets status to published. Re-publishing afterwards and
 # un-publishing are platform operations; the supplier only refreshes freshness.
 $version = Owner-Sql "SELECT version FROM catalog.properties WHERE id='$propertyId'"
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version=$version;status='published'}
 Check ($r.StatusCode -eq 403) 'supplier cannot publish before approval'

 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version=$version;status='submit'}
 Check ($r.StatusCode -eq 200) 'supplier submits for review'
 $state = Owner-Sql "SELECT status||'/'||moderation_status FROM catalog.properties WHERE id='$propertyId'"
 Check ($state -eq 'draft/in_review') 'submission moves moderation to in_review'
 $version = Owner-Sql "SELECT version FROM catalog.properties WHERE id='$propertyId'"

 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version=$version;status='approved'}
 Check ($r.StatusCode -eq 403) 'supplier cannot approve own listing'

 $nexus = New-Object Microsoft.PowerShell.Commands.WebRequestSession
 $r=Http-Req "$base/login" -WebSession $nexus
 $nexusCsrf=Csrf $r.Content
 $r=Http-Req "$base/login" -Method Post -WebSession $nexus -Headers @{Origin=$base} -Body @{csrf=$nexusCsrf;email=$env:ADMIN_EMAIL;password=$env:ADMIN_PASSWORD}
 Check ($r.StatusCode -eq 200) 'nexus admin login'
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $nexus -Headers @{Origin=$base} -Body @{csrf=$nexusCsrf;version=$version;status='approved'}
 Check ($r.StatusCode -eq 200) 'platform moderation approves listing'
 $state = Owner-Sql "SELECT status||'/'||moderation_status FROM catalog.properties WHERE id='$propertyId'"
 Check ($state -eq 'published/approved') 'approval publishes the listing'
 Check ((Owner-Sql "SELECT count(*) FROM catalog.published() WHERE id='$propertyId'") -eq '1') 'approved listing enters the public catalog'

 $version = Owner-Sql "SELECT version FROM catalog.properties WHERE id='$propertyId'"
 # The supplier owns freshness but not suspension: an unconfirmed listing simply
 # ages out of the catalogue, and only the platform can take it down.
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version=$version;status='confirm_current'}
 Check ($r.StatusCode -eq 200) 'supplier confirms listing is current'
 $version = Owner-Sql "SELECT version FROM catalog.properties WHERE id='$propertyId'"

 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version=$version;status='suspended'}
 Check ($r.StatusCode -eq 403) 'supplier cannot suspend own listing'
 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $nexus -Headers @{Origin=$base} -Body @{csrf=$nexusCsrf;version=$version;status='suspended';note='Smoke suspension'}
 Check ($r.StatusCode -eq 200) 'platform suspend command'
 $state = Owner-Sql "SELECT status||'/'||moderation_status FROM catalog.properties WHERE id='$propertyId'"
 Check ($state -eq 'draft/suspended') 'suspension withdraws the listing'
 Check ((Owner-Sql "SELECT count(*) FROM catalog.published() WHERE id='$propertyId'") -eq '0') 'suspended listing leaves the public catalog'

 $r=Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf;version='1';status='submit'}
 Check ($r.StatusCode -eq 409) 'stale version rejected'
 $r=Http-Req "$base/admin/listings" -WebSession $session
 Check ($r.Content.Contains($title) -and $r.Content.Contains('4500.10')) 'listing and exact money remain in program'
 $public=Http-Req "$base/?q=$title"
 Check (!$public.Content.Contains('<script>alert(1)</script>')) 'HTML injection escaped'
 # The public site is a corporate program site and is not a travel catalogue.
 Check (!$public.Content.Contains($title) -and $public.Content.Contains('NEXUS')) 'corporate homepage excludes travel listings'
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
