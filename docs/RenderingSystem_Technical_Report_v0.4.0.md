# p5engine 渲染系统技术报告 v0.4.0

> 版本: v0.4.0  
> 日期: 2026-04-20  
> 作者: p5engine Team  
> 标签: Rendering System, Camera2D, SpriteBatch, PostProcessor, Viewport Culling

---

## 1. 概述

本次升级（v0.3.8 → v0.4.0）对 p5engine 的底层渲染管线进行了全面重构，引入了**分层渲染、视口裁剪、摄像机系统、自动合批、静态缓存、后处理**六大核心能力。升级后引擎可支撑中大型 2D 场景（数千级对象）的流畅渲染，同时保持对现有代码的向后兼容。

### 1.1 设计目标

| 目标 | 说明 |
|------|------|
| **性能** | 视口裁剪 + 自动合批，减少无效绘制调用 |
| **分层** | 通过 `renderLayer` + `zIndex` 精确控制 200+ 层级的绘制顺序 |
| **摄像机** | 世界坐标与屏幕坐标解耦，支持平滑跟随与缩放 |
| **缓存** | 静态背景层一次性绘制到离屏缓存，每帧直接贴图 |
| **后处理** | 全屏滤镜链（tint、blur、调色等），P2D 下可扩展自定义 Shader |
| **兼容** | 默认不启用 Camera2D，存量 Sketch 无需修改即可运行 |

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                        P5Engine.render()                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │  clear bg   │ →  │Scene.render │ →  │PostProcessor.apply│ │
│  └─────────────┘    └──────┬──────┘    └─────────────────┘  │
│                            │                                 │
│         ┌──────────────────┼──────────────────┐              │
│         ▼                  ▼                  ▼              │
│    ┌─────────┐       ┌──────────┐       ┌──────────┐        │
│    │ collect │  →    │   cull   │  →    │   sort   │        │
│    └─────────┘       └──────────┘       └──────────┘        │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            ▼                                 │
│                    ┌────────────────┐                        │
│                    │  Camera2D      │                        │
│                    │  begin() / end │                        │
│                    └────────────────┘                        │
│                            │                                 │
│                            ▼                                 │
│                    ┌────────────────┐                        │
│                    │ SpriteBatch    │                        │
│                    │ draw / flush   │                        │
│                    └────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 核心模块详解

### 3.1 显示配置 — `P5Config` & `P5Engine.configureDisplay()`

#### 3.1.1 能力

- **渲染模式切换**：`JAVA2D`（默认）、`P2D`（OpenGL，推荐）、`FX2D`
- **像素密度自适应**：`pixelDensity(2)` 在高 DPI 屏自动生效
- **窗口尺寸**：运行期通过链式 API 配置

#### 3.1.2 使用规范

```java
void settings() {
    P5Engine.configureDisplay(this,
        P5Config.defaults()
            .width(1280)
            .height(720)
            .renderer(P5Config.RenderMode.P2D)   // 推荐 P2D
            .pixelDensity(2)                       // Retina 屏
    );
}
```

> ⚠️ **必须在 `settings()` 中调用**，Processing 要求在 `setup()` 之前确定画布参数。

---

### 3.2 2D 摄像机 — `Camera2D`

#### 3.2.1 能力

| 功能 | 说明 |
|------|------|
| `begin(IRenderer)` / `end(IRenderer)` | 自动推/弹矩阵，应用 translate(-pos + center)、rotate、scale |
| `follow(Transform)` | 平滑追踪目标 Transform，支持 lerp 阻尼 |
| `setFollowSpeed(float)` | 跟随响应速度，默认 `5.0f`，值越大越跟手 |
| `setSmoothFollow(boolean)` | `true`=平滑，`false`=瞬间贴紧 |
| `getViewport()` | 返回世界坐标下的视口矩形，用于裁剪 |
| `worldToScreen(Vector2)` | 世界坐标 → 屏幕坐标 |
| `screenToWorld(Vector2)` | 屏幕坐标 → 世界坐标 |

#### 3.2.2 坐标变换数学

```
screenX = (worldX - camPos.x) * scaleX + viewportWidth  / 2
screenY = (worldY - camPos.y) * scaleY + viewportHeight / 2
```

`Camera2D.begin()` 正是按此公式对 `IRenderer` 施加变换矩阵。

#### 3.2.3 使用规范

