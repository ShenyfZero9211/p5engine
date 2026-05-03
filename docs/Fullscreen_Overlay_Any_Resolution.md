# 全屏覆盖层适配任意分辨率的技术方案

> 文档版本: 1.0  
> 适用版本: p5engine 0.1.0-M1, Processing 4.5.2  
> 创建时间: 2026-05-03

---

## 1. 问题背景

p5engine 使用 `DisplayManager` 管理屏幕分辨率适配，默认采用 **FIT 模式**（等比缩放）：

- 设计分辨率（Design Resolution）固定为 `1280×720`
- 实际窗口/屏幕分辨率可以是任意比例（16:9、4:3、21:9 等）
- `DisplayManager` 自动计算 `uniformScale`、`offsetX`、`offsetY`，确保设计内容完整显示且不变形

FIT 模式的变换矩阵为：

```
translate(offsetX, offsetY)
scale(uniformScale, uniformScale)
```

其中：
- `uniformScale = min(actualWidth / designWidth, actualHeight / designHeight)`
- `offsetX = (actualWidth - designWidth * uniformScale) / 2`
- `offsetY = (actualHeight - designHeight * uniformScale) / 2`

**问题**：任何在 FIT 坐标系中绘制的图形，都会被上述矩阵变换。如果直接用设计坐标的尺寸（如 `1280×720`）绘制覆盖层，在非 16:9 分辨率下会出现黑边或未覆盖区域。

---

## 2. 典型故障现象

以 `WinLoseTextAnimator`（胜利/失败动画的黑色透明层）为例：

| 分辨率 | 设计坐标尺寸 | 实际覆盖区域 | 结果 |
|--------|-------------|-------------|------|
| 1280×720 (16:9) | 1280×720 | 1280×720 | ✅ 全屏 |
| 1280×960 (4:3) | 1280×960 | 1280×720 (被 FIT 偏移) | ❌ 上下黑边 |
| 1920×1080 (16:9) | 1920×1080 | 1920×1080 | ✅ 全屏 |

**根因**：`g.rect(0, 0, g.width, g.height)` 虽然使用了实际画布尺寸，但由于当前矩阵存在 `translate(offsetX, offsetY)`，矩形被偏移到了设计区域的位置，而非物理屏幕的 `(0, 0)` 起点。

---

## 3. 核心解决方案

### 3.1 原理

要绘制真正全屏的覆盖层，必须**绕过 FIT 坐标系的变换矩阵**，直接在**物理屏幕像素坐标系**（即 PGraphics 的原始坐标系）中绘制。

Processing/p5engine 提供了矩阵栈操作来实现这一点：

```java
g.pushMatrix();      // 保存当前 FIT 矩阵
g.resetMatrix();     // 重置为单位矩阵（无 translate/scale）
// ... 在物理像素坐标系中绘制 ...
g.popMatrix();       // 恢复 FIT 矩阵
```

### 3.2 关键代码

```java
// 绘制全屏黑色透明层
g.noStroke();
g.fill(0xFF000000, dimAlpha);
g.pushMatrix();
g.resetMatrix();
g.rect(0, 0, g.width, g.height);  // g.width/g.height = 物理画布尺寸
g.popMatrix();
```

### 3.3 为什么用 g.width/g.height

| 属性 | 含义 | 使用场景 |
|------|------|---------|
| `g.width` / `g.height` | 物理画布像素尺寸 | ✅ 全屏覆盖层、屏幕截图 |
| `dm.getDesignWidth()` / `dm.getDesignHeight()` | 设计逻辑分辨率（1280×720） | UI 布局、设计坐标定位 |
| `dm.getActualWidth()` / `dm.getActualHeight()` | 实际窗口像素尺寸 | 与操作系统交互、窗口管理 |

**注意**：在 `resetMatrix()` 后的坐标系中，`g.width/g.height` 与 `dm.getActualWidth()/Height` 通常相同，但 `g.width/g.height` 更直接，不依赖 DisplayManager。

---

## 4. 完整使用示例

### 4.1 胜利/失败动画覆盖层（WinLoseTextAnimator）

