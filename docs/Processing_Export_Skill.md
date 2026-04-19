# Processing PDE 项目导出 EXE — AI Agent 使用指南

## 适用场景

当用户要求以下操作时，使用本指南：
- 导出 Processing PDE 草图为独立可执行文件 (.exe)
- 精简导出的 JRE 体积（使用 JLink）
- 对 `examples\` 下的任意 PDE 项目进行构建

---

## 环境信息

| 组件 | 路径 |
|---|---|
| Processing IDE | `D:\Processing\Processing.exe` |
| JDK (含 jlink/jdeps) | `D:\java\jdk-17.0.10+7` |
| 构建脚本 | `E:\projects\kilo\p5engine\build.ps1` |
| 示例调用 | `E:\projects\kilo\p5engine\run_export_example.ps1` |

**平台**: Windows (PowerShell 5.1+)

---

## 快速使用

### 基本命令

```powershell
powershell -ExecutionPolicy Bypass -File "E:\projects\kilo\p5engine\build.ps1" -SketchPath "<PDE项目路径>" -OutputPath "<输出目录>" -Force
```

### 示例

**导出 ExampleExportDemo**:
```powershell
powershell -ExecutionPolicy Bypass -File "E:\projects\kilo\p5engine\build.ps1" -SketchPath "E:\projects\kilo\p5engine\examples\ExampleExportDemo" -OutputPath "E:\projects\kilo\p5engine\examples\ExampleExportDemo\output" -Force
```

**导出其他项目**:
```powershell
powershell -ExecutionPolicy Bypass -File "E:\projects\kilo\p5engine\build.ps1" -SketchPath "E:\projects\kilo\p5engine\examples\WindowPosTest" -OutputPath "E:\projects\kilo\p5engine\examples\WindowPosTest\output" -Force
```

---

## 脚本参数

| 参数 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `-SketchPath` | 是 | — | PDE 草图文件夹（包含 .pde 文件） |
| `-OutputPath` | 是 | — | 导出输出目录 |
| `-UseJlink` | 否 | `$true` | 是否使用 JLink 精简 JRE |
| `-JdkPath` | 否 | `D:\java\jdk-17.0.10+7` | JDK 路径 |
| `-ProcessingPath` | 否 | `D:\Processing\Processing.exe` | Processing 路径 |
| `-Force` | 否 | — | 强制覆盖输出目录（跳过确认） |

---

## 流程说明

脚本自动执行以下步骤：

1. **验证输入** — 检查 PDE 文件、Processing.exe、jdeps.exe 是否存在
2. **清理输出目录** — 如存在则删除重建（`--force` 模式）
3. **Processing CLI 导出** — 调用 `processing cli --export --variant=windows-amd64`
4. **jdeps 依赖分析** — 分析 lib/*.jar 的模块依赖
5. **JLink 精简** — 创建自定义 JRE（~42 MB）替换原完整 JRE（~266 MB）
6. **结果统计** — 输出 EXE 路径、大小、总包体积

---

## 输出产物

```
<OutputPath>/
├── *.exe                    # Launch4j 包装器 (~70 KB)
├── java/                    # 自定义精简 JRE (~42 MB)
│   └── bin/java.exe         # 可独立运行，无需系统 Java
├── lib/                     # 依赖 jar
└── source/                  # 源码备份
```

**典型体积**: ~51 MB（精简后），原始 ~309 MB

---

## 注意事项

### 1. Processing CLI 语法（Processing 4+）
- `Processing.exe` 是 IDE 启动器，**CLI 命令必须加 `cli` 子命令**
- 正确: `processing cli --sketch=... --output=... --export`
- 错误: `processing --sketch=... --export`（无 cli 会启动 IDE）

### 2. `--force` 参数位置
- Processing CLI 的 `--force` 必须放在 **`cli` 之后、所有参数之前**
- 正确: `processing cli --force --sketch=... --output=...`
- 错误: `processing cli --sketch=... --force --output=...`

### 3. PDE 项目的 library.properties 版本号
- Processing 要求 **`version` 为可解析的整数**（发布计数）；展示用 semver 放在 **`prettyVersion`**（字符串）。
- 仓库根目录 [`library.properties`](../../library.properties) 已采用 `version=1` 与 `prettyVersion=0.1.0-M1`；`compile-jar.ps1` 在覆盖 jar 时会同步复制到 Processing 库目录下的 `p5engine/library.properties`。

### 4. jdeps 模块依赖偏少
- jdeps 分析结果通常只有 4 个模块: `java.base,java.desktop,java.management,java.sql`
- **实际应使用 8 模块通用集**（`java.xml,java.sql,java.naming,java.net.http,java.management,java.logging` 等）
- 脚本已内置默认 8 模块集，jdeps 结果仅作参考

### 5. 禁用 JLink 模式
- 如不需要精简 JRE（使用完整嵌入 JRE）:
  ```powershell
  .\build.ps1 -SketchPath <path> -OutputPath <path> -UseJlink $false -Force
  ```
- 输出体积会变成 ~309 MB

### 6. PowerShell 5.1 兼容性
- 脚本针对 PowerShell 5.1 编写，**避免**使用以下语法:
  - 内联 `if` 表达式: `$var = if (...) { } else { }` ❌
  - `[ref]` 参数直接传递
- 如需扩展脚本，参考 `Processing_Export_JLink_Guide.md` 中的兼容性说明

### 7. EXE 验证
- 导出后可用 `Start-Process <exePath> -PassThru` 验证启动
- 检查输出的 `Id` 字段，有值即表示启动成功

---

## 故障排除

| 症状 | 可能原因 | 解决方案 |
|---|---|---|
| "no such option --sketch" | 缺少 `cli` 子命令 | 确认命令中有 `cli` |
| 输出目录仍存在 | `--force` 位置不对 | 放在 `cli` 之后 |
| EXE 启动闪退 | JLink 模块不足 | 使用 8 模块通用集 |
| jdeps 报缺失 JavaFX/SWT | JOGL 可选依赖 | 添加 `--ignore-missing-deps` |

---

## 参考文档

- 完整指南: `E:\projects\kilo\p5engine\Processing_Export_JLink_Guide.md`
- 构建脚本: `E:\projects\kilo\p5engine\build.ps1`
- Processing CLI: https://github.com/processing/processing4/wiki/Command-Line
