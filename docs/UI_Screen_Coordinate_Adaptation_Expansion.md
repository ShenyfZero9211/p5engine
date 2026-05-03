# p5engine UI 屏幕坐标适配引擎扩建技术报告

> 文档版本: 1.0  
> 适用版本: p5engine 0.1.0-M1, Processing 4.5.2  
> 创建时间: 2026-05-02

---

## 1. 问题背景

p5engine 的 UI 系统基于 **保留模式（Retained Mode）** 组件树，在 **即时模式（Immediate Mode）** 的 Processing 渲染管线之上运行。`DisplayManager` 负责将固定的设计分辨率 `1280×720` 通过 FIT 等比缩放到任意实际窗口尺寸，并在非 16:9 比例下产生 letterbox（黑边）。

### 1.1 FIT 模式下的坐标体系

```
translate(offsetX, offsetY)
scale(uniformScale, uniformScale)
```

其中：
- `uniformScale = min(actualWidth / 1280, actualHeight / 720)`
- `offsetX = (actualWidth - 1280 × uniformScale) / 2`
- `offsetY = (actualHeight - 720 × uniformScale) / 2`

### 1.2 已有的正确路径 vs. 错误路径

| 路径 | 转换方式 | 结果 | 正确性 |
|------|---------|------|--------|
| **UI 内部事件**（mouseEvent） | `actualToDesign()` → `root.hitTest()` | 命中检测正确 | ✅ 正确 |
| **外部代码直接 setBounds**（如右键菜单） | `actualToDesign()` → `panel.setBounds()` | 非 16:9 下出现偏移 | ❌ 错误 |

**根因**：`UIManager.update()` 将 root 设置在 `(-ox, -oy)` 以覆盖整个物理窗口。`actualToDesign()` 返回的是以设计区域左上角 `(0,0)` 为原点的坐标，而 UI 组件在 root 树中的位置需要以 root 原点 `(-ox, -oy)` 为基准。两者相差的正是 `(ox, oy)`。

### 1.3 已有的临时解决方案

在 `TowerDefenseMin2` 示例中，我们通过 `TdOverlay.pde` 中的 `UiCoords.fromActual()` 手动补偿了该偏移：

```java
static Vector2 fromActual(DisplayManager dm, float actualX, float actualY) {
    float scale = dm.getUniformScale();
    float ox = dm.getOffsetX() / scale;
    float oy = dm.getOffsetY() / scale;
    Vector2 design = dm.actualToDesign(new Vector2(actualX, actualY));
    return new Vector2(design.x + ox, design.y + oy);
}
```

这种方式虽然工作，但存在明显缺陷：
- 每个使用 UI 系统的项目都需要重复编写同样的补偿逻辑
- 代码散落在 PDE 示例中，无法被引擎统一维护
- 开发者容易遗漏补偿，导致 UI 在非 16:9 分辨率下错位
- 缺乏从 UI 坐标反向转换到屏幕坐标的 API

---

## 2. 坐标系统数学分析

### 2.1 三个坐标空间

在 FIT 模式下，系统同时存在三个坐标空间：

| 坐标空间 | 原点 | 单位 | 用途 |
|---------|------|------|------|
| **Physical Screen**（物理屏幕） | 窗口左上角 `(0,0)` | 像素 | 鼠标输入、物理像素绘制 |
| **Design Resolution**（设计分辨率） | FIT 区域左上角 `(0,0)` | 设计单位 | `DisplayManager` 转换、旧版 UI API |
| **UI Root Internal**（UI 内部） | root 左上角 `(-ox, -oy)` | 设计单位 | UI 组件 `setBounds()`、`hitTest()` |

### 2.2 坐标转换公式

**物理屏幕 → 设计分辨率**（由 `DisplayManager` 提供）：
```
designX = (screenX - offsetX) / scale
designY = (screenY - offsetY) / scale
```

**设计分辨率 → 物理屏幕**（由 `DisplayManager` 提供）：
```
screenX = designX × scale + offsetX
screenY = designY × scale + offsetY
```

**设计分辨率 → UI Root Internal**（核心补偿逻辑）：
```
uiX = designX + ox   // ox = offsetX / scale
uiY = designY + oy   // oy = offsetY / scale
```

推导：`root.x = -ox`，组件在 root 内部的绝对位置 = `root.x + uiX = -ox + uiX`。而 `containsPoint` 使用的正是这个绝对位置。因此 `actualToDesign` 得到 `designX` 后，需要 `+ox` 才能得到 root 内部的正确坐标。

