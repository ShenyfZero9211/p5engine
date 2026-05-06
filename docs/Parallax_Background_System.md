# LayerGroup 视差背景系统技术文档

> 文档状态：已完成 ✅  
> 关联计划：`plans/layergroup-parallax_f737500e.plan.md`

---

## 1. 系统概述

LayerGroup 视差背景系统是 p5engine 引擎级的渲染扩展，允许将世界层（`renderLayer < 100`）的对象按层分组，每组绑定独立的视差系数（`parallaxX / parallaxY`）。当相机移动时，不同分组的层以不同速度跟随相机，从而产生深度感——远景移动慢，近景移动快。

该系统最初为《TowerDefenseMin2》的星空背景设计，将原本单一层次的背景拆分为三层视差星空 + 一层正常游戏层，使深空场景获得明显的立体纵深感。

---

## 2. 架构设计

系统由**引擎层**（Java）和**PDE 层**（Processing）协同实现：

```
┌─────────────────────────────────────────────────────────────┐
│                        引擎层 (Java)                         │
├─────────────────────────────────────────────────────────────┤
│  LayerGroup        ── 定义 [layerMin, layerMax] + parallax  │
│  Camera2D          ── 新增 begin(renderer, px, py) 重载     │
│  Scene.renderWorld ── 按 LayerGroup 分组，每组独立相机变换   │
└─────────────────────────────────────────────────────────────┘
                              ↑
                              │ 编译为 p5engine.jar
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                        PDE 层 (Processing)                   │
├─────────────────────────────────────────────────────────────┤
│  WorldBgRenderer   ── 拆分为 4 层（0/1/2/3）                │
│  TdAppCore.pde     ── 创建 4 个 GameObject + 配置 LayerGroup │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 引擎层实现

### 3.1 LayerGroup 类

```java
public class LayerGroup {
    public final int layerMin;      // 包含
    public final int layerMax;      // 包含
    public final float parallaxX;   // X 轴视差系数
    public final float parallaxY;   // Y 轴视差系数

    public boolean contains(int layer) {
        return layer >= layerMin && layer <= layerMax;
    }
}
```

- 一个 `LayerGroup` 覆盖一段连续的 `renderLayer` 范围。
- 所有落在此范围内的 `Renderable` 都会以该组的视差系数进行相机变换。
- 不同组的 `layerMin/layerMax`**不应重叠**，否则先匹配的组生效。

### 3.2 Camera2D 的视差支持

原有 `begin(IRenderer)` 保持不变（内部委托给新的重载）：

```java
public void begin(IRenderer renderer) {
    begin(renderer, 1.0f, 1.0f);  // 完全跟随
}
```

新增视差重载：

```java
public void begin(IRenderer renderer, float parallaxX, float parallaxY) {
    Vector2 pos = getTransform().getPosition();
    float rot = getTransform().getRotation();
    renderer.pushTransform();
    renderer.translate(viewportOffsetX + viewportWidth / 2,
                       viewportOffsetY + viewportHeight / 2);
    renderer.scale(zoom, zoom);
    renderer.rotate(rot);
    // 关键：相机位移按视差缩放
    renderer.translate(-pos.x * parallaxX, -pos.y * parallaxY);
}
```

**变换顺序不变**：`translate(screenCenter) → scale(zoom) → rotate → translate(-camPos * parallax)`

### 3.3 Scene.renderWorld() 的分组渲染

```java
public void renderWorld(IRenderer renderer, Camera2D camera) {
    // 1. 收集所有 renderLayer < 100 的 RenderCommand
    // 2. 按 (renderLayer, zIndex) 排序
    // 3. 若未配置 LayerGroup：单遍渲染（向后兼容）
    // 4. 若配置了 LayerGroup：
    //    a. 遍历已排序命令，按 LayerGroup 分组
    //    b. 未匹配命令归入 "ungrouped"（默认 parallax=1.0）
    //    c. 对每个非空组：camera.begin(parallax) → 渲染命令 → camera.end()
}
```

**关键特性**：
- 每组独立调用 `camera.begin/end()`，即独立 `pushTransform/popTransform`。
- 组与组之间**不会合并批次**，但视差分组通常只涉及少量背景层，性能影响可忽略。
- 视口裁剪（Viewport Culling）仍基于主相机 `getViewport()`。对于 `parallax < 1.0` 的远景层，裁剪偏保守（可能多裁掉一些背景对象），但由于星星分布范围极大（见第 5 节），实际不会露出空白。

### 3.4 Scene API

```java
// 添加视差分组（可多次调用）
public void addLayerGroup(int layerMin, int layerMax,
                          float parallaxX, float parallaxY)

