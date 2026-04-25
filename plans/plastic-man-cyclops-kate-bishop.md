# 修复窗口居中受 DPI 缩放影响的问题

## 目标
修复 `SketchConfig.getCenterPosition()` 在高 DPI 缩放环境下获取的是逻辑分辨率而非物理分辨率的问题，确保 Processing 窗口正确居中。

## 背景
当前实现：
```java
public static int[] getCenterPosition(int windowWidth, int windowHeight) {
    java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
    java.awt.GraphicsDevice gd = ge.getDefaultScreenDevice();
    java.awt.Rectangle screenBounds = gd.getDefaultConfiguration().getBounds();
    java.awt.Rectangle usableBounds = ge.getMaximumWindowBounds();
    int x = (screenBounds.width - windowWidth) / 2 + screenBounds.x;
    int y = (usableBounds.height - windowHeight) / 2 + usableBounds.y;
    return new int[]{x, y};
}
```

问题：`gd.getDefaultConfiguration().getBounds()` 在 DPI 缩放（如 125%）下返回的是**逻辑分辨率**（如 2752×1152），而非**物理分辨率**（如 3440×1440）。这导致窗口居中位置计算错误。

## 方案

### 方案 A：使用 DisplayMode 获取物理分辨率（推荐）
根据用户提供的文档，使用 `GraphicsDevice.getDisplayMode()` 获取物理分辨率，不受 DPI 缩放影响：

```java
public static int[] getCenterPosition(int windowWidth, int windowHeight) {
    java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
    java.awt.GraphicsDevice gd = ge.getDefaultScreenDevice();
    java.awt.DisplayMode dm = gd.getDisplayMode();
    int screenW = dm.getWidth();   // 物理宽度，不受 DPI 影响
    int screenH = dm.getHeight();  // 物理高度，不受 DPI 影响
    int x = (screenW - windowWidth) / 2;
    int y = (screenH - windowHeight) / 2;
    return new int[]{x, y};
}
```

### 方案 B：使用 JOGL 获取屏幕尺寸
通过 `GLWindow.getScreen()` 获取屏幕尺寸，适用于 P2D/P3D 渲染器。但这增加了对 JOGL 的依赖，且只在 P2D 下有效。

## 推荐方案：方案 A

`DisplayMode.getWidth()/getHeight()` 返回的是硬件物理分辨率，不受操作系统 DPI 缩放设置影响。这是最简单、最通用的方案。

## 实施步骤

### 1. 修改 SketchConfig.getCenterPosition()
```java
public static int[] getCenterPosition(int windowWidth, int windowHeight) {
    try {
        java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
        java.awt.GraphicsDevice gd = ge.getDefaultScreenDevice();
        java.awt.DisplayMode dm = gd.getDisplayMode();
        int screenW = dm.getWidth();
        int screenH = dm.getHeight();
        int x = (screenW - windowWidth) / 2;
        int y = (screenH - windowHeight) / 2;
        return new int[]{x, y};
    } catch (Exception e) {
        // Fallback to previous method
        java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
        java.awt.GraphicsDevice gd = ge.getDefaultScreenDevice();
        java.awt.Rectangle screenBounds = gd.getDefaultConfiguration().getBounds();
        int x = (screenBounds.width - windowWidth) / 2 + screenBounds.x;
        int y = (screenBounds.height - windowHeight) / 2 + screenBounds.y;
        return new int[]{x, y};
    }
}
```

### 2. 同时修复 P5Engine.centerWindow() 和 restoreWindowPosition()
这两个方法也使用 `getCenterPosition()`，修改后会自动生效。

### 3. 可选：在 P5Engine.update() 中延迟居中
根据文档建议，窗口在 `setup()` 中可能还未完全创建，最佳时机是在 `draw()` 第一帧。但当前 `centerWindow()` 是在 `setup()` 中调用的，且 `restoreWindowPosition()` 在 `update()` 第一帧执行。

如果仍然有问题，可以考虑：
- 将 `centerWindow()` 的调用从 `setup()` 移到 `update()` 第一帧
- 或者添加一个 `windowCentered` 标志，确保只执行一次

## 验收标准
- [ ] 在 125% DPI 缩放下，窗口正确居中
- [ ] 在 100% DPI 缩放下，窗口正确居中
- [ ] 多显示器环境下使用主显示器分辨率

## 相关文件
- `src/main/java/shenyf/p5engine/config/SketchConfig.java` — 修改 getCenterPosition()
