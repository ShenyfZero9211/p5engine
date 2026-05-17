# 离屏渲染后的 FIT 自适应缩放

> 记录 `TdLevelList` / `LevelCarousel` 使用离屏 PGraphics buffer + GLSL shader 时，如何保持 FIT 缩放一致性的设计与实现。

---

## 1. 问题描述

关卡选择界面的卡片列表（`TdLevelList`）使用离屏 `PGraphics` buffer 渲染，并通过 GLSL shader 实现左右边缘淡出效果。但在导出后的 EXE 中（或任意非 1:1 分辨率下），关卡卡片内部的视觉元素（绿色徽章、选中发光边框、hover 高亮、圆角、描边粗细等）没有正确随 FIT 缩放，表现为：

- 徽章、锁图标、勾线偏小
- 发光边框、圆角、strokeWeight 与设计尺寸不成比例
- 整体视觉在高分屏上显得"干瘪"

---

## 2. 根因分析

### 2.1 正常 UI 绘制流程（无离屏 buffer）

```
TdAppCore.draw()
  └─ app.scale(uniformScale)          ← FIT 缩放 applied to applet.g
       └─ UIManager.render()
            └─ root.paint(applet.g)
                 └─ TdLevelCard.paint(applet.g)
```

在 `TdLevelCard.paint()` 中：
- `getWidth() = 220`，`getHeight() = 240` → **设计坐标**
- `margin = 6`，`radius = 4` → **设计坐标**
- 由于 `applet.g` 已被 `scale(uniformScale)`，所有设计坐标自动映射到 screen pixel
- `margin = 6` 在 1.5× FIT 下实际占用 **9 像素** ✅

### 2.2 离屏 buffer 绘制流程（修改前）

```
TdLevelList.paint()
  ├─ buffer = createGraphics(w * scale, h * scale, JAVA2D)   ← screen pixel 分辨率
  ├─ card.setSize(savedW * scale, savedH * scale)             ← 手动放大子组件
  ├─ applet.g = buffer
  ├─ paintChildren() → TdLevelCard.paint(buffer)
  │     └─ margin = 6 直接画进 buffer（screen pixel）
  └─ applet.image(snapshot, ax, ay, w, h)                    ← 1:1 贴回
```

关键差异：

| 步骤 | 正常流程 | 离屏 buffer 流程（修改前） |
|------|----------|---------------------------|
| 绘制上下文 | `applet.g` 已 `scale(uniformScale)` | `buffer` 是原生像素，无 matrix 缩放 |
| 子组件尺寸 | 设计坐标（220×240） | 手动放大到 screen pixel（330×360） |
| 硬编码值 | 设计坐标，被 FIT 自动放大 | 被当作 screen pixel 直接写入 |
| margin=6 最终像素 | `6 * uniformScale` | `6`（漏掉了 FIT 放大） |

**数学结论**：离屏 buffer 渲染中，硬编码像素值被直接写入高分辨率 buffer，然后 buffer 1:1 贴回屏幕，导致所有固定值相对于设计尺寸缩小了 `1/uniformScale` 倍。

### 2.3 为什么 `LevelCarousel` 没有这个问题？

`LevelCarousel.paintSelf()` 中：
- `buffer = createGraphics((int)w, (int)h, JAVA2D)` → **设计坐标大小**
- `drawCards(buffer)` 使用设计坐标绘制
- `applet.image(snapshot, ax, ay)` → 在 FIT 缩放的 `applet.g` 上绘制，buffer 被自动放大

因此 `LevelCarousel` 天然保持 FIT 一致性，无需额外处理。

---

## 3. 修复方案

### 3.1 核心原则：分层解耦

| 层级 | 职责 | 实现位置 |
|------|------|----------|
| **FIT 自适应缩放** | 将设计坐标统一映射到 screen pixel | `DisplayManager` → `TdLevelList.paint()` 内 `buffer.scale(uniformScale)` |
| **Carousel 相对缩放** | 中心卡片大、两侧卡片小的动态效果 | `TdLevelList.layoutCards()` → `setSize()` + `TdLevelCard` 内 `cardScale = w/220f` |

两层互不干涉：
- FIT 缩放由 UI 系统/离屏 buffer 统一处理
- Carousel 缩放由组件内部根据当前实际尺寸比例自适应

### 3.2 TdLevelList.paint() 修改

**修改前**：手动把子组件放大到 screen pixel，然后直接绘制到 buffer。

**修改后**：子组件保持设计坐标，在 buffer 内恢复 FIT 缩放。

```java
// 移除：手动缩放子组件的循环
// for (...) { card.setPosition(savedX * scale, savedY * scale); ... }

// 绘制到 buffer 时恢复 FIT 缩放
buffer.beginDraw();
buffer.background(0, 0);
buffer.scale(scale);           // ← 关键：恢复 FIT 缩放
paintChildren(applet, theme);
buffer.endDraw();
```

效果：
- `TdLevelCard.paint()` 中 `w = 220`（设计坐标）
- `margin = 6`（设计坐标）
- `buffer.scale(1.5)` 将其放大到 9 像素
- buffer 贴回屏幕时 1:1，显示正确 ✅

