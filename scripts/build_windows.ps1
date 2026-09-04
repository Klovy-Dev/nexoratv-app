# Build NexoraTV pour Windows : release + installeur en un seul fichier.
# Usage :  powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1 [-Version 1.2.0]
param(
  [string]$Version = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $Version) {
  $Version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
}
Write-Host "== NexoraTV $Version ==" -ForegroundColor Cyan

# 1. Build Flutter
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue)?.Source
if (-not $flutter) { $flutter = "C:\src\flutter\bin\flutter.bat" }
& $flutter build windows --release --build-name=$Version
if ($LASTEXITCODE -ne 0) { throw "flutter build a échoué" }

# 2. Installeur Inno Setup
$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "ISCC.exe introuvable — installe Inno Setup 6" }

& $iscc "/DAppVersion=$Version" "installer\nexoratv.iss"
if ($LASTEXITCODE -ne 0) { throw "compilation de l'installeur a échoué" }

$out = "installer\Output\NexoraTV-Setup-$Version.exe"
Write-Host "`nOK -> $out" -ForegroundColor Green
Get-Item $out | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
