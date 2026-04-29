# Processing 运行时分辨率与全屏切换技术报告

> 针对 p5engine 基于 Processing 4.5.2 + P2D (JOGL/NEWT) 渲染器的运行时窗口控制方案

---

## 1. 背景与目标

Processing 原生设计将窗口模式决策放在 `settings()` 阶段：
- `size(w, h, P2D)` → 窗口模式
- `fullScreen(P2D)` → 独占全屏（exclusive fullscreen）

**原生限制**：运行时调用 `surface.setSize()` 或 `fullScreen()` 不受官方支持，且在 JOGL/NEWT 底层上极不稳定（Windows 平台存在 EDT 死锁、GLContext 损坏等已知问题）。

**我们的目标**：
- 在游戏设置界面提供**运行时分辨率切换**（Dropdown 下拉框选择）
- 在游戏设置界面提供**运行时全屏/窗口切换**（ON/OFF 按钮）
- 配置持久化到 `.ini` 文件，重启后自动恢复

---

## 2. 技术架构

### 2.1 分层渲染与分辨率适配

p5engine 采用**工业级分辨率适配方案**，将渲染分为两层：

| 层级 | 职责 | 缩放策略 |
|---|---|---|
| **世界层 (World)** | 游戏场景、地图、敌人、子弹等 | 无缩放，直接铺满屏幕物理像素 |
| **UI 层 (UI)** | HUD、菜单、按钮、弹窗等 | FIT 模式，保持 16:9 宽高比，黑边填充 |

**关键组件**：
- `DisplayManager` — 管理设计分辨率（1280×720）与实际窗口尺寸的映射，提供 `actualToDesign()` 坐标转换
- `WorldViewport` — 世界层直接渲染到屏幕，绕过 UI 缩放矩阵
- `UIManager` — UI 层在 `pushMatrix/scale/popMatrix` 包裹下以 FIT 模式居中绘制

### 2.2 窗口管理器 (WindowManager)

`WindowManager` 是 p5engine 的窗口控制核心，通过 **NEWT 反射 API** 直接操作 JOGL 的 `GLWindow`：

```java
// 获取 NEWT 原生窗口对象
Object nativeSurface = applet.getSurface().getNative(); // GLWindow
boolean isJOGL = nativeSurface.getClass().getName().contains("newt");
```

**核心 API**：
| 方法 | 说明 |
|---|---|
| `setWindowSize(w, h)` | NEWT `GLWindow.setSize()` 反射调用 |
| `toggleFullscreen()` | 切换窗口化 ↔ 无边框全屏 |
| `setDisplayMode(mode)` | 设置 WINDOWED / BORDERLESS_FULLSCREEN / EXCLUSIVE_FULLSCREEN |
| `listAvailableResolutions()` | 枚举显示器所有可用分辨率 |
| `getScreenSize()` | 获取主显示器物理尺寸 |
| `centerWindow()` | 将窗口居中到屏幕 |

**为什么不使用 `surface.setSize()`？**
- `surface.setSize()` 在 Windows P2D 上偶发 `Waited 5000ms` EDT 死锁（JOGL/NEWT 的已知 bug）
- NEWT 反射调用 `GLWindow.setSize()` 直接绕过 Processing 的 `PSurfaceJOGL` 封装，死锁概率更低

---

## 3. 分辨率切换实现

### 3.1 实现原理

分辨率切换的本质是：**调用 `WindowManager.setWindowSize(targetW, targetH)` 改变窗口尺寸**，然后同步显示系统和相机。

```java
// 伪代码流程
app.engine.getWindowManager().setWindowSize(targetW, targetH);
app.engine.getDisplayManager().onWindowResize(targetW, targetH);
app.camera.setViewportSize(targetW, targetH);
app.camera.setViewportOffset(0, 0);
```

**为什么需要手动同步？**
- NEWT `setSize()` 绕过 Processing 的 `requestSize()` 异步机制
- `DisplayManager` 不会自动感知尺寸变化，必须显式通知
- `Camera` 视口需要与实际窗口尺寸保持一致，否则渲染会出现黑边或错位

### 3.2 分辨率列表过滤

从 `WindowManager.listAvailableResolutions()` 获取所有可用分辨率后，需要**过滤掉大于物理屏幕的分辨率**（窗口模式下窗口不能超出屏幕）：

```java
int[] screenSize = WindowManager.getScreenSize();
int screenW = screenSize[0];
int screenH = screenSize[1];

for (ResolutionInfo info : allResolutions) {
    if (info.width <= screenW && info.height <= screenH) {
        filteredRes.add(info);
    }
}
```