```java
void render(PGraphics g, float cx, float cy) {
    if (phase == Phase.DONE) return;

    // 1. 计算透明度
    int dimAlpha = ...;

    // 2. 绘制全屏黑色透明层（物理像素坐标系）
    g.noStroke();
    g.fill(0xFF000000, dimAlpha);
    g.pushMatrix();
    g.resetMatrix();
    g.rect(0, 0, g.width, g.height);  // 覆盖整个物理屏幕
    g.popMatrix();

    // 3. 绘制文本（继续在 FIT 坐标系中，保持与设计分辨率一致）
    g.textAlign(PApplet.CENTER, PApplet.CENTER);
    g.textSize(56);
    g.fill(0xFFFFFFFF);
    g.text(text, cx, cy);
}
```

### 4.2 调用方代码

```java
// TdAppCore.pde 的 draw() 中
app.pushMatrix();
app.translate(dm.getOffsetX(), dm.getOffsetY());
app.scale(dm.getUniformScale(), dm.getUniformScale());

// ... 其他 UI 绘制 ...

// Win/Lose 动画（内部自己处理矩阵）
if (TdFlow.winLoseAnimator != null) {
    TdFlow.winLoseAnimator.render(app.g, 
        dm.getDesignWidth() * 0.5f, 
        dm.getDesignHeight() * 0.5f - 40);
}

app.popMatrix();
```

### 4.3 暂停菜单覆盖层（已正确处理）

```java
// TdFlow.pde showPauseMenu()
Panel overlay = new Panel("pause_overlay") {
    @Override
    public void paint(PApplet applet, Theme theme) {
        applet.fill(0x66000000);
        applet.noStroke();
        // paint() 在 Panel 自己的坐标系中执行，Panel 被设置为全屏尺寸
        applet.rect(getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight());
    }
};
// 设置 Panel 尺寸为 FIT 缩放后的全屏逻辑尺寸
float w = dm.getActualWidth() / dm.getUniformScale();
float h = dm.getActualHeight() / dm.getUniformScale();
overlay.setBounds(0, 0, w, h);
```

**注意**：暂停菜单的覆盖层采用的是另一种方案——将 Panel 尺寸设为 FIT 坐标系中的全屏逻辑尺寸（`actual / uniformScale`），这样 Panel 会自动填满整个可视区域。这是 UI 组件的推荐做法。

---

## 5. 两种方案的对比与选型

| 方案 | 实现方式 | 适用场景 | 优点 | 缺点 |
|------|---------|---------|------|------|
| **A. pushMatrix/resetMatrix** | 在 render 中临时重置矩阵 | 自定义 Renderer、直接操作 PGraphics | 精确控制物理像素，不受 UI 层级影响 | 需要手动管理矩阵，不适合复杂 UI |
| **B. UI Panel 全屏尺寸** | Panel.setBounds(0, 0, w, h) | UI 框架内的覆盖层（暂停菜单、弹窗） | 与 UI 系统集成，支持事件、动画 | 需要计算 FIT 坐标系中的全屏尺寸 |

### 方案选型建议

- **自定义 Renderer 直接绘制**（如 `WinLoseTextAnimator`、`EnemyHpBarRenderer`）→ 用 **方案 A**
- **UI 框架内的 Panel/Window**（如暂停菜单、设置面板）→ 用 **方案 B**

---

## 6. 常见陷阱

### 陷阱 1：使用设计分辨率绘制覆盖层

```java
// ❌ 错误：在 FIT 坐标系中用设计分辨率画全屏矩形
g.rect(0, 0, 1280, 720);  // 只在 16:9 下全屏，其他比例会留黑边
```

### 陷阱 2：使用 g.width/g.height 但不 resetMatrix

```java
// ❌ 错误：尺寸对了，但坐标系有 offset/scale
g.rect(0, 0, g.width, g.height);  // 被 FIT 矩阵偏移/缩放，不在 (0,0)
```

### 陷阱 3：在 resetMatrix 后用设计坐标画 UI

```java
// ❌ 错误：文本位置在物理像素坐标系中，不在 FIT 坐标系中
g.pushMatrix();
g.resetMatrix();
g.rect(0, 0, g.width, g.height);
g.text("Victory!", 640, 320);  // 640x320 是物理像素，不是设计坐标
g.popMatrix();
```

### 陷阱 4：UI Panel 坐标未补偿 root 偏移

```java
// ❌ 错误：直接用 actualToDesign 设置 Panel 位置
Vector2 designMouse = dm.actualToDesign(new Vector2(app.mouseX, app.mouseY));
 panel.setBounds((int)designMouse.x, (int)designMouse.y, 100, 120);  // 在 21:9 下偏左 offsetX 像素，在 4:3 下偏上 offsetY 像素
```