**UI Root Internal → 设计分辨率**：
```
designX = uiX - ox
designY = uiY - oy
```

### 2.3 为什么 `screenToUi` 等价于 `screen / scale`

将 `actualToDesign` 代入补偿公式：
```
uiX = (screenX - offsetX) / scale + offsetX / scale
    = screenX / scale - offsetX / scale + offsetX / scale
    = screenX / scale
```

这说明：由于 root 被精确设置在 `(-ox, -oy)`，UI root 内部坐标与物理像素之间仅相差一个 `uniformScale` 因子。但这个结论成立的前提是 **root 必须正确更新**——如果开发者手动调用 `actualToDesign` 后忘记 `+ox/+oy` 补偿，就会出现偏移。

### 2.4 数值验证

以窗口 `1920×1200`（16:10）为例：
- `scale = min(1920/1280, 1200/720) = 1.5`
- 设计尺寸：`1280×1.5 = 1920`, `720×1.5 = 1080`
- `offsetX = 0`, `offsetY = (1200-1080)/2 = 60`
- `ox = 0`, `oy = 60/1.5 = 40`
- root bounds：`(-0, -40, 1280, 800)`

| 物理坐标 | actualToDesign | +ox/+oy (screenToUi) | root 内部含义 |
|---------|---------------|---------------------|--------------|
| `(0, 0)` | `(0, -40)` | `(0, 0)` | 物理屏幕左上角 |
| `(960, 600)` | `(640, 360)` | `(640, 400)` | 屏幕中心偏下（因 16:10 更高） |
| `(1920, 1200)` | `(1280, 760)` | `(1280, 800)` | 物理屏幕右下角 |

验证反向：
- `uiToScreen(640, 400)` = `designToActual(640-0, 400-40)` = `designToActual(640, 360)` = `(640×1.5+0, 360×1.5+60)` = `(960, 600)` ✅

---

## 3. 引擎扩建设计

### 3.1 设计目标

1. **消除重复代码**：将坐标补偿逻辑收拢到引擎内部
2. **双向转换**：同时支持 `screen→ui` 和 `ui→screen`
3. **向后兼容**：现有基于设计坐标的老代码完全不受影响
4. **API 一致性**：提供与 UI 组件直接集成的便捷方法
5. **Bug 修复**：解决 `keyEvent` 中鼠标坐标传递错误

### 3.2 不涉及的内容

- **不改变 FIT 缩放模型**：设计分辨率仍然是 `1280×720`，所有 UI 布局继续使用设计单位
- **不修改现有组件行为**：`setBounds(float, float, float, float)` 语义不变
- **不影响 `ScreenOverlay` 模式**：物理像素直接绘制仍然通过 `pushMatrix/resetMatrix` 实现

---

## 4. 具体实现

### 4.1 UIManager.java — 新增屏幕坐标 API

#### `screenToUi(float screenX, float screenY)`

将物理屏幕像素坐标转换为 UI root 内部坐标，可直接用于 `setBounds` / `setPosition`。

```java
public Vector2 screenToUi(float screenX, float screenY) {
    if (displayManager != null && displayManager.getScaleMode() != ScaleMode.NO_SCALE) {
        float scale = displayManager.getUniformScale();
        float ox = displayManager.getOffsetX() / scale;
        float oy = displayManager.getOffsetY() / scale;
        Vector2 design = displayManager.actualToDesign(
            new Vector2(screenX, screenY));
        return new Vector2(design.x + ox, design.y + oy);
    }
    return new Vector2(screenX, screenY);
}
```

- `NO_SCALE` 模式下直接返回输入，保持行为一致
- 内部复用 `actualToDesign` + `ox/oy` 补偿，与 `UiCoords.fromActual()` 逻辑等价

#### `uiToScreen(float uiX, float uiY)`

将 UI root 内部坐标转换回物理屏幕像素。

```java
public Vector2 uiToScreen(float uiX, float uiY) {
    if (displayManager != null && displayManager.getScaleMode() != ScaleMode.NO_SCALE) {
        float scale = displayManager.getUniformScale();
        float ox = displayManager.getOffsetX() / scale;
        float oy = displayManager.getOffsetY() / scale;
        return displayManager.designToActual(
            new Vector2(uiX - ox, uiY - oy));
    }
    return new Vector2(uiX, uiY);
}
```

#### 查询 API

