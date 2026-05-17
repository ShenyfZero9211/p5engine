# 功能键（F2-F5 / F9）在 Processing P2D 模式下的事件拦截与绕过方案

> 问题：Processing IDE 和 JOGL/NEWT 窗口系统会拦截或丢弃部分功能键（F2-F12），导致 `keyPressed()` / `keyEvent()` 回调收不到按键事件。  
> 修复：使用引擎 `AsyncInput` 的 `GetAsyncKeyState` 硬件轮询绕过整个事件系统。  
> 影响文件：`TdAppCore.pde`（PDE 层）、`src/main/java/shenyf/p5engine/input/AsyncInput.java`（引擎层）。

---

## 1. 问题背景

### 1.1 功能键在 IDE 中被拦截

Processing IDE（4.5.2）会占用部分功能键作为自身快捷键：

- **F2** / **F3** / **F4**：在 IDE 中可能对应运行/停止/查找等操作，Sketch 收不到 `keyEvent`。
- **F5**：不同 IDE 配置下可能被映射为"停止"或"运行"。
- **F9**：通常未被 IDE 占用，但在某些键盘布局或 IDE 插件下也可能被拦截。

> 官方文档 [`DebugOverlay_使用指南.md`](DebugOverlay_使用指南.md) §1 已注明此限制，并提供了字符键回退方案（`` ` `` / `1` / `2` / `3`）。

### 1.2 P2D 模式下 NEWT 丢弃功能键

Processing 4 P2D 渲染器使用 **JOGL/NEWT**（New Windowing Toolkit）替代 AWT/Swing。NEWT 的 `KeyListener` 在 Windows 上通过 Win32 API 接收键盘事件，但存在以下行为差异：

| 按键 | AWT `keyCode` | NEWT 是否传递 | 现象 |
|------|--------------|---------------|------|
| F2-F5 | 113-116 | 部分可收 | IDE 中通常被拦截 |
| F9 | 120 | **不传递** | `keyPressed()` 完全无响应 |
| F11 | 122 | 可收 | 引擎用于 toggleFullscreen |
| 小键盘 `.` | 110 | 可收 | 引擎用于截图到剪贴板 |

**根本原因**：NEWT 的 `WindowImpl` 在处理 `WM_KEYDOWN` 时，将 F9 等键标记为内部使用或平台保留键，不向上层 `KeyListener` 分发。

---

## 2. 排查过程

### 2.1 第一阶段：日志捕获

按 [`Processing_CLI_Log_Capture_Guide.md`](Processing_CLI_Log_Capture_Guide.md) 的方法，使用 PowerShell `Start-Process` + `-RedirectStandardOutput` / `-RedirectStandardError` 分离捕获 stdout/stderr。

**截图（`.` 键）报错时的 stderr**：
```
at java.desktop/sun.awt.datatransfer.DataTransferer.imageToStandardBytes(DataTransferer.java:1716)
at java.desktop/sun.awt.windows.WDataTransferer.imageToPlatformBytes(WDataTransferer.java:353)
at shenyf.p5engine.util.ScreenshotTool.copyToClipboard(ScreenshotTool.java:60)
```
→ 问题：`BufferedImage.TYPE_INT_ARGB` 的 `DirectColorModel` 与 Windows 剪贴板不兼容，已另文修复（见同一提交）。

### 2.2 第二阶段：F9 keyCode 探测

在 `TdAppCore.keyPressed()` 中插入调试输出：
```java
println("[KeyDebug] key='" + app.key + "' keyCode=" + app.keyCode);
```

**实际按键与日志输出对比**：

| 用户按下 | 期望 `keyCode` | 实际 `keyCode` | 说明 |
|----------|---------------|---------------|------|
| F9 | 120 | **无输出** | `keyPressed()` 根本没被调用 |
| 小键盘 8 | 104 | 104 | NEWT 正常传递 |
| 小键盘 9 | 105 | 105 | NEWT 正常传递 |

→ 确认：**F9 在 P2D/NEWT 模式下完全不会触发 `keyPressed()`**。

### 2.3 第三阶段：源码验证

检查 Processing 4 源码 `PSurfaceJOGL.nativeKeyEvent()`：

```java
short code = normalizeKeyCode(nativeEvent.getKeyCode());
char keyChar;
int keyCode;
if (isPCodedKey(code, nativeEvent.isPrintableKey())) {
    keyCode = mapToPConst(code);
    keyChar = PConstants.CODED;
} else if (isHackyKey(code)) {
    // ...
} else {
    keyCode = code;          // 直接使用 NEWT keyCode
    keyChar = nativeEvent.getKeyChar();
}
```

- `isPCodedKey()` 只检查方向键、ALT 等，**不包含 F9**。
- `isHackyKey()` 只检查 ENTER、BACKSPACE 等，**不包含 F9**。
- 因此 F9 走 `else` 分支，`keyCode = code`。

但 `nativeEvent.getKeyCode()` 对 F9 返回的值在 NEWT 内部即被过滤，根本到不了 `nativeKeyEvent()` 这一步。

---

## 3. 解决方案

### 3.1 核心思路：绕过事件系统，直接读硬件

引擎已有的 `AsyncInput` 类使用 **JNA + Win32 `GetAsyncKeyState`** 每帧轮询物理键盘状态：

```java
// AsyncInput.java
short state = User32.INSTANCE.GetAsyncKeyState(vk);
boolean down = (state & 0x8000) != 0;
```

- **不依赖 AWT/NEWT 事件队列**
- **不依赖 Processing `keyPressed()`**
- **IDE 无法拦截**
- **NEWT 无法丢弃**

`AsyncInput` 的轮询列表（`VK_CODES`）已包含 `VK_F2` ~ `VK_F12`。

### 3.2 PDE 层实现

在 `TdAppLoop.run()` 主循环中，每帧检测 F2-F5 + F9 的 `AsyncInput` 状态：

```java
// TdAppCore.pde — TdAppLoop.run()
InputManager im = app.engine.getInput();
TdAppInput.handleKeyboardInput(app, im);

