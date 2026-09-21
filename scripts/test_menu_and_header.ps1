. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

function Check($condition, $name) {
  if (!$condition) {
    throw "FAIL: $name"
  }
  Write-Output "PASS: $name"
}

Write-Output "=== Testing Modern Header, Separate Categories and Modules, and Chic Selectors ==="

# 1. Test Home Page (GET /)
$r = Invoke-WebRequest -Uri "$base/" -UseBasicParsing
Check ($r.StatusCode -eq 200) "GET / status 200"

# Verify header layout classes
Check ($r.Content.Contains('site-header-wrapper')) "Contains sticky glassmorphic site-header-wrapper"
Check ($r.Content.Contains('site-brand')) "Contains brand logo NEXUS TRAVELTECH"

# 2. Verify Distinct "Kategoriler" Dropdown
Check ($r.Content.Contains('categories-menu')) "Contains separate 'Kategoriler' dropdown menu"
Check ($r.Content.Contains('Otel & Konaklama') -or $r.Content.Contains('Otel &amp; Konaklama')) "Kategoriler contains Otel & Konaklama"
Check ($r.Content.Contains('Villa & Tatil Evi') -or $r.Content.Contains('Villa &amp; Tatil Evi')) "Kategoriler contains Villa & Tatil Evi"
Check ($r.Content.Contains('Tur & Deneyim') -or $r.Content.Contains('Tur &amp; Deneyim')) "Kategoriler contains Tur & Deneyim"
Check ($r.Content.Contains('Yat & Marina') -or $r.Content.Contains('Yat &amp; Marina')) "Kategoriler contains Yat & Marina"
Check ($r.Content.Contains('VIP Transfer')) "Kategoriler contains VIP Transfer"

# 3. Verify Distinct "Modüller" Dropdown
Check ($r.Content.Contains('modules-menu')) "Contains separate 'Moduller' dropdown menu"
Check ($r.Content.Contains('PMS') -and $r.Content.Contains('modul-pms')) "Moduller contains PMS link"
Check ($r.Content.Contains('Kanal') -and $r.Content.Contains('modul-channel-manager')) "Moduller contains Kanal Yoneticisi link"
Check ($r.Content.Contains('KBS') -and $r.Content.Contains('modul-kbs')) "Moduller contains KBS link"
Check ($r.Content.Contains('Dinamik') -and $r.Content.Contains('modul-dinamik-fiyat')) "Moduller contains Dinamik Fiyatlama AI link"

# 4. Verify Chic Language & Currency Selectors
Check ($r.Content.Contains('chic-selector-pill lang-pill')) "Contains chic language selector pill"
Check ($r.Content.Contains('chic-selector-pill cur-pill')) "Contains chic currency selector pill"
Check ($r.Content.Contains('site-language')) "Language select element present"
Check ($r.Content.Contains('site-currency')) "Currency select element present"
Check ($r.Content.Contains('value="tr"') -and $r.Content.Contains('TR')) "Language selector has TR"
Check ($r.Content.Contains('value="en"') -and $r.Content.Contains('EN')) "Language selector has EN"
Check ($r.Content.Contains('value="TRY"') -and $r.Content.Contains('TRY')) "Currency selector has TRY"
Check ($r.Content.Contains('value="EUR"') -and $r.Content.Contains('EUR')) "Currency selector has EUR"
Check ($r.Content.Contains('value="USD"') -and $r.Content.Contains('USD')) "Currency selector has USD"

# 5. Verify Programa Giriş button
Check ($r.Content.Contains('btn-nexus-login')) "Contains styled btn-nexus-login"

# 6. Verify Marketplace Page and Portal Network Banner
$r = Invoke-WebRequest -Uri "$base/ilanlar" -UseBasicParsing
Check ($r.StatusCode -eq 200) "GET /ilanlar status 200"
Check ($r.Content.Contains('portal-network-banner')) "Contains portal network banner"
Check ($r.Content.Contains('www.rezervasyonyap.com.tr')) "Mentions www.rezervasyonyap.com.tr"
Check ($r.Content.Contains('www.reservastioninturkey.com')) "Mentions www.reservastioninturkey.com"

Write-Output "`n=== ALL HEADER, CATEGORIES AND MODULES, AND CHIC SELECTOR TESTS PASSED! ==="
