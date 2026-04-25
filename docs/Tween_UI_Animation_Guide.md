# p5engine UI 动画开发指南

> 基于 TowerDefenseMin2 主菜单入场动画的实战经验总结。

---

## 一、Tween 系统核心能力

p5engine 内置 Tween 补间动画系统，由三个核心类组成：

| 类 | 职责 |
|---|---|
| `TweenManager` | 全局管理器，提供工厂方法创建动画，自动每帧更新 |
| `Tween` | 单个补间动画，支持链式配置（ease/delay/yoyo/repeat/onComplete） |
| `Ease` | 30+ 种缓动函数库（Quad/Cubic/Back/Elastic/Bounce 等） |

### 1.1 支持的动画目标

`Tween.Type` 分为两大类：

**GameObject 属性**
- `GO_POSITION` — 位置 (Vector2)
- `GO_ROTATION` — 旋转角度
- `GO_SCALE` — 缩放 (Vector2)

**UIComponent 属性**
- `UI_X` / `UI_Y` — 坐标
- `UI_WIDTH` / `UI_HEIGHT` — 尺寸
- `UI_ALPHA` — 透明度 (0~1)

**自定义回调（v0.4.5+）**
- `CUSTOM_FLOAT` — 通过 `Consumer<Float>` 回调驱动任意 float 值

### 1.2 基础用法模板

```java
TweenManager tm = app.engine.getTweenManager();
tm.setUseUnscaledTime(true);  // UI 动画通常使用真实时间，不受 timeScale 影响

tm.toAlpha(btn, 1f, 0.6f)     // 目标透明度, 持续时间(秒)
  .ease(Ease::outBack)        // 缓动曲线
  .delay(0.2f)                // 延迟启动
  .onComplete(() -> { /* ... */ })
  .start();
```

---

## 二、UIComponent 动画（按钮、窗口、面板）

### 2.1 渐显（Alpha）

```java
Button btn = new Button("btn_start");
btn.setAlpha(0);  // 初始透明
panel.add(btn);

tm.toAlpha(btn, 1f, 0.6f)
  .ease(Ease::outBack)
  .start();
```

### 2.2 位移动画（滑入/滑出）

```java
// 按钮从下方 30px 处滑入到最终位置
btn.setBounds(180, 70, 240, 52);  // 初始位置偏下

tm.toY(btn, 40, 0.6f)  // 目标 y=40, 耗时 0.6s
  .ease(Ease::outBack)
  .start();
```

> `toY()` 会自动读取组件当前 Y 坐标作为起点，无需手动设置 `from`。

### 2.3 组合动画（并行）

同时改变多个属性，启动多个 Tween 即可：

```java
tm.toY(btn, 40, 0.6f).ease(Ease::outBack).delay(0.3f).start();
tm.toAlpha(btn, 1f, 0.6f).ease(Ease::outBack).delay(0.3f).start();
```

### 2.4 批量位移（toXY / toSize）

```java
// 同时动画化 X 和 Y
Tween[] tweens = tm.toXY(panel, 100, 200, 0.5f);
tweens[0].ease(Ease::outQuad).start();  // X
tweens[1].ease(Ease::outQuad).start();  // Y
```

---

## 三、非 UI 元素动画（手绘文字、背景等）

### 3.1 问题背景

PDE 中直接 `text()`、`rect()` 绘制的元素**不是 UIComponent**，无法使用 `toX()`/`toAlpha()` 等方法。

### 3.2 解决方案：toFloat 回调（v0.4.5+）

引擎已扩展 `TweenManager.toFloat()`，通过回调将动画值传回 PDE：

```java
// PDE 层定义动画状态变量
static float titleProgress = 0f;  // 0=开始, 1=结束

// 启动动画
TweenManager tm = app.engine.getTweenManager();
tm.toFloat(0f, 1f, 0.8f, v -> {
    titleProgress = v;
}).ease(Ease::outBack).start();
```

