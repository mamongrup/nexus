$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r1 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -WebSession $session -UseBasicParsing
$csrf = [regex]::Match($r1.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value

$r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -Method Post -WebSession $session -Headers @{Origin = 'http://127.0.0.1:8081'} -Body @{
    csrf = $csrf
    email = 'admin@nexus.local'
    password = 'password123'
} -UseBasicParsing

# 1. Check /admin/listings/new
$p_new = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/admin/listings/new' -WebSession $session -UseBasicParsing
Write-Output "=== /admin/listings/new ==="
Write-Output "Status: $($p_new.StatusCode)"
Write-Output "Has category-tabs-grid: $($p_new.Content.Contains('category-tabs-grid'))"
Write-Output "Has active-category-hero: $($p_new.Content.Contains('active-category-hero'))"
Write-Output "Has category-selector-card: $($p_new.Content.Contains('category-selector-card'))"
Write-Output "Has procedure-guide-card: $($p_new.Content.Contains('procedure-guide-card'))"

# 2. Check /admin/listings/procedures
$p_proc = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/admin/listings/procedures' -WebSession $session -UseBasicParsing
Write-Output "=== /admin/listings/procedures ==="
Write-Output "Status: $($p_proc.StatusCode)"
Write-Output "Has procedures-hub-grid: $($p_proc.Content.Contains('procedures-hub-grid'))"
Write-Output "Has cat-icon-badge: $($p_proc.Content.Contains('cat-icon-badge'))"
Write-Output "Has benchmark-sync-banner: $($p_proc.Content.Contains('benchmark-sync-banner'))"
Write-Output "Has procedure-hub-card: $($p_proc.Content.Contains('procedure-hub-card'))"

# 3. Check /admin/category-fields/hotel
$p_cat = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/admin/category-fields/hotel' -WebSession $session -UseBasicParsing
Write-Output "=== /admin/category-fields/hotel ==="
Write-Output "Status: $($p_cat.StatusCode)"
Write-Output "Has category-tabs-grid: $($p_cat.Content.Contains('category-tabs-grid'))"
Write-Output "Has active-category-hero: $($p_cat.Content.Contains('active-category-hero'))"


