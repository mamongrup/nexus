$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminPassword = if ($env:ADMIN_PASSWORD) { $env:ADMIN_PASSWORD } elseif ($env:ALLOW_DEMO_PASSWORDS -eq 'true') { 'password123' } else { throw 'ADMIN_PASSWORD is required. Set ALLOW_DEMO_PASSWORDS=true only for local demo accounts.' }
$r1 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -WebSession $session -UseBasicParsing
$csrf = [regex]::Match($r1.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value

$r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -Method Post -WebSession $session -Headers @{Origin = 'http://127.0.0.1:8081'} -Body @{
    csrf = $csrf
    email = 'admin@nexus.local'
    password = $adminPassword
} -UseBasicParsing

$pages = @(
    '/admin/users',
    '/admin/profile',
    '/admin/campaigns',
    '/admin/tours',
    '/admin/fleet',
    '/admin/hr',
    '/admin/housekeeping',
    '/admin/accounting',
    '/admin/crm',
    '/admin/rate-shopper',
    '/admin/category-fields',
    '/admin/listings/new',
    '/admin/listings/procedures'
)

foreach ($page in $pages) {
    try {
        $res = Invoke-WebRequest -Uri ("http://127.0.0.1:8081" + $page) -WebSession $session -UseBasicParsing
        Write-Output "$page -> Status: $($res.StatusCode)"
    } catch {
        Write-Output "$page -> Error: $($_.Exception.Message)"
    }
}