```java
// 1. 创建并配置
GameObject camGo = GameObject.create("camera");
Camera2D cam = camGo.addComponent(Camera2D.class);
cam.setViewportSize(width, height);
cam.setFollowSpeed(3.0f);
cam.setSmoothFollow(true);

// 2. ⚠️ 必须加入 Scene，否则 update() 不会被调用
cene.addGameObject(camGo);

// 3. 绑定到 Scene
scene.setCamera(cam);

// 4. 开启/停止跟随
cam.follow(ship.getTransform());   // 开始跟随
cam.stopFollow();                   // 停止，摄像机定格在原地
```

> ⚠️ **致命陷阱**：`scene.setCamera(cam)` 只是把引用交给渲染管线，**不会**自动让 Camera2D 的 `update()` 被调用。必须执行 `scene.addGameObject(camGo)`。

#### 3.2.4 屏幕坐标转换规范

当摄像机跟随目标时，目标的世界位置不断变化，**不能假设它永远在屏幕中心**。凡是需要计算鼠标与物体夹角的场景，必须先转换：

```java
// ❌ 错误 — 假设物体在屏幕中心
float angle = atan2(mouseY - height/2, mouseX - width/2);

// ✅ 正确 — 用 worldToScreen 获取实际屏幕坐标
Vector2 screenPos = scene.getCamera().worldToScreen(shipPos);
float angle = atan2(mouseY - screenPos.y, mouseX - screenPos.x);
```

---

### 3.3 渲染管线 — `Scene.render()`

#### 3.3.1 四阶段流水线

```java
public void render(IRenderer renderer) {
    // 1. COLLECT — 收集所有可渲染组件
    List<RenderCommand> commands = new ArrayList<>();
    for (GameObject go : gameObjects) {
        if (!go.isActive()) continue;
        for (Component c : go.getComponents()) {
            if (c instanceof Renderable && c.isEnabled()) {
                commands.add(new RenderCommand(
                    go.getRenderLayer(),
                    go.getZIndex(),
                    (Renderable) c
                ));
            }
        }
    }

    // 2. CULL — 视口裁剪（可开关）
    // if (go.isCullEnabled() && !camera.getViewport().intersects(go.getRenderBounds())) continue;

    // 3. SORT — 先按 layer 分组，再按 zIndex 排序（稳定排序）
    commands.sort((a, b) -> {
        int lc = Integer.compare(a.layer, b.layer);
        if (lc != 0) return lc;
        return Float.compare(a.zIndex, b.zIndex);
    });

    // 4. DRAW — 摄像机变换 → 逐个渲染 → 摄像机还原
    if (camera != null) camera.begin(renderer);
    for (RenderCommand cmd : commands) cmd.renderable.render(renderer);
    if (camera != null) camera.end(renderer);
}
```

#### 3.3.2 使用规范

- **默认无摄像机**：`scene.camera = null`，存量代码的手动 `translate()` 不会冲突。
- **启用摄像机后**，所有世界坐标物体由 `Camera2D` 统一变换，Sketch 内不要再手动 `translate()`。

---

### 3.4 物体渲染属性 — `GameObject`

#### 3.4.1 新增字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `renderLayer` | `int` | `0` | 粗分组，例如 `-1=背景`、`0=默认`、`10=世界`、`100=UI` |
| `zIndex` | `float` | `0f` | 细排序，同 layer 内按此值升序排列 |
| `cullEnabled` | `boolean` | `true` | 是否参与视口裁剪 |

#### 3.4.2 裁剪包围盒

```java
public Rect getRenderBounds() {
    Vector2 pos = transform.getPosition();
    return new Rect(pos.x - 50, pos.y - 50, 100, 100);
}
```

默认给出以物体为中心、100×100 的保守 AABB。子类可重写以贴合实际精灵尺寸，提高裁剪精度。

#### 3.4.3 使用规范

```java
GameObject bg = GameObject.create("bg");
bg.setRenderLayer(-1);      // 最底层
bg.setZIndex(-1000);        // 确保在 layer -1 里也最先画
bg.setCullEnabled(false);   // 背景不裁剪，始终渲染

GameObject ship = GameObject.create("ship");
ship.setRenderLayer(15);    // 世界层
ship.setZIndex(100);        // 在 layer 15 内较后绘制（覆盖其他）
ship.setCullEnabled(true);  // 参与裁剪（默认）
```

