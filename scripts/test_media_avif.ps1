. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN
function Check($condition, $name) {
  if (!$condition) {
    throw "FAIL: $name"
  }
  Write-Output "PASS: $name"
}

function Csrf($html) {
  [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value
}

function Http-Req {
  param($Uri, $Method = 'GET', $WebSession, $Headers, $Body)
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

Write-Output "=== Testing AVIF Upload & Video Showcase ==="

# 1. Login as supplier
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $session
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got CSRF token ($csrf)"

$r = Http-Req "$base/login" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  email = 'supplier@nexus.local'
  password = $env:SUPPLIER_PASSWORD
}
Check ($r.StatusCode -eq 200) "Supplier login successful"

# 2. Get listing form CSRF
$r = Http-Req "$base/admin/listings/new" -WebSession $session
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got listing form CSRF token"
Check ($r.Content.Contains('hero_file_input')) "Listing form has hero image file input"
Check ($r.Content.Contains('hero_image')) "Listing form has hero_image input"
Check ($r.Content.Contains('gallery_file_input')) "Listing form has gallery file input"
Check ($r.Content.Contains('video_url')) "Listing form has video_url input"
Check ($r.Content.Contains('AVIF')) "Listing form mentions AVIF optimization"

# 3. Test AVIF upload via /admin/media/upload
# A small valid AVIF base64 test header (ftypavif box)
$sampleAvifB64 = "AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAADybWV0YQAAAAAAAAAoaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAGxpYmF2aWYAAAAADnBpdG0AAAAAAAEAAAAeaWxvYwAAAABEAAABAAEAAAAAAUoAAgAAAAEAAA=="
$r = Http-Req "$base/admin/media/upload" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  data = "data:image/avif;base64,$sampleAvifB64"
}
Check ($r.StatusCode -eq 200) "POST /admin/media/upload status 200"
$json = $r.Content | ConvertFrom-Json
Check ($json.success -eq $true) "Upload returned success=true"
Check ($json.format -eq 'avif') "Upload format is avif"
Check ($json.url.StartsWith('/static/uploads/') -and $json.url.EndsWith('.avif')) "Upload returned valid URL: $($json.url)"

# Verify file exists on disk
$localPath = "priv/static/uploads/$($json.filename)"
Check (Test-Path $localPath) "Uploaded AVIF file exists on disk at $localPath"
$uploadedAvifUrl = $json.url

# 4. Create listing with AVIF hero, gallery, and video
$title = "Luxury-AVIF-Villa-" + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$galleryUrls = "$uploadedAvifUrl,https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1000,https://images.unsplash.com/photo-1613977257363-707ba9348227?w=1000"
$videoUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

$r = Http-Req "$base/admin/listings" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  title = $title
  locality = 'Kas Antalya'
  capacity = '8'
  price = '18500.00'
  currency = 'TRY'
  hero_image = $uploadedAvifUrl
  gallery_images = $galleryUrls
  video_url = $videoUrl
  description = 'Luxury Kas Villa with AVIF photos and virtual tour video.'
  seo_title = "$title - Kas Luxury Villa"
  seo_description = 'Kas luxury villa rental with private pool and sea view.'
}
Write-Output "POST /admin/listings StatusCode: $($r.StatusCode)"
Check ($r.StatusCode -eq 303 -or $r.StatusCode -eq 302 -or $r.StatusCode -eq 200) "Listing created successfully"
if ($r.StatusCode -eq 303 -or $r.StatusCode -eq 302) {
  $r = Http-Req "$base/admin/listings" -WebSession $session
}

# 5. Fetch property ID from database
$appPassword = $env:PGPASSWORD
$propertyId = $null
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  $propertyId = & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT id FROM catalog.properties WHERE title='$title'"
  $dbMedia = & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT media::text FROM catalog.properties WHERE title='$title'"
  $dbVideo = & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT attributes->>'video_url' FROM catalog.properties WHERE title='$title'"
} finally {
  $env:PGPASSWORD = $appPassword
}

Check ($propertyId -match '^[a-f0-9-]{36}$') "Property persisted with UUID: $propertyId"
Check ($dbMedia.Contains($uploadedAvifUrl)) "Property media array in DB contains uploaded AVIF URL"
Check ($dbVideo -eq $videoUrl) "Property video_url in DB matches expected YouTube URL"

# 6. Test catalog.edit_values stored procedure
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  $editValues = & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc "SELECT * FROM catalog.edit_values('$propertyId')"
} finally {
  $env:PGPASSWORD = $appPassword
}
$editValuesStr = $editValues -join "`n"
Write-Output "DEBUG editValues: $editValuesStr"
Check ($editValuesStr.Contains($uploadedAvifUrl)) "catalog.edit_values returns hero_image AVIF"
Check ($editValuesStr.Contains($videoUrl)) "catalog.edit_values returns video_url"

# 7. Publish the listing so it appears on public marketplace
$r = Http-Req "$base/admin/listings/$propertyId/status" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  version = '1'
  status = 'published'
}
Check ($r.StatusCode -eq 200) "Listing published successfully"

# 8. Check public marketplace listing detail page
$r = Http-Req "$base/ilan/$propertyId"
Check ($r.StatusCode -eq 200) "Public marketplace detail page returns 200"
Check ($r.Content.Contains($uploadedAvifUrl)) "Public page contains uploaded AVIF image URL"
Check ($r.Content.Contains('detail-thumbnail-strip')) "Public page renders thumbnail strip gallery"
Check ($r.Content.Contains('video-card')) "Public page renders Video showcase card"

Write-Output "ALL AVIF UPLOAD & VIDEO TESTS PASSED SUCCESSFULLY!"
