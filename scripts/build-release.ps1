# p5engine Build Release Script
# Usage:
#   .\scripts\build-release.ps1 -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" -BuildEngine -Force
#   .\scripts\build-release.ps1 -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" -UsePpak -Force
#
# Parameters:
#   -SketchPath      : Path to the Processing sketch folder (required)
#   -OutputPath      : Output directory (default: <SketchPath>\output)
#   -BuildEngine     : Compile p5engine.jar before exporting
#   -UsePpak         : Pack data/ into data/data.ppak before exporting
#   -UseJlink        : Use JLink to create a custom slim JRE (default: $true)
#   -JdkPath         : JDK path for javac/jdeps/jlink (default: D:\java\jdk-17.0.10+7)
#   -ProcessingPath  : Processing.exe path (default: D:\Processing\Processing.exe)
#   -Force           : Overwrite existing output directory without prompting

param(
    [Parameter(Mandatory=$true)]
    [string]$SketchPath,

    [string]$OutputPath,
    [switch]$BuildEngine,
    [switch]$UsePpak,
    [bool]$UseJlink = $true,
    [string]$JdkPath = "D:\java\jdk-17.0.10+7",
    [string]$ProcessingPath = "D:\Processing\Processing.exe",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

function Write-Step([string]$msg) {
    Write-Host "[STEP] $msg" -ForegroundColor Green
}

function Write-Info([string]$msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-Warn([string]$msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-Err([string]$msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

function Get-FolderSize([string]$path) {
    $sum = 0
    if (Test-Path $path) {
        $items = Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if (-not $item.PSIsContainer) {
                $sum += $item.Length
            }
        }
    }
    return $sum
}

function Format-Size([long]$bytes) {
    if ($bytes -gt 1GB) {
        return "{0:N2} GB" -f ($bytes / 1GB)
    } elseif ($bytes -gt 1MB) {
        return "{0:N2} MB" -f ($bytes / 1MB)
    } else {
        return "{0:N2} KB" -f ($bytes / 1KB)
    }
}

# -----------------------------------------------------------------------------
# Resolve Paths
# -----------------------------------------------------------------------------

$SketchDir = (Resolve-Path $SketchPath).Path
$SketchName = Split-Path $SketchDir -Leaf

if ([string]::IsNullOrEmpty($OutputPath)) {
    $OutputPath = Join-Path $SketchDir "output"
}

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $RepoRoot "compile-jar.ps1"))) {
    # If scripts/ is not under repo root, try current directory
    $RepoRoot = "E:\projects\kilo\p5engine"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " p5engine Build Release Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Info "Sketch    : $SketchDir"
Write-Info "Output    : $OutputPath"
Write-Info "BuildEngine: $BuildEngine"
Write-Info "UsePpak   : $UsePpak"
Write-Info "UseJlink  : $UseJlink"
Write-Host ""

# -----------------------------------------------------------------------------
# STEP 1: Compile Engine (optional)
# -----------------------------------------------------------------------------

if ($BuildEngine) {
    Write-Step "Compiling p5engine.jar"
    $compileScript = Join-Path $RepoRoot "compile-jar.ps1"
    if (-not (Test-Path $compileScript)) {
        throw "compile-jar.ps1 not found at $compileScript"
    }

    Write-Info "Running compile-jar.ps1 ..."
    & $compileScript -RepoRoot $RepoRoot -JdkPath $JdkPath
    if ($LASTEXITCODE -ne 0) {
        throw "Engine compilation failed"
    }

    $engineJar = Join-Path $RepoRoot "library\p5engine.jar"
    $codeDir = Join-Path $SketchDir "code"
    if (-not (Test-Path $codeDir)) {
        New-Item -ItemType Directory -Path $codeDir -Force | Out-Null
    }

    Copy-Item $engineJar -Destination (Join-Path $codeDir "p5engine.jar") -Force
    Write-Info "Copied p5engine.jar -> $codeDir"

    # Also copy snakeyaml if the sketch uses YAML configs and doesn't have it
    $yamlJar = Join-Path $RepoRoot "build\shenyf\p5engine\resource\snakeyaml-2.2.jar"
    if (-not $yamlJar) {
        $yamlJar = Get-ChildItem $RepoRoot -Recurse -Filter "snakeyaml*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    $codeYaml = Join-Path $codeDir "snakeyaml-2.2.jar"
    if ($yamlJar -and -not (Test-Path $codeYaml)) {
        Copy-Item $yamlJar.FullName -Destination $codeYaml -Force
        Write-Info "Copied snakeyaml-2.2.jar -> $codeDir"
    }

    Write-Host ""
}

# -----------------------------------------------------------------------------
# STEP 2: Validate Environment
# -----------------------------------------------------------------------------

Write-Step "Validating environment"

if (-not (Test-Path $SketchDir)) {
    throw "Sketch path not found: $SketchDir"
}

$pdeFiles = Get-ChildItem $SketchDir -Filter *.pde
if ($pdeFiles.Count -eq 0) {
    throw "No .pde files found in sketch folder"
}

if (-not (Test-Path $ProcessingPath)) {
    throw "Processing.exe not found: $ProcessingPath"
}

$Jdeps = Join-Path $JdkPath "bin\jdeps.exe"
$Jlink = Join-Path $JdkPath "bin\jlink.exe"

if (-not (Test-Path $Jdeps)) {
    throw "jdeps.exe not found: $Jdeps"
}
if ($UseJlink -and -not (Test-Path $Jlink)) {
    throw "jlink.exe not found: $Jlink"
}

# Verify p5engine.jar exists in code/
$codeEngineJar = Join-Path $SketchDir "code\p5engine.jar"
if (-not (Test-Path $codeEngineJar)) {
    Write-Warn "p5engine.jar not found in sketch/code/. Export may fail if the sketch depends on it."
}

Write-Info "Environment OK"
Write-Host ""

# -----------------------------------------------------------------------------
# STEP 3: Prepare Output Directory
# -----------------------------------------------------------------------------

Write-Step "Preparing output directory"

if (Test-Path $OutputPath) {
    if ($Force) {
        Write-Warn "Removing existing output directory (Force mode)"
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
Write-Info "Output directory ready"
Write-Host ""

# -----------------------------------------------------------------------------
# STEP 4: Optional PPAK Packing
# -----------------------------------------------------------------------------

$ppakCreated = $false
if ($UsePpak) {
    Write-Step "Packing resources into PPAK"
    $ppakScript = Join-Path $RepoRoot "tools\ppak\ppak_pack.py"
    if (-not (Test-Path $ppakScript)) {
        throw "PPAK pack script not found: $ppakScript"
    }

    # Collect all resource directories at sketch root
    $ppakDirs = @()
    $ppakDirNames = @()
    foreach ($dirName in @("data", "music", "sounds", "textures", "images", "fonts", "assets", "resources", "videos", "maps", "levels")) {
        $dirPath = Join-Path $SketchDir $dirName
        if (Test-Path $dirPath) {
            $ppakDirs += $dirPath
            $ppakDirNames += $dirName
        }
    }

    if ($ppakDirs.Count -eq 0) {
        Write-Warn "No resource folders found, skipping PPAK"
    } else {
        # Ensure data/ directory exists so Processing CLI copies it
        $dataDir = Join-Path $SketchDir "data"
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }

        $ppakOutput = Join-Path $dataDir "data.ppak"

        # Remove existing data.ppak to avoid recursive packing
        if (Test-Path $ppakOutput) {
            Remove-Item $ppakOutput -Force
            Write-Warn "Removed existing data.ppak to avoid recursive packing"
        }

        Write-Info "Packing directories: $($ppakDirNames -join ', ')"
        Write-Info "Output: $ppakOutput"

        $pythonArgs = @($ppakScript) + $ppakDirs + @("-o", $ppakOutput)
        & python @pythonArgs
        if ($LASTEXITCODE -ne 0) {
            throw "PPAK packing failed"
        }
        $ppakCreated = $true
        Write-Info "PPAK created: $ppakOutput ($([math]::Round((Get-Item $ppakOutput).Length/1MB, 2)) MB)"
    }
    Write-Host ""
}

# -----------------------------------------------------------------------------
# STEP 5: Export with Processing CLI
# -----------------------------------------------------------------------------

Write-Step "Exporting sketch with Processing CLI"

$proc = Start-Process -FilePath $ProcessingPath `
    -ArgumentList "cli","--force","--sketch=`"$SketchDir`"","--output=`"$OutputPath`"","--export","--variant=windows-amd64" `
    -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -ne 0) {
    # Sometimes Processing returns non-zero but exe is still generated
    $exeFiles = Get-ChildItem $OutputPath -Filter *.exe -ErrorAction SilentlyContinue
    if ($null -eq $exeFiles -or $exeFiles.Count -eq 0) {
        throw "Processing export failed (exit code $($proc.ExitCode))"
    } else {
        Write-Warn "Processing returned exit code $($proc.ExitCode), but .exe was found. Continuing..."
    }
}

$exeFile = Get-ChildItem $OutputPath -Filter *.exe | Select-Object -First 1
if ($null -eq $exeFile) {
    throw "Export failed: .exe not found in output"
}

Write-Info "Export completed: $($exeFile.Name)"
Write-Host ""

# -----------------------------------------------------------------------------
# STEP 5b: Copy extra resource folders (music, sounds, textures, etc.)
# Processing CLI only copies the data/ folder; sketch-level resource dirs
# must be copied manually.
# -----------------------------------------------------------------------------

Write-Step "Copying extra resource folders"

$commonResourceNames = @("music", "sounds", "textures", "images", "fonts", "assets", "resources", "videos", "maps", "levels")
$excludeDirs = @("data", "code", "output", "build", "source", "dist", ".git", ".vscode", ".cursor", ".idea", ".gradle", "logs")
$extraDirs = Get-ChildItem $SketchDir -Directory | Where-Object {
    $name = $_.Name
    ($commonResourceNames -contains $name) -and ($excludeDirs -notcontains $name)
}

if ($ppakCreated) {
    Write-Info "PPAK mode: skipping copy of extra resource folders (already packed into data.ppak)"
} elseif ($extraDirs.Count -eq 0) {
    Write-Info "No extra resource folders found"
} else {
    foreach ($dir in $extraDirs) {
        $src = $dir.FullName
        $dst = Join-Path $OutputPath $dir.Name
        if (Test-Path $dst) {
            Remove-Item $dst -Recurse -Force
        }
        Copy-Item $src -Destination $dst -Recurse -Force
        $dirSize = (Get-ChildItem $dst -Recurse -File | Measure-Object -Property Length -Sum).Sum
        Write-Info "Copied $($dir.Name) -> $(Format-Size $dirSize)"
    }
}
Write-Host ""

# -----------------------------------------------------------------------------
# STEP 6: Optional JLink Slim JRE
# -----------------------------------------------------------------------------

if ($UseJlink) {
    Write-Step "Creating custom JRE with JLink"

    $libDir = Join-Path $OutputPath "lib"
    if (-not (Test-Path $libDir)) {
        throw "lib/ directory not found in output. Export may have failed."
    }

    # Analyze jar dependencies with jdeps
    $allJars = Get-ChildItem $libDir -Filter *.jar
    $mainJar = $allJars | Where-Object { $_.Name -like "*$SketchName*" } | Select-Object -First 1
    if ($null -eq $mainJar) {
        $mainJar = $allJars | Select-Object -First 1
    }

    Write-Info "Analyzing: $($mainJar.Name)"
    $classpath = ""
    $jarPaths = @()
    foreach ($jar in $allJars) {
        $jarPaths += $jar.FullName
    }
    $classpath = [string]::Join(";", $jarPaths)

    $jdepsOutput = & "$Jdeps" --print-module-deps --ignore-missing-deps --multi-release 17 -cp "$classpath" "$($mainJar.FullName)" 2>&1 | Out-String
    Write-Info "jdeps output: $jdepsOutput"

    # Extract java.* modules
    $moduleMatches = [regex]::Matches($jdepsOutput, "java\.[\w.]+")
    $moduleList = @()
    $seen = @{}
    foreach ($m in $moduleMatches) {
        $mod = $m.Value
        if (-not $seen.ContainsKey($mod)) {
            $seen[$mod] = $true
            $moduleList += $mod
        }
    }

    # Merge with recommended module set for Processing P2D/P3D
    $recommendedModules = @(
        "java.base", "java.desktop", "java.xml", "java.sql",
        "java.naming", "java.net.http", "java.management", "java.logging"
    )
    foreach ($mod in $recommendedModules) {
        if (-not $seen.ContainsKey($mod)) {
            $seen[$mod] = $true
            $moduleList += $mod
        }
    }

    $modules = [string]::Join(",", $moduleList)
    Write-Info "Using modules: $modules"

    # Run jlink
    $jmodsPath = Join-Path $JdkPath "jmods"
    $outJre = Join-Path $OutputPath "java-custom"

    & "$Jlink" `
        --module-path "$jmodsPath" `
        --add-modules "$modules" `
        --output "$outJre" `
        --compress=2 `
        --no-header-files `
        --no-man-pages `
        --strip-debug

    if ($LASTEXITCODE -ne 0) {
        throw "JLink failed (exit code $LASTEXITCODE)"
    }

    if (-not (Test-Path $outJre)) {
        throw "JLink output not found: $outJre"
    }

    $jreSize = Get-FolderSize $outJre
    Write-Info "Custom JRE created: $(Format-Size $jreSize)"

    # Replace original java directory
    $origJava = Join-Path $OutputPath "java"
    if (Test-Path $origJava) {
        Remove-Item $origJava -Recurse -Force
    }
    Rename-Item $outJre "java"
    Write-Info "Replaced original JRE with custom version"
    Write-Host ""
}

# -----------------------------------------------------------------------------
# STEP 7: Cleanup & Summary
# -----------------------------------------------------------------------------

Write-Step "Build Summary"

# Clean up temporary launch4j files if still present
$tempFiles = @("launch4j-build.xml", "launch4j-config.xml")
foreach ($tf in $tempFiles) {
    $tp = Join-Path $OutputPath $tf
    if (Test-Path $tp) {
        Remove-Item $tp -Force
    }
}

$exe = Get-ChildItem $OutputPath -Filter *.exe | Select-Object -First 1
Write-Host "  Executable : $($exe.FullName)" -ForegroundColor White
Write-Host "  EXE Size   : $(Format-Size $exe.Length)" -ForegroundColor White

$javaDir = Join-Path $OutputPath "java"
if (Test-Path $javaDir) {
    $javaSize = Get-FolderSize $javaDir
    Write-Host "  JRE Size   : $(Format-Size $javaSize)" -ForegroundColor White
}

$totalSize = Get-FolderSize $OutputPath
Write-Host "  Total Size : $(Format-Size $totalSize)" -ForegroundColor Green
Write-Host ""

if ($ppakCreated) {
    Write-Info "PPAK mode: all resources loaded from data/data.ppak"
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host " Build completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Run: $($exe.FullName)" -ForegroundColor Cyan
