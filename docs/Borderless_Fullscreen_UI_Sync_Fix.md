# Borderless 全屏后鼠标坐标偏差修复报告

## 问题描述
全屏启动后，鼠标输入坐标与 UI 视觉位置不匹配。鼠标明明在按钮上悬停，却点不着；偏一点位置反而能触发。

## 排查过程

### 第一轮：Timer `setWindowSize()` 方案
- `fullScreen(P2D)` 在 DPI 缩放时创建 **2752×1152 逻辑像素** 窗口
- Timer 强制 `setWindowSize(3440, 1440)`，`DisplayManager` 按 3440×1440 计算
- NEWT 鼠标坐标仍在 0~2752 范围，与 `DisplayManager` 的 0~3440 不匹配
- DPI 检测 `applet.displayWidth != physicalW` 在 DPI 感知应用下失效

### 第二轮：直接 `size(physicalW, physicalH)` 方案
- 修复 DPI 检测，用 `GraphicsConfiguration.getDefaultTransform()` 检测缩放
- `settings()` 直接用 `size(3440, 1440, P2D)` 创建物理像素窗口
- 坐标能对位，但这是**窗口模式**（有标题栏），不符合用户要求的 borderless 全屏

### 第三轮：Borderless 全屏方案（最终）
- `settings()` 以普通窗口启动，`setup()` 后延迟调用 `toggleFullscreen()`
- `toggleFullscreen()` 内部执行 `setUndecorated(true)` + `setSize(screenW, screenH)`
- **关键发现**：NEWT 的 `setSize()` **不会触发** Processing `windowResize()` 回调
- `DisplayManager` 一直停在 1280×960，实际窗口已变为 3440×1440
- **修复**：`toggleFullscreen()` 后再延迟 100ms，手动读取 `applet.width`/`applet.height` 同步 `DisplayManager` 和 `Camera`
- **补充**：全屏时确保 `p5engine.ini` 中 `[window_position] x=0 y=0`，避免启动时窗口先出现在其他位置再跳转

## 修复内容

### `src/main/java/shenyf/p5engine/core/P5Engine.java`
- `configureFullscreen()` 改用 `GraphicsConfiguration.getDefaultTransform().getScaleX()` 检测 DPI 缩放（备用方法）

### `src/main/java/shenyf/p5engine/core/WindowManager.java`
- `applyBorderlessFullscreen()` 在 `setSize()` 后添加 `setPosition(0, 0)`，确保窗口从屏幕左上角铺满

### `examples/TowerDefenseMin2/TowerDefenseMin2.pde`
- `settings()` 移除 `P5Engine.configureFullscreen()`，统一用 `P5Engine.configureDisplay()` 窗口模式初始化
- 全屏切换推迟到 `setup()` 后的 `toggleFullscreen()`

### `examples/TowerDefenseMin2/TdAppCore.pde`
- 全屏启动前将 `p5engine.ini` 的 `[window_position]` 设为 `x=0, y=0`
- 嵌套 Timer 实现 borderless 全屏：
  ```java
  // 200ms 后切换 borderless
  engine.getWindowManager().toggleFullscreen();
  // 再延迟 100ms 手动同步（NEWT setSize() 不触发 windowResize）
  engine.getDisplayManager().onWindowResize(width, height);
  camera.setViewportSize(width, height);
  ```
- 全屏不启用鼠标约束

## 验证结果
- CLI 编译通过
- `p5engine.ini` 确认 `[window_position] x=0 y=0`
- 启动日志确认流程正确：
  ```
  Loaded window position from p5engine.ini: 0,0
  Window positioned: 0, 0
  WindowManager: switching WINDOWED -> BORDERLESS_FULLSCREEN
  WindowManager: borderless fullscreen 3440x1440 @ 0,0
  ```
- 窗口模式行为不变

## 技术要点
| 问题 | 解决方案 |
|---|---|
| `fullScreen(P2D)` 在 DPI 缩放时返回逻辑像素 | `settings()` 用窗口模式启动，`setup()` 后 `toggleFullscreen()` |
| NEWT `setSize()` 不触发 `windowResize()` | `toggleFullscreen()` 后再延迟 100ms 手动同步 `DisplayManager` |
| `draw()` 周期内调用窗口操作导致死锁 | 使用 `Timer` 延迟 200ms+ 执行 |
| 窗口初始位置不在 (0,0) 导致铺满不全 | `applyBorderlessFullscreen()` 中添加 `setPosition(0,0)` |
| `p5engine.ini` 保存了旧位置导致启动闪烁 | 全屏启动前强制将 `p5engine.ini` `[window_position]` 设为 `0,0` |
