# p5engine Export Script
# Usage: .\export_game.ps1 -SketchPath "E:\projects\myGame" -OutputName "myGame"
#
# This script:
# 1. Copies data.ppak from sketch root to data/data.ppak
# 2. Exports the sketch as a Windows application using Processing CLI
# 3. Outputs to dist/ directory

param(
    [Parameter(Mandatory=$true)]
    [string]$SketchPath,

    [Parameter(Mandatory=$false)]
    [string]$OutputName
)

$ErrorActionPreference = "Stop"

$SketchDir = (Resolve-Path $SketchPath).Path
if (-not $OutputName) {
    $OutputName = Split-Path $SketchDir -Leaf
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " p5engine Export Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Sketch: $SketchDir" -ForegroundColor Gray
Write-Host "[INFO] Output: $OutputName" -ForegroundColor Gray
Write-Host ""

$PpakSrc = Join-Path $SketchDir "data.ppak"
$DataDir = Join-Path $SketchDir "data"
$PpakDst = Join-Path $DataDir "data.ppak"

if (Test-Path $PpakSrc) {
    Write-Host "[STEP 1/2] Copying data.ppak to data/ ..." -ForegroundColor Yellow

    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir | Out-Null
        Write-Host "  Created data/ directory" -ForegroundColor Gray
    }

    Copy-Item $PpakSrc -Destination $PpakDst -Force
    Write-Host "  [OK] Copied: data.ppak -> data/data.ppak" -ForegroundColor Green
} else {
    Write-Host "[STEP 1/2] No data.ppak found in sketch root (skipping copy)" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "[STEP 2/2] Exporting application ..." -ForegroundColor Yellow

$OutputParent = Join-Path (Split-Path $SketchDir -Parent) "dist"
$OutputDir = Join-Path $OutputParent $OutputName
$ExeFile = Join-Path $OutputDir "$OutputName.exe"

Write-Host "  Output directory: $OutputDir" -ForegroundColor Gray

& "D:\Processing\Processing.exe" cli `
    --sketch="$SketchDir" `
    --output="$OutputDir" `
    --export `
    --force

Write-Host "  Waiting for export to complete..." -ForegroundColor Gray
$waitCount = 0
while (-not (Test-Path $ExeFile) -and $waitCount -lt 60) {
    Start-Sleep -Seconds 1
    $waitCount++
}
if ($waitCount -ge 60) {
    Write-Host "  Timeout waiting for export" -ForegroundColor Gray
}

if (Test-Path $ExeFile) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " [OK] Export completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " Output: $OutputDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Files in output:" -ForegroundColor Gray
    Get-ChildItem $OutputDir -File | ForEach-Object {
        Write-Host "   - $($_.Name)" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host " [ERROR] Export failed - exe not found" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}