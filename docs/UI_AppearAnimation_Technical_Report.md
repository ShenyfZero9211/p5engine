# UI 组件浮现动画技术报告

> **版本**: p5engine 0.1.0-M1  
> **日期**: 2026-04-25  
> **作者**: AI Agent  
> **状态**: 已完成 ✅

---

## 1. 概述

### 1.1 背景
在 TowerDefenseMin2 项目中，主菜单、选关菜单、设置菜单等 UI 界面需要更流畅的入场效果。原有的实现中，只有主菜单的三个按钮有手动编写的 tween 动画，其他组件（Window、Panel、Label、Slider 等）都是直接出现，缺乏过渡感。

### 1.2 目标
- 为所有 UI 组件提供统一的"淡入+轻微上滑"浮现动画
- 将淡入（fade-in）和上滑（slide-up）拆分为独立的 API，方便灵活组合
- 保留原有主菜单按钮的 staggered 动画不变
- 动画在组件被添加到父容器时自动触发

### 1.3 最终效果
- **Window/Panel 等容器**：淡入效果（无位移）
- **Button/Label/Slider 等控件**：淡入 + 轻微上滑
- **多个组件**：支持 staggered（依次延迟）浮现

---

## 2. 技术实现

### 2.1 架构设计

动画系统分为三层：

```
┌─────────────────────────────────────┐
│  PDE 层 (TdFlow.pde)                │  ← 调用 appear()/fadeIn()/slideUp()
│  设置延迟参数，控制动画时序            │
├─────────────────────────────────────┤
│  UI 组件层 (UIComponent.java)        │  ← 存储动画状态（pending/delay/duration）
│  fadeIn() / slideUp() / appear()     │
├─────────────────────────────────────┤
│  容器层 (Container.java)             │  ← add() 时自动触发对应 tween
│  triggerFadeIn() / triggerSlideUp()  │
├─────────────────────────────────────┤
│  Tween 层 (TweenManager.java)        │  ← 执行实际的 alpha/Y 坐标插值
│  toAlpha() / toY()                   │
└─────────────────────────────────────┘
```

### 2.2 核心机制

#### 2.2.1 延迟触发机制
动画不是在调用 `appear()` 时立即执行，而是在组件被 `Container.add()` 加入父容器时才触发。这样做的好处：
- 组件可以在设置好位置、大小、延迟后再加入容器
- 容器负责统一管理和触发，减少 PDE 层代码复杂度
- 支持动态添加组件时的自动动画

#### 2.2.2 状态隔离
淡入和上滑各自维护独立的状态：

| 状态 | fadeIn | slideUp |
|------|--------|---------|
| pending 标志 | `fadeInPending` | `slideUpPending` |
| 延迟 | `fadeInDelay` | `slideUpDelay` |
| 持续时间 | `fadeInDuration` (默认 0.5s) | `slideUpDuration` (默认 0.5s) |
| 偏移量 | 无（只改 alpha） | `slideUpOffsetY` (默认 20px) |
| 原始位置 | 无 | `slideUpOriginalY` |

#### 2.2.3 组合快捷方式
`appear()` 是 `fadeIn()` + `slideUp()` 的组合：

```java
public void appear(float delay) {
    fadeIn(delay);
    slideUp(delay);
}

public void appear(float delay, float offsetY, float duration) {
    fadeIn(delay, duration);
    slideUp(delay, offsetY, duration);
}
```

---

## 3. API 文档

### 3.1 UIComponent 新增方法

#### `fadeIn(float delay)`
标记组件为待淡入状态，延迟 `delay` 秒后开始淡入，持续 0.5 秒。

#### `fadeIn(float delay, float duration)`
标记组件为待淡入状态，自定义持续时间。

#### `slideUp(float delay)`
标记组件为待上滑状态，延迟 `delay` 秒后开始上滑，偏移 20px，持续 0.5 秒。

#### `slideUp(float delay, float offsetY, float duration)`
标记组件为待上滑状态，自定义偏移量和持续时间。

#### `appear(float delay)`
组合调用：`fadeIn(delay)` + `slideUp(delay)`。

#### `appear(float delay, float offsetY, float duration)`
组合调用：`fadeIn(delay, duration)` + `slideUp(delay, offsetY, duration)`。

### 3.2 使用示例

#### 示例 1：简单淡入
```java
Window win = new Window("menu_win");
win.setBounds(340, 200, 600, 360);
win.fadeIn(0f);  // 立即淡入
root.add(win);   // 加入容器时自动触发动画
```

#### 示例 2：淡入+上滑（组合）
```java
Button btn = new Button("btn_start");
btn.setBounds(180, 70, 240, 52);
btn.appear(0.3f);  // 延迟 0.3s 后淡入+上滑
panel.add(btn);
```

#### 示例 3：自定义参数
```java
Button btn = new Button("btn_level_1");
btn.setBounds(100, 100, 140, 56);
btn.appear(0.1f, 16f, 0.4f);  // 延迟 0.1s, 上滑 16px, 持续 0.4s
panel.add(btn);
```

#### 示例 4：Staggered 依次浮现
```java
for (int i = 1; i <= 8; i++) {
    Button btn = new Button("btn_level_" + i);
    btn.setBounds(...);
    btn.appear(0.05f * i, 16f, 0.4f);  // 每个按钮延迟递增 0.05s
    panel.add(btn);
}
```

#### 示例 5：只上滑（不改 alpha）
```java
Label lbl = new Label("title");
lbl.setBounds(100, 50, 200, 30);
lbl.slideUp(0.2f, 30f, 0.6f);  // 只上滑 30px，alpha 保持原值
panel.add(lbl);
```

---

## 4. 修改文件清单

### 4.1 引擎层修改

