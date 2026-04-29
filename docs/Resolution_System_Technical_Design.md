# p5engine 分辨率与渲染窗口控制系统 — 技术设计文档

## 概述

本文档描述 p5engine v0.4.0+ 引入的分辨率与窗口控制体系。该系统实现了：

- **设计分辨率与渲染分辨率分离**：游戏逻辑/UI 坐标基于固定的设计分辨率（如 1280×720），实际窗口/framebuffer 大小由分辨率预设控制
- **P2D OpenGL 矢量渲染**：窗口尺寸即 framebuffer 尺寸，放大/缩小通过 OpenGL 矢量管线完成， primitives 和文字保持清晰
- **运行时全屏切换**：支持无边框窗口全屏（borderless）和独占全屏（exclusive），通过 JOGL/NEWT 反射实现
- **UI 统一自适应**：UIManager 的坐标、鼠标交互、布局全部基于设计分辨率，由引擎自动缩放到任意窗口大小

---

## 核心概念

### 设计分辨率（Design Resolution）

游戏逻辑、UI 布局、碰撞检测、Camera 视口等全部使用的设计时参考坐标系。

- 默认值：`1280 × 720`
- 配置位置：`DisplayConfig.designWidth / designHeight`
- 坐标范围：`(0, 0)` 到 `(designWidth, designHeight)`

### 渲染分辨率（Render Resolution）

实际的 OpenGL framebuffer / 窗口像素尺寸。由 `ResolutionPreset` 决定：

| 预设 | 分辨率 |
|------|--------|
| R720 | 1280 × 720 |
| R1080 | 1920 × 1080 |
| R1440 | 2560 × 1440 |
| R4K | 3840 × 2160 |
| CUSTOM | 自定义（通过 windowedWidth / windowedHeight） |

### 缩放模式（ScaleMode）

`DisplayManager` 在渲染时将设计分辨率映射到实际窗口大小：

- **NO_SCALE**：1:1 映射，不缩放
- **STRETCH**：非均匀拉伸填充整个窗口
- **FIT**（默认）：等比缩放，保持纵横比，可能有 letterbox
- **FILL**：等比缩放填充整个窗口，可能裁剪内容

---

## 架构

### 渲染管线

```
TowerDefenseMin2.draw()
    ├── pushMatrix()
    ├── translate(offsetX, offsetY)
    ├── scale(uniformScale, uniformScale)   ← 全局 DisplayManager 缩放
    │
    ├── TdAppLoop.run()
    │   ├── background() / TdMenuBg.draw()   ← 在缩放环境中
    │   ├── sketchUi.renderFrame()           ← UIManager 以设计坐标绘制
    │   ├── lighting.render()                ← 在缩放环境中
    │   ├── pause menu / sell menu paint()   ← 在缩放环境中
    │   ├── TdHUD.drawPauseOverlay()         ← 使用设计分辨率
    │   ├── TdMenuBg.drawTitle()             ← 使用设计分辨率
    │   └── engine.renderDebugOverlay()      ← 在缩放环境中（debug 文字会放大）
    │
    └── popMatrix()
```

### UI 缩放流程

```
UIManager.update()
    └── root.setBounds(0, 0, designW, designH)   ← 设计分辨率

UIManager.render()
    └── root.paint(applet, theme)                ← 设计坐标绘制
        └── 被 TowerDefenseMin2.draw() 的全局缩放包裹

UIManager.mouseEvent()
    └── actualToDesign(mouseX, mouseY)           ← 屏幕像素 → 设计坐标
        └── root.hitTest(designMx, designMy)     ← 设计坐标检测
```

---

## 窗口管理（WindowManager）

### 运行时全屏切换

```java
WindowManager wm = engine.getWindowManager();
wm.toggleFullscreen();                          // 窗口化 ↔ 无边框全屏
wm.setDisplayMode(DisplayMode.EXCLUSIVE_FULLSCREEN);  // 独占全屏
wm.setResolution(ResolutionPreset.R1440);       // 切换到 2560×1440
```

### 实现细节

- **无边框全屏**：通过 NEWT 反射调用 `GLWindow.setUndecorated(true)`、`setPosition(0,0)`、`setSize(screenW, screenH)`
- **独占全屏**：通过 NEWT 反射调用 `GLWindow.setFullscreen(true)`
- **Fallback**：如果 `setUndecorated` 在运行时不可用（某些平台），自动 fallback 到独占全屏
- **状态保存**：切换全屏前自动保存窗口化状态（位置、大小、装饰），退出全屏时恢复

### 快捷键

- **F11**：`WindowManager.toggleFullscreen()`

---

## 坐标系统

### 屏幕坐标 → 设计坐标

```java
DisplayManager dm = engine.getDisplayManager();
Vector2 design = dm.actualToDesign(new Vector2(mouseX, mouseY));
```

公式：
- `designX = (screenX - offsetX) / scaleX`
- `designY = (screenY - offsetY) / scaleY`

### 设计坐标 → 屏幕坐标

```java
Vector2 screen = dm.designToActual(new Vector2(designX, designY));
```

公式：
- `screenX = designX * scaleX + offsetX`
- `screenY = designY * scaleY + offsetY`

---

## 已知限制

1. **PDE 预处理器限制**：`size()` 只能在 `settings()` 中调用一次。运行时分辨率切换通过 NEWT `setSize()` 反射实现，但 Processing 内部缓存的 `width/height` 可能需要一帧才能同步
2. **debug overlay 缩放**：`engine.renderDebugOverlay()` 在全局缩放环境中，debug 文字会被放大。这是可接受的调试行为
3. **setUndecorated 平台差异**：某些平台（如 macOS）可能不支持运行时切换 `undecorated` 状态，会自动 fallback 到独占全屏
4. **Windows DPI 缩放**：Windows 系统级 DPI 缩放可能导致 `displayDensity()` 返回 1，但窗口实际像素密度由用户选择的 `ResolutionPreset` 控制，不受系统 DPI 影响

---

## 相关文件

| 路径 | 说明 |
|------|------|
| `src/main/java/shenyf/p5engine/rendering/ResolutionPreset.java` | 分辨率预设枚举 |
| `src/main/java/shenyf/p5engine/rendering/DisplayMode.java` | 显示模式枚举 |
| `src/main/java/shenyf/p5engine/rendering/DisplayConfig.java` | 显示配置（设计分辨率、预设、模式） |
| `src/main/java/shenyf/p5engine/rendering/DisplayManager.java` | 缩放计算与坐标转换 |
| `src/main/java/shenyf/p5engine/core/WindowManager.java` | 运行时窗口/全屏管理 |
| `src/main/java/shenyf/p5engine/core/P5Config.java` | 引擎配置（集成 resolutionPreset/displayMode） |
| `src/main/java/shenyf/p5engine/core/P5Engine.java` | 引擎核心（configureDisplay、F11 快捷键、resizable） |
| `src/main/java/shenyf/p5engine/ui/UIManager.java` | UI 管理器（设计坐标 mouseEvent、设计分辨率 root bounds） |
