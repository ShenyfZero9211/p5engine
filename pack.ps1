param(
    [Parameter(Mandatory=$true)]
    [string]$SketchPath,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "",

    [Parameter(Mandatory=$false)]
    [string]$Variant = "windows-amd64"
)

$ErrorActionPreference = "Stop"

$ProcessingExe = "D:\Processing\Processing.exe"

function Get-DirectorySize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    }
    return 0
}

if (-not (Test-Path $SketchPath)) {
    Write-Host "[ERROR] Sketch path not found: $SketchPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ProcessingExe)) {
    Write-Host "[ERROR] Processing.exe not found: $ProcessingExe" -ForegroundColor Red
    exit 1
}

if ($OutputPath -eq "") {
    $OutputPath = Join-Path $SketchPath "exported"
}

if (Test-Path $OutputPath) {
    Write-Host ""
    Write-Host "Output directory already exists: $OutputPath" -ForegroundColor Yellow
    Write-Host "  [O]verwrite" -ForegroundColor Cyan
    Write-Host "  [C]ancel" -ForegroundColor Cyan
    Write-Host "  [M]anual path (enter new path)" -ForegroundColor Cyan
    $choice = Read-Host "Please select an option"

    if ($choice -eq "C" -or $choice -eq "c") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    elseif ($choice -eq "M" -or $choice -eq "m") {
        $newPath = Read-Host "Enter new output path"
        if ($newPath -ne "") {
            $OutputPath = $newPath
        } else {
            Write-Host "Cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    elseif ($choice -eq "O" -or $choice -eq "o") {
        Write-Host "Removing existing output directory..." -ForegroundColor Yellow
        Remove-Item -Path $OutputPath -Recurse -Force
    } else {
        Write-Host "Invalid option. Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "=== P5Engine Pack Script ===" -ForegroundColor Green
Write-Host "Sketch: $SketchPath"
Write-Host "Output: $OutputPath"
Write-Host "Variant: $Variant"
Write-Host ""

Write-Host "[1/6] Exporting application..." -ForegroundColor Cyan
$p = Start-Process -FilePath $ProcessingExe -ArgumentList "cli --sketch=`"$SketchPath`" --output=`"$OutputPath`" --variant=$Variant --export" -NoNewWindow -Wait -PassThru

Write-Host "[2/6] Cleaning up JRE (keeping essential files)..." -ForegroundColor Cyan
$javaDir = Join-Path $OutputPath "java"
if (Test-Path $javaDir) {
    $cleanupItems = @(
        (Join-Path $javaDir "src.zip"),
        (Join-Path $javaDir "ct.sym"),
        (Join-Path $javaDir "jmods")
    )
    foreach ($item in $cleanupItems) {
        if (Test-Path $item) {
            Remove-Item -Path $item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Removed: $item" -ForegroundColor Gray
        }
    }

    $legalDir = Join-Path $javaDir "legal"
    if (Test-Path $legalDir) {
        Remove-Item -Path $legalDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed: $legalDir" -ForegroundColor Gray
    }
}

Write-Host "[3/6] Cleaning up non-Windows native libraries..." -ForegroundColor Cyan
$libDir = Join-Path $OutputPath "lib"
if (Test-Path $libDir) {
    $nativesToRemove = Get-ChildItem -Path $libDir -Filter "*natives-*" -ErrorAction SilentlyContinue
    foreach ($natives in $nativesToRemove) {
        if ($natives.Name -notlike "*windows*") {
            Remove-Item -Path $natives.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Removed: $($natives.Name)" -ForegroundColor Gray
        }
    }
}

Write-Host "[4/6] Cleaning up build artifacts..." -ForegroundColor Cyan
$buildXml = Join-Path $OutputPath "launch4j-build.xml"
if (Test-Path $buildXml) {
    Remove-Item -Path $buildXml -Force -ErrorAction SilentlyContinue
    Write-Host "  Removed: launch4j-build.xml" -ForegroundColor Gray
}

Write-Host "[5/6] Copying config file..." -ForegroundColor Cyan
$iniSource = Join-Path $SketchPath "p5engine.ini"
if (Test-Path $iniSource) {
    Copy-Item -Path $iniSource -Destination $OutputPath -Force
    Write-Host "  Copied: p5engine.ini" -ForegroundColor Gray
} else {
    Write-Host "  Skipped: p5engine.ini not found" -ForegroundColor Gray
}

Write-Host "[6/6] Complete!" -ForegroundColor Cyan

$sizeAfter = Get-DirectorySize $OutputPath
$originalSize = 300
$saved = $originalSize - $sizeAfter

Write-Host ""
Write-Host "=== Result ===" -ForegroundColor Green
Write-Host "  Output: $OutputPath" -ForegroundColor White
Write-Host "  Size: $sizeAfter MB" -ForegroundColor White
if ($saved -gt 0) {
    Write-Host "  Saved: ~$saved MB (vs original ~$originalSize MB)" -ForegroundColor Green
}

$exePath = Get-ChildItem -Path $OutputPath -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exePath) {
    Write-Host "  Executable: $($exePath.Name)" -ForegroundColor White
}
Write-Host ""