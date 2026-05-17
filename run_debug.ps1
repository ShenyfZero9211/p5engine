$sketchPath = "E:\projects\kilo\p5engine\examples\TowerDefenseMin2"
$buildPath = "$sketchPath\build"
$processingExe = "D:\Processing\Processing.exe"

if (Test-Path $buildPath) {
    Remove-Item $buildPath -Recurse -Force
}

$errLog = "$env:TEMP\piercer_err.log"
$outLog = "$env:TEMP\piercer_out.log"

if (Test-Path $errLog) { Remove-Item $errLog }
if (Test-Path $outLog) { Remove-Item $outLog }

$proc = Start-Process $processingExe `
    -ArgumentList "cli","--sketch=`"$sketchPath`"","--output=`"$buildPath`"","--run","--force" `
    -RedirectStandardError $errLog `
    -RedirectStandardOutput $outLog `
    -PassThru -NoNewWindow

Write-Host "Started PID: $($proc.Id)"
Write-Host "等待 20 秒收集日志..."
Start-Sleep -Seconds 20

Write-Host ""
Write-Host "=== stderr (last 20 lines) ==="
Get-Content $errLog -ErrorAction SilentlyContinue | Select-Object -Last 20

Write-Host ""
Write-Host "=== stdout (last 40 lines) ==="
Get-Content $outLog -ErrorAction SilentlyContinue | Select-Object -Last 40
