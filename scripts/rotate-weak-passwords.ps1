# Rotates every NEXUS account that still verifies against a known weak
# password and fails if any remain. Run this after setup and whenever the
# demo password helper has been used.
. "$PSScriptRoot/env.ps1"
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $ProjectRoot

# Passwords that must never survive in a reachable database.
$Weak = @(
  'password123', 'password', 'admin123', '12345678', 'nexus123',
  'deneme123', 'test1234', '123456', 'qwerty', 'changeme', 'secret'
)

# Accounts whose credential is kept in .env so an operator can read it without
# guessing. Every other account keeps whatever random value it was issued.
$Managed = [ordered]@{
  'admin@nexus.local'          = 'ADMIN_PASSWORD'
  'supplier@nexus.local'       = 'SUPPLIER_PASSWORD'
  'agency@nexus.local'         = 'AGENCY_PASSWORD'
  'kalite-denetim@nexus.local' = 'QUALITY_PASSWORD'
}

function New-Secret {
  # RandomNumberGenerator::GetBytes(int) only exists on .NET Core, and the
  # project must also run on the Windows PowerShell 5.1 that ships with the OS.
  $bytes = New-Object byte[] 24
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  (($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join '').ToLowerInvariant()
}

function Get-WeakActiveEmails {
  $quoted = ($Weak | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
  $sql = @"
SELECT email FROM auth.users
 WHERE active
   AND password_hash IN (SELECT crypt(candidate, password_hash) FROM unnest(ARRAY[$quoted]::text[]) AS candidate)
 ORDER BY email;
"@
  & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -Atc $sql
  if ($LASTEXITCODE -ne 0) { throw 'Zayıf parola taraması başarısız' }
}

function Set-EnvValue {
  param([string]$Key, [string]$Value)
  $path = Join-Path $ProjectRoot '.env'
  $lines = [IO.File]::ReadAllLines($path)
  $found = $false
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "^$Key=") {
      $lines[$i] = "$Key=$Value"
      $found = $true
    }
  }
  if (-not $found) { $lines += "$Key=$Value" }
  [IO.File]::WriteAllLines($path, $lines, (New-Object Text.UTF8Encoding($false)))
}

$appPassword = $env:PGPASSWORD
try {
  $env:PGPASSWORD = $env:PGOWNER_PASSWORD
  $targets = @(Get-WeakActiveEmails)
  if ($targets.Count -eq 0) {
    Write-Output 'Zayıf parola bulunmadı; hiçbir hesap değiştirilmedi.'
  }
  foreach ($email in $targets) {
    $secret = New-Secret
    # psql does not expand :variables passed through -c, so the statement is
    # written to a file and executed with -f, matching scripts/migrate.ps1.
    $sql = "UPDATE auth.users SET password_hash = crypt(:'pw', gen_salt('bf', 12)) WHERE email = :'mail';`n"
    $temp = Join-Path $ProjectRoot '.local/rotate-password.sql'
    try {
      [IO.File]::WriteAllText($temp, $sql, (New-Object Text.UTF8Encoding($false)))
      & "$PgBin/psql.exe" -X -w -U $env:PGOWNER -v ON_ERROR_STOP=1 -v "pw=$secret" -v "mail=$email" -f $temp
      if ($LASTEXITCODE -ne 0) { throw "Parola güncellenemedi: $email" }
    } finally { Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue }
    $key = $Managed[$email]
    if ($key) { Set-EnvValue -Key $key -Value $secret }
    $label = if ($key) { "$key (değer .env içinde)" } else { 'parola yalnızca yöneticide saklanır' }
    Write-Output "Döndürüldü: $email -> $label"
  }
  $remaining = @(Get-WeakActiveEmails)
  if ($remaining.Count -gt 0) {
    throw "Hâlâ zayıf parola taşıyan hesaplar: $($remaining -join ', ')"
  }
  Write-Output 'Doğrulama tamam: açık hesaplarda bilinen zayıf parola kalmadı.'
} finally {
  $env:PGPASSWORD = $appPassword
}