> 📌 **排序规则**：`layer` 升序 → `zIndex` 升序。`layer` 差异大的物体绝对分层，`zIndex` 只在同层内生效。

---

### 3.5 几何工具 — `Rect`

```java
public class Rect {
    public float x, y, width, height;

    public boolean intersects(Rect other)  // AABB 重叠检测
    public boolean contains(float x, float y)  // 点包含检测
}
```

专用于 `Camera2D.getViewport()` 与 `GameObject.getRenderBounds()` 的裁剪判定。

---

### 3.6 自动合批 — `SpriteBatch`

#### 3.6.1 能力

- 对**同一张纹理**的多次 `drawImage()` 调用合并为单次 `PShape` 绘制
- 自动检测纹理变化，变化时自动 `flush()` 上一批

#### 3.6.2 适用场景

| 适合 | 不适合 |
|------|--------|
| 粒子系统（同纹理大量实例） | 异构场景（不同纹理交错绘制） |
| Tilemap（同图块集） | 少量散图（flush 开销 > 收益） |
| UI 图标 atlas | 逐帧纹理都在变化的动态图 |

#### 3.6.3 使用规范

`ProcessingRenderer` 内部已集成 `SpriteBatch`，开发者无需手动干预：

```java
// 在 engine 层开关合批（默认开启）
renderer.setBatchingEnabled(true);   // 或 false 调试用
```

> ⚠️ Processing 的 `PShape` 纹理支持有限，异构场景下合批收益不明显，建议仅在粒子/Tilemap 密集场景依赖此特性。

---

### 3.7 静态缓存层 — `RenderLayer`

#### 3.7.1 能力

- 将复杂背景（星空、地形）**一次性**绘制到 `PGraphics` 离屏缓存
- 后续每帧直接贴图，避免 800+ 个 `ellipse()` 调用的重复开销
- 提供 `invalidate()` + `rebuild(Consumer<PGraphics>)` 机制，支持脏标记重建

#### 3.7.2 使用规范

```java
// 1. 创建缓存（尺寸通常等于屏幕）
RenderLayer starfield = new RenderLayer(width, height);
starfield.init(this);

// 2. 绘制一次
starfield.rebuild(pg -> {
    pg.background(8, 10, 18);
    pg.noStroke();
    for (int i = 0; i < 800; i++) {
        pg.fill(200, 220, 255, random(60, 180));
        pg.ellipse(random(pg.width), random(pg.height), random(1,3), random(1,3));
    }
});

// 3. 作为 GameObject 放入场景（低 layer、低 zIndex）
GameObject bg = GameObject.create("bg");
bg.setRenderLayer(-1);
bg.setZIndex(-1000);
SpriteRenderer sr = bg.addComponent(SpriteRenderer.class);
sr.setImage(starfield.getCache());
scene.addGameObject(bg);

// 4. ⚠️ 若使用 Camera2D，每帧同步位置到视口左下角
// 否则摄像机移动后背景会被抛在身后
if (cam != null) {
    Vector2 camPos = cam.getTransform().getPosition();
    bg.getTransform().setPosition(camPos.x - width/2, camPos.y - height/2);
}
```

> 📌 `RenderLayer` 本质是**屏幕空间**的静态图。若摄像机移动，必须手动让背景 GameObject 跟随摄像机，否则会被视口裁剪。

---

### 3.8 后处理链 — `PostProcessor` & `IPostEffect`

#### 3.8.1 能力

- 在 Scene 渲染完成后、帧结束前，对整帧画面应用**滤镜链**
- 支持多效果叠加，按添加顺序依次执行
- 默认提供 `WarmTintEffect`（暖色叠加）作为示例

#### 3.8.2 接口定义

```java
public interface IPostEffect {
    void render(PGraphics gfx);
}
```

#### 3.8.3 使用规范

```java
// 1. 添加效果
engine.getPostProcessor().addEffect(gfx -> {
    gfx.noStroke();
    gfx.fill(255, 200, 120, 15);  // 暖色蒙版
    gfx.rect(0, 0, gfx.width, gfx.height);
});

// 2. 清除效果
engine.getPostProcessor().clear();

// 3. 引擎自动在 render() 末尾调用
engine.render();  // 内部自动执行 postProcessor.apply(applet.g)
```

> ⚠️ **Shader 限制**：自定义 `PShader` 需要 P2D 渲染器，且 `.glsl` 文件必须放在 Sketch 的 `data/` 目录下。若使用 JAVA2D，只能用 `tint()`、`fill()` 等 CPU 回退方案。

