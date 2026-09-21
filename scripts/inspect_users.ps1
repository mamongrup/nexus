$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r1 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -WebSession $session -UseBasicParsing
$csrf = [regex]::Match($r1.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value

$r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -Method Post -WebSession $session -Headers @{Origin = 'http://127.0.0.1:8081'} -Body @{
    csrf = $csrf
    email = 'admin@nexus.local'
    password = 'password123'
} -UseBasicParsing

$p = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/admin/users' -WebSession $session -UseBasicParsing
Write-Output "--- /admin/users ---"
Write-Output "Status: $($p.StatusCode)"
Write-Output "Has active-category-hero: $($p.Content.Contains('active-category-hero'))"
Write-Output "Has benchmark-sync-banner: $($p.Content.Contains('benchmark-sync-banner'))"
Write-Output "Has role-cards-grid: $($p.Content.Contains('role-cards-grid'))"
Write-Output "Has role-definition-card: $($p.Content.Contains('role-definition-card'))"
Write-Output "Has user-management-card: $($p.Content.Contains('user-management-card'))"
Write-Output "Has user-avatar-circle: $($p.Content.Contains('user-avatar-circle'))"
Write-Output "Has password-reset-form-box: $($p.Content.Contains('password-reset-form-box'))"

