param(
    [string]$SketchPath = "E:\projects\kilo\p5engine\examples\ExampleExportDemo",
    [string]$OutputPath = "E:\projects\kilo\p5engine\examples\ExampleExportDemo\output",
    [bool]$UseJlink = $true,
    [string]$JdkPath = "D:\java\jdk-17.0.10+7",
    [string]$ProcessingPath = "D:\Processing\Processing.exe",
    [switch]$Force
)

$JLink = "$JdkPath\bin\jlink.exe"
$Jdeps = "$JdkPath\bin\jdeps.exe"
$ModuleSet = "java.base,java.desktop,java.xml,java.sql,java.naming,java.net.http,java.management,java.logging"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Processing Export Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[STEP] Validating input parameters" -ForegroundColor Green

if (-not (Test-Path $SketchPath)) {
    throw "Sketch path not found: $SketchPath"
}

$pdfCount = (Get-ChildItem $SketchPath -Filter *.pde).Count
if ($pdfCount -eq 0) {
    throw "No .pde files found in sketch folder"
}

if (-not (Test-Path $ProcessingPath)) {
    throw "Processing.exe not found: $ProcessingPath"
}

if (-not (Test-Path $Jdeps)) {
    throw "jdeps.exe not found: $Jdeps"
}

if ($UseJlink -and -not (Test-Path $JLink)) {
    throw "jlink.exe not found: $JLink"
}

Write-Host "[INFO] Sketch: $SketchPath"
Write-Host "[INFO] Output: $OutputPath"
Write-Host "[INFO] Use JLink: $UseJlink"
Write-Host ""

Write-Host "[STEP] Preparing output directory" -ForegroundColor Green

if (Test-Path $OutputPath) {
    if ($Force) {
        Write-Host "[WARN] Removing existing output directory (Force mode)"
        Remove-Item $OutputPath -Recurse -Force
    } else {
        $confirm = Read-Host "Output folder already exists. Delete and continue? (y/n)"
        if ($confirm -ne "y") {
            throw "Build cancelled by user"
        }
        Remove-Item $OutputPath -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
Write-Host "[INFO] Output directory ready" -ForegroundColor Cyan
Write-Host ""

Write-Host "[STEP] Exporting sketch with Processing CLI" -ForegroundColor Green

Write-Host "[INFO] Command: Processing CLI export" -ForegroundColor Cyan
$proc = Start-Process -FilePath $ProcessingPath -ArgumentList "cli","--force","--sketch=`"$SketchPath`"","--output=`"$OutputPath`"","--export","--variant=windows-amd64" -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -ne 0 -and (Test-Path (Join-Path $OutputPath "*.exe")) -eq $false) {
    throw "Processing export failed (exit code $($proc.ExitCode))"
}

$exeFound = Get-ChildItem $OutputPath -Filter *.exe -ErrorAction SilentlyContinue
if ($null -eq $exeFound) {
    throw "Export failed: .exe not found in output"
}

Write-Host "[INFO] Export completed successfully" -ForegroundColor Cyan
Write-Host ""

if ($UseJlink) {
    Write-Host "[STEP] Analyzing jar dependencies with jdeps" -ForegroundColor Green

    $libDir = Join-Path $OutputPath "lib"
    $allJars = Get-ChildItem $libDir -Filter *.jar
    $mainJar = $allJars | Where-Object { $_.Name -like "*Example*" -or $_.Name -like "*core*" } | Select-Object -First 1
    if ($null -eq $mainJar) {
        $mainJar = $allJars | Select-Object -First 1
    }

    Write-Host "[INFO] Analyzing: $($mainJar.FullName)"

    $classpath = ($allJars | ForEach-Object { $_.FullName }) -join ";"
    $jdepOut = & "$Jdeps" --print-module-deps --ignore-missing-deps --multi-release 17 -cp $classpath "$($mainJar.FullName)" 2>&1 | Out-String

    Write-Host "[INFO] jdeps output: $jdepOut"

    $moduleMatch = [regex]::Matches($jdepOut, "java\.\w+") | Select-Object -Unique
    if ($moduleMatch.Count -gt 0) {
        $moduleList = $moduleMatch | ForEach-Object { $_.Value }
        $modules = [string]::Join(",", $moduleList)
    } else {
        $modules = $ModuleSet
    }

    Write-Host "[INFO] Using modules: $modules"
    Write-Host ""

    Write-Host "[STEP] Creating custom JRE with JLink" -ForegroundColor Green

    $jmodsPath = Join-Path $JdkPath "jmods"
    $outJre = Join-Path $OutputPath "java-custom"

    Write-Host "[INFO] Creating custom JRE with JLink"

    & "$JLink" --module-path "$jmodsPath" --add-modules "$modules" --output "$outJre" --compress=2 --no-header-files --no-man-pages --strip-debug

    if ($LASTEXITCODE -ne 0) {
        throw "JLink failed (exit code $LASTEXITCODE)"
    }

    if (-not (Test-Path $outJre)) {
        throw "JLink output not found: $outJre"
    }

    $jreSize = (Get-ChildItem $outJre -Recurse | Measure-Object -Property Length -Sum).Sum
    Write-Host "[INFO] Custom JRE created: $([math]::Round($jreSize/1MB, 2)) MB" -ForegroundColor Cyan

    $origJava = Join-Path $OutputPath "java"
    if (Test-Path $origJava) {
        Remove-Item $origJava -Recurse -Force
    }
    Rename-Item $outJre "java"
    Write-Host "[INFO] Replaced original JRE with custom version" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "[STEP] Build Summary" -ForegroundColor Green

$exe = Get-ChildItem $OutputPath -Filter *.exe | Select-Object -First 1
Write-Host "  Executable : $($exe.FullName)" -ForegroundColor White
Write-Host "  Size       : $([math]::Round($exe.Length/1KB, 2)) KB" -ForegroundColor White

$javaDir = Join-Path $OutputPath "java"
if (Test-Path $javaDir) {
    $javaSize = (Get-ChildItem $javaDir -Recurse | Measure-Object -Property Length -Sum).Sum
    Write-Host "  Custom JRE : $([math]::Round($javaSize/1MB, 2)) MB" -ForegroundColor White
}

$total = (Get-ChildItem $OutputPath -Recurse | Measure-Object -Property Length -Sum).Sum
Write-Host "  Total size : $([math]::Round($total/1MB, 2)) MB" -ForegroundColor Green
Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