---

## 7. UI 框架坐标系转换

### 7.1 背景：UI root 的负偏移

p5engine 的 UI 框架（`UIManager`）为了处理 FIT letterboxing，将 root Panel 的 bounds 设为：

```java
float ox = dm.getOffsetX() / dm.getUniformScale();
float oy = dm.getOffsetY() / dm.getUniformScale();
root.setBounds(-ox, -oy, actualWidth / scale, actualHeight / scale);
```

这使得 UI 组件在设计坐标系中拥有比 `1280×720` 更大的绘制区域，能够覆盖整个物理屏幕（包括黑边区域）。

**副作用**：任何通过 `actualToDesign()` 转换的坐标（相对于设计原点），直接作为 Panel 的 `setBounds()` 参数时，会因为 root 的负偏移而产生位置偏差。

### 7.2 正确转换：物理像素 → UI 框架坐标

将鼠标或任意物理屏幕坐标转换为 UI 框架中的正确 Panel 坐标：

```java
float ox = dm.getOffsetX() / dm.getUniformScale();
float oy = dm.getOffsetY() / dm.getUniformScale();
Vector2 design = dm.actualToDesign(new Vector2(mouseX, mouseY));
float panelX = design.x + ox;
float panelY = design.y + oy;
panel.setBounds((int)panelX, (int)panelY, w, h);
```

### 7.3 右键菜单案例

以 `TdAppCore.pde showSellMenu()` 为例：

```java
DisplayManager dm = app.engine.getDisplayManager();
Vector2 designMouse = dm.actualToDesign(new Vector2(app.mouseX, app.mouseY));
float ox = dm.getOffsetX() / dm.getUniformScale();
float oy = dm.getOffsetY() / dm.getUniformScale();
app.sellMenuPanel.setBounds(
    (int)(designMouse.x + ox),
    (int)(designMouse.y + oy),
    100, 120
);
```

| 分辨率 | `offsetX` | `offsetY` | 未修复偏移 | 修复后 |
|--------|-----------|-----------|-----------|-------|
| 1280×720 (16:9) | 0 | 0 | ✅ 正确 | ✅ 正确 |
| 1280×960 (4:3) | 0 | 120 | 偏上 120px | ✅ 正确 |
| 2560×1080 (21:9) | 320 | 0 | 偏左 320px | ✅ 正确 |

---

## 8. 调试技巧

在排查覆盖层显示问题时，输出关键尺寸信息：

```java
DisplayManager dm = TowerDefenseMin2.inst.engine.getDisplayManager();
println("[Debug] actual=" + dm.getActualWidth() + "x" + dm.getActualHeight()
    + " design=" + dm.getDesignWidth() + "x" + dm.getDesignHeight()
    + " scale=" + dm.getUniformScale()
    + " offset=(" + dm.getOffsetX() + "," + dm.getOffsetY() + ")"
    + " g=" + g.width + "x" + g.height);
```

典型输出（4:3 分辨率）：
```
[Debug] actual=1280x960 design=1280x720 scale=1.0 offset=(0.0,120.0) g=1280x960
```

从输出可以看出 `offsetY=120`，这就是 FIT 模式在 4:3 屏幕上的上下黑边高度。

---

## 8. 相关文件

- `examples/TowerDefenseMin2/TdFlow.pde` — `WinLoseTextAnimator`
- `examples/TowerDefenseMin2/TdAppCore.pde` — 主绘制循环、FIT 矩阵设置
- `src/main/java/shenyf/p5engine/rendering/DisplayManager.java` — 分辨率适配核心

---

## 9. 总结

| 要点 | 说明 |
|------|------|
| FIT 坐标系 | 经过 `translate(offset) + scale(uniform)` 变换的坐标系，用于 UI 布局 |
| 物理像素坐标系 | PGraphics 原始坐标系，`(0,0)` 对应屏幕左上角 |
| 全屏覆盖层 | 必须在物理像素坐标系中绘制，使用 `pushMatrix/resetMatrix/popMatrix` |
| 尺寸取值 | 使用 `g.width/g.height`（物理画布尺寸），不要用设计分辨率 |
| 文本/UI 定位 | 仍在 FIT 坐标系中进行，保持与设计分辨率一致 |
