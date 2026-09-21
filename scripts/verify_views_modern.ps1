. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

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

Write-Output "=== Testing Modern Hugeicons Across Views ==="

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Http-Req "$base/login" -WebSession $session
$csrf = Csrf $r.Content
if (!$csrf) { throw "No CSRF found on login" }

$r = Http-Req "$base/login" -Method Post -WebSession $session -Headers @{Origin = $base} -Body @{
  csrf = $csrf
  email = 'admin@nexus.local'
  password = $env:ADMIN_PASSWORD
}

if ($r.StatusCode -ne 200) {
  Write-Output "Login returned status: $($r.StatusCode)"
}

$pages = @(
  '/',
  '/blog',
  '/ilanlar',
  '/admin/ai-hub',
  '/admin/campaigns',
  '/admin/rate-shopper',
  '/admin/users',
  '/admin/social-media',
  '/admin/category-fields/hotel',
  '/admin/accounting',
  '/admin/housekeeping',
  '/admin/hr'
)

$allPassed = $true
foreach ($p in $pages) {
  $res = Http-Req "$base$p" -WebSession $session
  $count = ([regex]::Matches($res.Content, 'huge-icon')).Count
  Write-Output ("{0,-30} HTTP {1} | huge-icon count: {2}" -f $p, $res.StatusCode, $count)
  if ($res.StatusCode -ne 200 -or $count -eq 0) {
    $allPassed = $false
  }
}

if ($allPassed) {
  Write-Output "`nSUCCESS: All admin and public pages render with HTTP 200 and modern Hugeicons!"
} else {
  throw "Some pages failed verification"
}
