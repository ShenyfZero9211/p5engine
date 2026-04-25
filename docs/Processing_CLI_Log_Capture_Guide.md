# Processing CLI 日志捕获与调试指南

> 本文档记录如何在 Processing CLI 环境下分离捕获 stdout/stderr，以及 p5engine 双日志系统的工作机制与最佳实践。
>
> 适用版本：Processing 4.5.2, p5engine 0.1.0-M1, PowerShell 5.1+

---

## 目录

1. [问题背景](#1-问题背景)
2. [PowerShell 标准流重定向](#2-powershell-标准流重定向)
3. [完整捕获脚本模板](#3-完整捕获脚本模板)
4. [p5engine 双日志系统](#4-p5engine-双日志系统)
5. [最佳实践与技巧](#5-最佳实践与技巧)
6. [常见问题排查](#6-常见问题排查)

---

## 1. 问题背景

Processing IDE 的 GUI 运行模式下，控制台输出直接显示在 IDE 底部，方便但难以持久化。使用 Processing CLI (`processing.exe cli --run`) 时：

- **无交互式控制台**：`processing.exe cli` 启动的子进程不继承当前终端的 stdin/stdout
- **日志分散**：引擎日志进 `logs/` 目录，PDE `println()` 输出到控制台，错误信息到 stderr
- **调试困难**：当需要同时分析引擎内部状态（Java）和 PDE 层状态（Processing）时，信息来源不统一

**目标**：建立一套完整的日志捕获方案，将 stdout（含 `println`）和 stderr（含 Java 异常）分离存储，同时保留引擎文件日志能力。

---

## 2. PowerShell 标准流重定向

### 2.1 核心原理

Windows 进程有三个标准流：

| 流 | 句柄 | PowerShell 参数 | 用途 |
|----|------|-----------------|------|
| stdin  | 0 | `-RedirectStandardInput`  | 进程输入 |
| stdout | 1 | `-RedirectStandardOutput` | 正常输出（`println`, `System.out`） |
| stderr | 2 | `-RedirectStandardError`  | 错误输出（异常、警告） |

Processing CLI 运行时的输出分布：

```
┌─────────────────────────────────────────┐
│  Processing CLI 子进程                   │
│  ├─ PDE println() ────────→ stdout      │
│  ├─ Logger.info() ────────→ stdout      │
│  ├─ Logger.debug() ───────→ stdout      │
│  ├─ System.err.println() ─→ stderr      │
│  └─ Java Exception Stack ─→ stderr      │
└─────────────────────────────────────────┘
         │                    │
         ▼                    ▼
   $outLog 文件          $errLog 文件
```

### 2.2 基础用法

```powershell
$proc = Start-Process "D:\Processing\Processing.exe" `
    -ArgumentList "cli", "--sketch=`"$sketchPath`"", "--run", "--force" `
    -RedirectStandardOutput "$env:TEMP\stdout.log" `
    -RedirectStandardError  "$env:TEMP\stderr.log" `
    -PassThru -NoNewWindow

# 等待进程结束
$proc.WaitForExit()

# 读取输出
Get-Content "$env:TEMP\stdout.log" -Tail 50
Get-Content "$env:TEMP\stderr.log" -Tail 20
```

### 2.3 实时流处理（高级）

如果需要**实时**查看输出同时持久化到文件，使用 `Tee-Object`：

```powershell
# 实时显示 + 保存到文件（注意：这需要在同一进程中执行，不适合 Start-Process）
& "D:\Processing\Processing.exe" cli --sketch="$sketchPath" --run --force 2>&1 |
    Tee-Object -FilePath "$env:TEMP\combined.log"
```

> ⚠️ `2>&1` 将 stderr 合并到 stdout，会丢失错误分离能力。推荐调试阶段用分离文件，排查完成后用合并流。

### 2.4 分离捕获的最佳实践

```powershell
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "$sketchPath\run_logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$outLog = "$logDir\run_${timestamp}_out.log"
$errLog = "$logDir\run_${timestamp}_err.log"

$proc = Start-Process "D:\Processing\Processing.exe" `
    -ArgumentList "cli", "--sketch=`"$sketchPath`"", "--output=`"$buildPath`"", "--run", "--force" `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -PassThru -NoNewWindow

Write-Host "[INFO] PID: $($proc.Id), stdout: $outLog, stderr: $errLog"

# 非阻塞方式：等待 N 秒后检查
Start-Sleep -Seconds 10

# 实时查看最新日志
Get-Content $outLog -Wait -Tail 10  # 类似 tail -f
```

---

## 3. 完整捕获脚本模板

### 3.1 调试模式脚本（分离日志 + 自动分析）

```powershell
<#
.SYNOPSIS
    Processing PDE 调试运行脚本 - 分离捕获 stdout/stderr
.DESCRIPTION
    编译并运行 Processing 项目，将 stdout 和 stderr 分离存储，
    支持自动检测关键错误模式。
#>
param(
    [string]$SketchPath = "E:\projects\kilo\p5engine\examples\TowerDefenseMin2",
    [string]$ProcessingExe = "D:\Processing\Processing.exe",
    [int]$WaitSeconds = 15,
    [switch]$KeepLogs
)

$ErrorActionPreference = 'Stop'

# ── 路径准备 ──
$buildPath = "$SketchPath\build"
$logDir = "$SketchPath\run_logs"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$outLog = "$logDir\${timestamp}_out.log"
$errLog = "$logDir\${timestamp}_err.log"

# ── 清理旧构建 ──
if (Test-Path $buildPath) {
    Remove-Item $buildPath -Recurse -Force
}

# ── 启动进程并分离捕获 ──
Write-Host "[START] Launching Processing CLI..." -ForegroundColor Cyan
Write-Host "  stdout -> $outLog"
Write-Host "  stderr -> $errLog"

$proc = Start-Process $ProcessingExe `
    -ArgumentList "cli", "--sketch=`"$SketchPath`"", "--output=`"$buildPath`"", "--run", "--force" `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -PassThru -NoNewWindow

Write-Host "[INFO] PID: $($proc.Id)"

# ── 等待运行 ──
Start-Sleep -Seconds $WaitSeconds

# ── 输出摘要 ──
Write-Host "`n[SUMMARY] stdout lines:" -ForegroundColor Green
$outLines = Get-Content $outLog -ErrorAction SilentlyContinue
$outLines | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "`n[SUMMARY] stderr lines:" -ForegroundColor Yellow
$errLines = Get-Content $errLog -ErrorAction SilentlyContinue
$errLines | Measure-Object | Select-Object -ExpandProperty Count

# ── 自动错误检测 ──
$patterns = @(
    @{ Pattern = "Exception|Error|FATAL";   Color = "Red";    Label = "ERRORS" },
    @{ Pattern = "WARN|warning";            Color = "Yellow"; Label = "WARNINGS" },
    @{ Pattern = "hud_minimap|rootHit";     Color = "Cyan";   Label = "MINIMAP DEBUG" },
    @{ Pattern = "jumpCameraTo";            Color = "Green";  Label = "CAMERA JUMPS" }
)

foreach ($p in $patterns) {
    $matches = $outLines | Select-String -Pattern $p.Pattern
    if ($matches) {
        Write-Host "`n[$($p.Label)]" -ForegroundColor $p.Color
        $matches | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor $p.Color }
    }
}

# ── 清理 ──
if (-not $KeepLogs) {
    Write-Host "`n[CLEANUP] Removing log files (use -KeepLogs to preserve)" -ForegroundColor Gray
    Remove-Item $outLog, $errLog -ErrorAction SilentlyContinue
}

Write-Host "`n[DONE]" -ForegroundColor Cyan
```

### 3.2 使用示例

```powershell
# 基础运行（15秒自动收集）
.\Run-ProcessingDebug.ps1

# 延长等待时间到 30 秒
.\Run-ProcessingDebug.ps1 -WaitSeconds 30

# 保留日志文件
.\Run-ProcessingDebug.ps1 -KeepLogs
```

---

## 4. p5engine 双日志系统

### 4.1 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                     p5engine 日志架构                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   PDE 层 (Processing)          Java 层 (p5engine)           │
│   ┌─────────────┐              ┌─────────────────────┐     │
│   │ println()   │              │ Logger.info()       │     │
│   │ print()     │              │ Logger.debug()      │     │
│   └──────┬──────┘              │ Logger.warn()       │     │
│          │                      │ Logger.error()      │     │
│          │                      └──────────┬──────────┘     │
│          │                                 │                │
│          ▼                                 ▼                │
│   ┌─────────────┐              ┌─────────────────────┐     │
│   │  stdout     │◄─────────────│  System.out         │     │
│   │  (控制台)    │              │  (INFO/WARN/DEBUG)  │     │
│   └──────┬──────┘              └──────────┬──────────┘     │
│          │                                 │                │
│          │                      ┌──────────┴──────────┐     │
│          │                      ▼                     ▼     │
│          │              ┌──────────┐          ┌──────────┐  │
│          │              │ 文件日志  │          │ 控制台   │  │
│          │              │ logs/    │          │ (已包含)  │  │
│          │              └──────────┘          └──────────┘  │
│          │                                                   │
│          └──────────────────────────────────────────────►    │
│                          PowerShell 捕获                      │
│                          $outLog 文件                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Logger API 详解

**位置**：`src/main/java/shenyf/p5engine/util/Logger.java`

#### 日志级别

| 级别 | 优先级 | 默认显示 | 用途 |
|------|--------|----------|------|
| DEBUG | 0 | ❌ 需启用 | 详细调试信息（每帧数据、坐标计算） |
| INFO  | 1 | ✅ | 关键流程节点（初始化、状态切换） |
| WARN  | 2 | ✅ | 警告（资源缺失、降级处理） |
| ERROR | 3 | ✅ | 错误（异常、致命问题） |

#### 基础用法

```java
// 简单消息（无标签）
Logger.info("Game started");
Logger.warn("Asset not found: " + path);
Logger.error("Failed to load level", exception);

// 带标签的消息（推荐，便于过滤）
Logger.info("Camera", "zoomAt start amount=" + amount);
Logger.debug("Minimap", "hitTest: x=" + x + ", y=" + y);
```

#### 配置方法

```java
// 在 PDE setup() 中配置
void setup() {
    engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
    
    // 启用 DEBUG 级别（默认 INFO）
    shenyf.p5engine.util.Logger.setLevel(shenyf.p5engine.util.Logger.Level.DEBUG);
    
    // 启用 debug() 方法（默认关闭，即使级别设为 DEBUG）
    shenyf.p5engine.util.Logger.setDebugEnabled(true);
    
    // 只保留特定标签的 DEBUG 信息（可选）
    shenyf.p5engine.util.Logger.setTagFilter("Camera", "Minimap", "UIMgr");
}
```

#### 文件日志配置

```java
// 启用文件输出（默认关闭，即使 P5Config.logToFile(true) 也只是引擎层面）
Logger.setFileLogging(true);

// 自定义日志目录（默认 logs/）
Logger.setLogDirectory("my_logs");

// 设置单个文件大小上限（MB）
Logger.setMaxFileSizeMB(10);

// 设置保留文件数量
Logger.setMaxFileCount(14);

// 获取当前日志文件路径
String path = Logger.getCurrentLogFilePath();
```

### 4.3 两种日志的对比

| 特性 | PDE `println()` | `Logger.info/debug()` |
|------|----------------|----------------------|
| **来源** | Processing PDE | p5engine Java |
| **时间戳** | ❌ 无 | ✅ 有（毫秒精度） |
| **日志级别** | ❌ 无 | ✅ DEBUG/INFO/WARN/ERROR |
| **标签过滤** | ❌ 无 | ✅ `setTagFilter()` |
| **文件持久化** | ❌ 仅控制台 | ✅ `setFileLogging(true)` |
| **自动轮转** | ❌ 无 | ✅ 按大小/数量轮转 |
| **性能影响** | 低 | 极低（异步缓冲） |
| **适用场景** | 快速调试、临时输出 | 生产环境、结构化分析 |

---

## 5. 最佳实践与技巧

### 5.1 调试工作流

```
阶段 1: 快速定位（PDE println）
    └─ 在可疑位置插入 println，运行 GUI 模式查看

阶段 2: 深度分析（分离捕获）
    └─ 切换到 CLI 模式，分离 stdout/stderr
    └─ 启用 Logger.setDebugEnabled(true)
    └─ 使用 PowerShell 脚本自动收集和分析

阶段 3: 生产清理
    └─ 移除所有 println
    └─ 将关键日志改为 Logger.info()
    └─ 保留 Logger.debug() 供后续排查
```

### 5.2 推荐的日志策略

**PDE 层（.pde 文件）**：
```java
// ❌ 避免：临时调试后忘记删除
println("x=" + x);

// ✅ 推荐：使用 Logger（如果 PDE 能访问）
// 或通过引擎事件传递

// ✅ 也接受：带明确标记的临时调试，完成后删除
// println("[TEMP DEBUG] minimap bounds=" + bounds);
```

**Java 层（引擎源码）**：
```java
// ✅ 关键流程节点
Logger.info("UIMgr", "mouseEvent act=" + act + " hit=" + hitId);

// ✅ 详细调试（受 debugEnabled 控制，不会污染生产环境）
Logger.debug("Camera", "zoomAt: pos=" + pos + " zoom=" + zoom);

// ✅ 性能敏感代码：使用条件编译或懒计算
if (Logger.isDebugEnabled()) {
    Logger.debug("Render", "draw calls=" + callCount + ", verts=" + vertCount);
}
```

### 5.3 快速分析命令

```powershell
# 查看最近 N 条日志
Get-Content $outLog -Tail 20

# 实时跟踪（类似 tail -f）
Get-Content $outLog -Wait -Tail 10

# 按标签过滤
Select-String -Path $outLog -Pattern "\[UIMgr\]"

# 统计各组件日志数量
(Select-String -Path $outLog -Pattern "\[(\w+)\]").Matches |
    Group-Object { $_.Groups[1].Value } |
    Sort-Object Count -Descending

# 查找异常堆栈
Select-String -Path $errLog -Pattern "Exception|at shenyf|Caused by"

# 时间范围过滤（假设时间戳格式统一）
Select-String -Path $outLog -Pattern "2026-04-25 00:0[6-7]:" |
    Select-String -Pattern "MOUSE_PRESSED"
```

### 5.4 与 IDE 调试的配合

| 场景 | 推荐方式 |
|------|----------|
| 快速验证变量值 | `println()` + GUI 模式 |
| 分析鼠标/输入事件流 | CLI 分离捕获 + `Logger.debug()` |
| 排查偶发崩溃 | CLI 分离捕获 + 重点检查 `$errLog` |
| 性能分析 | CLI 捕获 + 时间戳差值计算 |
| 长时间稳定性测试 | `Logger.setFileLogging(true)` + 后台运行 |

---

## 6. 常见问题排查

### Q1: 为什么 `logs/` 目录下没有 `println()` 的内容？

**A**: `logs/` 只收集通过 `Logger.xxx()` 写入的日志。`println()` 输出到 stdout，需要使用 PowerShell 的 `-RedirectStandardOutput` 捕获。

### Q2: `Logger.debug()` 设置了级别为 DEBUG 还是不输出？

**A**: `Logger.debug()` 有两层控制：
1. 全局级别：`setLevel(Level.DEBUG)` — 允许 DEBUG 级别通过
2. debug 开关：`setDebugEnabled(true)` — 实际启用 debug 方法

两者都必须设置。

### Q3: stderr 文件为空，但程序崩溃了？

**A**: Processing CLI 的崩溃可能发生在 JVM 层面（如 JOGL native crash），这类错误可能不经过 stderr。检查：
- Windows 事件查看器 (`eventvwr.msc`)
- Processing 的 `hs_err_pid*.log`（JVM crash dump）
- 使用 `-Xmx` 调整内存限制

### Q4: 如何同时实时查看和保存日志？

**A**: 使用 `Tee-Object`，但会合并 stdout/stderr：
```powershell
& $processingExe cli --sketch=$sketchPath --run --force 2>&1 |
    Tee-Object -FilePath "$env:TEMP\combined.log"
```

如需分离，开两个 PowerShell 窗口分别执行：
```powershell
# 窗口 1: 监控 stdout
Get-Content "$env:TEMP\stdout.log" -Wait

# 窗口 2: 启动程序
Start-Process $processingExe ... -RedirectStandardOutput "$env:TEMP\stdout.log"
```

### Q5: 日志文件太大怎么办？

**A**: 
1. 使用 `Logger.setMaxFileSizeMB()` 限制单文件大小
2. 使用 `Logger.setMaxFileCount()` 限制保留数量
3. 定期清理：
```powershell
Get-ChildItem "logs" -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item
```

---

## 附录：参考命令速查

```powershell
# 一键运行并捕获（复制即用）
$sketch = "E:\projects\kilo\p5engine\examples\TowerDefenseMin2"
$proc = Start-Process "D:\Processing\Processing.exe" `
    -ArgumentList "cli","--sketch=`"$sketch`"","--run","--force" `
    -RedirectStandardOutput "$env:TEMP\out.log" `
    -RedirectStandardError "$env:TEMP\err.log" `
    -PassThru -NoNewWindow
Start-Sleep 10
Get-Content "$env:TEMP\out.log" -Tail 30
```

---

*文档版本: 1.0*  
*创建时间: 2026-04-25*  
*适用平台: Windows (PowerShell 5.1+)*  
*Processing 版本: 4.5.2*  
*p5engine 版本: 0.1.0-M1*


$sketchPath = "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" $buildPath = "$sketchPath\build" $processingExe = "D:\Processing\Processing.exe" if (Test-Path $buildPath) { Remove-Item $buildPath -Recurse -Force } $errLog = "$env:TEMP\title2_err.log" $outLog = "$env:TEMP\title2_out.log" $proc = Start-Process $processingExe -ArgumentList "cli","--sketch=`"$sketchPath`"","--output=`"$buildPath`"","--run","--force" -RedirectStandardError $errLog -RedirectStandardOutput $outLog -PassThru -NoNewWindow Write-Host "Started PID: $($proc.Id)" Write-Host "请开始游戏并输掉比赛（让敌人到达基地扣光护盾），然后点击'主菜单'按钮" Write-Host "等待 60 秒收集日志..." Start-Sleep -Seconds 60 Write-Host "`n=== stderr ===" Get-Content $errLog -ErrorAction SilentlyContinue | Select-Object -Last 5 Write-Host "`n=== stdout (showLose/buildMainMenu/titleProgress 相关) ===" Get-Content $outLog -ErrorAction SilentlyContinue | Select-String -Pattern "showLose|buildMainMenu|titleProgress|tween count|btnMenu clicked" | Select-Object -Last 40
