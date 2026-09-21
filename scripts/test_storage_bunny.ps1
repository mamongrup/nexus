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

Write-Output "=== Testing Configurable Local & BunnyCDN Storage ==="

# 1. Login as supplier
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $session
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got CSRF token from login"

$r = Http-Req "$base/login" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  email = 'supplier@nexus.local'
  password = $env:SUPPLIER_PASSWORD
}
Check ($r.StatusCode -eq 200) "Supplier login successful"

# 2. Verify listing form UI has CDN and storage badges
$r = Http-Req "$base/admin/listings/new" -WebSession $session
$csrf = Csrf $r.Content
Check ($csrf.Length -gt 20) "Got listing form CSRF"
Check ($r.Content.Contains('cdn-badge')) "Listing form contains cdn-badge CSS class"
Check ($r.Content.Contains('BunnyCDN')) "Listing form mentions BunnyCDN"

# 3. Test standard AVIF upload to local storage
$sampleBase64 = "data:image/avif;base64,AAAAIGZ0eXBhdmlmAAAAAGF2aWZtZGF0AAAAAA=="
$r = Http-Req "$base/admin/media/upload" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  data = $sampleBase64
}
Check ($r.StatusCode -eq 200) "POST /admin/media/upload status 200"
$json = $r.Content | ConvertFrom-Json
Check ($json.success -eq $true) "Upload returned success=true"
Check ($json.format -eq "avif") "Upload format is avif"
Check ($json.local_saved -eq $true) "File confirmed saved to local storage"
$defaultFile = Join-Path "priv/static/uploads" $json.filename
Check (Test-Path $defaultFile) "Uploaded AVIF exists on local disk: $defaultFile"

# 4. Test BunnyCDN test endpoint
$r = Http-Req "$base/admin/storage/test_bunny" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  region = 'storage.bunnycdn.com'
  zone = 'test-zone'
  api_key = 'dummy-key'
}
Check ($r.StatusCode -ne 500) "BunnyCDN test endpoint handled gracefully without server crash"
Write-Output "BunnyCDN test response: $($r.Content)"

# 5. Test Listing creation with returned image URL
$testTitle = "BunnyCDN-Storage-Villa-" + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$r = Http-Req "$base/admin/listings" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  title = $testTitle
  locality = 'Bodrum Mugla'
  capacity = '6'
  price = '25000.00'
  currency = 'TRY'
  hero_image = $json.url
  gallery_images = "$($json.url),https://images.unsplash.com/photo-1512917774080-9991f1c4c750.avif"
  video_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  description = "Luxury Villa with BunnyCDN and local storage integration."
  seo_title = "$testTitle - Luxury Villa"
  seo_description = "Bodrum luxury villa with private pool"
}
Write-Output "POST /admin/listings StatusCode: $($r.StatusCode)"
if ($r.StatusCode -ne 200 -and $r.StatusCode -ne 302 -and $r.StatusCode -ne 303) {
  $noticeMatch = [regex]::Match($r.Content, '<div class="panel notice[^>]*>(.*?)</div>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  Write-Output "Notice: $($noticeMatch.Groups[1].Value.Trim())"
}
Check ($r.StatusCode -eq 303 -or $r.StatusCode -eq 302 -or $r.StatusCode -eq 200) "Listing with storage image created successfully"

Write-Output "`n*** ALL STORAGE & BUNNYCDN INTEGRATION TESTS PASSED (100% SUCCESS) ***"
