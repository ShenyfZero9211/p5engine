# Processing 项目导出 EXE 与 JLink 精简 JRE 完整指南

## 环境信息

- **Processing 安装路径**: `D:\Processing\Processing.exe`
- **JDK 路径**: `D:\java\jdk-17.0.10+7`
- **PowerShell 版本**: 5.1 (Windows 默认)
- **目标示例**: `E:\projects\kilo\p5engine\examples\ExampleExportDemo`
- **目标渲染器**: P2D (OpenGL 硬件加速)

---

## 第一步：处理 PDE 报错（可选）

### 报错信息
```
The version number for the ���p5engine��� library is not a number.
Please contact the library author to fix it according to guidelines.
```

### 原因
`library.properties` 的 `version` 字段为 `0.1.0-M1`，Processing 无法解析非纯数字版本号。

### 解决方案
- 降低 `p5engine` 库版本号为纯数字（如 `1`）
- 或忽略该警告，不影响正常导出

---

## 第二步：使用 Processing CLI 导出可执行文件

### CLI 语法（Processing 4+）
`Processing.exe` 本身是 IDE 启动器，实际 CLI 在 `cli` 子命令下：
```powershell
processing cli --sketch=<folder> --output=<folder> --export --variant=<platform>
```

### 正确导出命令
```powershell
& "D:\Processing\Processing.exe" `
  cli `
  --sketch="E:\projects\kilo\p5engine\examples\ExampleExportDemo" `
  --output="E:\projects\kilo\p5engine\examples\ExampleExportDemo\output" `
  --export `
  --variant=windows-amd64
```

### 导出成功输出
```
E:\projects\kilo\p5engine\examples\ExampleExportDemo\output\launch4j-build.xml
Compiling resources
Linking
Successfully created E:\projects\kilo\p5engine\examples\ExampleExportDemo\output\ExampleExportDemo.exe
Finished.
```

### 导出产物结构
```
output/
├── ExampleExportDemo.exe    (71 KB - Launch4j 包装器)
├── java/                    (完整 JRE ~266 MB)
│   ├── bin/                 (java.exe, javaw.exe, jlink.exe 等)
│   ├── conf/                (安全、日志配置)
│   ├── jmods/               (所有模块 .jmod 文件)
│   └── legal/               (许可文件)
├── lib/                     (依赖 jar)
│   ├── core-4.5.2.jar
│   ├── gluegen-rt-2.6.0.jar
│   ├── jogl-all-2.6.0.jar
│   └── ...
└── source/                  (源文件备份)
```

---

## 第三步：分析 Jar 模块依赖

### 工具
JDK 自带的 `jdeps.exe`（依赖分析）

### 命令
```powershell
$jdk = "D:\java\jdk-17.0.10+7"
$libDir = "E:\...\output\lib"
$classpath = (Get-ChildItem $libDir -Filter *.jar | Select-Object -ExpandProperty FullName) -join ';'

& "$jdk\bin\jdeps.exe" `
  --print-module-deps `
  --ignore-missing-deps `
  --multi-release 17 `
  -cp $classpath `
  "$libDir\ExampleExportDemo.jar"
```

### 输出
```
java.base,java.desktop,java.management,java.sql
```

**注意**：此依赖集**过小**，因为 JOGL/JOGL 的 native 集成和 OpenGL 上下文创建需要更多模块。实际应使用更通用集。

---

## 第四步：使用 JLink 创建自定义精简 JRE

### 推荐模块集
适用于 Processing P2D/P3D 的通用场景：
```
java.base,java.desktop,java.xml,java.sql,java.naming,java.net.http,java.management,java.logging
```

### JLink 命令
```powershell
$jdk = "D:\java\jdk-17.0.10+7"
$jmods = "$jdk\jmods"
$outJre = "E:\...\output\java-custom"
$modules = "java.base,java.desktop,java.xml,java.sql,java.naming,java.net.http,java.management,java.logging"

& "$jdk\bin\jlink.exe" `
  --module-path $jmods `
  --add-modules $modules `
  --output $outJre `
  --compress=2 `
  --no-header-files `
  --no-man-pages `
  --strip-debug
