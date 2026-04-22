# p5engine v0.4.0 渲染系统升级总结

> 对应计划：`plans/camera-zoom-ui-minimap_a3f7b2d1.plan.md`  
> 版本标签：`v0.4.0`

---

## 一、问题根因：Minimap 在 P2D 下显示异常

### 1.1 现象

Minimap 组件在 P2D 模式下仅显示深灰色背景，边框、视口矩形、飞船点均不可见。

### 1.2 根因分析（双重陷阱）

#### 陷阱 A：`fill(int)` 对负数颜色值解析异常

Processing 的 `color(r, g, b, a)` 在 alpha ≥ 128 时生成的 int 在 Java 中表现为**负数**（最高位为 1）。P2D/OpenGL 渲染器的 `fill(int)` 实现无法正确解析这些负数，导致颜色被忽略或解析为纯黑。

```java
// 危险：color(10,10,10,200) = 0xC80A0A0A → 负数 int
int c = color(10, 10, 10, 200);   // Java 中 c < 0
g.fill(c);                        // P2D 下可能解析为黑色或无效
```

**修复**：始终使用三参数 `fill(float r, float g, float b)`，将 int 颜色手动拆分为 RGB 分量：

```java
private static void setFillRGB(PGraphics g, int c) {
    float r = ((c >> 16) & 0xFF);
    float gr = ((c >> 8) & 0xFF);
    float b = (c & 0xFF);
    g.fill(r, gr, b);
}
```

#### 陷阱 B：`pushStyle()` / `popStyle()` 与多次 `fill()` 切换冲突

在 P2D（OpenGL）模式下，同一个 `pushStyle()`/`popStyle()` 块内**多次切换 `fill()` 颜色**会导致 OpenGL 材质状态未正确同步。表现为：第一次 `fill()` 生效，后续切换被忽略。

```java
// 在 P2D 下危险：
g.pushStyle();
g.fill(30, 30, 35);   // ✅ 生效
rect(...);
g.fill(90, 90, 90);   // ❌ 可能被忽略，仍使用上一颜色
rect(...);
g.popStyle();
```

**修复**：在 Minimap 等需要多次切换颜色的绘制逻辑中，**移除 `pushStyle()`/`popStyle()`**，改为显式设置所需状态（`noStroke()`、`rectMode(CORNER)` 等），由调用方保证状态恢复。

> 注：单次 `fill()` 的绘制逻辑（如 ShipRenderer）使用 `pushStyle()`/`popStyle()` 仍然安全。

---

## 二、今后开发注意点（P2D 渲染器）

| 注意点 | 说明 | 推荐做法 |
|--------|------|----------|
| **避免 `fill(int)`** | 负数 int 在 P2D 下解析异常 | 始终使用 `fill(r, g, b)` 或 `fill(r, g, b, a)` |
| **慎用 `pushStyle()` 内多次换色** | OpenGL 状态同步问题 | 多次换色时不用 `pushStyle()`，或每换一种颜色就 `push/pop` 一次 |
| **screen 层绘制** | `renderLayer >= 100` 不受 Camera2D 变换，但受 DisplayManager 缩放 | 坐标使用设计分辨率，DisplayManager 自动适配 |
| **坐标系区分** | 世界坐标 vs 屏幕坐标 vs 设计分辨率坐标 | 世界 → Camera2D → 屏幕 → DisplayManager → 实际像素 |
| **窗口 Resize** | 需要调用 `surface.setResizable(true)` 并处理 `windowResize()` | 参考 RenderDemo 中的 `windowResize()` 实现 |

---

## 三、Phase 1~4 执行效果

### Phase 1：Camera2D Zoom ✅

- `zoom` / `zoomAt(amount, focusScreenPos)`：以焦点为中心缩放，保持焦点屏幕位置不变
- `setWorldBounds(Rect)` + `clampToBounds()`：限制摄像机位置和 zoom 范围，确保不会看到世界外面
- `jumpCenterTo(x, y)`：瞬时跳转摄像机中心
- `worldToScreen()` / `screenToWorld()`：完整支持 zoom + rotation 的坐标转换

### Phase 2：DisplayManager 分辨率自适应 ✅

