$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'
if (!(Test-Path -LiteralPath $envFile)) {
  throw '.env bulunamadı.'
}

Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  $index = $line.IndexOf('=')
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim()
  }
}

$pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
$common = @('-X','-w','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
$expected = @(
  'property_type',
  'bedroom_count',
  'bathroom_count',
  'guest_capacity',
  'pool_type',
  'kitchen',
  'season_rules'
)

$query = @"
SELECT split_part(trim(both '{}' from data::text), ',', 2)
FROM onboarding.category_fields('holiday_home')
ORDER BY 1;
"@

$actual = @(& $pg @common -Atc $query)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB sözleşme kontrolü çalıştırılamadı.'
}

$actualSorted = @($actual | Sort-Object)
$expectedSorted = @($expected | Sort-Object)
if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) {
  throw "Nexus DB holiday_home alanları sözleşmeyle uyumsuz: $($actualSorted -join ',')"
}

$propertyTypeQuery = @"
SELECT data::text
FROM onboarding.category_fields('holiday_home')
WHERE data::text LIKE '%,property_type,%';
"@
$propertyType = @(& $pg @common -Atc $propertyTypeQuery)
if ($LASTEXITCODE -ne 0 -or $propertyType.Count -ne 1) {
  throw 'Nexus DB holiday_home.property_type alanı okunamadı.'
}
if ($propertyType[0] -notlike '*,select,"Villa,Apart,Bungalov,Daire,Residence",true,true,10}') {
  throw "Nexus DB holiday_home.property_type seçenekleri uyumsuz: $($propertyType[0])"
}

Write-Output 'Nexus DB holiday_home alan sözleşmesi uyumlu.'

$expectedYacht = @(
  'yacht_type',
  'capacity',
  'cabin_count',
  'departure_port',
  'route',
  'captain_included',
  'fuel_policy'
)

$yachtQuery = @"
SELECT split_part(trim(both '{}' from data::text), ',', 2)
FROM onboarding.category_fields('yacht')
ORDER BY 1;
"@
$actualYacht = @(& $pg @common -Atc $yachtQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB yacht sözleşme kontrolü çalıştırılamadı.'
}
$actualYachtSorted = @($actualYacht | Sort-Object)
$expectedYachtSorted = @($expectedYacht | Sort-Object)
if (($actualYachtSorted -join ',') -ne ($expectedYachtSorted -join ',')) {
  throw "Nexus DB yacht alanları sözleşmeyle uyumsuz: $($actualYachtSorted -join ',')"
}

$yachtTypeQuery = @"
SELECT data::text
FROM onboarding.category_fields('yacht')
WHERE data::text LIKE '%,yacht_type,%';
"@
$yachtType = @(& $pg @common -Atc $yachtTypeQuery)
if ($LASTEXITCODE -ne 0 -or $yachtType.Count -ne 1) {
  throw 'Nexus DB yacht.yacht_type alanı okunamadı.'
}
if ($yachtType[0] -notlike '*,select,"Gulet,Motoryat,Yelkenli,Katamaran,Tekne",true,true,10}') {
  throw "Nexus DB yacht.yacht_type seçenekleri uyumsuz: $($yachtType[0])"
}

Write-Output 'Nexus DB yacht alan sözleşmesi uyumlu.'

$contractPath = Join-Path $projectRoot 'contracts/supplier-listing-contract.v1.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$categoryAttributes = $contract.category_attributes
foreach ($categoryName in $categoryAttributes.PSObject.Properties.Name) {
  $expectedFields = @($categoryAttributes.$categoryName | Sort-Object)
  $dbFieldQuery = @"
SELECT split_part(trim(both '{}' from data::text), ',', 2)
FROM onboarding.category_fields('$categoryName')
ORDER BY 1;
"@
  $dbFields = @(& $pg @common -Atc $dbFieldQuery)
  if ($LASTEXITCODE -ne 0) {
    throw "Nexus DB $categoryName alanları okunamadı."
  }
  $actualFields = @($dbFields | Sort-Object)
  if (($actualFields -join ',') -ne ($expectedFields -join ',')) {
    throw "Nexus DB $categoryName alanları sözleşmeyle uyumsuz: $($actualFields -join ',')"
  }
}