### 3.3 Dropdown 集成示例

```java
Dropdown ddRes = new Dropdown("dd_res");
ddRes.setBounds(ctrlX, y, 220, rowH);
for (ResolutionInfo info : resList) {
    ddRes.addItem(info.getLabel());
}
ddRes.setSelectedIndex(currentIdx);
ddRes.setOnSelect(() -> {
    int idx = ddRes.getSelectedIndex();
    ResolutionInfo info = resList.get(idx);
    int targetW = Math.min(info.width, screenW);
    int targetH = Math.min(info.height, screenH);
    
    // ① 改变窗口尺寸
    app.engine.getWindowManager().setWindowSize(targetW, targetH);
    
    // ② 同步显示管理器
    app.engine.getDisplayManager().onWindowResize(targetW, targetH);
    
    // ③ 同步相机视口
    if (app.camera != null) {
        app.camera.setViewportSize(targetW, targetH);
        app.camera.setViewportOffset(0, 0);
    }
});
```

### 3.4 注意事项

| 注意点 | 说明 |
|---|---|
| **同步顺序** | 必须先 `setWindowSize()`，再 `onWindowResize()`，再 `camera.setViewportSize()` |
| **尺寸钳制** | 窗口模式下的分辨率不能超过物理屏幕尺寸，否则 NEWT 可能行为异常 |
| **相机偏移** | 每次 resize 后需将相机视口偏移重置为 `(0, 0)`，避免旧偏移导致渲染错位 |
| **保存配置** | 如果需要在重启后恢复，需将目标分辨率保存到配置文件 |

---

## 4. 全屏切换实现

### 4.1 实现原理

我们的全屏方案是 **Borderless Fullscreen（无边框窗口化全屏）**，而非 Exclusive Fullscreen（独占全屏）。

```java
// Borderless 实现核心
saveWindowedState();                          // 保存当前窗口尺寸/位置
int screenW = ...;                            // 获取屏幕尺寸
int screenH = ...;
setUndecorated(true);                         // 去掉窗口边框（best-effort）
setSize(screenW, screenH);                    // 尺寸设为屏幕大小
```

**为什么不用 Exclusive Fullscreen？**
- JOGL `GLWindow.setFullscreen(true)` 在 Windows 上会导致窗口**直接消失**（显卡驱动兼容性问题）
- Exclusive Fullscreen 独占显示器，Alt+Tab 切换时黑屏/闪烁严重
- Borderless Windowed 实际上是窗口，Alt+Tab 切换更平滑，系统仍可覆盖显示（如音量条、任务管理器）

### 4.2 关键代码：applyBorderlessFullscreen

```java
private boolean applyBorderlessFullscreen() {
    if (!isJOGL || nativeSurface == null) {
        return false;  // 不回退 exclusive，避免窗口消失
    }
    try {
        saveWindowedState();

        // 获取屏幕尺寸
        Method getScreen = nativeSurface.getClass().getMethod("getScreen");
        Object screen = getScreen.invoke(nativeSurface);
        if (screen == null) return false;
        int screenW = (Integer) screen.getClass().getMethod("getWidth").invoke(screen);
        int screenH = (Integer) screen.getClass().getMethod("getHeight").invoke(screen);

        // 去边框（best-effort，失败不影响后续）
        try {
            Method setUndecorated = nativeSurface.getClass().getMethod("setUndecorated", boolean.class);
            setUndecorated.invoke(nativeSurface, true);
        } catch (Exception e) {
            Logger.debug("setUndecorated failed: " + e.getMessage());
        }

        // 关键步骤：尺寸设为屏幕大小
        try {
            Method setSize = nativeSurface.getClass().getMethod("setSize", int.class, int.class);
            setSize.invoke(nativeSurface, screenW, screenH);
        } catch (Exception e) {
            Logger.warn("setSize failed: " + e.getMessage());
            return false;
        }

        return true;
    } catch (Exception e) {
        Logger.warn("applyBorderlessFullscreen failed: " + e.getMessage());
        return false;
    }
}
```

### 4.3 延迟调用策略

**核心问题**：在 Processing `draw()` / `mouseEvent()` 周期内直接调用 `setSize()` 会触发 NEWT resize 事件，Processing 的 `PSurfaceJOGL` 在 resize 回调中调用 `handleDraw()`，导致**递归 draw**（`handleDraw() called before finishing`）。

**解决方案**：使用 `java.util.Timer` 延迟执行，等当前渲染帧完全结束后再切换。

