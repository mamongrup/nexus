. "$PSScriptRoot/env.ps1"
Set-Location -LiteralPath $ProjectRoot
& "$PSScriptRoot/prepare-build.ps1"
gleam format --check
if ($LASTEXITCODE -ne 0) { throw 'Format kontrolü başarısız' }
gleam test
if ($LASTEXITCODE -ne 0) { throw 'Birim testleri başarısız' }
$appPassword=$env:PGPASSWORD
try {
 $env:PGPASSWORD=$env:PGOWNER_PASSWORD
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/isolation.sql"
 if ($LASTEXITCODE -ne 0) { throw 'DB testleri başarısız' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/reservation_lifecycle.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Rezervasyon yaşam döngüsü testleri başarısız' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/settings_isolation.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Ayar izolasyon testleri başarısız' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/cms.sql"
 if ($LASTEXITCODE -ne 0) { throw 'CMS testleri başarısız' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/ai_scope.sql"
 if ($LASTEXITCODE -ne 0) { throw 'AI scope tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/ai_governance_and_finance.sql"
 if ($LASTEXITCODE -ne 0) { throw 'AI governance ve finans testleri başarısız' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/external_operation_truth.sql"
 if ($LASTEXITCODE -ne 0) { throw 'External operation truth tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/external_operation_existing_listing.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Existing listing operation truth tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/frozen_quote_ledger.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Frozen quote ledger tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/operational_provider_truth.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Operational provider truth tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/external_operation_queue.sql"
 if ($LASTEXITCODE -ne 0) { throw 'External operation queue tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/external_operation_worker.sql"
 if ($LASTEXITCODE -ne 0) { throw 'External operation worker tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/external_operation_retry.sql"
 if ($LASTEXITCODE -ne 0) { throw 'External operation retry tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/marketplace_feed_v2.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Marketplace feed v2 tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/cny_currency.sql"
 if ($LASTEXITCODE -ne 0) { throw 'CNY currency tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/listing_module_scope.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Listing module scope tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/listing_review.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Listing review workflow tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/supplier_application.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Supplier application workflow tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/sector_benchmarking.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Sector benchmarking tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/elite_hospitality_suite.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Elite hospitality suite tests failed' }
 & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f "$ProjectRoot/db/tests/category_values.sql"
 if ($LASTEXITCODE -ne 0) { throw 'Category value validation tests failed' }
 foreach ($testFile in Get-ChildItem -LiteralPath "$ProjectRoot/test" -Filter '*.sql' | Sort-Object Name) {
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -f $testFile.FullName
  if ($LASTEXITCODE -ne 0) { throw "Database test failed: $($testFile.Name)" }
 }
} finally { $env:PGPASSWORD=$appPassword }
