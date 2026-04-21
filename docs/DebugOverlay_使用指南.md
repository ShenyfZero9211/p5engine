# p5engine DebugOverlay 调试系统使用指南

## 概述

DebugOverlay 是 p5engine v0.2.x 引入的运行时调试 Overlay 系统，无需修改任何业务代码即可在屏幕上实时查看：

- **性能 HUD** — FPS、对象数、碰撞检查数、活跃 Tween 数、DeltaTime
- **碰撞体可视化** — 绿色线框绘制所有 Collider 的边界和中心点
- **GameObject 层级查看器** — 左侧面板列出场景中所有对象的层级树、组件和状态

## 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `debug/DebugOverlay.java` | 新增 | 核心类，管理三个调试面板的绘制和开关 |
| `core/P5Engine.java` | 修改 | 集成 DebugOverlay，注册快捷键，提供 `renderDebugOverlay()` 公共方法 |
| `core/P5Config.java` | 修改 | 新增 `debugOverlay(boolean)` 配置项，默认 `false` |
| `scene/Scene.java` | 修改 | 新增 `collisionCheckCount` 计数器及 `incrementCollisionCheckCount()` |
| `collision/CircleCollider.java` | 修改 | 每次距离比较时调用 `scene.incrementCollisionCheckCount()` |
| `tween/TweenManager.java` | 无需修改 | 已有 `getActiveCount()` 方法 |
| `sources.txt` | 修改 | 加入 `debug/DebugOverlay.java` |

## 技术要点

### 1. 快捷键检测的跨平台问题

Processing IDE 会拦截部分功能键（如 F2/F3/F4 可能对应 IDE 的运行/停止快捷键），导致 sketch 收不到 `keyEvent`。因此采用**双键位设计**：

- 字符键（`` ` ``、`1`、`2`、`3`）—— 可靠，不受 IDE 干扰
- 功能键（F2、F3、F4）—— 在 CLI 运行或导出后的独立程序中可用

```java
char k = event.getKey();
if (k == '`' || k == '~' || code == java.awt.event.KeyEvent.VK_BACK_QUOTE) {
    debugOverlay.toggle();          // 总开关
} else if (code == java.awt.event.KeyEvent.VK_F2 || k == '1') {
    debugOverlay.toggleGizmos();    // Gizmos
} else if (code == java.awt.event.KeyEvent.VK_F3 || k == '2') {
    debugOverlay.toggleTree();      // Scene Tree
} else if (code == java.awt.event.KeyEvent.VK_F4 || k == '3') {
    debugOverlay.toggleHud();       // HUD
}
```

### 2. 绘制时机：手动调用 vs 自动挂载

**方案 A（自动）**：`P5Engine.render()` 末尾自动调用 `debugOverlay.render()`。
- 适用：完全使用 `engine.render()` 进行场景渲染的 sketch
- 不适用：自定义 draw（如 TweenDemo 手动绘制 GameObject）

**方案 B（手动）**：在 sketch `draw()` 末尾调用 `engine.renderDebugOverlay()`。
- 适用：所有 sketch，无论是否使用 `engine.render()`
- 推荐：作为兜底方案，确保 overlay 总能显示

TweenDemo 和 TowerDefenseMin 均采用了**方案 B**：

```java
// TweenDemo.pde
draw() {
    background(14, 18, 30);
    engine.update();
    renderGameObjects();
    ui.update(dt);
    ui.render();
    engine.renderDebugOverlay();  // <-- 手动调用
}
```

### 3. Scene Tree 的层级推断

GameObject 本身没有 `children` 列表，层级关系存储在 `Transform.parent` 中。DebugOverlay 每帧构建一次临时映射：

```java
Map<GameObject, List<GameObject>> tree = new HashMap<>();
List<GameObject> roots = new ArrayList<>();
for (GameObject go : scene.getGameObjects()) {
    Transform parent = go.getTransform().getParent();
    if (parent == null || parent.getGameObject() == null) {
        roots.add(go);
    } else {
        tree.computeIfAbsent(parent.getGameObject(), k -> new ArrayList<>()).add(go);
    }
}
```

### 4. Collider 类型擦除问题

`Collider` 是接口，不继承 `Component`。`GameObject.hasComponent(Collider.class)` 因泛型约束 `T extends Component` 无法编译。正确做法是遍历 components 用 `instanceof` 判断：

```java
for (Component comp : go.getComponents()) {
    if (comp instanceof Collider) {
        Collider collider = (Collider) comp;
        // ...
    }
}
```

### 5. 碰撞计数器设计

计数器放在 `Scene` 中，每帧 `update()` 开始时清零。`CircleCollider.checkCollisions()` 在每次实际距离比较前递增：

```java
if (scene != null) {
    scene.incrementCollisionCheckCount();
}
if (distSq < minDist * minDist) {
    onCollision(other);
}
```

这样 HUD 显示的"Collisions"是**每帧实际执行的碰撞检测对数**，而非碰撞事件数。

## 使用方法

### 默认开启

```java
void setup() {
    engine = P5Engine.create(this, P5Config.defaults().debugOverlay(true));
}
```

### 运行时开关

| 按键 | 功能 |
|------|------|
| `` ` ``（反引号） | 切换整个 Debug Overlay 显示/隐藏 |
| `1` | 切换碰撞体可视化（Gizmos） |
| `2` | 切换 GameObject 层级查看器（Scene Tree） |
| `3` | 切换 FPS/计数 HUD |
| `F2` / `F3` / `F4` | 同上（CLI/独立程序中可用） |