Write-Output 'Nexus DB tüm kategori alan sözleşmeleri uyumlu.'

function Assert-OnboardingItems($kind, $expectedItems) {
  $query = "SELECT data[2] FROM onboarding.supplier_onboarding_contract_items() WHERE data[1]='$kind' ORDER BY data[3]::int, data[2];"
  $actualItems = @(& $pg @common -Atc $query)
  if ($LASTEXITCODE -ne 0) {
    throw "Nexus DB tedarikçi onboarding sözleşmesi okunamadı: $kind"
  }
  $actualSorted = @($actualItems | Sort-Object)
  $expectedSorted = @($expectedItems | Sort-Object)
  if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) {
    throw "Nexus DB tedarikçi onboarding $kind sözleşmesi uyumsuz: $($actualSorted -join ',')"
  }
}

Assert-OnboardingItems 'identity_field' @($contract.supplier_onboarding.required_identity_fields)
Assert-OnboardingItems 'business_field' @($contract.supplier_onboarding.required_business_fields)
Assert-OnboardingItems 'required_document' @($contract.supplier_onboarding.required_documents)
Assert-OnboardingItems 'approval_status' @($contract.supplier_onboarding.approval_statuses)

foreach ($categoryName in $categoryAttributes.PSObject.Properties.Name) {
  $requiredDocumentQuery = @"
SELECT data[1]
FROM onboarding.required_document_codes('$categoryName')
ORDER BY data[1];
"@
  $actualDocuments = (@(& $pg @common -Atc $requiredDocumentQuery) | Sort-Object) -join ','
  if ($LASTEXITCODE -ne 0) {
    throw "Nexus DB $categoryName onboarding belge sözleşmesi okunamadı."
  }
  $expectedDocuments = (@($contract.supplier_onboarding.required_documents) | Sort-Object) -join ','
  if ($actualDocuments -ne $expectedDocuments) {
    throw "Nexus DB $categoryName onboarding belgeleri sözleşmeyle uyumsuz: $actualDocuments"
  }
}

Write-Output 'Nexus DB tedarikçi onboarding sözleşmesi uyumlu.'

$expectedSupplierPanelModules = @($contract.supplier_panel_modules | Sort-Object)
$supplierPanelModuleQuery = @"
SELECT code
FROM onboarding.product_modules
WHERE active
ORDER BY code;
"@
$actualSupplierPanelModules = @(& $pg @common -Atc $supplierPanelModuleQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB tedarikçi panel modül sözleşmesi okunamadı.'
}
$actualSupplierPanelModules = @($actualSupplierPanelModules | Where-Object { $expectedSupplierPanelModules -contains $_ } | Sort-Object)
if (($actualSupplierPanelModules -join ',') -ne ($expectedSupplierPanelModules -join ',')) {
  throw "Nexus DB tedarikçi panel modülleri sözleşmeyle uyumsuz: $($actualSupplierPanelModules -join ',')"
}

Write-Output 'Nexus DB tedarikçi panel modül sözleşmesi uyumlu.'

$supplierPermissionDecisionQuery = @"
SELECT concat_ws('|',
  onboarding.role_allows_supplier_permission('accounting', 'supplier.accounting.manage')::text,
  onboarding.role_allows_supplier_permission('housekeeping', 'supplier.accounting.manage')::text,
  onboarding.role_allows_supplier_permission('editor', 'supplier.catalog.submit_review')::text,
  onboarding.role_allows_any_supplier_permission('frontdesk', 'supplier.reservations.view,supplier.reservations.manage')::text,
  onboarding.role_allows_any_supplier_permission('viewer', 'supplier.pricing.manage')::text
);
"@
$supplierPermissionDecision = @(& $pg @common -Atc $supplierPermissionDecisionQuery)
if ($LASTEXITCODE -ne 0 -or $supplierPermissionDecision.Count -ne 1) {
  throw 'Nexus DB tedarikçi permission karar fonksiyonu okunamadı.'
}
if ($supplierPermissionDecision[0] -ne 'true|false|true|true|false') {
  throw "Nexus DB tedarikçi permission kararları sözleşmeyle uyumsuz: $($supplierPermissionDecision[0])"
}

