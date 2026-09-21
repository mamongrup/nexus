. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Login
$r = Invoke-WebRequest "$base/login" -WebSession $session -UseBasicParsing
$csrf = [regex]::Match($r.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value
$null = Invoke-WebRequest "$base/login" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf; email='supplier@nexus.local'; password=$env:SUPPLIER_PASSWORD} -UseBasicParsing

# 1. Verify New Listing Page contains Rich Editor & AI Buttons
$formResp = Invoke-WebRequest "$base/admin/listings/new/hotel" -WebSession $session -UseBasicParsing
if (!$formResp.Content.Contains('rich-editor-container')) { throw 'FAIL: rich-editor-container not found in form' }
if (!$formResp.Content.Contains('data-ai-trigger="title"')) { throw 'FAIL: title AI trigger not found' }
if (!$formResp.Content.Contains('data-ai-trigger="description"')) { throw 'FAIL: description AI trigger not found' }
if (!$formResp.Content.Contains('data-ai-trigger="seo"')) { throw 'FAIL: seo AI trigger not found' }
if (!$formResp.Content.Contains('editor.js')) { throw 'FAIL: editor.js script tag not found' }
Write-Output 'PASS: Listing form contains Rich Editor, AI Buttons and editor.js'

# 2. Test POST /admin/ai/generate endpoint
$aiBody = @{
  csrf = $csrf
  category_code = 'hotel'
  locality = 'Beşiktaş / Boğaz Hattı, İstanbul'
  title = ''
  capacity = '2'
  field = 'all'
  ajax = '1'
}
$aiResp = Invoke-WebRequest "$base/admin/ai/generate" -Method Post -WebSession $session -Headers @{Origin=$base} -Body $aiBody -UseBasicParsing
$json = $aiResp.Content | ConvertFrom-Json
if (!$json.success) { throw 'FAIL: AI response not success' }
Write-Output "DEBUG DESCRIPTION:"
Write-Output $json.description
if (!$json.description.Contains('##')) { throw 'FAIL: AI description does not contain ##' }


# 3. Test individual field triggers
$aiTitle = (Invoke-WebRequest "$base/admin/ai/generate" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf; category_code='villa'; locality='Bodrum'; field='title'; ajax='1'} -UseBasicParsing).Content | ConvertFrom-Json
if (!$aiTitle.title.Contains('Bodrum')) { throw 'FAIL: Villa title generation' }
Write-Output "PASS: Title-only trigger verified: $($aiTitle.title)"

$aiSeo = (Invoke-WebRequest "$base/admin/ai/generate" -Method Post -WebSession $session -Headers @{Origin=$base} -Body @{csrf=$csrf; category_code='car'; locality='Antalya'; field='seo'; ajax='1'} -UseBasicParsing).Content | ConvertFrom-Json
if (!$aiSeo.seo_title.Contains('Antalya')) { throw 'FAIL: Car SEO generation' }
Write-Output "PASS: SEO-only trigger verified: $($aiSeo.seo_title)"

Write-Output 'ALL AI EDITOR & GENERATION CHECKS PASSED!'