```java
// 运行时按钮点击：延迟 200ms
java.util.Timer t = new java.util.Timer();
t.schedule(new java.util.TimerTask() {
    public void run() {
        t.cancel();
        app.engine.getWindowManager().toggleFullscreen();
    }
}, 200);

// 启动时自动全屏：同样延迟 200ms
if (TdSaveData.isFullscreen()) {
    java.util.Timer t = new java.util.Timer();
    t.schedule(new java.util.TimerTask() {
        public void run() {
            t.cancel();
            engine.getWindowManager().toggleFullscreen();
        }
    }, 200);
}
```

**延迟时间选择**：
| 延迟 | 结果 |
|---|---|
| 0ms（立即） | `handleDraw() called before finishing`，窗口消失 |
| 50ms | 不够稳定，偶发窗口消失 |
| 200ms | **当前设定，经验证稳定** |
| 500ms | 绝对稳定，但用户感知延迟明显 |

### 4.4 恢复窗口模式

```java
private void restoreWindowed() {
    // ① 关闭 exclusive fullscreen（如果之前是 exclusive）
    if (currentMode == EXCLUSIVE_FULLSCREEN) {
        setFullscreen.invoke(nativeSurface, false);
    }
    
    // ② 恢复边框（best-effort）
    if (!savedDecorated) {
        setUndecorated.invoke(nativeSurface, true);  // 先 true 再 false（某些平台需要）
        setUndecorated.invoke(nativeSurface, false);
    }
    
    // ③ 恢复尺寸
    setSize.invoke(nativeSurface, savedW, savedH);
    
    // ④ 恢复位置
    if (savedX >= 0 && savedY >= 0) {
        setPosition.invoke(nativeSurface, savedX, savedY);
    } else {
        centerWindow();
    }
}
```

---

## 5. 已知问题与解决方案

### 5.1 EDT 死锁（`Waited 5000ms`）

**现象**：
```
java.lang.RuntimeException: Waited 5000ms for: <...>[count 3, qsz 0, owner <main-FPSAWTAnimator#00-Timer0>] - <main-Display-.windows_nil-1-EDT-1>
```

**根因**：NEWT 的 Event Dispatch Thread (EDT) 和 FPSAnimator 渲染线程争夺 `RecursiveLock`。当 `setResizable()`、`setUndecorated()` 或 `setSize()` 在渲染线程上直接调用时，可能触发死锁。

**对策**：
- 使用 NEWT 反射直接调用 `GLWindow.setSize()`，绕过 `PSurfaceJOGL.setSize()`（后者内部会调用 `setResizable`）
- 避免在 `draw()` / `mouseEvent()` 周期内调用窗口操作 → 使用 `Timer` 延迟 200ms+

### 5.2 handleDraw() 递归（`handleDraw() called before finishing`）

**现象**：控制台输出 `handleDraw() called before finishing`，随后可能黑屏或窗口消失。

**根因**：NEWT 的 `setSize()` 触发 `windowResized` 回调，`PSurfaceJOGL` 在回调中调用 `sketch.windowResize()`，如果此时 `draw()` 尚未结束，Processing 检测到递归并跳过当前帧。

**对策**：
- 延迟调用 `toggleFullscreen()`，确保 `draw()` 完全结束
- **禁止**在 `draw()`、`update()`、`mouseEvent()` 等回调中直接调用 `setSize()`

### 5.3 GLContext 损坏（`Error swapping buffers`）

**现象**：
```
com.jogamp.opengl.GLException: Error swapping buffers
```

**根因**：`GLWindow.setSize()` 导致 NEWT 重创建 `GLDrawable`，OpenGL 上下文未正确迁移，后续帧的 `swapBuffers()` 失败。

**对策**：
- 这是 JOGL/显卡驱动的底层兼容性问题，应用层无法根治
- Borderless 方案（`setSize` 到屏幕尺寸）比 Exclusive Fullscreen（`setFullscreen(true)`）触发概率更低
- 如果发生，只能重启程序恢复

### 5.4 `IllegalAccessException`（PDE 中 `registerMethod` 陷阱）

**现象**：使用 `registerMethod("post", new Object() { public void post() {...} })` 时抛 `IllegalAccessException`。

**根因**：PDE 预处理器将匿名类变成非 public 的内部类（如 `TowerDefenseMin2$TdAppSetup$1`），Processing 反射调用时无法访问。

**对策**：
- PDE 中**不要**使用 `registerMethod` 配匿名类
- 改用 `java.util.Timer` 固定延迟方案

