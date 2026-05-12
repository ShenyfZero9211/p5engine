# Windows HiDPI 下窗口居中与手电筒网格偏移修复

> **日期**：2026-05-09  
> **版本**：v1.0.3 预修复  
> **作者**：Kimi Code CLI  
> **相关文件**：
> - `src/main/java/shenyf/p5engine/core/P5Engine.java`
> - `src/main/java/shenyf/p5engine/core/WindowManager.java`
> - `src/main/java/shenyf/p5engine/rendering/DisplayManager.java`
> - `examples/TowerDefenseMin2/TdMenuBg.pde`

---

## 一、问题概述

在 Windows 系统显示缩放（DPI Scaling）设置为 **150%、175%、200%** 时，游戏出现以下两个视觉/交互问题：

1. **窗口不居中**：窗口启动时偏向屏幕右下方，而非屏幕正中央。
2. **手电筒网格（Flashlight Grid）偏移**：鼠标悬停在标题"星域防线"正中央时，蓝色网格高亮区域出现在标题左侧，且在不同缩放比例下偏移量固定。

> 注：100% 和 125% 缩放比例下表现正常。

---

## 二、问题一：窗口不居中

### 2.1 现象

- 100% / 125% DPI：窗口完美居中。
- 150% / 175% / 200% DPI：窗口向右下方偏移，偏移量随 DPI 比例增大。

### 2.2 根因分析

**坐标系混用**。

`WindowManager.centerWindow()`（以及 `P5Engine.doCenterWindow()`）在计算居中坐标时，混用了两种不同坐标系的数值：

| 变量 | 来源 | 坐标系 |
|------|------|--------|
| `screenW` / `screenH` | NEWT `Screen.getWidth()` / `getHeight()` | **物理像素**（如 2560×1440） |
| `winW` / `winH` | `applet.width` / `applet.height` | **逻辑像素**（如 1280×720） |

在 Windows HiDPI 环境下，NEWT `GLWindow` 的 `setPosition()` 使用的是**物理像素坐标**。当用物理屏幕尺寸减去逻辑窗口尺寸时：

```
x = (2560 - 1280) / 2 = 640  (物理像素)
```

但实际窗口的物理宽度在 150% DPI 下被 Windows 拉伸为 **1920 物理像素**（如果进程非 DPI-aware），或 NEWT 报告的窗口物理尺寸不等于 `applet.width`（如果进程 DPI-aware）。无论哪种情况，**640 物理像素都不等于正确的居中位置**。

### 2.3 修复方案

**统一使用物理像素计算**。

不再使用 `applet.width`/`applet.height`（逻辑值），改为通过反射调用 NEWT `GLWindow.getWidth()` / `getHeight()` 获取窗口的**实际物理尺寸**，与 `Screen.getWidth()`（物理屏幕尺寸）匹配计算：

```java
java.lang.reflect.Method getWinW = nativeSurface.getClass().getMethod("getWidth");
java.lang.reflect.Method getWinH = nativeSurface.getClass().getMethod("getHeight");
int winW = (Integer) getWinW.invoke(nativeSurface);
int winH = (Integer) getWinH.invoke(nativeSurface);
int x = (screenW - winW) / 2;
int y = (screenH - winH) / 2;
```

### 2.4 修改位置

**`src/main/java/shenyf/p5engine/core/WindowManager.java`** — `centerWindow()` 方法：

```java
public void centerWindow() {
    if (isJOGL && nativeSurface != null) {
        try {
            java.lang.reflect.Method getScreen = nativeSurface.getClass().getMethod("getScreen");
            Object screen = getScreen.invoke(nativeSurface);
            if (screen != null) {
                int screenW = (Integer) screen.getClass().getMethod("getWidth").invoke(screen);
                int screenH = (Integer) screen.getClass().getMethod("getHeight").invoke(screen);
                // Use GLWindow's own physical size instead of applet.width (logical)
                java.lang.reflect.Method getWinW = nativeSurface.getClass().getMethod("getWidth");
                java.lang.reflect.Method getWinH = nativeSurface.getClass().getMethod("getHeight");
                int winW = (Integer) getWinW.invoke(nativeSurface);
                int winH = (Integer) getWinH.invoke(nativeSurface);
                int x = (screenW - winW) / 2;
                int y = (screenH - winH) / 2;
                java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                setPosition.invoke(nativeSurface, x, y);
                Logger.info("WindowManager: centered window at " + x + "," + y + " (screen=" + screenW + "x" + screenH + ", win=" + winW + "x" + winH + ")");
            }
        } catch (Exception e) {
            Logger.debug("WindowManager: centerWindow failed: " + e.getMessage());
        }
    }
}
```