Write-Output 'Nexus DB tedarikçi permission karar sözleşmesi uyumlu.'

$expectedListingStatuses = @($contract.listing_common.statuses | Sort-Object)
$listingStatusQuery = @"
SELECT data[1]
FROM onboarding.supplier_listing_lifecycle_statuses()
ORDER BY data[2]::int;
"@
$actualListingStatuses = @(& $pg @common -Atc $listingStatusQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB ilan yaşam döngüsü sözleşmesi okunamadı.'
}
if (((@($actualListingStatuses | Sort-Object)) -join ',') -ne ($expectedListingStatuses -join ',')) {
  throw "Nexus DB ilan yaşam döngüsü sözleşmesi uyumsuz: $($actualListingStatuses -join ',')"
}

Write-Output 'Nexus DB ilan yaşam döngüsü sözleşmesi uyumlu.'

$listingValidationInvalidQuery = @'
SELECT field_key
FROM onboarding.validate_listing_contract(
  'holiday_home',
  jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'Villa'))
)
ORDER BY field_key;
'@
$missingInvalid = @(& $pg @common -Atc $listingValidationInvalidQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB ilan sözleşme doğrulama fonksiyonu çalıştırılamadı.'
}
$expectedMissingHolidayHome = @(
  'bathroom_count',
  'bedroom_count',
  'guest_capacity'
) | Sort-Object
if (((@($missingInvalid | Sort-Object)) -join ',') -ne ($expectedMissingHolidayHome -join ',')) {
  throw "Nexus DB eksik ilan alanı doğrulaması uyumsuz: $($missingInvalid -join ',')"
}

$listingValidationValidQuery = @'
SELECT field_key
FROM onboarding.validate_listing_contract(
  'holiday_home',
  jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'Villa', 'bedroom_count', '3', 'bathroom_count', '2', 'guest_capacity', '6'))
)
ORDER BY field_key;
'@
$missingValid = @(& $pg @common -Atc $listingValidationValidQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB geçerli ilan sözleşme doğrulaması çalıştırılamadı.'
}
if ($missingValid.Count -ne 0) {
  throw "Nexus DB geçerli ilan sözleşme doğrulaması alan eksik döndürdü: $($missingValid -join ',')"
}

Write-Output 'Nexus DB ilan sözleşme doğrulaması uyumlu.'

$listingPublishGuardQuery = @'
DO $$
DECLARE
  tenant uuid;
  blocked boolean := false;
  missing_common text;
  sample catalog.properties%ROWTYPE;