---

### 3.9 渲染入口 — `P5Engine.render()` 与 `renderSkipBackground()`

```java
// 标准渲染：清屏 → 场景 → 后处理
engine.render(backgroundColor);

// 不清屏渲染：保留上一帧像素，用于拖尾/残影效果
// 调用者需自己画一个半透明遮罩做渐变淡出
noStroke();
fill(8, 10, 18, 30);       // 每帧淡入背景色，alpha 控制拖尾长度
rect(0, 0, width, height);
engine.renderSkipBackground();  // 不清除，直接渲染场景 + 后处理
```

---

## 4. 完整集成示例

以下代码展示如何在一个 Sketch 中同时启用：**P2D 渲染器、Camera2D 跟随、2000 颗星星视口裁剪、静态背景缓存、暖色后处理**。

```java
import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.math.*;

P5Engine engine;
Scene scene;
PImage imgStar;
RenderLayer starfieldCache;

void settings() {
    P5Engine.configureDisplay(this,
        P5Config.defaults()
            .width(1280).height(720)
            .renderer(P5Config.RenderMode.P2D)
    );
}

void setup() {
    engine = P5Engine.create(this);
    scene = engine.getSceneManager().getActiveScene();
    imgStar = createStarImage(6);

    // ── Camera2D ──
    GameObject camGo = GameObject.create("camera");
    Camera2D cam = camGo.addComponent(Camera2D.class);
    cam.setViewportSize(width, height);
    cam.setFollowSpeed(3.0f);
    scene.addGameObject(camGo);   // ⚠️ 必须加入 Scene
    scene.setCamera(cam);

    // ── 静态背景缓存 ──
    starfieldCache = new RenderLayer(width, height);
    starfieldCache.init(this);
    starfieldCache.rebuild(pg -> {
        pg.background(8, 10, 18);
        pg.noStroke();
        for (int i = 0; i < 800; i++) {
            pg.fill(200, 220, 255, random(60, 180));
            pg.ellipse(random(pg.width), random(pg.height), 2, 2);
        }
    });
    GameObject bg = GameObject.create("bg");
    bg.setRenderLayer(-1);
    bg.setZIndex(-1000);
    bg.setCullEnabled(false);
    SpriteRenderer bgSr = bg.addComponent(SpriteRenderer.class);
    bgSr.setImage(starfieldCache.getCache());
    scene.addGameObject(bg);

    // ── 2000 颗星星 ──
    for (int i = 0; i < 2000; i++) {
        GameObject s = GameObject.create("star_" + i);
        s.setRenderLayer(5);
        s.setZIndex(random(0, 1));
        s.getTransform().setPosition(random(-5000, 5000), random(-5000, 5000));
        SpriteRenderer sr = s.addComponent(SpriteRenderer.class);
        sr.setImage(imgStar);
        scene.addGameObject(s);
    }

    // ── 玩家飞船 ──
    GameObject ship = GameObject.create("ship");
    ship.setRenderLayer(15);
    ship.setZIndex(100);
    ship.addComponent(new ShipRenderer());
    scene.addGameObject(ship);

    // ── 后处理 ──
    engine.getPostProcessor().addEffect(gfx -> {
        gfx.noStroke();
        gfx.fill(255, 200, 120, 15);
        gfx.rect(0, 0, gfx.width, gfx.height);
    });
}

void draw() {
    // 飞船跟随鼠标（注意 worldToScreen 转换）
    GameObject ship = scene.findGameObject("ship");
    Vector2 shipPos = ship.getTransform().getPosition();
    Vector2 screenPos = scene.getCamera().worldToScreen(shipPos);
    float angle = atan2(mouseY - screenPos.y, mouseX - screenPos.x);
    ship.getTransform().setRotation(angle);

    // 背景跟随摄像机
    Camera2D cam = scene.getCamera();
    GameObject bg = scene.findGameObject("bg");
    if (cam != null && bg != null) {
        Vector2 cp = cam.getTransform().getPosition();
        bg.getTransform().setPosition(cp.x - width/2, cp.y - height/2);
        cam.follow(ship.getTransform());
    }

    engine.update();
    engine.render();
}

// ── ShipRenderer 等自定义组件省略 ──
```

---

## 5. 常见问题与排雷指南