#### `src/main/java/shenyf/p5engine/ui/UIComponent.java`
- **新增字段**：`fadeInPending`, `fadeInDelay`, `fadeInDuration`, `slideUpPending`, `slideUpDelay`, `slideUpOffsetY`, `slideUpDuration`, `slideUpOriginalY`
- **新增方法**：`fadeIn()`, `slideUp()`, `appear()`（组合）及对应的 getter/clear 方法
- **删除字段**：`appearPending`, `appearDelay`, `appearOffsetY`, `appearDuration`, `appearOriginalY`
- **删除方法**：旧的 `appear()` 单状态实现

#### `src/main/java/shenyf/p5engine/ui/Container.java`
- **修改 `add()`**：分别检查 `isFadeInPending()` 和 `isSlideUpPending()`
- **新增方法**：`triggerFadeIn()` — 只执行 alpha tween
- **新增方法**：`triggerSlideUp()` — 只执行 Y 坐标 tween
- **删除方法**：`triggerAppear()` 单方法实现

### 4.2 应用层修改

#### `examples/TowerDefenseMin2/TdFlow.pde`
- **主菜单 `buildMainMenu()`**：Window/Panel/versionPanel 改为 `fadeIn()`，按钮保留原有手动 tween + `appear()`
- **选关菜单 `showLevelSelect()`**：Window/Panel 改为 `fadeIn()`，关卡按钮和返回按钮使用 `appear()` staggered
- **设置菜单 `showSettings()`**：Window/Panel 改为 `fadeIn()`，各控件按行使用 `appear()` staggered
- **胜利菜单 `showWin()`**：Window/Panel 改为 `fadeIn()`，按钮使用 `appear()`
- **暂停菜单 `showPauseMenu()`**：overlay/Window/Panel 改为 `fadeIn()`，按钮使用 `appear()`
- **失败菜单 `showLose()`**：Window/Panel 改为 `fadeIn()`，按钮使用 `appear()`

---

## 5. 技术细节

### 5.1 动画时序

所有 UI 动画使用 **unscaled time**（不受游戏时间缩放影响）：

```java
app.engine.getTweenManager().killAll();
app.engine.getTweenManager().setUseUnscaledTime(true);
```

这样即使游戏中按了 1-5 键调整 timeScale，UI 动画仍然以正常速度播放。

### 5.2 缓动函数

默认使用 `Ease::outQuad` 缓动：
- 开始时速度较快，接近目标时减速
- 给人自然、柔和的入场感
- 比线性缓动更有"浮现"的感觉

### 5.3 默认值

| 参数 | 默认值 | 说明 |
|------|--------|------|
| fadeInDuration | 0.5s | 淡入持续时间 |
| slideUpOffsetY | 20px | 上滑偏移量（向下偏移后滑回原位） |
| slideUpDuration | 0.5s | 上滑持续时间 |

### 5.4 与手动 Tween 的兼容性

`appear()`/`fadeIn()`/`slideUp()` 与手动 `tm.toAlpha()`/`tm.toY()` 完全兼容：
- 自动动画在 `Container.add()` 时触发
- 手动动画可以随时添加
- 同一组件上可以同时存在多个 tween（如主菜单按钮既有 `appear()` 又有手动 `toY`）

**注意**：如果手动设置了 `setAlpha(0)` 然后调用 `appear()`，组件会先被 `appear()` 设为 alpha=0，然后 tween 到 alpha=1。如果手动 tween 也修改了 alpha，两者会同时作用，最终效果取决于 tween 的目标值。

---

## 6. 最佳实践

### 6.1 容器 vs 控件的动画选择

| 组件类型 | 推荐动画 | 原因 |
|----------|----------|------|
| Window | `fadeIn()` | 容器不需要位移，淡入即可 |
| Panel | `fadeIn()` | 布局容器，位移会带动所有子组件 |
| Button | `appear()` | 需要明显的入场感 |
| Label | `fadeIn()` 或 `appear()` | 根据重要性选择 |
| Slider | `appear()` | 交互控件，需要吸引注意力 |

### 6.2 Staggered 延迟计算

建议每行/每组递增 0.08s ~ 0.15s：

```java
float rowDelay = 0f;
float step = 0.08f;

// 第一行
label1.appear(rowDelay);
slider1.appear(rowDelay + 0.03f);
rowDelay += step;

// 第二行
label2.appear(rowDelay);
slider2.appear(rowDelay + 0.03f);
rowDelay += step;
```

### 6.3 避免动画冲突

如果组件已经通过手动 tween 设置了 alpha/Y 动画，建议：
- 不使用 `appear()`，避免重复动画
- 或确保手动 tween 的延迟大于自动动画的延迟

---

## 7. 已知限制

1. **动画只触发一次**：`appear()`/`fadeIn()`/`slideUp()` 只在第一次 `add()` 时触发。如果组件被移除后重新添加，需要重新调用这些方法。

2. **需要 TweenManager**：如果 `P5Engine.getInstance()` 为 null 或 `getTweenManager()` 为 null，动画不会触发，组件会直接以最终状态显示。

3. **布局管理器影响**：如果 Panel 使用了 GridLayout/FlowLayout 等自动布局，组件的 `setPosition()` 可能会被布局管理器覆盖。建议在 `add()` 之前设置好 `appear()`，让 `Container.add()` 在布局完成后触发动画。

---

## 8. 未来扩展

可能的扩展方向：
- `slideDown()` / `slideLeft()` / `slideRight()`：其他方向的滑入
- `scaleIn()`：缩放浮现
- `appearFrom(UIComponent anchor)`：从某个组件位置飞入
- `setAppearEasing(Ease ease)`：自定义缓动函数
- `appearSequence(List<UIComponent> comps)`：批量设置依次延迟