- `ScaleMode`：NO_SCALE / STRETCH / FIT / FILL 四种模式
- `DisplayConfig`：设计分辨率配置（默认 1280×720）
- `DisplayManager.begin(PGraphics)` / `end()`：自动应用 translate + scale 映射设计分辨率到实际窗口
- `actualToDesign()` / `designToActual()`：鼠标等输入坐标的转换
- `P5Engine.render()` 已集成 DisplayManager 变换

### Phase 3：Anchor UI 布局 ✅

- `Anchor` 枚举：15 种锚点（9 点定位 + 5 种拉伸 + STRETCH_FULL）
- `AnchorLayout.calcRect()`：基于设计分辨率计算 UI 元素位置
- screen 层（`renderLayer >= 100`）：不受 Camera2D 变换，但受 DisplayManager 缩放
- RenderDemo 中的 HUD 已完全使用 Anchor 布局

### Phase 4：Minimap ✅

- 绘制世界边界、视口矩形（绿色）、飞船点（蓝色）
- `contains(x, y)` / `minimapToWorld(x, y)`：点击检测与世界坐标映射
- 已修复 P2D 兼容性问题（见上文）

---

## 四、使用技巧

### 4.1 Camera2D 常用模式

```java
// 1. 以鼠标为中心缩放
cam.zoomAt(-event.getCount(), new Vector2(mouseX, mouseY));

// 2. 以屏幕中心缩放
cam.zoomAt(3, new Vector2(width / 2, height / 2));

// 3. 平滑跟随
cam.setSmoothFollow(true);
cam.setFollowSpeed(3.0f);
cam.follow(ship.getTransform());

// 4. 边界约束
cam.setWorldBounds(new Rect(-6000, -6000, 12000, 12000));
// clampToBounds() 会在 zoomAt/setZoom 后自动调用
```

### 4.2 DisplayManager 与窗口 Resize

```java
void settings() {
  P5Engine.configureDisplay(this, P5Config.defaults()
    .width(1280).height(720)
    .renderer(P5Config.RenderMode.P2D)
    .displayConfig(DisplayConfig.defaults()
      .designWidth(1280)
      .designHeight(720)
      .scaleMode(ScaleMode.FIT)
      .resizable(true)));
}

void setup() {
  surface.setResizable(true);  // 必须在 setup() 中再次调用
}

void windowResize(int newW, int newH) {
  engine.getDisplayManager().onWindowResize(newW, newH);
}
```

### 4.3 UI / 小地图放在 Screen 层

```java
// HUD、小地图等必须设置 renderLayer >= 100
GameObject hud = GameObject.create("hud");
hud.setRenderLayer(100);   // screen 层，不受 Camera2D 变换
hud.setZIndex(1000);       // 同层内排序
hud.setCullEnabled(false); // 屏幕元素永不裁剪
scene.addGameObject(hud);
```

### 4.4 小地图配置

```java
Minimap minimap = minimapGo.addComponent(Minimap.class);
minimap.setWorldBounds(new Rect(-6000, -6000, 12000, 12000));
minimap.setRect(1080, 520, 180, 180);  // 设计分辨率坐标
// 颜色必须使用不透明正数（或任意值，内部已自动拆分为 RGB）
minimap.setColors(
  color(30, 30, 35),      // 背景
  color(90, 90, 90),      // 边框
  color(120, 255, 120),   // 视口
  color(80, 200, 255)     // 飞船
);
```

### 4.5 坐标转换链

```
世界坐标 (worldX, worldY)
    ↓  Camera2D.worldToScreen()
屏幕坐标 (screenX, screenY) — 设计分辨率下的屏幕位置
    ↓  DisplayManager.designToActual()
实际像素 (actualX, actualY) — 真实窗口像素，含黑边偏移
```

反向（输入事件）：
```
鼠标实际像素 (mouseX, mouseY)
    ↓  DisplayManager.actualToDesign()
设计分辨率坐标 (designX, designY)
    ↓  Camera2D.screenToWorld()
世界坐标 (worldX, worldY)
```

---

## 五、验收状态

