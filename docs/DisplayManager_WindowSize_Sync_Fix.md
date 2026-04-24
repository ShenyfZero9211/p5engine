# DisplayManager 窗口尺寸同步问题修复总结

## 问题描述

`P5Engine.create()` 在 `setup()` 中执行时，`applet.width/height` 还是 Processing 的默认值 `800×600`，导致 `DisplayManager` 按 `800×600` 计算了缩放和偏移。但 `settings()` 中的 `size(1280, 720)` 随后把窗口调整为 `1280×720`，造成 `actualToDesign()` 和 `designToActual()` 基于错误的尺寸计算，产生坐标偏差。

### 具体表现

- `DisplayManager` 初始化时 `actualWidth/Height = 800×600`
- `settings()` 后窗口实际变为 `1280×720`
- `ScaleMode.FIT` 下计算出的 `scale=0.625`、`offsetY=75`
- 所有鼠标坐标转换（`actualToDesign` → `screenToWorld` → `worldToScreen` → `designToActual`）都基于错误的缩放参数
- 结果是：洋十字验证（`worldToScreen` 回 `designToActual`）能回到鼠标位置（因为它用同一套错误参数互逆），但离屏 buffer 中用 `renderCam` 渲染的内容（buffer 尺寸是实际的 `1280×720`，不经过 `DisplayManager` 缩放）与主屏幕的坐标系不一致，导致视觉偏移

## 根因

Processing 的 `settings()` 在 `setup()` 之前执行，`size(1280, 720)` 设置了窗口尺寸，但 `P5Engine.create(this)` 在 `setup()` 中调用时，`applet.width/height` 可能尚未反映最终尺寸（取决于 Processing 的初始化时序）。`DisplayManager` 在 `P5Engine` 构造函数中捕获了此时的 `width/height`，之后不再自动更新。

## 修复方法

在 `setup()` 末尾、所有 UI 组件初始化完成后，手动调用 `DisplayManager.onWindowResize()` 强制同步实际窗口尺寸：

```java
void setup() {
    // ... P5Engine.create(), UI 初始化, WorldViewport 创建 ...
    
    // CRITICAL FIX: sync DisplayManager to actual window size.
    // P5Engine.create() may have captured the default 800x600 size before
    // settings()/size() took effect. Force a resize sync now.
    engine.getDisplayManager().onWindowResize(width, height);
}
```

## 验证

修复后日志显示：
```
DisplayManager scale=1.0 offset=(0.0,0.0)
```

坐标转换链条恢复正常，红色高亮格子精确跟随鼠标。

## 影响范围

此问题影响所有使用 `ScaleMode.FIT` 或 `ScaleMode.FILL` 且 `settings()` 中 `size()` 与 `P5Config` 默认值不一致的示例。建议在 `setup()` 末尾统一添加 `onWindowResize` 同步调用。

## 相关文件

- `src/main/java/shenyf/p5engine/rendering/DisplayManager.java`
- `src/main/java/shenyf/p5engine/core/P5Engine.java`
- `examples/ViewportGridTest/ViewportGridTest.pde`
- `examples/TowerDefenseMin/TowerDefenseMin.pde`