// 清除所有分组（恢复默认单遍渲染）
public void clearLayerGroups()
```

---

## 4. PDE 层实现（TowerDefenseMin2）

### 4.1 WorldBgRenderer 的四层拆分

原 `WorldBgRenderer` 在单一 `renderLayer=0` 上绘制所有背景内容。现在按内容深度拆分为 4 个 `GameObject`，每个绑定不同的 `renderLayer`：

| GameObject | renderLayer | 视差系数 | 绘制内容 |
|:---|:---:|:---:|:---|
| `world_bg_far`  | 0 | 0.08 | 深空背景（3×3 区域）+ 远景稀疏暗星 |
| `world_bg_mid`  | 1 | 0.25 | 中景密集星星 + 漂移星云 |
| `world_bg_near` | 2 | 0.45 | 近景亮星（圆形光晕） |
| `world_bg_plat` | 3 | 1.00 | 平台、BlockedZone、路径、基地/出口/出生点 |

### 4.2 LayerGroup 配置

在 `TdAppCore.pde` 的 `run()`（setup）中：

```java
gameScene.clearLayerGroups();
gameScene.addLayerGroup(0, 0, 0.08f, 0.08f);   // 远景
gameScene.addLayerGroup(1, 1, 0.25f, 0.25f);   // 中景
gameScene.addLayerGroup(2, 2, 0.45f, 0.45f);   // 近景
gameScene.addLayerGroup(3, 99, 1.0f, 1.0f);    // 游戏层
```

### 4.3 分层渲染器实现

`WorldBgRenderer` 新增 `layerIndex` 字段，通过 `switch` 分发到不同绘制方法：

```java
static class WorldBgRenderer extends RendererComponent {
    final int layerIndex;

    WorldBgRenderer() { this(3); }
    WorldBgRenderer(int layerIndex) { this.layerIndex = layerIndex; }

    protected void renderShape(PGraphics g) {
        switch (layerIndex) {
            case 0: drawFarLayer(g, lv, time);  break;
            case 1: drawMidLayer(g, lv, time);  break;
            case 2: drawNearLayer(g, lv, time); break;
            default: drawPlatformLayer(g, lv, time); break;
        }
    }
}
```

---

## 5. 防边缘露出策略

视差层的核心难点：**当相机移动到世界边缘时，视差层的内容可能移出视口，露出空白（默认黑色背景）**。

### 5.1 深空背景：3×3 超大面积

远景层（layer 0）的深空背景不局限于 `[0, worldW] × [0, worldH]`，而是绘制在 `[-worldW, -worldH, worldW*3, worldH*3]`：

```java
g.rect(-lv.worldW, -lv.worldH, lv.worldW * 3, lv.worldH * 3);
```

**数学验证**：
- 视差系数 `0.08`，相机最大位移为世界对角线的一半。
- 当相机位于 `(worldW, worldH)` 时，远景层偏移量为 `(-worldW*0.08, -worldH*0.08)`。
- 3×3 区域相对于视口的最大可见范围为 `[-worldW - offset, 2*worldW - offset]`，远大于任何可能露出边缘的情况。
- 由于深空背景是纯色的 `#080A14`，即使与窗口背景色 `#0E1222` 略有差异，大面积覆盖也保证了无缝过渡。

### 5.2 星星/星云：3×3 分布 + 不同随机种子

三层星星每层使用**不同的随机种子**，分布范围均为 `[-worldW, 2*worldW] × [-worldH, 2*worldH]`：

```java
// Far:  seed = lv.id * 7919
// Mid:  seed = lv.id * 7919 + 1
// Near: seed = lv.id * 7919 + 2

float sx = rng.nextFloat() * lv.worldW * 3 - lv.worldW;
float sy = rng.nextFloat() * lv.worldH * 3 - lv.worldH;
```

这样每层星星云独立分布，密度可控，且不会因为视差移动而露出空白区域。

---

## 6. 性能优化

### 6.1 P2D 下的绘制优化

