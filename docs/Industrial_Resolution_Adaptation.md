# 工业级分辨率适配方案实现报告

## 问题描述

原有分辨率系统使用单一全局 FIT 缩放，将世界+UI+背景统一缩放到一个居中矩形内。这导致：
- 21:9 屏幕左右出现大面积黑边
- 4:3 屏幕上下出现黑边
- 分辨率列表为固定枚举，无法适配显示器实际支持的模式

## 核心方案：分层渲染（Layered Rendering）

将单一全局缩放拆分为两层独立策略：

### 层1 — 世界层（World Layer）
- 坐标系：实际屏幕像素（1:1）
- 缩放策略：无缩放
- 视口尺寸：实际窗口像素尺寸
- 效果：世界铺满全屏；21:9 横向可见更多，4:3 纵向可见更多

### 层2 — UI 层（UI Layer）
- 坐标系：设计分辨率 1280×720
- 缩放策略：FIT（保持比例，居中）
- 效果：UI 不变形，悬浮在世界层之上

**无黑边原理**：世界层先铺满全屏，UI 层的 FIT "空白"区域已被世界内容填充，视觉上没有黑边。

## 修改内容

### 引擎层（Java）

1. **新增 `ResolutionInfo`** (`shenyf.p5engine.rendering.ResolutionInfo`)
   - 数据类：width, height, refreshRate, bitDepth
   - 支持 `getLabel()`、`getAspectRatio()`、`equals()`/`hashCode()`（按宽高去重）

2. **增强 `DisplayManager`** (`shenyf.p5engine.rendering.DisplayManager`)
   - 新增 `getSafeAreaRect()` — 返回 FIT 区域（UI 安全渲染区域）
   - 新增 `getWorldAreaRect()` — 返回整个窗口区域（世界渲染区域）
   - 新增 `screenToDesign()` / `designToScreen()` 便捷转换

3. **增强 `WorldViewport`** (`shenyf.p5engine.ui.WorldViewport`)
   - 新增 `renderDirect(PApplet, screenX, screenY, screenW, screenH)`
   - Buffer 大小使用实际像素尺寸，直接 `image()` 绘制到屏幕（不经过 UI 缩放矩阵）

4. **增强 `WindowManager`** (`shenyf.p5engine.core.WindowManager`)
   - 新增 `listAvailableResolutions()` — 通过 `GraphicsEnvironment` 枚举所有显示模式，去重排序
   - 新增 `applyResolution(ResolutionInfo)` — 运行时应用指定分辨率

5. **增强 `DisplayConfig` / `P5Config`**
   - `DisplayConfig` 新增 `currentResolution` 字段，`resolution(ResolutionInfo)` fluent API
   - `getRenderWidth/Height()` 优先级：`currentResolution` > `CUSTOM preset` > 固定 preset
   - `P5Config` 新增 `resolution(ResolutionInfo)` / `getResolution()` API

### 游戏层（PDE）

1. **`TowerDefenseMin2.draw()`**
   - 移除全局 `pushMatrix → translate → scale → popMatrix`
   - 改为在 `TdAppLoop.run()` 内部分层处理

2. **`TdAppLoop.run()`** — 分层渲染管线
   - **Layer 1**：背景清除 + `worldViewport.renderDirect(0, 0, width, height)` 铺满全屏 + 光照覆盖全屏
   - **Layer 2**：`pushMatrix → FIT → UI 渲染 → popMatrix`
   - 菜单背景、暂停覆盖、胜利/失败动画均在 FIT 矩阵内部渲染

3. **`TdAppSetup.setupWorldViewport()`**
   - `worldWindow` 不再加入 UI root（独立管理）
   - `worldViewport` 直接创建，不通过 UI 树
   - Camera viewport 初始化为全屏 `(width, height)`

4. **`TdAppUtils.syncCameraToWindow()`**
   - Camera viewport 同步到 `app.width / app.height`（全屏）
   - Viewport offset 设为 `(0, 0)`

5. **`TdAppUtils.isMouseOverHud()`**
   - 移除 `world_win` / `world_vp` 的特殊排除逻辑（它们已不在 UI 树中）

6. **`TdCamera.isMouseInViewport()`**
   - 改用实际屏幕坐标检查（而非设计坐标），因为 camera viewport 现在匹配全屏

7. **`TdFlow.showSettings()`**
   - 分辨率按钮改为动态枚举：`WindowManager.listAvailableResolutions()`
   - 分辨率切换时同步 camera viewport 到全屏
   - 移除已废弃的 `worldWindow` 引用

## 验证结果

- `compile-jar.ps1` — 引擎编译通过 ✅
- Processing CLI build — PDE 编译通过 ✅
- 运行时日志确认：
  - `Window: 1920x1080` — 窗口尺寸正确
  - `DisplayManager synced to actual window: 1920x1080` — 显示管理器同步正确

## 技术限制

- **JOGL NEWT `setResizable` 死锁**：Windows 上 `surface.setResizable(true)` 仍可能触发 EDT 死锁（`Waited 5000ms`）。这是 JOGL/Processing 已知问题，不影响核心渲染功能。
- **MENU 状态背景**：`TdMenuBg` 的星星和网格仅在 FIT 区域内绘制，超宽屏幕两侧为纯色背景。不影响 PLAYING 状态的无黑边效果。

## 后续优化方向

1. **UI 锚点化**：使用 `AnchorLayout` 的 `STRETCH_TOP` / `STRETCH_RIGHT` 让 TopBar / BuildPanel 在超宽屏幕上延展到屏幕边缘
2. **分辨率热切换**：在设置菜单中添加显示模式切换（窗口化 / 无边框全屏 / 独占全屏）
3. **SafeArea 可视化**：调试模式下绘制 SafeArea 边界，辅助 UI 布局调试
