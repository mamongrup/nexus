. "$PSScriptRoot/env.ps1"
$base = $env:APP_ORIGIN

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Record-Test($name, $status, $details) {
    $item = [PSCustomObject]@{
        Name = $name
        Status = $status
        Details = $details
    }
    $results.Add($item)
    if ($status -eq "PASS") {
        Write-Host " [OK] $name" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $name - $details" -ForegroundColor Red
    }
}

function Csrf($html) {
    $m = [regex]::Match($html, 'name="csrf"[^>]*value="([^"]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

function Http-Get($url, $session = $null) {
    try {
        $p = @{ Uri = $url; Method = 'GET'; UseBasicParsing = $true }
        if ($session) { $p['WebSession'] = $session }
        $resp = Invoke-WebRequest @p
        return @{ StatusCode = $resp.StatusCode; Content = $resp.Content }
    } catch {
        $errResp = $_.Exception.Response
        if ($errResp) {
            $reader = New-Object System.IO.StreamReader($errResp.GetResponseStream())
            return @{ StatusCode = [int]$errResp.StatusCode; Content = $reader.ReadToEnd() }
        }
        return @{ StatusCode = 500; Content = $_.Exception.Message }
    }
}

function Http-Post($url, $body, $session = $null) {
    try {
        $p = @{ Uri = $url; Method = 'POST'; Body = $body; UseBasicParsing = $true; Headers = @{ Origin = $base } }
        if ($session) { $p['WebSession'] = $session }
        $resp = Invoke-WebRequest @p
        return @{ StatusCode = $resp.StatusCode; Content = $resp.Content }
    } catch {
        $errResp = $_.Exception.Response
        if ($errResp) {
            $reader = New-Object System.IO.StreamReader($errResp.GetResponseStream())
            return @{ StatusCode = [int]$errResp.StatusCode; Content = $reader.ReadToEnd() }
        }
        return @{ StatusCode = 500; Content = $_.Exception.Message }
    }
}

Write-Host "`n=== 1. PUBLIC SITE BUTTONS & LINKS AUDIT ===" -ForegroundColor Cyan

$publicRoutes = @(
    @{ Name = "Ana Sayfa"; Path = "/" },
    @{ Name = "İlanlar Kataloğu"; Path = "/ilanlar" },
    @{ Name = "İlanlar Kategori: Villa"; Path = "/ilanlar?category=villa" },
    @{ Name = "İlanlar Kategori: Otel"; Path = "/ilanlar?category=hotel" },
    @{ Name = "İlanlar Kategori: Yat"; Path = "/ilanlar?category=yacht" },
    @{ Name = "İlanlar Arama Butonu"; Path = "/ilanlar?q=Bodrum" },
    @{ Name = "Modül PMS"; Path = "/modul-pms" },
    @{ Name = "Modül Kanal Yöneticisi"; Path = "/modul-channel-manager" },
    @{ Name = "Modül KBS Kimlik"; Path = "/modul-kbs" },
    @{ Name = "Modül Ön Büro POS"; Path = "/modul-pos" },
    @{ Name = "Modül Dinamik Fiyatlama AI"; Path = "/modul-ai" },
    @{ Name = "Modül Finans & Muhasebe"; Path = "/modul-finance" },
    @{ Name = "Modül e-Fatura"; Path = "/modul-einvoice" },
    @{ Name = "Modül Tur & Aktivite"; Path = "/modul-tours" },
    @{ Name = "Modül Filo Kiralama"; Path = "/modul-fleet" },
    @{ Name = "Blog & Rehber"; Path = "/blog" },
    @{ Name = "Blog Kategori: Mevzuat"; Path = "/blog?category=mevzuat" },
    @{ Name = "Blog Yazı Detayı 1"; Path = "/blog/7464-sayili-konut-izin-belgesi-ve-turizm-mevzuati" },
    @{ Name = "Blog Yazı Detayı 2"; Path = "/blog/otel-ve-villalarda-yapay-zeka-ile-dinamik-fiyatlama" },
    @{ Name = "İletişim Sayfası"; Path = "/iletisim" },
    @{ Name = "Kayıt Ol Sayfası"; Path = "/kayit-ol" },
    @{ Name = "Giriş Yap Sayfası"; Path = "/admin/login" }
)

foreach ($r in $publicRoutes) {
    $res = Http-Get "$base$($r.Path)"
    if ($res.StatusCode -eq 200) {
        Record-Test "Public Link: $($r.Name) ($($r.Path))" "PASS" "200 OK"
    } else {
        Record-Test "Public Link: $($r.Name) ($($r.Path))" "FAIL" "Status $($res.StatusCode)"
    }
}

Write-Host "`n=== 2. ADMIN AUTHENTICATION & LOGIN BUTTON ===" -ForegroundColor Cyan
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginGet = Http-Get "$base/login" $adminSession
$adminCsrf = Csrf $loginGet.Content

if ($adminCsrf -ne "") {
    Record-Test "Login CSRF Token Retrieval" "PASS" "Token found"
} else {
    Record-Test "Login CSRF Token Retrieval" "FAIL" "CSRF missing"
}

$loginPost = Http-Post "$base/login" @{
    csrf = $adminCsrf
    email = $env:ADMIN_EMAIL
    password = $env:ADMIN_PASSWORD
} $adminSession

if ($loginPost.StatusCode -eq 200 -or $loginPost.StatusCode -eq 302 -or $loginPost.StatusCode -eq 303) {
    Record-Test "Admin Login Button (Çalışma alanına gir →)" "PASS" "Status $($loginPost.StatusCode)"
} else {
    Record-Test "Admin Login Button (Çalışma alanına gir →)" "FAIL" "Status $($loginPost.StatusCode)"
}

Write-Host "`n=== 3. ADMIN SIDEBAR NAVIGATION BUTTONS AUDIT ===" -ForegroundColor Cyan

$adminSidebarRoutes = @(
    @{ Name = "Genel Bakış / Operasyon"; Path = "/admin" },
    @{ Name = "İlanlar Portföyü"; Path = "/admin/listings" },
    @{ Name = "Kategori Prosedürleri Rehberi"; Path = "/admin/listings/procedures" },
    @{ Name = "Takvim & Fiyatlar"; Path = "/admin/calendar" },
    @{ Name = "Opsiyon Yönetimi"; Path = "/admin/options" },
    @{ Name = "İndirimler & Kampanyalar"; Path = "/admin/campaigns" },
    @{ Name = "Piyasa & Rakip Fiyat"; Path = "/admin/rate-shopper" },
    @{ Name = "Misafir CRM & WhatsApp"; Path = "/admin/crm" },
    @{ Name = "Tur Operasyonu & Paketler"; Path = "/admin/tours" },
    @{ Name = "Araç Kiralama & Filo"; Path = "/admin/fleet" },
    @{ Name = "e-Fatura & Mali Entegrasyon"; Path = "/admin/einvoice" },
    @{ Name = "Yapay Zeka Merkezi"; Path = "/admin/ai-hub" },
    @{ Name = "Sosyal Medya Masası"; Path = "/admin/social-media" },
    @{ Name = "Kat Hizmetleri & Housekeeping"; Path = "/admin/housekeeping" },
    @{ Name = "İnsan Kaynakları & Bordro"; Path = "/admin/hr" },
    @{ Name = "Departmanlar"; Path = "/admin/departments" },
    @{ Name = "Ön Muhasebe & Kasa"; Path = "/admin/accounting" },
    @{ Name = "Finans & Hakediş Takası"; Path = "/admin/finance" },
    @{ Name = "Fiyatlama & Komisyon Motoru"; Path = "/admin/pricing" },
    @{ Name = "İşletme Dijital İkizi"; Path = "/admin/digital-twin" },
    @{ Name = "Ekip & Üye Yönetimi"; Path = "/admin/users" },
    @{ Name = "Kullanıcı Profili"; Path = "/admin/profile" },
    @{ Name = "Sistem Ayarları"; Path = "/admin/settings" },
    @{ Name = "Site İçerik Yönetimi"; Path = "/admin/site" },
    @{ Name = "Modül Kataloğu & Atamalar"; Path = "/admin/modules" },
    @{ Name = "Rezervasyonlar"; Path = "/admin/reservations" },
    @{ Name = "Opsiyon Talepleri"; Path = "/admin/requests" },
    @{ Name = "İş Ortakları"; Path = "/admin/partners" },
    @{ Name = "Kategori Kriter Şemaları"; Path = "/admin/category-fields" },
    @{ Name = "Tedarikçi Doğrulama Başvuruları"; Path = "/admin/onboarding" }
)

foreach ($r in $adminSidebarRoutes) {
    $res = Http-Get "$base$($r.Path)" $adminSession
    if ($res.StatusCode -eq 200) {
        Record-Test "Admin Nav: $($r.Name) ($($r.Path))" "PASS" "200 OK"
    } else {
        Record-Test "Admin Nav: $($r.Name) ($($r.Path))" "FAIL" "Status $($res.StatusCode)"
    }
}

Write-Host "`n=== 4. SUPPLIER WORKSPACE BUTTONS AUDIT ===" -ForegroundColor Cyan
$supplierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$sLoginGet = Http-Get "$base/login" $supplierSession
$sCsrf = Csrf $sLoginGet.Content
$sLoginPost = Http-Post "$base/login" @{
    csrf = $sCsrf
    email = "supplier@nexus.local"
    password = $env:SUPPLIER_PASSWORD
} $supplierSession

if ($sLoginPost.StatusCode -eq 200 -or $sLoginPost.StatusCode -eq 302 -or $sLoginPost.StatusCode -eq 303) {
    Record-Test "Supplier Login Button" "PASS" "Status $($sLoginPost.StatusCode)"
} else {
    Record-Test "Supplier Login Button" "FAIL" "Status $($sLoginPost.StatusCode)"
}

$supplierRoutes = @(
    @{ Name = "Tedarikçi Operasyon Kokpiti"; Path = "/admin" },
    @{ Name = "Tedarikçi İlanlar"; Path = "/admin/listings" },
    @{ Name = "Tedarikçi Takvim"; Path = "/admin/calendar" },
    @{ Name = "Tedarikçi Kampanyalar"; Path = "/admin/campaigns" },
    @{ Name = "Tedarikçi Kat Hizmetleri"; Path = "/admin/housekeeping" },
    @{ Name = "Tedarikçi Muhasebe"; Path = "/admin/accounting" },
    @{ Name = "Tedarikçi Rezervasyonlar"; Path = "/admin/reservations" },
    @{ Name = "Tedarikçi Talepler"; Path = "/admin/requests" }
)

foreach ($r in $supplierRoutes) {
    $res = Http-Get "$base$($r.Path)" $supplierSession
    if ($res.StatusCode -eq 200) {
        Record-Test "Supplier Nav: $($r.Name) ($($r.Path))" "PASS" "200 OK"
    } else {
        Record-Test "Supplier Nav: $($r.Name) ($($r.Path))" "FAIL" "Status $($res.StatusCode)"
    }
}

Write-Host "`n=== 5. AGENCY WORKSPACE BUTTONS AUDIT ===" -ForegroundColor Cyan
$agencySession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$aLoginGet = Http-Get "$base/login" $agencySession
$aCsrf = Csrf $aLoginGet.Content
$aLoginPost = Http-Post "$base/login" @{
    csrf = $aCsrf
    email = "agency@nexus.local"
    password = $env:AGENCY_PASSWORD
} $agencySession

if ($aLoginPost.StatusCode -eq 200 -or $aLoginPost.StatusCode -eq 302 -or $aLoginPost.StatusCode -eq 303) {
    Record-Test "Agency Login Button" "PASS" "Status $($aLoginPost.StatusCode)"
} else {
    Record-Test "Agency Login Button" "FAIL" "Status $($aLoginPost.StatusCode)"
}

$agencyRoutes = @(
    @{ Name = "Acente Ürün Portföyü"; Path = "/admin/partners" },
    @{ Name = "Acente Talepleri"; Path = "/admin/requests" },
    @{ Name = "Acente Rezervasyonları"; Path = "/admin/reservations" },
    @{ Name = "Acente POS Ayarları"; Path = "/admin/settings" }
)

foreach ($r in $agencyRoutes) {
    $res = Http-Get "$base$($r.Path)" $agencySession
    if ($res.StatusCode -eq 200) {
        Record-Test "Agency Nav: $($r.Name) ($($r.Path))" "PASS" "200 OK"
    } else {
        Record-Test "Agency Nav: $($r.Name) ($($r.Path))" "FAIL" "Status $($res.StatusCode)"
    }
}

Write-Host "`n=== 6. INTERACTIVE ACTION FORMS SUBMISSION AUDIT ===" -ForegroundColor Cyan

# 6.1 Admin Rate Shopper competitor add button
$rsPage = Http-Get "$base/admin/rate-shopper" $adminSession
$rsCsrf = Csrf $rsPage.Content
$rsPost = Http-Post "$base/admin/rate-shopper/competitor" @{
    csrf = $rsCsrf
    competitor_name = "Test Rakip Otel"
    star_rating = "5"
    channel = "Global OTA"
    room_type = "Deluxe Suit"
    competitor_price = "5500"
    our_price = "4800"
    currency = "TRY"
    target_date = "2026-09-20"
    ai_recommendation = "Fiyat avantajını koru"
} $adminSession
if ($rsPost.StatusCode -eq 200 -or $rsPost.StatusCode -eq 302 -or $rsPost.StatusCode -eq 303) {
    Record-Test "Form Button: Rate Shopper Rakip Fiyat Ekle" "PASS" "Status $($rsPost.StatusCode)"
} else {
    Record-Test "Form Button: Rate Shopper Rakip Fiyat Ekle" "FAIL" "Status $($rsPost.StatusCode)"
}

# 6.2 Admin CRM send whatsapp button
$crmPage = Http-Get "$base/admin/crm" $adminSession
$crmCsrf = Csrf $crmPage.Content
$crmPost = Http-Post "$base/admin/crm/message" @{
    csrf = $crmCsrf
    recipient_phone = "+905321112233"
    recipient_name = "Test Misafir"
    message_type = "pre_arrival"
    content = "Hoş geldiniz mesajı test"
} $adminSession
if ($crmPost.StatusCode -eq 200 -or $crmPost.StatusCode -eq 302 -or $crmPost.StatusCode -eq 303) {
    Record-Test "Form Button: CRM WhatsApp Mesajı Gönder" "PASS" "Status $($crmPost.StatusCode)"
} else {
    Record-Test "Form Button: CRM WhatsApp Mesajı Gönder" "FAIL" "Status $($crmPost.StatusCode)"
}

# 6.3 Admin Tours Activity add button
$toursPage = Http-Get "$base/admin/tours" $adminSession
$toursCsrf = Csrf $toursPage.Content
$toursPost = Http-Post "$base/admin/tours/activity" @{
    csrf = $toursCsrf
    title = "Test Balon Turu"
    location = "Göreme"
    category = "balloon"
    duration = "3"
    net_price = "150"
    sale_price = "200"
    currency = "EUR"
    capacity = "20"
} $adminSession
if ($toursPost.StatusCode -eq 200 -or $toursPost.StatusCode -eq 302 -or $toursPost.StatusCode -eq 303) {
    Record-Test "Form Button: Tur Aktivitesi Ekle" "PASS" "Status $($toursPost.StatusCode)"
} else {
    Record-Test "Form Button: Tur Aktivitesi Ekle" "FAIL" "Status $($toursPost.StatusCode)"
}

# 6.4 Admin Fleet Vehicle add button
$fleetPage = Http-Get "$base/admin/fleet" $adminSession
$fleetCsrf = Csrf $fleetPage.Content
$fleetPost = Http-Post "$base/admin/fleet/vehicle" @{
    csrf = $fleetCsrf
    plate_number = "34 TST 999"
    brand = "Mercedes"
    model = "C200"
    model_year = "2024"
    transmission = "automatic"
    fuel_type = "diesel"
    current_km = "5000"
    daily_rate = "4000"
} $adminSession
if ($fleetPost.StatusCode -eq 200 -or $fleetPost.StatusCode -eq 302 -or $fleetPost.StatusCode -eq 303) {
    Record-Test "Form Button: Araç Filoya Ekle" "PASS" "Status $($fleetPost.StatusCode)"
} else {
    Record-Test "Form Button: Araç Filoya Ekle" "FAIL" "Status $($fleetPost.StatusCode)"
}

# 6.5 Admin e-Invoice issue button
$invPage = Http-Get "$base/admin/einvoice" $adminSession
$invCsrf = Csrf $invPage.Content
$invPost = Http-Post "$base/admin/einvoice/issue" @{
    csrf = $invCsrf
    invoice_type = "e-Arsiv"
    profile_id = "EARSIVFATURA"
    currency = "TRY"
    customer_title = "Test Müşteri"
    tax_or_tc_number = "11111111111"
    tax_office = "Kadıköy V.D."
    net_amount = "10000"
} $adminSession
if ($invPost.StatusCode -eq 200 -or $invPost.StatusCode -eq 302 -or $invPost.StatusCode -eq 303) {
    Record-Test "Form Button: e-Fatura / e-Arşiv Kes" "PASS" "Status $($invPost.StatusCode)"
} else {
    Record-Test "Form Button: e-Fatura / e-Arşiv Kes" "FAIL" "Status $($invPost.StatusCode)"
}

# 6.6 Admin Social Media Post Create button
$smPage = Http-Get "$base/admin/social-media" $adminSession
$smCsrf = Csrf $smPage.Content
$smPost = Http-Post "$base/admin/social-media/post" @{
    csrf = $smCsrf
    platform = "instagram"
    title = "Test Gönderi"
    caption = "Harika bir tatil sizi bekliyor #tatil"
    media_url = "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800"
    link_url = "https://nexustraveltech.com/ilan/bodrum-villa"
} $adminSession
if ($smPost.StatusCode -eq 200 -or $smPost.StatusCode -eq 302 -or $smPost.StatusCode -eq 303) {
    Record-Test "Form Button: Sosyal Medya Gönderisi Paylaş" "PASS" "Status $($smPost.StatusCode)"
} else {
    Record-Test "Form Button: Sosyal Medya Gönderisi Paylaş" "FAIL" "Status $($smPost.StatusCode)"
}

# 6.7 Contact form button
$contactSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$contactPage = Http-Get "$base/iletisim" $contactSession
$contactCsrf = Csrf $contactPage.Content
$contactPost = Http-Post "$base/iletisim" @{
    csrf = $contactCsrf
    name = "Test Ziyaretçi"
    email = "ziyaretci@test.com"
    subject = "Fiyat Teklifi"
    message = "Merhaba, kurumsal paketleriniz hakkında bilgi almak istiyorum."
} $contactSession
if ($contactPost.StatusCode -eq 200 -or $contactPost.StatusCode -eq 302 -or $contactPost.StatusCode -eq 303) {
    Record-Test "Form Button: İletişim Formu Gönder" "PASS" "Status $($contactPost.StatusCode)"
} else {
    Record-Test "Form Button: İletişim Formu Gönder" "FAIL" "Status $($contactPost.StatusCode)"
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
$total = $results.Count
$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host "Total Tests: $total | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