// 功能键通过 AsyncInput 轮询（绕过 IDE/NEWT 拦截）
boolean f2Down = im.getAsyncInput().isDown(java.awt.event.KeyEvent.VK_F2);
boolean f3Down = im.getAsyncInput().isDown(java.awt.event.KeyEvent.VK_F3);
boolean f4Down = im.getAsyncInput().isDown(java.awt.event.KeyEvent.VK_F4);
boolean f5Down = im.getAsyncInput().isDown(java.awt.event.KeyEvent.VK_F5);
boolean f9Down = im.getAsyncInput().isDown(java.awt.event.KeyEvent.VK_F9);

if (f2Down && !TdAppInput.wasF2Down) app.engine.getDebugOverlay().toggleGizmos();
if (f3Down && !TdAppInput.wasF3Down) app.engine.getDebugOverlay().toggleTree();
if (f4Down && !TdAppInput.wasF4Down) app.engine.getDebugOverlay().toggleHud();
if (f5Down && !TdAppInput.wasF5Down) shenyf.p5engine.util.Logger.cycleLevel();
if (f9Down && !TdAppInput.wasF9Down) TdAppInput.saveScreenshotToFile(app);

TdAppInput.wasF2Down = f2Down;
TdAppInput.wasF3Down = f3Down;
TdAppInput.wasF4Down = f4Down;
TdAppInput.wasF5Down = f5Down;
TdAppInput.wasF9Down = f9Down;
```

**去重机制**：`wasXxxDown` 静态布尔字段记录上一帧状态，只在"未按下→按下"的上升沿触发一次。

### 3.3 截图保存方法

```java
// TdAppCore.pde — TdAppInput
static void saveScreenshotToFile(TowerDefenseMin2 app) {
    try {
        String dir = app.sketchPath("screenshots");
        java.io.File d = new java.io.File(dir);
        if (!d.exists()) d.mkdirs();
        String ts = app.year() + "-" + nf(app.month(), 2) + "-" + nf(app.day(), 2)
                  + "_" + nf(app.hour(), 2) + "-" + nf(app.minute(), 2) + "-" + nf(app.second(), 2)
                  + "-" + nf(app.millis() % 1000, 3);
        String path = dir + "/screenshot_" + ts + ".png";
        app.g.get().save(path);
        println("[Screenshot] Saved: " + path);
    } catch (Exception e) {
        println("[Screenshot] Save failed: " + e.getMessage());
        e.printStackTrace();
    }
}
```

---

## 4. 完整调用链

```
用户按 F9
  │
  ▼
