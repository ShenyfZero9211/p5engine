$sketchPath = "E:\projects\kilo\p5engine\examples\TowerDefenseMin2"
$buildPath = "$sketchPath\build"
$processingExe = "D:\Processing\Processing.exe"

if (Test-Path $buildPath) {
    Remove-Item $buildPath -Recurse -Force
}

$errLog = "$env:TEMP\td2_err.log"
$outLog = "$env:TEMP\td2_out.log"
Remove-Item $errLog, $outLog -ErrorAction SilentlyContinue

$proc = Start-Process $processingExe `
    -ArgumentList "cli","--sketch=`"$sketchPath`"","--output=`"$buildPath`"","--run","--force" `
    -RedirectStandardError $errLog `
    -RedirectStandardOutput $outLog `
    -PassThru -NoNewWindow

Write-Host "[INFO] PID: $($proc.Id)"
Write-Host "[INFO] 请在游戏中尝试读取 level 8 存档，等待 45 秒收集日志..."
Start-Sleep -Seconds 45

Write-Host "`n=== stdout last 30 lines ==="
Get-Content $outLog -ErrorAction SilentlyContinue | Select-Object -Last 30
Write-Host "`n=== stderr last 20 lines ==="
Get-Content $errLog -ErrorAction SilentlyContinue | Select-Object -Last 20
Write-Host "`n[DONE] 如果程序仍在运行，请手动关闭"