```java
public float getUiWidth()    // root.getWidth()  — 覆盖全窗的设计单位宽度
public float getUiHeight()   // root.getHeight() — 覆盖全窗的设计单位高度
public float getUiOffsetX()  // root.getX()      — 通常为 -ox（负值表示左黑边）
public float getUiOffsetY()  // root.getY()      — 通常为 -oy（负值表示上黑边）
```

#### `createPanelAtScreen(String id, float screenX, float screenY, float w, float h)`

便捷工厂方法，直接按物理屏幕位置创建 Panel：

```java
public Panel createPanelAtScreen(String id, float screenX, float screenY, float w, float h) {
    Vector2 uiPos = screenToUi(screenX, screenY);
    Panel p = panel(id);
    p.setBounds(uiPos.x, uiPos.y, w, h);
    return p;
}
```

### 4.2 UIComponent.java — 组件级便捷方法

#### `setScreenPosition(UIManager ui, float screenX, float screenY)`

```java
public void setScreenPosition(UIManager ui, float screenX, float screenY) {
    Vector2 uiPos = ui.screenToUi(screenX, screenY);
    setPosition(uiPos.x, uiPos.y);
}
```

#### `setScreenBounds(UIManager ui, float screenX, float screenY, float w, float h)`

```java
public void setScreenBounds(UIManager ui, float screenX, float screenY, float w, float h) {
    Vector2 uiPos = ui.screenToUi(screenX, screenY);
    setBounds(uiPos.x, uiPos.y, w, h);
}
```

这两个方法让任何已有 UI 组件都可以一键切换到屏幕坐标定位，无需手动调用 `screenToUi`。

### 4.3 keyEvent Bug 修复

**问题**：`keyEvent()` 中向键盘事件处理器传递的是 `applet.mouseX/Y`（原始物理像素），而 `onEvent()` 的 `absMouseX/Y` 参数在 UI 体系内被假定为 **设计坐标**。

```java
// 修复前（错误）
f.onEvent(UIEvent.key(...), applet.mouseX, applet.mouseY);

// 修复后（正确）
f.onEvent(UIEvent.key(...), designMouseX, designMouseY);
```

`designMouseX/Y` 是 `UIManager.update()` 每帧更新的静态变量，已经过 `actualToDesign` 转换，与 `mouseEvent()` 中使用的坐标体系一致。这确保了：
- 键盘触发的下拉菜单弹出位置正确
- `TextInput` 等组件的鼠标相关逻辑在键盘事件中获得一致坐标

---

## 5. 使用示例

### 5.1 场景：在物理屏幕右上角创建一个 200×100 的浮动提示

**旧方式（手动补偿，易出错）**：
```java
float scale = dm.getUniformScale();
float ox = dm.getOffsetX() / scale;
float oy = dm.getOffsetY() / scale;
Vector2 design = dm.actualToDesign(new Vector2(width - 210, 10));
Panel tip = ui.panel("tip");
tip.setBounds(design.x + ox, design.y + oy, 200, 100);
```

**新方式（引擎 API）**：
```java
Panel tip = ui.createPanelAtScreen("tip", width - 210, 10, 200, 100);
```

或：
```java
Panel tip = ui.panel("tip");
tip.setScreenBounds(ui, width - 210, 10, 200, 100);
```

### 5.2 场景：将已有组件移动到鼠标点击的屏幕位置

```java
// 在 mousePressed 中
Button btn = ui.button("popup_btn");
btn.setScreenPosition(ui, mouseX, mouseY);
```

### 5.3 场景：创建一个覆盖整个物理窗口的遮罩层

```java
Panel overlay = ui.panel("overlay");
overlay.setScreenBounds(ui, 0, 0, ui.getUiWidth(), ui.getUiHeight());
overlay.setBackgroundColor(0x88000000);
```

注意：`ui.getUiWidth()` 返回的是设计单位宽度（`actualWidth / scale`），恰好等于覆盖全窗所需的设计单位尺寸。

### 5.4 场景：已知 UI 组件位置，获取其在屏幕上的物理像素位置

```java
// 获取 Panel 左上角在屏幕上的物理像素坐标
float absX = panel.getAbsoluteX();
float absY = panel.getAbsoluteY();
Vector2 screenPos = ui.uiToScreen(absX, absY);
```

---

## 6. 向后兼容性

### 6.1 零破坏变更

| 原有 API | 状态 | 说明 |
|---------|------|------|
| `setBounds(x, y, w, h)` | 完全保留 | 语义不变，仍接受设计单位 |
| `setPosition(x, y)` | 完全保留 | 语义不变 |
| `actualToDesign()` / `designToActual()` | 完全保留 | `DisplayManager` 行为不变 |
| 所有 UI 组件内部事件 | 完全保留 | `mouseEvent` 已有正确路径不受影响 |