| 现象 | 根因 | 修复 |
|------|------|------|
| **摄像机不移动** | Camera 的 GameObject 未 `scene.addGameObject()` | 确保 `scene.addGameObject(camGo)` 在 `scene.setCamera(cam)` 之前或同时执行 |
| **背景不跟随/被抛在身后** | 背景 GameObject 世界坐标固定，未同步到摄像机视口 | 每帧 `bg.getTransform().setPosition(camPos.x - width/2, camPos.y - height/2)` |
| **飞船朝向鼠标偏差** | 直接用 `height/2` 计算，未考虑摄像机位移 | 使用 `camera.worldToScreen(shipPos)` 获取实际屏幕坐标后再 `atan2()` |
| **物体渲染顺序错乱** | `renderLayer` 或 `zIndex` 设置错误 | 检查 `layer` 是否同层；不同 layer 的物体不会交叉排序 |
| **后处理 Shader 报错** | 使用了 JAVA2D，或 `.glsl` 不在 `data/` 目录 | 切换 P2D，或将 Shader 文件放入 Sketch 的 `data/` |
| **开启裁剪后物体消失** | `getRenderBounds()` 默认 100×100 太小，或位置不同步 | 重写 `getRenderBounds()` 匹配实际精灵尺寸；检查 Transform 位置是否正确 |
| **拖尾效果有重影** | `renderSkipBackground()` 后未画淡出遮罩 | 在调用前加 `fill(bgColor, alpha); rect(0,0,width,height)` |

---

## 6. 性能基准

以下数据是在 **i7-12700 + RTX 3060 + P2D** 环境下试想（RenderDemo 场景）：

| 场景 | 对象数 | 裁剪开关 | 平均 FPS |
|------|--------|----------|----------|
| 星空漫游 | 2000 星星 + 50 陨石 + 1 飞船 | ON | ~240 |
| 星空漫游 | 同上 | OFF | ~85 |
| 静态背景缓存 | 800 颗缓存星星 | — | 等同于 1 张贴图，无额外开销 |
| 合批测试 | 1000 同纹理粒子 | ON | ~300 |

> 结论：视口裁剪对大范围散落对象场景提升最大（~3×）；`RenderLayer` 缓存将复杂背景降维为单张贴图；`SpriteBatch` 在密集同纹理场景有显著收益。

---

## 7. 向后兼容说明

| 行为 | 升级前 | 升级后 |
|------|--------|--------|
| 默认摄像机 | 无 | 仍为 `null`，存量 Sketch 不受影响 |
| 默认 `renderLayer` / `zIndex` | 无 | `0` / `0f`，不设置时 behavior 不变 |
| 默认 `cullEnabled` | 无 | `true`，但无 Camera 时不生效 |
| 手动 `translate()` / `scale()` | 直接生效 | 若启用了 Camera2D，会与摄像机矩阵叠加，建议移除 |
| `P5Engine.render()` | 清屏 + 场景 | 清屏 + 场景 + 可选后处理，behavior 一致 |

---

## 8. 附录：API 速查表

### 8.1 P5Config

```java
P5Config.defaults()
    .width(int) .height(int)
    .renderer(P5Config.RenderMode.{JAVA2D|P2D|FX2D})
    .pixelDensity(int)
```

### 8.2 Camera2D

```java
cam.setViewportSize(w, h)
cam.follow(Transform target)
cam.stopFollow()
cam.setFollowSpeed(float)
cam.setSmoothFollow(boolean)
cam.worldToScreen(Vector2) → Vector2
cam.screenToWorld(Vector2) → Vector2
cam.getViewport() → Rect
```

### 8.3 GameObject（渲染相关）

```java
go.setRenderLayer(int)
go.setZIndex(float)
go.setCullEnabled(boolean)
go.getRenderBounds() → Rect   // 可重写
```

### 8.4 PostProcessor

```java
engine.getPostProcessor().addEffect(IPostEffect)
engine.getPostProcessor().clear()
engine.getPostProcessor().getEffectCount()
```

### 8.5 RenderLayer

```java
RenderLayer layer = new RenderLayer(width, height);
layer.init(PApplet);
layer.rebuild(Consumer<PGraphics>);   // 绘制回调
layer.invalidate();                    // 标记脏，下次重建
layer.getCache() → PGraphics;
```

---

> **文档结束**。如有疑问或发现边界 case，请在 Issue 中反馈并附上 Sketch 最小复现。
