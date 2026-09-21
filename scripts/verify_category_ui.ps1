$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r1 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -WebSession $session -UseBasicParsing
$csrf = [regex]::Match($r1.Content, 'name="csrf"[^>]*value="([^"]+)"').Groups[1].Value

$r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/login' -Method Post -WebSession $session -Headers @{Origin = 'http://127.0.0.1:8081'} -Body @{
    csrf = $csrf
    email = 'admin@nexus.local'
    password = 'password123'
} -UseBasicParsing

$r3 = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/admin/category-fields/hotel' -WebSession $session -UseBasicParsing
Write-Output "STATUS: $($r3.StatusCode)"
$rcss = Invoke-WebRequest -Uri 'http://127.0.0.1:8081/static/admin-modern.css' -UseBasicParsing
Write-Output "CSS Status: $($rcss.StatusCode)"
Write-Output "Has existing-field-card: $($rcss.Content.Contains('existing-field-card'))"
Write-Output "Has fields-list-grid: $($rcss.Content.Contains('fields-list-grid'))"
Write-Output "Has form-grid grid-3: $($rcss.Content.Contains('form-grid.grid-3'))"