### 3.3 在 draw() 中使用动画值

```java
static void drawTitle(PApplet g, String title) {
    // 根据 progress 计算实际属性
    float startY = 360f, endY = 120f;
    float curY = startY + (endY - startY) * titleProgress;

    int alpha = (int)(Math.min(255, Math.max(0, 255 * titleProgress)));
    float scale = Math.max(0, 0.8f + 0.2f * titleProgress);

    g.textSize(48 * scale);
    g.fill(224, 230, 240, alpha);
    g.text(title, 640, curY);
}
```

### 3.4 与 UIComponent 动画的对比

| | UIComponent | 非 UI 元素（toFloat） |
|---|---|---|
| 目标 | Button/Window/Panel 等 | PDE 手绘内容 |
| 驱动方式 | 引擎自动修改组件属性 | 回调更新 PDE 变量 |
| 是否需要 draw() 配合 | 否 | 是 |
| 可动画属性 | x/y/w/h/alpha | 任意（自行在回调中实现） |

---

## 四、动画编排技巧

### 4.1 时间线设计

以主菜单入场动画为例：

```
0.0s  ├─ 标题浮现+上移 (0.8s)
0.3s  │  ├─ 按钮1 滑入 (0.6s)
0.45s │  │  ├─ 按钮2 滑入 (0.6s)
0.60s │  │  │  ├─ 按钮3 滑入 (0.6s)
0.80s ▼  ▼  ▼  ▼ 全部到位
```

### 4.2 Staggered（交错）动画

多个元素依次启动，形成波浪感：

```java
float baseDelay = 0.3f;
float stagger = 0.15f;

tm.toY(btn1, 40, 0.6f).delay(baseDelay).start();
tm.toY(btn2, 110, 0.6f).delay(baseDelay + stagger).start();
tm.toY(btn3, 180, 0.6f).delay(baseDelay + stagger * 2).start();
```

### 4.3 使用 Sequence 编排复杂流程

对于需要严格先后顺序的动画，使用 `Scheduler.sequence()`：

```java
app.engine.getScheduler().sequence()
    .wait(0.5f)
    .run(() -> { /* 播放音效 */ })
    .tween(tm.toAlpha(panel, 1f, 0.3f))
    .wait(0.2f)
    .tween(tm.toY(panel, 100, 0.4f))
    .start();
```

---

## 五、完整示例：主菜单入场动画

### 5.1 PDE 状态定义

```java
// TdMenuBg.pde
static float titleProgress = 0f;  // 标题动画进度
```

### 5.2 动画启动（buildMainMenu）

```java
// TdFlow.pde — buildMainMenu()

// 1. 标题动画：从中心浮现并上移
TdMenuBg.titleProgress = 0f;
TweenManager tm = app.engine.getTweenManager();
tm.setUseUnscaledTime(true);

tm.toFloat(0f, 1f, 0.8f, v -> {
    TdMenuBg.titleProgress = v;
}).ease(Ease::outBack).start();

// 2. 按钮初始位置（偏下）
btnStart.setBounds(180, 70, 240, 52);
btnSettings.setBounds(180, 140, 240, 52);
btnQuit.setBounds(180, 210, 240, 52);

// 3. 按钮交错滑入+渐显
float d = 0.3f;
tm.toY(btnStart, 40, 0.6f).ease(Ease::outBack).delay(d).start();
tm.toAlpha(btnStart, 1f, 0.6f).ease(Ease::outBack).delay(d).start();

tm.toY(btnSettings, 110, 0.6f).ease(Ease::outBack).delay(d + 0.15f).start();
tm.toAlpha(btnSettings, 1f, 0.6f).ease(Ease::outBack).delay(d + 0.15f).start();

tm.toY(btnQuit, 180, 0.6f).ease(Ease::outBack).delay(d + 0.30f).start();
tm.toAlpha(btnQuit, 1f, 0.6f).ease(Ease::outBack).delay(d + 0.30f).start();
```

