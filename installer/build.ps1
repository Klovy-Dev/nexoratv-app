# Fabrique l'installeur Windows de NexoraTV et affiche le bloc à mettre
# dans update.json.
#
#   powershell -ExecutionPolicy Bypass -File installer\build.ps1
#
# Prérequis : Inno Setup 6 (winget install JRSoftware.InnoSetup).
# La version vient du pubspec.yaml (« version: 2.1.0+210 » -> 2.1.0).

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Write-Host "NexoraTV $version" -ForegroundColor Cyan

flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'La compilation a échoué.' }

# Runtime Visual C++ joint à l'appli : sans lui, NexoraTV ne démarre pas sur
# un PC qui ne l'a pas déjà.
$release = 'build\windows\x64\runner\Release'
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  $src = Join-Path $env:WINDIR "System32\$dll"
  if (Test-Path $src) { Copy-Item $src $release -Force }
}

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 introuvable : winget install JRSoftware.InnoSetup' }

& $iscc "/DAppVersion=$version" installer\nexoratv.iss
if ($LASTEXITCODE -ne 0) { throw "La création de l'installeur a échoué." }

$name = "NexoraTV-Setup-$version.exe"
$setup = "build\installer\$name"
$hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()

# Dépôt GitHub : celui du manifeste déclaré dans lib/core/config.dart.
$config = Get-Content lib\core\config.dart -Raw
$repo = [regex]::Match($config, 'githubusercontent\.com/([^/]+/[^/]+)/').Groups[1].Value

Write-Host ''
Write-Host "Installeur : $setup" -ForegroundColor Green
Write-Host "1. Créer la release GitHub « v$version » sur $repo et y joindre $name"
Write-Host '2. Remplacer le bloc "windows" de update.json par :'
Write-Host ''
@"
  "windows": {
    "version": "$version",
    "url": "https://github.com/$repo/releases/download/v$version/$name",
    "sha256": "$hash",
    "notes": "…",
    "mandatory": false
  },
"@
