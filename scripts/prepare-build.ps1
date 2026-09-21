# Windows junctions do not require Developer Mode, unlike symbolic links.
$ErrorActionPreference='Stop'
$ProjectRoot=Split-Path $PSScriptRoot -Parent
foreach($mode in @('dev','prod')) {
  $sources=@(Get-ChildItem -LiteralPath "$ProjectRoot/build/packages" -Directory)
  foreach($pkg in $sources) {
    $src=Join-Path $pkg.FullName 'priv'
    $dest="$ProjectRoot/build/$mode/erlang/$($pkg.Name)/priv"
    if ((Test-Path -LiteralPath $src) -and !(Test-Path -LiteralPath $dest)) {
      New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
      New-Item -ItemType Junction -Path $dest -Target $src | Out-Null
    }
  }
  $dest="$ProjectRoot/build/$mode/erlang/nexustraveltech/priv"
  if (!(Test-Path -LiteralPath $dest)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    New-Item -ItemType Junction -Path $dest -Target "$ProjectRoot/priv" | Out-Null
  }
}
