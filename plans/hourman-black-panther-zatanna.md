# 窗口激活时鼠标移出约束（第五版）

## 目标
当游戏窗口处于激活状态时，将鼠标光标约束在窗口内部。

## 背景
前四版尝试均失败：
1. Robot 拉回：坐标映射问题
2. JNA ClipCursor：可能未正确调用或坐标错误
3. JOGL confinePointer：反射调用可能无效
4. 事件拦截 + JNA GetWindowRect：仍然无效

核心问题：Processing P2D 渲染器使用 JOGL/NEWT，其窗口模型与标准 AWT 完全不同。`applet.getSurface().getNative()` 返回的 `GLWindow` 不是 AWT 组件，导致所有基于 AWT Frame 的方法都失效。

## 新方案：直接在 PDE 层用 Robot 约束（绕过引擎）

既然引擎层面的约束一直失败，考虑在 PDE  sketch 的 `draw()` 中直接处理。PDE 可以直接访问 `surface` 和 `mouseX/mouseY`。

### 方案 A：PDE draw() 中每帧检测并 Robot 拉回
在 `TowerDefenseMin2.pde` 的 `draw()` 末尾添加：
```java
// Constrain mouse to window
if (focused) {
  if (mouseX < 0 || mouseX >= width || mouseY < 0 || mouseY >= height) {
    // Use surface location for screen coords
    int sx = frame.getX();
    int sy = frame.getY();
    int cx = constrain(mouseX, 0, width - 1);
    int cy = constrain(mouseY, 0, height - 1);
    try {
      new java.awt.Robot().mouseMove(sx + cx, sy + cy);
    } catch (Exception e) {}
  }
}
```

**问题**：Processing 3.0+ 的 `frame` 变量是伪对象，`getX()/getY()` 返回 (0,0)。

### 方案 B：使用 `surface` 的 `setLocation()` 反推（不可靠）

### 方案 C：使用全屏无边框窗口 + 自定义光标（根本解决）
如果改为全屏模式（`fullScreen()`），鼠标自然被限制在屏幕内。但用户要求窗口模式。

### 方案 D：使用 JNA 获取当前前台窗口 HWND，然后 ClipCursor
不依赖 Processing 的窗口引用，直接使用 Windows API 获取当前进程的前台窗口：
```java
// Get the foreground window (should be our game window when focused)
HWND hwnd = User32.INSTANCE.GetForegroundWindow();
// Get its client rect in screen coords
RECT rect = new RECT();
User32.INSTANCE.GetClientRect(hwnd, rect);
POINT pt = new POINT(rect.left, rect.top);
User32.INSTANCE.ClientToScreen(hwnd, pt);
rect.left = pt.x;
rect.top = pt.y;
rect.right = rect.left + (rect.right - rect.left);
rect.bottom = rect.top + (rect.bottom - rect.top);
User32.INSTANCE.ClipCursor(rect);
```

**风险**：如果用户 Alt+Tab 切出，前台窗口变成其他应用，ClipCursor 会错误地约束到其他窗口。需要在失焦时释放。

### 方案 E：使用 `java.awt.MouseInfo` 获取全局鼠标位置，计算是否在屏幕某区域内
结合 `Toolkit.getDefaultToolkit().getScreenSize()` 和窗口位置（如果能获取到）。

### 方案 F：改用 JAVA2D 渲染器（放弃 P2D）
JAVA2D 渲染器使用标准 AWT Frame，`getFrameFromSurface()` 可以正常工作，所有之前的方案都会有效。

**代价**：失去 P2D 的硬件加速，但对塔防游戏性能影响可能不大。

## 最终推荐：方案 D（JNA GetForegroundWindow + ClipCursor）+ 失焦检测

不依赖 Processing 窗口引用，直接使用 Windows API。当窗口激活时获取前台窗口并约束，失焦时释放。

### 实现
```java
// In MouseClipper
public static void clipToForegroundWindow() {
    WinDef.HWND hwnd = User32.INSTANCE.GetForegroundWindow();
    if (hwnd == null) return;
    
    WinDef.RECT rect = new WinDef.RECT();
    User32.INSTANCE.GetClientRect(hwnd, rect);
    
    // Convert client rect to screen coords
    WinDef.POINT pt = new WinDef.POINT(rect.left, rect.top);
    User32.INSTANCE.ClientToScreen(hwnd, pt);
    rect.left = pt.x;
    rect.top = pt.y;
    
    WinDef.POINT pt2 = new WinDef.POINT(rect.right, rect.bottom);
    User32.INSTANCE.ClientToScreen(hwnd, pt2);
    rect.right = pt2.x;
    rect.bottom = pt2.y;
    
    User32.INSTANCE.ClipCursor(rect);
}
```

### 调用时机
- 在 `P5Engine.update()` 中，当 `applet.focused` 为 true 时调用
- 当 `applet.focused` 为 false 时调用 `ClipCursor(null)` 释放

## 备选：方案 F（改用 JAVA2D 渲染器）
如果方案 D 仍然失败，这是最后手段。将 `TowerDefenseMin2.pde` 的 `settings()` 中的 `P2D` 改为默认（JAVA2D）。

## 验收标准
- [ ] 窗口激活时，鼠标无法移出窗口边界
- [ ] 窗口未激活时，鼠标自由移动
- [ ] 关闭游戏时释放鼠标约束

## 相关文件
- `src/main/java/shenyf/p5engine/util/MouseClipper.java` — 新增 clipToForegroundWindow()
- `src/main/java/shenyf/p5engine/core/P5Engine.java` — 调用新的 clip 方法