### 手动绘制调用

如果你的 sketch 没有调用 `engine.render()`，请在 `draw()` 末尾添加：

```java
void draw() {
    // ... 你的绘制逻辑 ...
    engine.renderDebugOverlay();
}
```

### 代码中程序化控制

```java
// 开关整个 overlay
engine.getDebugOverlay().toggle();

// 单独开关某个面板
engine.getDebugOverlay().toggleGizmos();
engine.getDebugOverlay().toggleTree();
engine.getDebugOverlay().toggleHud();

// 查询状态
boolean on = engine.getDebugOverlay().isEnabled();
```

## 面板详解

### HUD（左上角）

```
┌───────────────┐
│ FPS: 60       │
│ Objects: 12   │
│ Collisions: 0 │
│ Tweens: 3     │
│ Delta: 0.017  │
└───────────────┘
```

- **FPS**：当前帧率（来自 `P5GameTime.getFrameRate()`）
- **Objects**：活跃场景中 `GameObject` 总数
- **Collisions**：本帧实际执行的碰撞检测距离比较次数
- **Tweens**：当前活跃的 Tween 动画数量
- **Delta**：上一帧 deltaTime（秒）

### Scene Tree（左侧）

半透明面板，列出所有 GameObject：

- **白色文字**：active = true
- **灰色文字**：active = false
- **缩进**：反映 Transform.parent 层级关系
- **右侧数字**：该对象挂载的 Component 数量

示例：
```
Scene Tree (12)
box (1)
circle (1)
pointer (1)
```

### Collider Gizmos

- **绿色圆形线框**：Collider 的边界（`getCollisionRadius()` × 2）
- **绿色中心点**：Collider 的世界坐标中心
- **半径标签**：显示 `r=xx.x` 数值

## 注意事项

1. **Processing IDE 快捷键冲突**：F2/F3/F4 可能被 IDE 拦截，优先使用 `` ` `` / `1` / `2` / `3`。
2. **自定义绘制 sketch 需手动调用**：不调用 `engine.render()` 的 sketch 必须在 `draw()` 末尾加 `engine.renderDebugOverlay()`。
3. **性能开销**：Overlay 每帧遍历所有 GameObject 和 Component，复杂场景（>1000 对象）建议仅在调试时开启。
4. **Clip 限制**：Scene Tree 使用 `PGraphics.clip()` 限制绘制区域，在 P2D 渲染器下表现正常，其他渲染器如有问题可注释掉 `g.clip()` 相关代码。
5. **碰撞计数仅统计 CircleCollider**：当前引擎只有圆形碰撞体，若后续增加 AABB/Polygon Collider，也需在各自的 `checkCollisions()` 中调用 `incrementCollisionCheckCount()`。