BEGIN
  SELECT tenant_id INTO tenant FROM catalog.properties ORDER BY created_at LIMIT 1;

  BEGIN
    INSERT INTO catalog.properties(
      tenant_id,
      title,
      locality,
      description,
      capacity,
      nightly_minor,
      currency,
      status,
      category_code,
      attributes
    )
    VALUES(
      tenant,
      'Contract Guard Test',
      'Test',
      'Test',
      1,
      10000,
      'TRY',
      'published',
      'holiday_home',
      jsonb_build_object('property_type', 'Villa')
    );
  EXCEPTION WHEN check_violation THEN
    blocked := true;
  END;

  IF NOT blocked THEN
    RAISE EXCEPTION 'listing contract publish guard did not block invalid listing';
  END IF;

  SELECT * INTO sample FROM catalog.properties ORDER BY created_at LIMIT 1;
  sample.title := 'Contract Guard Valid Test';
  sample.locality := 'Test';
  sample.description := 'Test description';
  sample.capacity := 6;
  sample.nightly_minor := 10000;
  sample.currency := 'TRY';
  sample.status := 'published';
  sample.category_code := 'holiday_home';
  sample.seo_title := 'Contract Guard Valid Test';
  sample.seo_description := 'Contract guard valid description';
  sample.media := jsonb_build_array(jsonb_build_object('url','/static/test.jpg'));

  SELECT string_agg(field_key, ', ' ORDER BY field_key)
  INTO missing_common
  FROM catalog.validate_listing_common_contract(sample);

  IF coalesce(missing_common, '') <> '' THEN
    RAISE EXCEPTION 'valid listing common contract was reported incomplete: %', missing_common;
  END IF;

  sample.locality := '';
  sample.description := '';
  sample.capacity := 0;
  sample.nightly_minor := 0;
  sample.seo_title := '';
  sample.seo_description := '';
  sample.media := '[]'::jsonb;

  SELECT string_agg(field_key, ', ' ORDER BY field_key)
  INTO missing_common
  FROM catalog.validate_listing_common_contract(sample);

  IF missing_common IS NULL THEN
    RAISE EXCEPTION 'invalid listing common contract was not reported incomplete';
  END IF;
END $$;
'@
& $pg @common -v ON_ERROR_STOP=1 -c $listingPublishGuardQuery | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB ilan yayına alma sözleşme koruması çalışmadı.'
}

Write-Output 'Nexus DB ilan yayına alma sözleşme koruması uyumlu.'

$canonicalCategorySqlList = (@($categoryAttributes.PSObject.Properties.Name) | ForEach-Object { "'$_'" }) -join ','
$invalidFilterCategoryQuery = @"
SELECT category_code
FROM onboarding.category_filter_groups
WHERE category_code NOT IN ($canonicalCategorySqlList)
ORDER BY category_code;
"@
$invalidFilterCategories = @(& $pg @common -Atc $invalidFilterCategoryQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB yönetilebilir filtre kategori kapsamı okunamadı.'
}
if ($invalidFilterCategories.Count -gt 0) {
  throw "Nexus DB yönetilebilir filtrelerde sözleşme dışı kategori kodu var: $($invalidFilterCategories -join ',')"
}

$managedFilterCoverageQuery = @"
SELECT c
FROM unnest(ARRAY[$canonicalCategorySqlList]) AS expected(c)
WHERE NOT EXISTS (
  SELECT 1
  FROM onboarding.category_filter_groups g
  WHERE g.category_code = expected.c
    AND g.active
)
ORDER BY c;
"@
$missingManagedFilterCategories = @(& $pg @common -Atc $managedFilterCoverageQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB yönetilebilir filtre kategori kapsama kontrolü çalıştırılamadı.'
}
if ($missingManagedFilterCategories.Count -gt 0) {
  throw "Nexus DB yönetilebilir filtre grubu eksik kategoriler: $($missingManagedFilterCategories -join ',')"
}

$managedFilterChecks = @(
  @{ Category = 'holiday_home'; Group = 'property_type'; Expected = @('apart','bungalov','daire','residence','villa') },
  @{ Category = 'yacht'; Group = 'yacht_type'; Expected = @('gulet','katamaran','motoryat','tekne','yelkenli') }
)

foreach ($check in $managedFilterChecks) {
  $groupQuery = @"
SELECT data[1]
FROM onboarding.category_filter_groups_for('$($check.Category)', 'tr')
WHERE data[3]='$($check.Group)';
"@
  $groupId = ((& $pg @common -Atc $groupQuery) | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0 -or -not $groupId) {
    throw "Nexus DB yönetilebilir filtre grubu eksik: $($check.Category).$($check.Group)"
  }

  $itemsQuery = @"
SELECT data[2]
FROM onboarding.category_filter_items_for('$groupId'::uuid, 'tr')
ORDER BY data[2];
"@
  $items = @(& $pg @common -Atc $itemsQuery)
  if ($LASTEXITCODE -ne 0) {
    throw "Nexus DB yönetilebilir filtre maddeleri okunamadı: $($check.Category).$($check.Group)"
  }
  if (((@($items | Sort-Object)) -join ',') -ne ((@($check.Expected | Sort-Object)) -join ',')) {
    throw "Nexus DB yönetilebilir filtre maddeleri uyumsuz: $($check.Category).$($check.Group) -> $($items -join ',')"
  }
}

