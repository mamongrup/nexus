. "$PSScriptRoot/env.ps1"
$base=$env:APP_ORIGIN
for($attempt=0;$attempt-lt 30;$attempt++){try{$ready=Invoke-RestMethod "$base/v1/health" -TimeoutSec 1;if($ready.database-eq'ready'){break}}catch{};Start-Sleep -Milliseconds 250}
$run=[guid]::NewGuid().ToString()
$supplier=[guid]::NewGuid().ToString(); $nexus=[guid]::NewGuid().ToString()
$bytes=New-Object byte[] 24; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:NEXUS_STAGE1_PASSWORD=[Convert]::ToBase64String($bytes)
$sqlFile=Join-Path $ProjectRoot ".local/stage1-$run.sql"
$testDocument=""
function Assert($value,$name){if(!$value){throw "FAIL: $name"};Write-Host "PASS: $name"}
function Sql($content){$content|Set-Content -LiteralPath $sqlFile -Encoding utf8;$saved=$env:PGPASSWORD;try{$env:PGPASSWORD=$env:PGOWNER_PASSWORD;$out=& "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -Atq -f $sqlFile;if($LASTEXITCODE-ne 0){throw 'Fixture SQL failed'};return $out}finally{$env:PGPASSWORD=$saved}}
function Token($content){[regex]::Match($content,'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value}
function Request($uri,$method='GET',$session=$null,$body=$null){$p=@{Uri="$base$uri";Method=$method;UseBasicParsing=$true;SkipHttpErrorCheck=$true};if($session){$p.WebSession=$session};if($body){$p.Body=$body;$p.Headers=@{Origin=$base}};Invoke-WebRequest @p}
function Login($id){$browser=New-Object Microsoft.PowerShell.Commands.WebRequestSession;$page=Request '/login' 'GET' $browser;$page=Request '/login' 'POST' $browser @{csrf=(Token $page.Content);email="$id@stage1.test";password=$env:NEXUS_STAGE1_PASSWORD};Assert ($page.StatusCode-eq 200) 'login';@{browser=$browser;csrf=(Token $page.Content)}}
function Post($who,$path,$values){$values.csrf=$who.csrf;Request $path 'POST' $who.browser $values}
function Upload($who,$path,$values,$file){$cookie=($who.browser.Cookies.GetCookies($base)|ForEach-Object{"$($_.Name)=$($_.Value)"})-join'; ';$responseFile=Join-Path $ProjectRoot ".local/upload-response-$run.txt";$args=@('-s','-o',$responseFile,'-w','%{http_code}','-b',$cookie,'-H',"Origin: $base",'-F',"csrf=$($who.csrf)");foreach($key in $values.Keys){$args+=@('-F',"$key=$($values[$key])")};$args+=@('-F',"document=@$file;type=application/pdf","$base$path");$status=& curl.exe @args;[pscustomobject]@{StatusCode=[int]$status;Content=(Get-Content $responseFile -Raw -ErrorAction SilentlyContinue)}}
try{
 Sql @"
\getenv test_password NEXUS_STAGE1_PASSWORD
INSERT INTO core.organizations(id,legal_name,kind) VALUES('$supplier','Stage 1 supplier','supplier'),('$nexus','Stage 1 nexus','nexus');
INSERT INTO auth.users(tenant_id,email,password_hash,display_name,role) SELECT id,id::text||'@stage1.test',crypt(:'test_password',gen_salt('bf',12)),'Stage 1','owner' FROM core.organizations WHERE id IN ('$supplier','$nexus');
"@|Out-Null
 $s=Login $supplier;$n=Login $nexus
 $page=Post $s '/admin/application' @{category='villa';legal_name='Stage 1 Supplier Ltd.';full_name='Stage One Supplier';tc='12345678901'};Assert ($page.StatusCode-eq 200) 'supplier creates application'
 $application=Sql "SELECT id FROM onboarding.applications WHERE tenant_id='$supplier';"
 $requirements=@(Sql "SELECT id FROM onboarding.requirements WHERE category_code='villa' AND required ORDER BY position;")
 $testDocument=Join-Path $ProjectRoot ".local/stage1-$run.pdf";[IO.File]::WriteAllBytes($testDocument,[Text.Encoding]::ASCII.GetBytes("%PDF-1.4`n% NEXUS stage 1 test`n%%EOF"))
 foreach($requirement in $requirements){$page=Upload $s "/admin/application/$application/document" @{requirement=$requirement} $testDocument;if($page.StatusCode-ne 200){Write-Host "UPLOAD RESPONSE: $($page.StatusCode) $($page.Content)"};Assert ($page.StatusCode-eq 200) 'supplier uploads required document'}
 $page=Post $n "/admin/applications/$application/identity" @{result='verified';reason='Stage 1 test'};Assert ($page.StatusCode-eq 200) 'NEXUS verifies identity'
 $documents=@(Sql "SELECT id FROM onboarding.documents WHERE application_id='$application';")
 foreach($document in $documents){$page=Post $n "/admin/applications/document/$document" @{status='accepted'};Assert ($page.StatusCode-eq 200) 'NEXUS accepts document'}
 $page=Post $n "/admin/applications/$application/decision" @{decision='approved';reason='All requirements complete'};Assert ($page.StatusCode-eq 200) 'NEXUS approves supplier category'
 $page=Request '/admin/listings/new/villa' 'GET' $s.browser;Assert ($page.StatusCode-eq 200-and$page.Content.Contains('attr_bedrooms')) 'approved listing form is available'
 $title="Stage 1 listing $run"
 $page=Post $s '/admin/listings' @{category_code='villa';title=$title;locality='Antalya';description='Doğrulanmış ve güncel test ilanı açıklaması';capacity='4';price='5000.00';currency='TRY';seo_title='Stage 1 SEO title';seo_description='Stage 1 SEO description';attr_bedrooms='2';attr_bathrooms='2'};Assert ($page.StatusCode-eq 200) 'supplier creates approved-category draft'
 $property=Sql "SELECT id FROM catalog.properties WHERE tenant_id='$supplier';";$version=Sql "SELECT version FROM catalog.properties WHERE id='$property';"
 $page=Post $s "/admin/listings/$property/status" @{version=$version;status='submit';note=''};Assert ($page.StatusCode-eq 200) 'supplier submits listing to NEXUS'
 $version=Sql "SELECT version FROM catalog.properties WHERE id='$property';";$page=Post $n "/admin/listings/$property/status" @{version=$version;status='approved';note=''};if($page.StatusCode-ne 200){Write-Host "APPROVAL RESPONSE: $($page.StatusCode) $($page.Content)"};Assert ($page.StatusCode-eq 200) 'NEXUS approves and publishes listing'
 $page=Request '/ilanlar';Assert ($page.StatusCode-eq 200-and$page.Content.Contains($title)) 'approved current listing is public'
}finally{
 $uploaded=@(Sql "SELECT substring(storage_key from 8) FROM onboarding.documents WHERE application_id IN(SELECT id FROM onboarding.applications WHERE tenant_id='$supplier') AND storage_key LIKE 'upload:%';")
 Sql @"
DELETE FROM booking.reservations WHERE tenant_id='$supplier';DELETE FROM booking.option_requests WHERE supplier_id='$supplier';DELETE FROM inventory.allocations WHERE tenant_id='$supplier';DELETE FROM booking.holds WHERE tenant_id='$supplier';DELETE FROM booking.quotes WHERE tenant_id='$supplier';DELETE FROM inventory.days WHERE tenant_id='$supplier';DELETE FROM inventory.resources WHERE tenant_id='$supplier';DELETE FROM catalog.property_units WHERE property_id IN(SELECT id FROM catalog.properties WHERE tenant_id='$supplier');DELETE FROM catalog.properties WHERE tenant_id='$supplier';DELETE FROM onboarding.syndication_events WHERE application_id IN(SELECT id FROM onboarding.applications WHERE tenant_id='$supplier');DELETE FROM onboarding.documents WHERE application_id IN(SELECT id FROM onboarding.applications WHERE tenant_id='$supplier');DELETE FROM onboarding.identity_checks WHERE application_id IN(SELECT id FROM onboarding.applications WHERE tenant_id='$supplier');DELETE FROM onboarding.applications WHERE tenant_id='$supplier';DELETE FROM events.audit WHERE tenant_id IN('$supplier','$nexus');DELETE FROM events.outbox WHERE tenant_id IN('$supplier','$nexus');DELETE FROM auth.users WHERE tenant_id IN('$supplier','$nexus');DELETE FROM core.organizations WHERE id IN('$supplier','$nexus');
"@|Out-Null
 foreach($stored in $uploaded){Remove-Item -LiteralPath (Join-Path $ProjectRoot ".local/uploads/$stored") -ErrorAction SilentlyContinue};$cleanup=@($sqlFile,(Join-Path $ProjectRoot ".local/upload-response-$run.txt"));if($testDocument){$cleanup+=$testDocument};Remove-Item -LiteralPath $cleanup -ErrorAction SilentlyContinue;Remove-Item Env:NEXUS_STAGE1_PASSWORD -ErrorAction SilentlyContinue
}