| 验收项 | 状态 |
|--------|------|
| Camera2D `begin()` 正确应用 zoom 变换 | ✅ |
| 滚轮以鼠标为中心缩放 | ✅ |
| 摄像机位置被约束在世界边界内 | ✅ |
| 窗口 resize 后自动适配 | ✅ |
| 全屏/窗口切换 | ✅（通过 `surface.setSize()`） |
| UI 元素使用 Anchor 布局 | ✅ |
| 小地图显示世界缩略图、单位、视口 | ✅ |
| 点击小地图跳转摄像机 | ✅ |
| UI 区域优先消费输入事件 | ✅（`isMouseOverMinimap()` 检查） |
| RenderDemo 完整展示所有功能 | ✅ |

---

## 六、时间缩放系统（Time Scaling）

p5engine 内置了完整的时间缩放支持，可让游戏世界加速/减速/暂停，同时保持渲染帧率稳定。

### 6.1 核心概念

| 时间类型 | 获取方法 | 用途 |
|----------|----------|------|
| **游戏时间** | `getDeltaTime()` | 世界逻辑、物理、AI、游戏内动画（受 timeScale 影响） |
| **真实时间** | `getRealDeltaTime()` | UI 动画、输入冷却、网络超时（不受 timeScale 影响） |

### 6.2 P5GameTime API

```java
P5GameTime gt = engine.getGameTime();

// 瞬时设置
gt.setTimeScale(0.5f);   // 半速
gt.setTimeScale(2.0f);   // 双倍速

// 平滑过渡（推荐）
gt.setTargetTimeScale(0.1f);   // 目标 0.1x
gt.setTransitionSpeed(5.0f);   // 过渡速度

// 暂停 / 恢复
gt.pause();
gt.resume();
gt.togglePause();

// 查询
float dt  = gt.getDeltaTime();       // 游戏 delta（缩放后）
float rdt = gt.getRealDeltaTime();   // 真实 delta（未缩放）
boolean p = gt.isPaused();
```

### 6.3 子系统时间规范

| 子系统 | 使用的时间 | 说明 |
|--------|-----------|------|
| `Scene.update()` | `getDeltaTime()` | 世界逻辑 |
| `Scheduler` | 双参数（scaled + real） | Timer 可自选 `timeScaleAffected` |
| `TweenManager` | 可配置 | `setUseUnscaledTime(true/false)`，默认 false（游戏优先） |
| `AudioManager` | 真实时间 | 音频不受 timeScale 影响 |

### 6.4 RenderDemo 时间控制

| 按键 | 功能 |
|------|------|
| `1` | timeScale → 0.1x（超级慢动作） |
| `2` | timeScale → 0.5x（慢动作） |
| `3` | timeScale → 1.0x（正常） |
| `4` | timeScale → 2.0x（快进） |
| `5` | timeScale → 5.0x（极速） |
| `P` | 暂停 / 恢复 |

---

## 七、RenderDemo 控制说明（完整版）

| 按键 | 功能 |
|------|------|
| `C` | 切换摄像机跟随 |
| `V` | 切换视口裁剪 |
| `B` | 切换后处理暖色滤镜 |
| `S` | 切换轨迹拖尾效果 |
| `M` | 切换缩放模式（NO_SCALE / FIT / FILL / STRETCH） |
| `+` / `-` | 以屏幕中心缩放 |
| `0` | 重置 zoom 为 1.0 |
| `1` ~ `5` | 时间缩放档位 |
| `P` | 暂停 / 恢复 |
| 鼠标滚轮 | 以鼠标位置为中心缩放 |
| 左键按住 | 飞船加速前进 |
| 点击小地图 | 摄像机跳转到对应世界位置 |

---

## 八、相关文件

- `src/main/java/shenyf/p5engine/rendering/Camera2D.java`
- `src/main/java/shenyf/p5engine/rendering/DisplayManager.java`
- `src/main/java/shenyf/p5engine/rendering/DisplayConfig.java`
- `src/main/java/shenyf/p5engine/rendering/ScaleMode.java`
- `src/main/java/shenyf/p5engine/rendering/Anchor.java`
- `src/main/java/shenyf/p5engine/rendering/AnchorLayout.java`
- `src/main/java/shenyf/p5engine/rendering/Minimap.java`
- `src/main/java/shenyf/p5engine/scene/Scene.java`
- `examples/RenderDemo/RenderDemo.pde`