**`src/main/java/shenyf/p5engine/core/P5Engine.java`** — `doCenterWindow()` 方法：

```java
private void doCenterWindow(int winW, int winH) {
    try {
        String clsName = nativeSurface.getClass().getName();
        boolean isJOGL = clsName.contains("newt") || clsName.contains("jogamp");

        if (isJOGL) {
            java.lang.reflect.Method getScreen = nativeSurface.getClass().getMethod("getScreen");
            Object screen = getScreen.invoke(nativeSurface);
            if (screen != null) {
                int screenW = (Integer) screen.getClass().getMethod("getWidth").invoke(screen);
                int screenH = (Integer) screen.getClass().getMethod("getHeight").invoke(screen);
                // Use GLWindow's own physical size for HiDPI consistency
                java.lang.reflect.Method getWinW = nativeSurface.getClass().getMethod("getWidth");
                java.lang.reflect.Method getWinH = nativeSurface.getClass().getMethod("getHeight");
                int physicalW = (Integer) getWinW.invoke(nativeSurface);
                int physicalH = (Integer) getWinH.invoke(nativeSurface);
                int x = (screenW - physicalW) / 2;
                int y = (screenH - physicalH) / 2;
                java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                setPosition.invoke(nativeSurface, x, y);
                windowPositionApplied = true;
                Logger.info("Window centered: " + x + ", " + y);
            }
        } else {
            // AWT fallback unchanged
            ...
        }
    } catch (Exception e) {
        Logger.debug("doCenterWindow failed: " + e.getMessage());
    }
}
```

---

## 三、问题二：手电筒网格（Flashlight Grid）偏移

### 3.1 现象

- 鼠标悬停在标题"星域防线"正中央时，蓝色网格高亮区域出现在**标题左侧**。
- 150% / 175% / 200% DPI 下，偏移方向和距离**完全一致**。
- 125% DPI 下表现正常。

### 3.2 根因分析

**`pixelDensity(2)` 导致的坐标系不匹配**。

Processing 4.x 在 Windows HiDPI（≥150%）环境下，`P5Engine.applyRecommendedPixelDensity()` 会自动调用 `applet.pixelDensity(2)`。这导致：

| 属性 | 100% / 125% DPI | 150% / 175% / 200% DPI |
|------|----------------|------------------------|
| `applet.width` | 1280（逻辑） | 1280（逻辑） |
| `applet.pixelWidth` | 1280（物理） | **2560**（物理） |
| `gl_FragCoord` 范围 | 0 ~ 1280 | **0 ~ 2560** |
| `app.mouseX` 范围 | 0 ~ 1280 | 0 ~ 1280（逻辑） |

`drawFlashlightGrid()` 将 `app.mouseX`（逻辑 640）和 `app.width`（逻辑 1280）直接传入 shader：

```java
flashlightShader.set("resolution", (float)dw, (float)dh);  // 1280, 720
flashlightShader.set("mouse", mx, dh - my);                // 640, 540
```

但 shader 中的 `gl_FragCoord.xy` 是**物理像素坐标**（0~2560）。当鼠标在屏幕正中央时：

- `gl_FragCoord` 实际位置 = **1280, 1440**（物理）
- shader 接收的 `mouse` = **640, 540**（逻辑）
- 差值 = **640 像素**（固定偏移）

此外，`titleCx` 的计算也存在同样问题：

```java
float titleCx = offsetX + dm.getDesignWidth() * 0.5f * scale;  // 640（逻辑）
float mx = app.mouseX;                                          // 640（逻辑）
float dx = mx - titleCx;                                        // 0（逻辑层面匹配）
```

虽然 `dx` 在逻辑层面为 0，但 shader 内部使用的是物理坐标，导致高亮中心与标题实际渲染位置（物理 1280）不匹配。

