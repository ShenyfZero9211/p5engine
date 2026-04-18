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
$JdkBin = "D:\java\jdk-17.0.10+7\bin"

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

$sizeBefore = Get-DirectorySize $OutputPath
if ($sizeBefore -gt 0) {
    Write-Host "[1/8] Removing old output... ($sizeBefore MB)" -ForegroundColor Cyan
    Remove-Item -Path $OutputPath -Recurse -Force
}

Write-Host "[2/8] Exporting application..." -ForegroundColor Cyan
Write-Host "  Command: $ProcessingExe cli --sketch=$SketchPath --output=$OutputPath --variant=$Variant --export" -ForegroundColor Gray
$p = Start-Process -FilePath $ProcessingExe -ArgumentList "cli --sketch=`"$SketchPath`" --output=`"$OutputPath`" --variant=$Variant --export" -NoNewWindow -Wait -PassThru

Write-Host "[3/8] Analyzing dependencies..." -ForegroundColor Cyan
$coreJar = Join-Path $OutputPath "lib\core-4.5.2.jar"
if (-not (Test-Path $coreJar)) {
    $libDir = Join-Path $OutputPath "lib"
    $coreJar = Get-ChildItem -Path $libDir -Filter "core-*.jar" | Select-Object -First 1 | ForEach-Object { $_.FullName }
}

if ($coreJar -and (Test-Path $coreJar)) {
    $depsOutput = & (Join-Path $JdkBin "jdeps") --ignore-missing-deps --print-module-deps $coreJar 2>&1 | Out-String
    $depsOutput = $depsOutput -replace "`n", "" -replace "`r", ""
    $depsMatch = [regex]::Match($depsOutput, '([a-z.,]+)')
    if ($depsMatch.Success) {
        $deps = $depsMatch.Groups[1].Value
    } else {
        $deps = "java.base,java.desktop"
    }
} else {
    $deps = "java.base,java.desktop"
}
Write-Host "  Modules: $deps" -ForegroundColor Gray

Write-Host "[4/8] Generating slim JRE..." -ForegroundColor Cyan
$javaJmods = Join-Path $OutputPath "java\jmods"
$tempJre = Join-Path $OutputPath "java_slim"

if (-not (Test-Path $javaJmods)) {
    Write-Host "[ERROR] jmods directory not found. Cannot create slim JRE." -ForegroundColor Red
    Write-Host "  Path: $javaJmods" -ForegroundColor Red
    exit 1
}

Write-Host "  Command: jlink ..." -ForegroundColor Gray
$jlinkArgs = "--no-header-files --no-man-pages --compress=2 --strip-debug --module-path `"$javaJmods`" --add-modules $deps --output `"$tempJre`""
$p = Start-Process -FilePath (Join-Path $JdkBin "jlink.exe") -ArgumentList $jlinkArgs -NoNewWindow -Wait -PassThru

if (-not (Test-Path $tempJre)) {
    Write-Host "[ERROR] jlink failed to create slim JRE." -ForegroundColor Red
    exit 1
}

Write-Host "[5/8] Replacing JRE..." -ForegroundColor Cyan
Remove-Item -Path (Join-Path $OutputPath "java") -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item -Path $tempJre -NewName "java" -Force

Write-Host "[6/8] Cleaning up unnecessary files..." -ForegroundColor Cyan
$cleanupItems = @(
    (Join-Path $OutputPath "java\src.zip"),
    (Join-Path $OutputPath "java\ct.sym"),
    (Join-Path $OutputPath "java\legal"),
    (Join-Path $OutputPath "java\conf"),
    (Join-Path $OutputPath "java\jmods"),
    (Join-Path $OutputPath "launch4j-build.xml")
)
foreach ($item in $cleanupItems) {
    if (Test-Path $item) {
        Remove-Item -Path $item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$nativesToRemove = Get-ChildItem -Path (Join-Path $OutputPath "lib") -Filter "*natives-*" -ErrorAction SilentlyContinue
foreach ($natives in $nativesToRemove) {
    if ($natives.Name -notlike "*windows*") {
        Remove-Item -Path $natives.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed: $($natives.Name)" -ForegroundColor Gray
    }
}

Write-Host "[7/8] Copying config file..." -ForegroundColor Cyan
$iniSource = Join-Path $SketchPath "p5engine.ini"
if (Test-Path $iniSource) {
    Copy-Item -Path $iniSource -Destination $OutputPath -Force
    Write-Host "  Copied: p5engine.ini" -ForegroundColor Gray
} else {
    Write-Host "  Skipped: p5engine.ini not found" -ForegroundColor Gray
}

Write-Host "[8/8] Complete!" -ForegroundColor Cyan

$sizeAfter = Get-DirectorySize $OutputPath
$originalJava = 300
$saved = $originalJava - $sizeAfter

Write-Host ""
Write-Host "=== Result ===" -ForegroundColor Green
Write-Host "  Output: $OutputPath" -ForegroundColor White
Write-Host "  Size: $sizeAfter MB" -ForegroundColor White
if ($saved -gt 0) {
    Write-Host "  Saved: ~$saved MB (vs original ~$originalJava MB)" -ForegroundColor Green
}

$exePath = Get-ChildItem -Path $OutputPath -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exePath) {
    Write-Host "  Executable: $($exePath.Name)" -ForegroundColor White
}
Write-Host ""