文档 `Build_Release_System.md` 详细描述了 p5engine 项目的 Windows 独立应用打包发布流程。以下是核心内容摘要：

---

## 📋 文档核心要点

**打包系统整合了三套技术：**

| 技术 | 输出 | 作用 |
|------|------|------|
| Processing CLI | `.exe` + `lib/` + `source/` | 将 PDE 草图编译为独立 Windows 应用 |
| JLink | `java/` (~42 MB) | 从 JDK 17 提取必要模块，生成精简 JRE |
| PPAK | `data/data.ppak` | 将 `data/` `music/` `sounds/` `textures/` 打包为单文件 |

**最终产物**：双击 `.exe` 即可运行，**无需系统预装 Java**。

---

## ⚡ 常用构建命令

```powershell
# 基础导出（JLink 精简 JRE，资源不打包）
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 `
    -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" `
    -Force

# 完整导出（编译引擎 + PPAK 资源打包 + JLink 精简）
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 `
    -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" `
    -BuildEngine -UsePpak -Force

# 不精简 JRE（保留完整 JDK ~266MB，兼容性最高）
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 `
    -SketchPath "E:\projects\kilo\p5engine\examples\TowerDefenseMin2" `
    -UseJlink $false -Force
```

---

## ❓ 你需要我做什么？

1. **执行完整打包**（编译引擎 + PPAK + JLink + EXE 导出）
2. **仅执行基础导出**（不打包 PPAK，适合开发调试）
3. **只想要文档内容**（我已经读完了，不需要执行）

请告诉我你想执行哪个方案，我立即运行。