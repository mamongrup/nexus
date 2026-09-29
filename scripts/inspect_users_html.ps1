$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminPassword = if ($env:ADMIN_PASSWORD) { $env:ADMIN_PASSWORD } elseif ($env:ALLOW_DEMO_PASSWORDS -eq 'true') { 'password123' } else { throw 'ADMIN_PASSWORD is required. Set ALLOW_DEMO_PASSWORDS=true only for local demo accounts.' }
$r1 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -WebSession $session -UseBasicParsing
$csrf = [regex]::Match($r1.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value

$r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -Method Post -WebSession $session -Headers @{Origin = 'http://127.0.0.1:8081'} -Body @{
    csrf = $csrf
    email = 'admin@nexus.local'
    password = $adminPassword
} -UseBasicParsing

$p = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/admin/users' -WebSession $session -UseBasicParsing
$idx = $p.Content.IndexOf('user-card-grid')
if ($idx -gt 0) {
    Write-Output "=== USER CARD GRID HTML ==="
    Write-Output $p.Content.Substring($idx - 20, [Math]::Min(1500, $p.Content.Length - $idx + 20))
}