在 Processing 的 P2D（OpenGL）模式下，以下原生函数性能极差：
- `g.ellipse()` — 每调用产生大量顶点缓冲上传
- `g.rect(x, y, w, h, radius)` — 内部实现复杂，频繁切换 OpenGL 状态

系统全面使用 `beginShape()/endShape(CLOSE)` 的轻量多边形替代：

```java
// 通用多边形圆（所有代码共用）
public static void drawPolyCircle(PGraphics g, float cx, float cy,
                                   float radius, int segments) {
    g.beginShape();
    for (int i = 0; i < segments; i++) {
        float a = PApplet.TWO_PI / segments * i;
        g.vertex(cx + PApplet.cos(a) * radius,
                 cy + PApplet.sin(a) * radius);
    }
    g.endShape(PApplet.CLOSE);
}
```

### 6.2 各层的分段数控制

- **远景暗星**：`1~2px` 小方块（`g.rect` 开销极小，无需 polygon）
- **中景星星**：`1~3px` 小方块
- **近景亮星**：圆形光晕，外层 12 段、内层 10 段、核心 8 段
- **星云**：`drawPolyCircle(..., 16)`
- **平台边缘/路径**：`beginShape(CLOSE)` 多边形

---

## 7. 向后兼容性

| 场景 | 行为 |
|:---|:---|
| 未调用 `addLayerGroup()` | `Scene.renderWorld()` 保持原有单遍渲染，与修改前**完全一致** |
| `WorldBgRenderer()` 无参构造 | 默认 `layerIndex = 3`（游戏层），绘制平台/路径等内容，与修改前**功能一致** |
| 现有示例未配置 LayerGroup | 引擎 JAR 替换后无需任何改动即可编译运行 |

---

## 8. 使用指南

### 8.1 在引擎中启用视差（Java）

```java
Scene scene = engine.getSceneManager().getActiveScene();
scene.clearLayerGroups();
scene.addLayerGroup(0, 0, 0.1f, 0.1f);   // 远景
scene.addLayerGroup(1, 1, 0.3f, 0.3f);   // 中景
scene.addLayerGroup(2, 99, 1.0f, 1.0f);  // 游戏层
```

### 8.2 在 PDE 中分配 renderLayer

创建多个 `GameObject`，分别设置 `renderLayer`：

```java
GameObject bgFar = GameObject.create("bg_far");
bgFar.addComponent(new MyBgRenderer(0));  // 远景绘制逻辑
bgFar.setRenderLayer(0);
bgFar.setCullEnabled(false);  // 背景通常不参与视口裁剪
gameScene.addGameObject(bgFar);
```

### 8.3 设计视差层时的注意事项

1. **LayerGroup 范围不要重叠**，否则先添加的组优先匹配。
2. **未匹配的 renderLayer 默认 parallax=1.0**，即正常相机跟随。
3. **视差层内容应覆盖足够大的区域**，避免相机移动到边缘时露出空白。
4. **视口裁剪基于主相机 viewport**，视差层对象如果靠近世界边缘，建议关闭 `CullEnabled`（`go.setCullEnabled(false)`）。

---

## 9. 验收结果

| 验收项 | 状态 |
|:---|:---:|
| 远景星星以 0.08 视差跟随相机 | ✅ |
| 中景星云以 0.25 视差跟随相机 | ✅ |
| 近景亮星以 0.45 视差跟随相机 | ✅ |
| 平台/路径/游戏对象以 1.0 正常跟随 | ✅ |
| 未配置 LayerGroup 时向后兼容 | ✅ |
| 编译通过（compile-jar.ps1） | ✅ |
| 示例编译通过（processing cli --build） | ✅ |

---

## 10. 相关文件

### 引擎源码
- `src/main/java/shenyf/p5engine/rendering/LayerGroup.java` — 新增
- `src/main/java/shenyf/p5engine/rendering/Camera2D.java` — 修改（`begin` 视差重载）
- `src/main/java/shenyf/p5engine/scene/Scene.java` — 修改（`renderWorld` 分组渲染）

### PDE 示例
- `examples/TowerDefenseMin2/TdRenderers.pde` — `WorldBgRenderer` 四层拆分
- `examples/TowerDefenseMin2/TdAppCore.pde` — 4 个 GameObject 创建 + LayerGroup 配置

### 构建输出
- `library/p5engine.jar`
- `examples/TowerDefenseMin2/code/p5engine.jar`

---

*文档创建时间：2026-05-02*