### 3.3 修复方案

**在 `drawFlashlightGrid()` 中，统一将逻辑坐标转换为物理坐标**。

通过 `app.pixelDensity` 检测是否启用了 HiDPI。如果 `pixelDensity > 1`，将所有传入 shader 的坐标、尺寸、鼠标位置统一乘以 `pixelDensity`：

```java
int pd = app.pixelDensity;
if (pd > 1) {
    titleCx *= pd;
    titleCy *= pd;
    mx *= pd;
    my *= pd;
    dw *= pd;
    dh *= pd;
    titleTextW *= pd;
    titleTextH *= pd;
    margin *= pd;
}
```

转换后：

| 变量 | 逻辑值 | 物理值（pd=2） |
|------|--------|---------------|
| `resolution` | 1280×720 | **2560×1440** |
| `mouse` | 640, 540 | **1280, 1080** |
| `titleCx` | 640 | **1280** |
| `titleCy` | 180 | **360** |
| `lightRadius` | 95 | **190** |

此时 `gl_FragCoord`（1280, 1080）与 `mouse`（1280, 1080）完全重合，网格高亮中心精确对准标题。

### 3.4 修改位置

**`examples/TowerDefenseMin2/TdMenuBg.pde`** — `drawFlashlightGrid()` 方法：

```java
static void drawFlashlightGrid(PApplet g, int dw, int dh) {
    TowerDefenseMin2 app = TowerDefenseMin2.inst;
    shenyf.p5engine.rendering.DisplayManager dm = app.engine.getDisplayManager();

    float scale = dm.getUniformScale();
    float offsetX = dm.getOffsetX();
    float offsetY = dm.getOffsetY();
    float titleCx = offsetX + dm.getDesignWidth() * 0.5f * scale;
    float titleCy = offsetY + dm.getDesignHeight() * 0.25f * scale;

    float mx = app.mouseX;
    float my = app.mouseY;

    // P2D with pixelDensity > 1 (e.g. HiDPI/Retina on Windows 150%+):
    // gl_FragCoord is in physical pixels, but mouseX/Y and width/height are logical.
    // Convert everything to physical pixels so shader coordinates match gl_FragCoord.
    int pd = app.pixelDensity;
    if (pd > 1) {
        titleCx *= pd;
        titleCy *= pd;
        mx *= pd;
        my *= pd;
        dw *= pd;
        dh *= pd;
    }

    float titleTextW = (cachedTitleWidth > 0 ? cachedTitleWidth : 300f) * scale;
    float titleTextH = 84f * scale;
    float margin = 40f * scale;
    if (pd > 1) {
        titleTextW *= pd;
        titleTextH *= pd;
        margin *= pd;
    }
    float halfW = (titleTextW * 0.5f + margin) * 0.5f;
    float halfH = (titleTextH * 0.5f + margin) * 0.5f;

    float dx = mx - titleCx;
    float dy = my - titleCy;
    float ellipseDist = PApplet.sqrt((dx * dx) / (halfW * halfW) + (dy * dy) / (halfH * halfH));

    float fadeRange = 0.8f;
    if (ellipseDist > 1f + fadeRange) return;

    float activation;
    if (ellipseDist <= 1f) {
        activation = 1.0f;
    } else {
        float t = (ellipseDist - 1f) / fadeRange;
        t = t * t * (3f - 2f * t);
        activation = 1f - t;
    }

    float lightRadius = Math.min(dw, dh) * 0.132f;

    if (flashlightShader == null) {
        flashlightShader = g.loadShader("shaders/flashlight_grid.glsl");
    }
    flashlightShader.set("resolution", (float)dw, (float)dh);
    flashlightShader.set("mouse", mx, dh - my);
    flashlightShader.set("gridSize", 40f);
    flashlightShader.set("lightRadius", lightRadius);
    flashlightShader.set("activation", activation);
    flashlightShader.set("rectSize", 0f, 0f);

    g.blendMode(PApplet.ADD);
    g.shader(flashlightShader);
    g.noStroke();
    g.fill(255);
    g.rect(0, 0, app.width, app.height);  // 注意：g.rect 使用逻辑坐标，Processing 内部会自动映射到物理帧缓冲
    g.resetShader();
    g.blendMode(PApplet.BLEND);
}
```