Write-Output 'Nexus DB yönetilebilir kategori filtreleri uyumlu.'

$syncContractStateQuery = @"
SELECT data[1] || '=' || data[2]
FROM onboarding.sync_contract_state()
ORDER BY data[1];
"@
$syncContractStateRows = @(& $pg @common -Atc $syncContractStateQuery)
if ($LASTEXITCODE -ne 0) {
  throw 'Nexus DB senkronizasyon sözleşme durumu okunamadı.'
}
$syncContractState = @{}
foreach ($row in $syncContractStateRows) {
  $parts = $row -split '=', 2
  if ($parts.Count -eq 2) {
    $syncContractState[$parts[0]] = $parts[1]
  }
}
if ($syncContractState['catalog_contract_version'] -ne '1.1.0') {
  throw "Nexus DB sync katalog sözleşme sürümü uyumsuz: $($syncContractState['catalog_contract_version'])"
}
if ($syncContractState['supplier_listing_contract_version'] -ne $contract.contract_version) {
  throw "Nexus DB sync ilan sözleşme sürümü uyumsuz: $($syncContractState['supplier_listing_contract_version'])"
}
if ([int]$syncContractState['active_category_count'] -ne 17) {
  throw "Nexus DB sync kategori sayısı uyumsuz: $($syncContractState['active_category_count'])"
}
if ([int]$syncContractState['active_filter_item_count'] -lt 17) {
  throw "Nexus DB sync filtre maddesi sayısı şüpheli: $($syncContractState['active_filter_item_count'])"
}
if ([int]$syncContractState['active_supplier_module_count'] -ne $expectedSupplierPanelModules.Count) {
  throw "Nexus DB sync tedarikçi modül sayısı uyumsuz: $($syncContractState['active_supplier_module_count'])"
}
if (-not $syncContractState['supplier_module_detail_signature'] -or $syncContractState['supplier_module_detail_signature'].Length -ne 32) {
  throw "Nexus DB sync tedarikçi modül detay imzası geçersiz: $($syncContractState['supplier_module_detail_signature'])"
}

Write-Output 'Nexus DB senkronizasyon sözleşme durumu uyumlu.'

$applicationPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  & $pg -X -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $env:PGDATABASE -v ON_ERROR_STOP=1 -f (Join-Path $projectRoot 'test/platform_control_center.sql')
  if ($LASTEXITCODE -ne 0) { throw 'Platform süper yönetici denetimi başarısız.' }
  & $pg -X -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $env:PGDATABASE -v ON_ERROR_STOP=1 -f (Join-Path $projectRoot 'test/supplier_document_expiry_guard.sql')
  if ($LASTEXITCODE -ne 0) { throw 'Tedarikçi belge süresi onay denetimi başarısız.' }
  & $pg -X -w -h $env:PGHOST -p $env:PGPORT -U $env:PGOWNER -d $env:PGDATABASE -v ON_ERROR_STOP=1 -f (Join-Path $projectRoot 'test/supplier_listing_approval_loss.sql')
  if ($LASTEXITCODE -ne 0) { throw 'Tedarikçi ilan yayın yetkisi denetimi başarısız.' }
} finally {
  $env:PGPASSWORD = $applicationPassword
}
Write-Output 'Platform süper yönetici denetimi geçti.'
Write-Output 'Tedarikçi belge süresi onay denetimi geçti.'
Write-Output 'Tedarikçi ilan yayın yetkisi denetimi geçti.'