### 6.2 新增 API 清单

| 新增 API | 所在类 | 用途 |
|---------|--------|------|
| `screenToUi(x, y)` | `UIManager` | 屏幕 → UI 坐标 |
| `uiToScreen(x, y)` | `UIManager` | UI → 屏幕坐标 |
| `getUiWidth()` | `UIManager` | 查询 UI root 宽度 |
| `getUiHeight()` | `UIManager` | 查询 UI root 高度 |
| `getUiOffsetX()` | `UIManager` | 查询 UI root X 偏移 |
| `getUiOffsetY()` | `UIManager` | 查询 UI root Y 偏移 |
| `createPanelAtScreen(...)` | `UIManager` | 屏幕坐标创建 Panel |
| `setScreenPosition(ui, x, y)` | `UIComponent` | 屏幕坐标设置位置 |
| `setScreenBounds(ui, x, y, w, h)` | `UIComponent` | 屏幕坐标设置边界 |

### 6.3 旧临时方案的迁移建议

如果项目中已有类似 `UiCoords.fromActual()` 的手动补偿代码，可以逐步替换为引擎 API：

| 旧代码 | 新代码 |
|--------|--------|
| `UiCoords.fromActual(dm, x, y)` | `ui.screenToUi(x, y)` |
| `UiCoords.setFullscreenBounds(panel, dm)` | `panel.setScreenBounds(ui, 0, 0, ui.getUiWidth(), ui.getUiHeight())` |

`TdOverlay.pde` 中的 `UiCoords` 类可保留作为向后兼容包装，或在确认无其他依赖后逐步弃用。

---

## 7. 验证结果

- `compile-jar.ps1` — 引擎编译通过 ✅
- Processing CLI build (`TowerDefenseMin2`) — PDE 编译通过 ✅
- 坐标转换双向验证：
  - `screenToUi(0, 0)` → `(0, 0)`（16:10 下 root 左上角对齐物理屏幕左上角）
  - `uiToScreen(640, 400)` → `(960, 600)`（屏幕中心点往返一致）
- `keyEvent` 修复后，键盘事件中的鼠标坐标与设计坐标体系一致 ✅

---

## 8. 相关文件

### 引擎层（修改）
- `src/main/java/shenyf/p5engine/ui/UIManager.java`
  - 新增 `screenToUi()`、`uiToScreen()`、`getUiWidth()`、`getUiHeight()`、`getUiOffsetX()`、`getUiOffsetY()`、`createPanelAtScreen()`
  - 修复 `keyEvent()` 鼠标坐标传递
- `src/main/java/shenyf/p5engine/ui/UIComponent.java`
  - 新增 `setScreenPosition()`、`setScreenBounds()`

### 引擎层（未修改，被依赖）
- `src/main/java/shenyf/p5engine/rendering/DisplayManager.java`
  - 提供 `actualToDesign()` / `designToActual()` / `getUniformScale()` / `getOffsetX/Y()`
- `src/main/java/shenyf/p5engine/math/Vector2.java`
  - 坐标传递的数据载体

### 游戏层（现有临时方案，可作为迁移参考）
- `examples/TowerDefenseMin2/TdOverlay.pde`
  - `ScreenOverlay` 类：物理像素直接绘制工具
  - `UiCoords` 类：手动坐标补偿实现（可被引擎 API 替代）

---

## 9. 技术边界与注意事项

1. **仅在 `ScaleMode.FIT` / `ScaleMode.FILL` 下有效**：`NO_SCALE` 模式下 `screenToUi` 直接透传，逻辑等价
2. **root 必须已更新**：`screenToUi` 依赖 `DisplayManager` 的当前状态，调用前应确保 `UIManager.update()` 至少执行过一次（通常在 `draw()` 中已满足）
3. **宽高参数仍为设计单位**：`createPanelAtScreen` 和 `setScreenBounds` 中的 `w, h` 参数仍然使用 **设计单位**，只有 `x, y` 使用屏幕像素。这是有意为之——UI 组件的尺寸在设计阶段确定，位置在运行时根据屏幕确定
4. **锚点系统互不干扰**：使用 `setScreenBounds()` 设置的组件仍然可以拥有 anchor 标志，但 anchor 的重新计算会在下一帧 `update()` 中覆盖手动设置的值。如果需要固定屏幕位置，应清除 anchor（`setAnchor(0)`）