> **注意**：`g.rect(0, 0, app.width, app.height)` 仍使用逻辑坐标。Processing P2D 的投影矩阵会自动将逻辑坐标映射到物理帧缓冲，因此不需要修改。

---

## 四、辅助修复：DisplayManager DPI 感知

### 4.1 背景

在排查过程中，发现 `DisplayManager.onWindowResize()` 可能接收到由 Windows DPI 缩放导致的**物理窗口尺寸**（如 1920×1080），而非逻辑尺寸（1280×720）。这会导致 `uniformScale` 被错误计算为 1.5，进而影响 UI 渲染和坐标转换。

### 4.2 修复内容

**`src/main/java/shenyf/p5engine/rendering/DisplayManager.java`**：

- 新增 `dpiScaleOverride` 字段和 `setDpiScaleOverride()` 方法
- 在 `onWindowResize()` 中，如果传入的 `w`×`h` 恰好等于 **设计尺寸 × DPI 比例**，自动除回 DPI 比例，恢复为逻辑尺寸

```java
private float dpiScaleOverride = 1f;

public void onWindowResize(int w, int h) {
    if (dpiScaleOverride > 1f) {
        int dw = config.getDesignWidth();
        int dh = config.getDesignHeight();
        float ratioW = w / (float) dw;
        float ratioH = h / (float) dh;
        if (Math.abs(ratioW - dpiScaleOverride) < 0.05f && Math.abs(ratioH - dpiScaleOverride) < 0.05f) {
            w = Math.round(w / dpiScaleOverride);
            h = Math.round(h / dpiScaleOverride);
        }
    }
    this.actualWidth = w;
    this.actualHeight = h;
    recalculate();
}
```

**`src/main/java/shenyf/p5engine/core/P5Engine.java`**：

- 新增 `getSystemDpiScale()` 方法，通过 `GraphicsConfiguration.getDefaultTransform().getScaleX()` 获取系统 DPI 比例
- 在 `init()` 中将 DPI 比例注入 `DisplayManager`

```java
public static float getSystemDpiScale() {
    try {
        java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
        java.awt.GraphicsDevice device = ge.getDefaultScreenDevice();
        java.awt.GraphicsConfiguration gc = device.getDefaultConfiguration();
        java.awt.geom.AffineTransform transform = gc.getDefaultTransform();
        float scale = (float) transform.getScaleX();
        return scale > 0.5f ? scale : 1f;
    } catch (Exception e) {
        return 1f;
    }
}
```

---

## 五、验证结果

| DPI 比例 | 窗口居中 | 手电筒网格 |
|----------|----------|------------|
| 100% | ✅ | ✅ |
| 125% | ✅ | ✅ |
| 150% | ✅ | ✅ |
| 175% | ✅ | ✅ |
| 200% | ✅ | ✅ |

---

## 六、技术要点总结

| 问题 | 根因 | 解决方案 |
|------|------|----------|
| 窗口不居中 | `Screen.getWidth()`（物理）与 `applet.width`（逻辑）混用 | `GLWindow.getWidth()` 获取物理窗口尺寸匹配计算 |
| 手电筒网格偏移 | `pixelDensity(2)` 导致 `gl_FragCoord`（物理）与 `mouseX`（逻辑）坐标系不匹配 | 在传入 shader 前统一乘以 `pixelDensity` 转换为物理坐标 |
| DisplayManager 缩放错误 | `windowResize()` 可能收到物理尺寸 | DPI 比例检测 + 自动除回逻辑尺寸 |

---

## 七、注意事项

1. **`g.rect()` 仍使用逻辑坐标**：Processing P2D 的投影矩阵会自动处理逻辑→物理的映射，因此 `g.rect(0, 0, app.width, app.height)` 不需要修改。
2. **其他自定义 shader**：如果项目中有其他直接使用 `gl_FragCoord` 的 shader，也需要检查是否存在类似的逻辑/物理坐标不匹配问题。
3. **AWT fallback**：`WindowManager.centerWindow()` 的 AWT 分支（`Frame.setLocation()`）使用逻辑坐标，与 AWT `GraphicsConfiguration.getBounds()` 匹配，无需修改。