---

## 6. 使用指南

### 6.1 在设置界面集成

**推荐布局**（从上到下）：
```
主音量      [========●====]
音乐音量    [=====●=======]
音效音量    [=========●===]
全屏显示    [ON/OFF]      ← 点击立即保存配置，延迟 200ms 后切换
分辨率      [1920x1080 ▼] ← 选择后立即生效
语言        [中文] [English]
缩放跟随鼠标 [ON/OFF]
```

**全屏按钮代码**：
```java
Button btnFullscreenToggle = new Button("btn_fullscreen_toggle");
btnFullscreenToggle.setLabel(TdSaveData.isFullscreen() ? "ON" : "OFF");
btnFullscreenToggle.setBounds(ctrlX, y, 80, rowH);
btnFullscreenToggle.setAction(() -> {
    boolean next = !TdSaveData.isFullscreen();
    TdSaveData.setFullscreen(next);
    
    // 延迟 200ms 执行，避开 draw() 周期
    java.util.Timer t = new java.util.Timer();
    t.schedule(new java.util.TimerTask() {
        public void run() {
            t.cancel();
            if (app.engine.getWindowManager() != null) {
                app.engine.getWindowManager().toggleFullscreen();
            }
        }
    }, 200);
    
    TdFlow.showSettings(app);  // 刷新界面
});
```

### 6.2 配置持久化

```java
// TdSaveData.pde
static boolean isFullscreen() {
    return cfg.getBoolean("display", "fullscreen", false);
}
static void setFullscreen(boolean v) {
    cfg.set("display", "fullscreen", v);
}

// 启动时自动恢复
if (TdSaveData.isFullscreen()) {
    java.util.Timer t = new java.util.Timer();
    t.schedule(new java.util.TimerTask() {
        public void run() {
            t.cancel();
            engine.getWindowManager().toggleFullscreen();
        }
    }, 200);
}
```

### 6.3 最佳实践

| 场景 | 推荐做法 |
|---|---|
| **启动时全屏** | `settings()` 保持窗口模式，`setup()` 完成后延迟 200ms 调用 `toggleFullscreen()` |
| **运行时切换** | 按钮 action 中先保存配置、刷新界面，再用 `Timer` 延迟 200ms 调用 `toggleFullscreen()` |
| **分辨率切换** | 直接调用 `setWindowSize()` + `onWindowResize()` + `camera.setViewportSize()`，无需延迟 |
| **窗口恢复** | `restoreWindowed()` 会自动恢复保存的尺寸和位置 |
| **多显示器** | 当前方案仅支持主显示器，跨显示器需额外处理 `getScreen()` 逻辑 |

---

## 7. 相关文件

| 文件 | 职责 |
|---|---|
| `src/main/java/shenyf/p5engine/core/WindowManager.java` | NEWT 反射窗口控制（setSize/toggleFullscreen/centerWindow） |
| `src/main/java/shenyf/p5engine/rendering/DisplayManager.java` | 设计分辨率与实际窗口尺寸的映射管理 |
| `src/main/java/shenyf/p5engine/ui/Dropdown.java` | 3A 风格下拉框组件（分辨率选择） |
| `examples/TowerDefenseMin2/TdFlow.pde` | 设置界面 UI 布局与事件绑定 |
| `examples/TowerDefenseMin2/TdSaveData.pde` | 配置持久化（SketchConfig） |
| `examples/TowerDefenseMin2/TdAppCore.pde` | 启动时配置恢复逻辑 |
| `examples/TowerDefenseMin2/TowerDefenseMin2.pde` | `settings()` 入口与 `windowResize()` 回调 |

---

## 8. 总结

| 特性 | Processing 原生 `fullScreen()` | p5engine `WindowManager.toggleFullscreen()` |
|---|---|---|
| 调用时机 | 仅 `settings()` | 任何时刻 |
| 模式 | Exclusive Fullscreen | Borderless Windowed |
| 稳定性 | 启动时绝对稳定 | 运行时 200ms 延迟下基本稳定 |
| Alt+Tab | 黑屏/闪烁 | 平滑切换 |
| 状态恢复 | 不支持 | 支持（尺寸/位置） |
| 适用场景 | 启动时决定不再改变 | 需要游戏中随时切换 |

**最终建议**：在 Windows + P2D 环境下，如果需要**运行时热切换**全屏/窗口，p5engine 的 Borderless 方案是目前唯一可行的 workaround。务必配合 **200ms 延迟调用**，避免在 `draw()` 周期内直接触发 NEWT resize。