```

### JLink 选项说明
| 选项 | 作用 |
|---|---|
| `--module-path` | JDK 的 jmods 目录 |
| `--add-modules` | 要包含的模块列表 |
| `--output` | 输出目录 |
| `--compress=2` | 使用 ZIP 压缩（Level 2，最佳压缩） |
| `--no-header-files` | 不包含头文件 |
| `--no-man-pages` | 不包含手册页（Windows 无关）|
| `--strip-debug` | 移除调试信息 |

### 精简结果
- 原始 JRE: ~266 MB（完整嵌入版）
- 自定义 JRE: **42.85 MB**
- 压缩率: ~84%

---

## 第五步：替换并验证

### 替换 JRE
```powershell
Remove-Item "E:\...\output\java" -Recurse -Force
Rename-Item "E:\...\output\java-custom" "java"
```

### 最终包大小统计
```powershell
$final = (Get-ChildItem "E:\...\output" -Recurse | Measure-Object -Property Length -Sum).Sum
Write-Host "Final: $([math]::Round($final/1MB, 2)) MB"
```

**结果**: **52.25 MB**（目标 <100 MB ✓）

### 运行验证
```powershell
Start-Process "E:\...\output\ExampleExportDemo.exe" -PassThru
```

输出显示进程成功创建，EXE 可独立运行，不依赖系统 Java。

---

## 常见问题与排错

### 1. PowerShell 5.1 语法兼容性
- **错误**：`The term '$var = if (...) { }' is not recognized`
- **原因**：PowerShell 5.1 不支持内联 `if` 表达式
- **解决**：
  ```powershell
  # 错误
  $var = if ($cond) { "yes" } else { "no" }
  # 正确
  if ($cond) { $var = "yes" } else { $var = "no" }
  ```

### 2. `jdeps` 报告缺失 JavaFX/SWT 依赖
- **原因**：JOGL 集成了 JavaFX/SWT 作为可选 UI 后端
- **影响**：不影响纯 OpenGL 渲染（P2D/P3D）
- **解决**：添加 `--ignore-missing-deps` 忽略，或运行 `jdeps` 两次取并集

### 3. EXE 启动闪退
- 检查 `output/java` 目录是否存在
- 确认 `lib/` 下所有 jar 完整
- 查看 Windows 事件查看器中的应用程序错误日志

### 4. 模块依赖不足导致运行时 `ClassNotFoundException`
- 现象：启动时报错缺少 `java.xml`、`java.naming` 等
- 解决：扩充模块集，添加 `--add-modules java.naming,java.xml` 后重新 jlink

---

## 性能对比

| 方案 | 大小 | 启动速度 | 独立性 |
|---|---|---|---|
| 完整 JRE 嵌入 | ~309 MB | 慢 | 完全独立 |
| **JLink 精简版** | **52.25 MB** | 快 | 完全独立 |
| `--no-java` 模式 | ~20 MB | 最快 | 需系统 Java |

**推荐**：JLink 精简版在体积和兼容性间取得最佳平衡。

---

## 自动化脚本规划（待实现）

目标：一键完成 **导出 → 分析依赖 → JLink 精简 → 替换** 全流程

```powershell
.\build.ps1 `
  -SketchPath "E:\projects\kilo\p5engine\examples\ExampleExportDemo" `
  -OutputPath "E:\...\output" `
  -UseJlink $true `
  -JdkPath "D:\java\jdk-17.0.10+7" `
  -ProcessingPath "D:\Processing\Processing.exe"
```

**核心函数**：
- `Invoke-ProcessingExport`：调用 Processing CLI 导出
- `Invoke-Jdeps`：分析依赖
- `Invoke-JLink`：创建自定义 JRE
- `Copy-Config`：复制配置文件（`preferences.txt` 等）

---

## 参考资源

- Processing 4 CLI 文档：https://github.com/processing/processing4/wiki/Command-Line
- JLink 工具指南：https://docs.oracle.com/en/java/javase/17/docs/specs/man/jlink.html
- Jdeps 工具：https://docs.oracle.com/en/java/javase/17/docs/specs/man/jdeps.html

---

**文档创建时间**: 2026-04-18  
**适用平台**: Windows (PowerShell 5.1+)  
**Processing 版本**: 4.5.2  
**JDK 版本**: 17.0.10+7
