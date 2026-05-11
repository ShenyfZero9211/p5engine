# p5engine 打包发布系统技术报告

> **文档版本**: 1.0  
> **更新日期**: 2026-05-11  
> **适用版本**: p5engine 0.1.0-M1, Processing 4.5.2, JDK 17  
> **适用平台**: Windows (PowerShell 5.1+)

---

## 目录

1. [系统概述](#1-系统概述)
2. [架构与流程](#2-架构与流程)
3. [Processing CLI 导出机制](#3-processing-cli-导出机制)
4. [JLink JRE 精简](#4-jlink-jre-精简)
5. [PPAK 资源打包系统](#5-ppak-资源打包系统)
6. [build-release.ps1 使用指南](#6-build-releaseps1-使用指南)
7. [引擎端 PPAK 集成](#7-引擎端-ppak-集成)
8. [体积对比与性能](#8-体积对比与性能)
9. [常见问题与排错](#9-常见问题与排错)
10. [附录：文件清单](#10-附录文件清单)

---

## 1. 系统概述

p5engine 打包发布系统是一套面向 Processing 4 游戏的 Windows 平台独立应用导出方案，整合了三套核心技术：

| 技术层 | 职责 | 输出产物 |
|--------|------|----------|
| **Processing CLI** | 将 PDE 草图编译、打包为可独立运行的 Windows EXE | `.exe` + `lib/` + `data/` + `source/` |
| **JLink** | 从完整 JDK 中提取应用实际需要的模块，生成精简 JRE | `java/` (~42 MB) |
| **PPAK** | 将分散的资源文件（data/music/sounds/textures）打包为单文件归档 | `data/data.ppak` |

最终产物为一个完整的 Windows 文件夹，无需系统预装 Java，双击 `.exe` 即可运行。

---

## 2. 架构与流程

### 2.1 整体流程图

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   PDE 源代码     │     │   资源文件夹     │     │   JDK 17        │
│  (.pde + code/)  │     │ (data/music/...) │     │  (完整 ~300MB)  │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     scripts/build-release.ps1                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────┐ │
│  │Build Engine │  │Pack PPAK    │  │Export EXE   │  │JLink   │ │
│  │(compile-jar)│  │(ppak_pack.py)│  │(Processing) │  │(jlink) │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   output/        │
                    │   ├── .exe       │
                    │   ├── java/      │  <-- 精简 JRE
                    │   ├── lib/       │  <-- jar 依赖
                    │   ├── data/      │  <-- data.ppak + 配置文件
                    │   └── source/    │  <-- 源代码备份
                    └─────────────────┘
```

### 2.2 流程步骤详解

| 步骤 | 命令/工具 | 输入 | 输出 | 说明 |
|------|-----------|------|------|------|
| ① 编译引擎 | `compile-jar.ps1` | `src/main/java/` | `library/p5engine.jar` | 编译为 fat jar，内含 TinySound |
| ② 复制 jar | `Copy-Item` | `library/p5engine.jar` | `sketch/code/` | 引擎 jar 必须放入 sketch 的 code/ 目录 |
| ③ 打包 PPAK | `ppak_pack.py` | `data/` `music/` `sounds/` `textures/` | `data/data.ppak` | 多目录合并为单文件，保留路径前缀 |
| ④ 导出 EXE | `processing cli --export` | sketch 文件夹 | `output/` 基础结构 | Launch4j 生成包装器 EXE |
| ⑤ 复制资源 | `Copy-Item` | sketch 根目录资源文件夹 | `output/` | 仅非 PPAK 模式执行 |
| ⑥ 分析依赖 | `jdeps` | `lib/*.jar` | 模块列表 | 自动分析 jar 依赖的 JDK 模块 |
| ⑦ 精简 JRE | `jlink` | JDK `jmods/` | `output/java/` | 仅保留必要模块 (~84% 压缩) |

---

## 3. Processing CLI 导出机制

### 3.1 CLI 命令格式

```powershell
processing.exe cli `
  --sketch="<sketch_folder>" `
  --output="<output_folder>" `
  --export `
  --variant=windows-amd64 `
  --force
```

### 3.2 内部机制（源码分析）

Processing 4 的导出流程位于 `processing.mode.java` 包中：

```
Commander (CLI 入口)
  └── JavaBuild.build()        ← 编译 PDE → Java → .class
      └── exportApplication()  ← 生成平台特定产物
```

**Windows 导出关键行为**（`JavaBuild.java:779-1025`）：

1. **复制 JRE**：若 `embedJava=true`，将 `Platform.getJavaHome()` 完整复制到 `output/java/` (~266 MB)
2. **创建主 jar**：将编译后的 `.class` + `data/` 文件夹内容打包为 `output/lib/<SketchName>.jar`
3. **复制依赖 jar**：将 `code/` 中的 jar 和库依赖复制到 `output/lib/`
4. **生成 EXE**：通过 Launch4j（ant 任务）生成包装器 EXE
   - `headerType = gui`（无控制台窗口）
   - `dontWrapJar = true`（不将 jar 包进 EXE）
   - classpath = `lib/*.jar`
   - JRE 路径 = `java/;%PATH%`
5. **复制 data 文件夹**：`sketch/data/` → `output/data/`（**注意**：Processing 只自动复制 `data/`）

### 3.3 关键限制

- Processing CLI **仅自动复制 `data/` 目录**
- sketch 根目录下的 `music/`、`sounds/`、`textures/` 等**不会**被自动复制
- 必须通过外部脚本补充复制，或打包进 PPAK

---

## 4. JLink JRE 精简

### 4.1 原理

JDK 9+ 引入模块系统（JPMS），`jlink` 工具可以从模块化 JDK 中仅提取应用需要的模块，生成自定义运行时镜像（custom runtime image）。

### 4.2 依赖分析

```powershell
$classpath = (Get-ChildItem lib -Filter *.jar | Select-Object FullName) -join ';'
jdeps.exe `
  --print-module-deps `
  --ignore-missing-deps `
  --multi-release 17 `
  -cp $classpath `
  lib\Main.jar
```

TowerDefenseMin2 的 jdeps 输出：
```
java.base,java.desktop,java.management,java.sql
```

### 4.3 推荐模块集

jdeps 分析结果偏保守（JOGL 的 native 集成需要更多模块），实际使用扩展模块集：

```
java.base,java.desktop,java.xml,java.sql,java.naming,java.net.http,java.management,java.logging
```

### 4.4 JLink 命令

```powershell
jlink.exe `
  --module-path "$jdk\jmods" `
  --add-modules "java.base,java.desktop,java.xml,java.sql,java.naming,java.net.http,java.management,java.logging" `
  --output "$output\java-custom" `
  --compress=2 `           # ZIP 压缩（最佳）
  --no-header-files `      # 移除 C 头文件
  --no-man-pages `         # 移除手册页
  --strip-debug            # 移除调试符号
```

### 4.5 精简效果

| 项目 | 大小 | 说明 |
|------|------|------|
| 完整 JRE | ~266 MB | Processing 导出时嵌入的完整 JDK |
| JLink 精简 JRE | **~42.85 MB** | 仅保留 8 个核心模块 |
| **压缩率** | **~84%** | 体积减少 223 MB |

---

## 5. PPAK 资源打包系统

### 5.1 设计目标

- **减少文件数量**：将数百个分散的资源文件合并为 1 个文件，便于分发
- **保护资源**：资源不再以原始文件形式暴露
- **统一加载**：引擎层自动识别，游戏代码无需感知 PPAK 是否存在
- **多目录支持**：将 `data/`、`music/`、`sounds/`、`textures/` 统一打包

### 5.2 文件格式

PPAK 是一种自定义二进制包格式：

```
+----------- 4 bytes --------+----------- 2 bytes --------+
|         MAGIC (b'PPAK')    |       VERSION (1)          |
+---------------------------+---------------------------+
|          ENTRY COUNT (4)   |      RESERVED (4)          |
+---------------------------+---------------------------+
|                    INDEX SECTION                        |
|  [Offset:4] [Size:4] [NameLen:2] [Name:NameLen]  ...    |
+---------------------------+---------------------------+
|                    DATA SECTION                         |
|                   (raw file data)                       |
+-------------------------------------------------------+
```

- **路径前缀规则**：每个源目录以其**文件夹名**作为包内路径前缀
  - `data/config/levels.yaml` → 包内路径 `data/config/levels.yaml`
  - `music/TopGun.ogg` → 包内路径 `music/TopGun.ogg`
  - `textures/ruins_0.png` → 包内路径 `textures/ruins_0.png`

### 5.3 Python 工具用法

```bash
# 多目录打包（推荐）
python tools/ppak/ppak_pack.py data/ music/ sounds/ textures/ -o data/data.ppak

# 单目录打包（兼容旧版）
python tools/ppak/ppak_pack.py data/ data.ppak

# 查看包内容
python tools/ppak/ppak_ls.py data/data.ppak --grep "music/"

# 解包
python tools/ppak/ppak_unpack.py data/data.ppak extracted/
```

### 5.4 运行时加载流程

```
游戏请求加载 "music/TopGun.ogg"
         │
         ▼
┌─────────────────┐
│  PPak.isReady()? │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
  是(true)   否(false)
    │         │
    ▼         ▼
┌────────┐  ┌─────────────────┐
│ 查 PPAK │  │ toSketchDataPath()│
│ 索引   │  │ 解析为文件系统路径  │
└───┬────┘  └────────┬────────┘
    │                │
    ▼                ▼
┌────────┐      ┌────────────┐
│ 命中？  │      │ sketch/music/│
└───┬────┘      │ TopGun.ogg   │
    │           └────────────┘
┌───┴───┐
│ 是   否 │
▼       ▼
返回    回退文件系统
包内数据
```

---

## 6. build-release.ps1 使用指南

### 6.1 参数说明

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$SketchPath,           # PDE 草图文件夹路径（必填）
    [string]$OutputPath,           # 输出目录（默认 <SketchPath>\output）
    [switch]$BuildEngine,          # 是否先编译 p5engine.jar
    [switch]$UsePpak,              # 是否将资源打包为 PPAK
    [bool]$UseJlink = $true,       # 是否使用 JLink 精简 JRE（默认开启）
    [string]$JdkPath = "D:\java\jdk-17.0.10+7",
    [string]$ProcessingPath = "D:\Processing\Processing.exe",
    [switch]$Force                 # 强制覆盖输出目录
)
```

### 6.2 常用命令

```powershell
# 基础导出（JLink 精简，无 PPAK）
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 `
    -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" `
    -Force

# 完整导出（编译引擎 + PPAK 打包 + JLink 精简）
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 `
    -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" `
    -BuildEngine -UsePpak -Force

# 仅导出，不精简 JRE（保留完整 JDK，兼容性最高）
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 `
    -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" `
    -UseJlink $false -Force
```

### 6.3 PPAK 开关说明

| 模式 | 命令 | 输出特征 | 适用场景 |
|------|------|----------|----------|
| **PPAK 模式** | `-UsePpak` | `data/data.ppak` 单文件，无 `music/` `sounds/` `textures/` 文件夹 | **推荐分发**，文件整洁 |
| **传统模式** | 不加 `-UsePpak` | `data/` + `music/` + `sounds/` + `textures/` 分散文件夹 | **开发调试**，便于热更新资源 |

运行时无需配置：引擎自动检测 `data/data.ppak` 是否存在，存在则启用 PPAK，不存在则回退文件系统。

---

## 7. 引擎端 PPAK 集成

### 7.1 自动初始化

`P5Engine.init()` 在引擎初始化时自动调用：

```java
PPak ppak = PPak.getInstance();
ppak.init(applet);
if (ppak.isReady()) {
    Logger.info("  PPak: loaded " + ppak.count() + " resources");
} else {
    Logger.info("  PPak: not found, using file system fallback");
}
```

**无需在 sketch 中手动调用 `PPak.init()`。**

### 7.2 资源加载 API 的 PPAK 透明性

所有引擎层资源加载 API 已实现"PPAK 优先、文件系统回退"：

| API | PPAK 路径示例 | 回退路径 |
|-----|--------------|----------|
| `ImageManager.load("textures/bg.png")` | PPAK: `textures/bg.png` | `sketch/textures/bg.png` |
| `AudioManager.loadMusic("music/bgm.ogg")` | PPAK: `music/bgm.ogg` | `sketch/music/bgm.ogg` |
| `AudioManager.playOneShot("sfx/hit.wav")` | PPAK: `sfx/hit.wav` | `sketch/sfx/hit.wav` |
| `app.createInput("config/game.yaml")` | ❌ 不经过 PPAK | `sketch/data/config/game.yaml` |

**注意**：`createInput()` 是 Processing 标准 API，不经过 PPAK。因此 YAML/JSON 配置文件通常保留在 `data/` 文件夹中（不打包或也打包但主要依赖文件系统）。

### 7.3 目录扫描适配

对于需要扫描目录的场景（如动态加载所有 `music/Track*.ogg`），游戏代码已适配：

```java
// TdSound.initTracks() — 优先从 PPAK 列出文件
PPak ppak = PPak.getInstance();
if (ppak.isReady()) {
    String[] all = ppak.list();
    // 过滤 music/ 前缀的 Track*.ogg
} else {
    // 回退：文件系统扫描 sketchPath("music")
}
```

---

## 8. 体积对比与性能

### 8.1 TowerDefenseMin2 导出体积对比

| 方案 | 总大小 | 组成 | 适用场景 |
|------|--------|------|----------|
| **传统 + JLink** | **87.44 MB** | EXE 70KB + JRE 42.85MB + 资源 29MB | 开发调试 |
| **PPAK + JLink** | **117.05 MB** | EXE 70KB + JRE 42.85MB + PPAK 58.95MB + data 129KB | **推荐分发** |
| 完整 JRE（无 JLink） | ~309 MB | EXE 70KB + 完整 JRE 266MB + 资源 29MB | 兼容性优先 |

**PPAK 模式体积增大的原因**：
- PPAK 当前未启用压缩（`--compress` 可选）
- OGG/PNG 等格式本身已是压缩格式，二次压缩收益有限
- PPAK 的价值在于**文件数量减少**和**资源保护**，而非体积压缩

### 8.2 启动性能

| 指标 | 传统模式 | PPAK 模式 | 说明 |
|------|----------|-----------|------|
| 首次启动 | ~3-4 秒 | ~3-4 秒 | PPAK 索引在内存中，加载速度相当 |
| 资源加载 | 文件系统 I/O | 内存映射/解压 | 小文件场景 PPAK 略快（减少 open 调用） |
| 音频播放 | 直接文件流 | 临时文件流 | PPAK 音频先解压到临时文件再播放 |

---

## 9. 常见问题与排错

### Q1: 导出的 EXE 启动闪退，日志显示 `NullPointerException: sketchPath()`

**原因**：`SketchConfig.getDefaultSketchName()` 在 `settings()` 生命周期中 `applet` 为 null。

**解决**：已修复。确保使用最新的 `p5engine.jar`（`compile-jar.ps1` 编译后复制到 `code/`）。

### Q2: 音乐/音效无法播放，日志显示文件未找到

**原因**：
1. Processing CLI 导出时未复制 `music/`、`sounds/` 文件夹
2. 或 PPAK 中缺少对应路径

**排查**：
```powershell
# 检查 output/ 中是否有 music/ 文件夹（非 PPAK 模式）
ls output/music/

# 或检查 PPAK 内容（PPAK 模式）
python tools/ppak/ppak_ls.py output/data/data.ppak --grep "music/"
```

### Q3: PPAK 打包后体积反而变大了

**原因**：PPAK 默认不压缩，而 OGG/PNG 已是压缩格式。

**建议**：PPAK 的主要价值是减少文件数量和保护资源。如需进一步压缩，可尝试 `--compress` 参数：
```powershell
python tools/ppak/ppak_pack.py data/ music/ -o data.ppak --compress
```

### Q4: 如何在开发时快速切换 PPAK / 非 PPAK 模式？

**方法**：删除或重命名 `data/data.ppak`，引擎会自动回退到文件系统。
```powershell
# 临时禁用 PPAK（回退文件系统）
Rename-Item data/data.ppak data/data.ppak.bak

# 恢复 PPAK
Rename-Item data/data.ppak.bak data/data.ppak
```

### Q5: JLink 报错 `Error: Module xxx not found`

**原因**：jdeps 分析漏掉了某些模块。

**解决**：在 `build-release.ps1` 的 `$ModuleSet` 变量中追加缺失模块，重新运行。

### Q6: Launch4j 生成 EXE 失败，`library.properties version is not a number`

**原因**：`library.properties` 的 `version` 字段必须为正整数。

**解决**：确认 `library.properties` 内容为：
```properties
version=1
prettyVersion=0.1.0-M1
```

---

## 10. 附录：文件清单

### 10.1 打包系统文件

| 文件 | 说明 | 修改权限 |
|------|------|----------|
| `scripts/build-release.ps1` | 统一打包脚本 | 按需修改参数 |
| `compile-jar.ps1` | 引擎编译脚本 | 通常无需修改 |
| `scripts/export_game.ps1` | PPAK-only 旧脚本 | 保留参考 |
| `build.ps1` | 旧版构建脚本 | 保留参考 |

### 10.2 PPAK 工具文件

| 文件 | 说明 |
|------|------|
| `tools/ppak/ppak_pack.py` | 打包工具（支持多目录） |
| `tools/ppak/ppak_lib.py` | PPAK 核心库 |
| `tools/ppak/ppak_ls.py` | 查看包内容 |
| `tools/ppak/ppak_unpack.py` | 解包工具 |
| `tools/ppak/ppak_cli.py` | CLI 集成工具 |

### 10.3 引擎源文件（PPAK 相关）

| 文件 | 说明 |
|------|------|
| `src/main/java/shenyf/p5engine/resource/ppak/PPak.java` | PPAK 主类（回退路径、初始化） |
| `src/main/java/shenyf/p5engine/resource/ppak/PPakDecoder.java` | 解码器 |
| `src/main/java/shenyf/p5engine/resource/ppak/PPakImage.java` | 图片加载 |
| `src/main/java/shenyf/p5engine/resource/ppak/PPakAudio.java` | 音频加载 |
| `src/main/java/shenyf/p5engine/resource/ppak/PPakFont.java` | 字体加载 |
| `src/main/java/shenyf/p5engine/core/P5Engine.java` | 引擎初始化（PPak 自动检测） |
| `src/main/java/shenyf/p5engine/rendering/ImageManager.java` | 图片管理（PPAK 优先） |
| `src/main/java/shenyf/p5engine/audio/AudioManager.java` | 音频管理（PPAK 优先） |

### 10.4 游戏适配文件

| 文件 | 说明 |
|------|------|
| `examples/TowerDefenseMin2/TdSound.pde` | 音乐/音效管理（PPAK 扫描 + 加载） |
| `examples/TowerDefenseMin2/TdAssets.pde` | 贴图加载（PPAK 扫描 + 加载） |

---

## 参考资源

- [Processing 4 CLI 文档](https://github.com/processing/processing4/wiki/Command-Line)
- [JLink 工具指南](https://docs.oracle.com/en/java/javase/17/docs/specs/man/jlink.html)
- [Jdeps 工具文档](https://docs.oracle.com/en/java/javase/17/docs/specs/man/jdeps.html)
- [PPAK 整合文档](PPAK_INTEGRATION.md)
- [Processing 导出与 JLink 指南](Processing_Export_JLink_Guide.md)
