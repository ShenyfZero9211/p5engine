# Compile p5engine sources with JDK 17, pack library\p5engine.jar, then replace the
# Processing-installed library jar (so sketches pick up the new build).
#
# Default: after a successful build, overwrites:
#   E:\projects\processing_env\libraries\p5engine\library\p5engine.jar
# with the newly built jar (same as repo library\p5engine.jar).
# To skip that copy (only keep repo library\p5engine.jar): .\compile-jar.ps1 -NoCopy
#
# 默认：编译成功后，用新生成的 jar 覆盖 Processing 库目录下的 p5engine.jar（路径见上）。
# 若本次不覆盖 Processing 库：加上 -NoCopy
#
# Usage: .\compile-jar.ps1   (from repo root, or pass -RepoRoot)

param(
    [string]$RepoRoot = "E:\projects\kilo\p5engine",
    [string]$JdkPath = "D:\java\jdk-17.0.10+7",
    [string]$ProcessingLibDest = "E:\projects\processing_env\libraries\p5engine\library",
    [switch]$NoCopy
)

$ErrorActionPreference = "Stop"
$javac = Join-Path $JdkPath "bin\javac.exe"
$jar = Join-Path $JdkPath "bin\jar.exe"
$core = Join-Path $RepoRoot "library\core-4.5.2.jar"
$tinySound = Join-Path $RepoRoot "libs\TinySound.jar"
$jorbis = Join-Path $RepoRoot "libs\jorbis.jar"
$tritonus = Join-Path $RepoRoot "libs\tritonus_share.jar"
$vorbisspi = Join-Path $RepoRoot "libs\vorbisspi.jar"
$jna = "D:\Processing\app\jna-5.18.1-cb531ec131e1c68c45b5d45fe5b9878.jar"
$jnaPlatform = "D:\Processing\app\jna-platform-5.18.1-a7af0779ec98bfe22dfb07b153283d.jar"
$sources = Join-Path $RepoRoot "sources.txt"
$classes = Join-Path $RepoRoot "build\classes"
$outJar = Join-Path $RepoRoot "library\p5engine.jar"

if (-not (Test-Path $javac)) { throw "javac not found: $javac" }
if (-not (Test-Path $core)) { throw "core jar not found: $core" }
if (-not (Test-Path $tinySound)) { throw "TinySound jar not found: $tinySound" }
if (-not (Test-Path $sources)) { throw "sources.txt not found: $sources" }

New-Item -ItemType Directory -Path $classes -Force | Out-Null
# Clean all previous class files to avoid stale bundled deps
Get-ChildItem -Path $classes -Recurse | Remove-Item -Recurse -Force
New-Item -ItemType Directory -Path $classes -Force | Out-Null

Write-Host "[compile-jar] javac @sources.txt" -ForegroundColor Cyan
$cp = "$core;$tinySound"
if (Test-Path $jorbis) { $cp += ";$jorbis" }
if (Test-Path $tritonus) { $cp += ";$tritonus" }
if (Test-Path $vorbisspi) { $cp += ";$vorbisspi" }
if (Test-Path $jna) { $cp += ";$jna" }
if (Test-Path $jnaPlatform) { $cp += ";$jnaPlatform" }
& $javac --release 17 -encoding UTF-8 -cp $cp -d $classes "@$sources"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Unzip dependency jars into build so they are bundled into the fat jar
function Unpack-Jar($jarPath, $label) {
    if (-not (Test-Path $jarPath)) { return }
    Write-Host "[compile-jar] unpacking $label into classes" -ForegroundColor Cyan
    $zipCopy = Join-Path $env:TEMP "$label.zip"
    Copy-Item -Path $jarPath -Destination $zipCopy -Force
    Expand-Archive -Path $zipCopy -DestinationPath $classes -Force
    Remove-Item -Path $zipCopy -Force
}
Unpack-Jar $tinySound "TinySound"
# OGG decoder jars are kept separate (not packed into fat jar) so Java Sound SPI
# can discover them correctly from the classpath. Copy them to sketch code/ instead.
# Unpack-Jar $jorbis "jorbis"
# Unpack-Jar $tritonus "tritonus"
# Unpack-Jar $vorbisspi "vorbisspi"

Write-Host "[compile-jar] jar cf p5engine.jar" -ForegroundColor Cyan
Push-Location $classes
try {
    # Pack everything in build/classes (shenyf + kuusisto + org + com + ...)
    & $jar cf $outJar .
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

if (-not $NoCopy) {
    if (-not (Test-Path $ProcessingLibDest)) {
        New-Item -ItemType Directory -Path $ProcessingLibDest -Force | Out-Null
    }
    $processingJar = Join-Path $ProcessingLibDest "p5engine.jar"
    Copy-Item -Path $outJar -Destination $processingJar -Force
    Write-Host "[compile-jar] replaced Processing library jar -> $processingJar" -ForegroundColor Green
    Write-Host "[compile-jar] 已用新 jar 覆盖 Processing 库: $processingJar" -ForegroundColor Green
    $props = Join-Path $RepoRoot "library.properties"
    $libRoot = Split-Path $ProcessingLibDest -Parent
    if (Test-Path $props) {
        Copy-Item -Path $props -Destination (Join-Path $libRoot "library.properties") -Force
        Write-Host "[compile-jar] copied library.properties -> $(Join-Path $libRoot 'library.properties')" -ForegroundColor Green
    }
} else {
    Write-Host "[compile-jar] skipped Processing library replace (-NoCopy); repo jar only: $outJar" -ForegroundColor Yellow
}

Write-Host "[compile-jar] done: $outJar" -ForegroundColor Green