### 5.3 绘制时应用动画值

```java
// TdMenuBg.pde — drawTitle()
static void drawTitle(PApplet g, String title) {
    float startY = 360f, endY = 120f;
    float curY = startY + (endY - startY) * titleProgress;
    int alpha = (int)(Math.min(255, Math.max(0, 255 * titleProgress)));
    float scale = Math.max(0, 0.8f + 0.2f * titleProgress);

    g.textAlign(PApplet.CENTER, PApplet.CENTER);
    g.textSize(48 * scale);

    // 阴影
    g.fill(74, 158, 255, (int)(60 * titleProgress));
    g.text(title, 642, curY + 2);

    // 主文字
    g.fill(224, 230, 240, alpha);
    g.text(title, 640, curY);
}
```

---

## 六、缓动函数速查

| 缓动 | 效果 | 适用场景 |
|---|---|---|
| `Ease::linear` | 匀速 | 进度条、指示器 |
| `Ease::outQuad` | 先快后慢 | 一般位移动画 |
| `Ease::outBack` | 超过目标后回弹 | 按钮、标题弹出（推荐） |
| `Ease::outElastic` | 弹性震荡 | 强调性动画 |
| `Ease::outBounce` | 弹跳落地 | 掉落效果 |
| `Ease::inOutCubic` | 平滑加减速 | 窗口展开/收起 |

---

## 七、常见问题

### Q1: PDE 中 `Ease.outBack(t)` 报错？

Processing 预处理器会把 `Ease.outBack` 误解析为内部类访问。

**正确**：`Ease::outBack`（方法引用，用于 `.ease()`）
**错误**：`Ease.outBack(t)`（会被预处理器破坏）

如果需要在 PDE 中手动计算缓动值，建议通过 `toFloat` 回调由引擎驱动。

### Q2: 动画在暂停时不播放？

确保设置 `tm.setUseUnscaledTime(true)`，这样 UI 动画使用真实时间，不受 `timeScale` 影响。

### Q3: 重复进入菜单时动画不重新播放？

每次构建菜单时重置动画状态变量并重启动画：

```java
TdMenuBg.titleProgress = 0f;  // 重置
tm.toFloat(0f, 1f, 0.8f, v -> { ... }).start();  // 重新启动
```

### Q4: 回调中的 lambda 在 PDE 中编译不过？

Processing 4（Java 17）支持 lambda，但确保：
- 使用 `v -> { ... }` 简写形式
- 不要在 lambda 中捕获太多外部变量（PDE 预处理器可能出错）
- 如有问题，将回调逻辑抽到独立方法中

### Q5: `toFloat` 回调中的值超出 [0,1]？

某些缓动（如 `outBack`）会产生 overshoot（值 >1 或 <0）。在 PDE 层使用时注意 clamp：

```java
int alpha = (int)(Math.min(255, Math.max(0, 255 * progress)));
```

---

## 八、扩展引擎（添加新的 Tween 类型）

如需支持新的动画属性，修改以下文件：

1. **`src/main/java/shenyf/p5engine/tween/Tween.java`**
   - `Type` enum 增加新类型
   - `applyValue()` 增加对应分支

2. **`src/main/java/shenyf/p5engine/tween/TweenManager.java`**
   - 增加工厂方法（如 `toColorR()`、`toRotationDegrees()` 等）

3. 重新编译 `p5engine.jar` 并拷贝到 `code/` 目录

---

## 相关文件

- `src/main/java/shenyf/p5engine/tween/Tween.java`
- `src/main/java/shenyf/p5engine/tween/TweenManager.java`
- `src/main/java/shenyf/p5engine/tween/Ease.java`
- `examples/TowerDefenseMin2/TdFlow.pde`
- `examples/TowerDefenseMin2/TdMenuBg.pde`
