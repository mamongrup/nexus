. "$PSScriptRoot/env.ps1"
Set-Location -LiteralPath $ProjectRoot
& "$PSScriptRoot/prepare-build.ps1"
gleam format --check
if ($LASTEXITCODE -ne 0) { throw 'Format kontrolü başarısız' }
# DB entegrasyon kendi-testleri bu kapıda gürültülü kırılsın (DB burada var).
$env:REQUIRE_TEST_DB = "true"
gleam test
if ($LASTEXITCODE -ne 0) { throw 'Birim testleri başarısız' }
# SQL test zinciri tek kaynaktan: db/tests fixture sırası + test/*.sql kabul
# katmanı platform-agnostik koşucuda yaşar; Windows kapısı ile CI artık aynı
# betiği çağırdığı için sıra ikinci bir yere kopyalanmaz.
& "$PSScriptRoot/run-db-tests.ps1"
if ($LASTEXITCODE -ne 0) { throw 'SQL test zinciri başarısız' }