### 3.3 TdLevelCard.paint() 修改

引入 `cardScale` 处理 carousel 相对缩放：

```java
float cardScale = w / 220f;   // 当前宽度相对于设计宽度 220 的比例
```

所有固定像素值乘以 `cardScale`：
- 背景圆角：`4 * cardScale`
- 预览区 margin：`6 * cardScale`
- 绿色徽章半径：`18 * cardScale`
- 选中发光 strokeWeight：`(6f + pulse * 7.5f) * cardScale`
- 锁图标、勾线等同步缩放

注意：`cardScale` **不**处理 FIT 缩放，FIT 已由 `TdLevelList` 的 `buffer.scale()` 统一处理。

### 3.4 LevelCarousel.drawCards() 修改

`LevelCarousel` 本身已正确保持 FIT 一致性，但部分视觉元素在 carousel 相对缩放时漏乘了 `scale`：

| 元素 | 修改前 | 修改后 |
|------|--------|--------|
| 背景圆角 | `rect(0, 0, cardW, cardH, 4)` | `rect(..., 4 * scale)` |
| 选中边框 strokeWeight | `2` | `2 * scale` |
| 内层 glow strokeWeight | `1` | `1 * scale` |
| hover 边框 strokeWeight | `1` | `1 * scale` |
| 徽章勾线 strokeWeight | `1.5f` | `1.5f * scale` |

---

## 4. 事件穿透修复

### 4.1 问题

关卡选择界面有左右箭头按钮（`btnLeft`、`btnRight`）与 `TdLevelList` 并列。当鼠标悬停在箭头按钮上时，`TdLevelList.update()` 仍会根据鼠标位置给下方卡片设置 hover 状态，`onEvent()` 也会响应点击。

### 4.2 方案

**引擎端** `UIManager.java` 新增辅助方法：

```java
/** Returns true if the deepest component under the mouse is {@code ancestor} or one of its descendants. */
public boolean isMouseOverDescendantOf(UIComponent ancestor) {
    if (ancestor == null || mouseOverComponent == null) return false;
    UIComponent c = mouseOverComponent;
    while (c != null) {
        if (c == ancestor) return true;
        c = c.getParent();
    }
    return false;
}
```

**PDE 端** `TdLevelList` 中使用：

```java
// update()：设置 hover 前先检查鼠标是否在自己 subtree 内
boolean overSelf = appRef.ui.isMouseOverDescendantOf(this);
for (TdLevelCard card : cards) {
    card.setHover(overSelf && card.isVisible() && ...);
}

// onEvent()：事件入口直接拦截
public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
    if (!isEnabled()) return false;
    if (!appRef.ui.isMouseOverDescendantOf(this)) return false;
    // ... 正常处理
}
```

效果：鼠标在箭头按钮上时，卡片既不 hover 也不响应点击。

---

## 5. 相关文件变更

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `src/main/java/shenyf/p5engine/ui/UIManager.java` | 新增方法 | `isMouseOverDescendantOf(UIComponent)` |
| `examples/TowerDefenseMin2/TdLevelList.pde` | 重构 | 离屏 buffer 内恢复 FIT 缩放；事件穿透拦截 |
| `examples/TowerDefenseMin2/TdLevelCard.pde` | 修改 | `cardScale = w/220f` 自适应；徽章/发光/边框缩放 |
| `examples/TowerDefenseMin2/LevelCarousel.pde` | 修改 | 圆角、边框、strokeWeight 补乘 `scale` |

---

## 6. 注意事项

1. **离屏 buffer 的分辨率**：`TdLevelList` 的 buffer 宽高为 `designSize * uniformScale`，保持高分辨率以避免边缘 shader 锯齿。FIT 缩放通过 `buffer.scale(uniformScale)` 在绘制阶段恢复，不改变 buffer 分辨率。

2. **Matrix 堆叠**：`TdLevelCard.paint()` 内部有 `pushMatrix → scale(pressScale) → popMatrix`，与 `buffer.scale(uniformScale)` 正确堆叠，按下效果不受影响。

3. **图片资源**：`previewImage` 通过 `g.image(px, py, pw, ph)` 绘制，`pw/ph` 是设计坐标，被 `buffer.scale()` 正确放大到 screen pixel。

4. **字体大小**：`textSize` 使用 `Math.max(12 * cardScale, h * 0.075f)`，兼顾 carousel 缩放和比例自适应。

5. **不要重复处理 FIT**：`cardScale` 仅处理 `layoutCards()` 造成的相对缩放，**不**应再乘 `uniformScale`。FIT 由更高层统一处理。

---

## 7. 验证方法

1. 在 1280×720（设计分辨率，uniformScale=1.0）下观察，所有元素比例应正常
2. 在 1920×1080（uniformScale≈1.5）下观察，徽章、边框、发光应与 1280×720 下保持相同**视觉比例**
3. 鼠标悬停左右箭头按钮时，下方卡片不应高亮
4. 点击箭头按钮时，不应误触发卡片选中/进入关卡