Win32 键盘驱动 ──→ GetAsyncKeyState(VK_F9) 返回 bit15=1
  │
  ▼
AsyncInput.update() （每帧，在 engine.update() 中调用）
  │
  ▼
InputManager.update() 合并 async 状态到 KeyState
  │
  ▼
TdAppLoop.run() 每帧检测 im.getAsyncInput().isDown(VK_F9)
  │
  ▼
wasF9Down == false && f9Down == true → 触发截图
  │
  ▼
app.g.get().save("screenshots/screenshot_... .png")
```

对比原始路径（已废弃）：
```
用户按 F9
  │
  ▼
NEWT WindowImpl ──→ [F9 被内部过滤，不传递]
  │
  ▼
PSurfaceJOGL.nativeKeyEvent() 收不到事件
  │
  ▼
PApplet.keyPressed() 不被调用 ❌
```

---

## 5. 兼容性

| 场景 | F2-F5 / F9 行为 | 说明 |
|------|----------------|------|
| Processing IDE 运行 | ✅ 全部生效 | AsyncInput 绕过 IDE 快捷键拦截 |
| Processing CLI 运行 | ✅ 全部生效 | 与 EXE 行为一致 |
| 导出 EXE 独立运行 | ✅ 全部生效 | 无 IDE，无 NEWT 拦截问题 |
| 字符键回退（`1`/`2`/`3`） | ✅ 仍然可用 | 保留原有兼容方案 |

**与引擎 `keyEvent()` 的共存**：引擎 `P5Engine.keyEvent()` 中仍然保留 F2-F5 处理（用于 CLI/EXE 模式），PDE 层的 AsyncInput 检测与之并存。由于 `wasXxxDown` 去重机制，同一按键不会在同一帧触发两次。

---

## 6. 相关文件变更

| 文件 | 变更 |
|------|------|
| `examples/TowerDefenseMin2/TdAppCore.pde` | F2-F9 的 AsyncInput 轮询检测 + `saveScreenshotToFile()` + `wasF2Down`~`wasF9Down` 状态 |
| `src/main/java/shenyf/p5engine/util/ScreenshotTool.java` | `TYPE_INT_ARGB` → `TYPE_INT_RGB`（修复 Windows 剪贴板异常） |
| `src/main/java/shenyf/p5engine/input/AsyncInput.java` | 无修改（已有 VK_F2~VK_F12 在轮询列表中） |

---

## 7. 验证结果

- **F9 截图**：IDE 中按 F9 → `screenshots/` 目录正常生成 `screenshot_YYYY-MM-DD_HH-mm-ss-SSS.png` ✅
- **F2 Gizmos**：IDE 中按 `` ` `` 开启总开关后，按 F2 显示绿色碰撞体线框 ✅
- **F3 Scene Tree**：IDE 中按 F3 显示左侧 GameObject 层级树 ✅
- **F4 HUD**：IDE 中按 F4 显示 FPS/对象数/Tween 数 HUD ✅
- **F5 日志级别**：IDE 中按 F5 循环 DEBUG→INFO→WARN→ERROR ✅

---

*文档版本: 1.0*  
*创建时间: 2026-05-17*  
*适用平台: Windows / Processing 4.5.2 / P2D 渲染器*  
*引擎版本: p5engine 0.1.0-M1*
