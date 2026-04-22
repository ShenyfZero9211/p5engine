# 摄像机 Zoom、分辨率自适应、UI 自适应与小地图系统

> **状态：设计中** 📝

## 目标

将以下四大能力整合进 p5engine 渲染系统：

1. **Camera2D Zoom** — 滚轮/按键拉远拉近，以鼠标为中心缩放，保持世界边界约束
2. **分辨率自适应** — 窗口可自由调整大小、全屏/窗口切换，渲染质量不受分辨率变化影响
3. **UI 自适应** — UI 元素的比例、大小、位置随分辨率变化自动适配
4. **小地图（Minimap）** — 伴随摄像机平移，用户可点击小地图跳转查看任意区域

参考实现：`E:\projects\opencode\RTS_p5_copy\RTS_p5`（RTS 游戏原型，含完整 Camera/Minimap/UI 设计）

## 背景

当前 p5engine Camera2D 已具备基础跟随和平滑移动，但缺少以下能力：
- `zoom` 字段已存在但 `begin()` 未应用缩放变换
- 无世界边界约束（可无限滚出地图）
- 无分辨率自适应概念（窗口大小变化后所有坐标硬编码失效）
- 无 UI 布局系统（所有 HUD 在 draw() 里用绝对坐标绘制）
- 无小地图组件

RTS_p5 参考项目的关键设计模式：
- `Camera.zoomAt(wheel, focusX, focusY)`：以鼠标焦点为中心缩放，缩放后该点屏幕位置不变
- `Camera.clampToBounds()`：限制摄像机在世界矩形内，且 zoom 不小于"刚好装下整个世界"的值
- `Minimap`：固定矩形区域，按比例缩小渲染世界，叠加视口矩形，点击即跳转
- `UISystem`：所有 UI 坐标基于 `width/height` 动态计算，支持侧边栏、按钮网格、滚动面板

## 实施步骤

### Phase 1: Camera2D Zoom 与边界约束

**1.1 完善 Camera2D.zoom 在渲染管线中的应用**

当前 `Camera2D.begin()` 未使用 `zoom`：
```java
public void begin(IRenderer renderer) {
    Vector2 pos = getTransform().getPosition();
    renderer.pushTransform();
    renderer.translate(-pos.x + viewportWidth/2, -pos.y + viewportHeight/2);
    // ❌ 缺少 zoom 的 scale 变换
}
```

修改为：
```java
public void begin(IRenderer renderer) {
    Vector2 pos = getTransform().getPosition();
    renderer.pushTransform();
    // 先移到屏幕中心，再缩放，最后平移
    renderer.translate(viewportWidth/2, viewportHeight/2);
    renderer.scale(zoom, zoom);
    renderer.translate(-pos.x, -pos.y);
}
```

**1.2 添加 zoomAt（以焦点为中心缩放）**

参考 RTS_p5 的 `zoomAt(float wheelAmount, float focusScreenX, float focusScreenY)`：

```java
public void zoomAt(float amount, Vector2 focusScreenPos) {
    // 1. 记录焦点在当前 zoom 下的世界坐标
    Vector2 focusWorldBefore = screenToWorld(focusScreenPos);
    
    // 2. 应用 zoom 变化
    zoom *= pow(wheelZoomStep, amount);
    zoom = constrain(zoom, effectiveMinZoom(), maxZoom);
    
    // 3. 调整摄像机位置，使焦点世界坐标在新 zoom 下对应相同屏幕位置
    Vector2 pos = getTransform().getPosition();
    pos.x = focusWorldBefore.x - (focusScreenPos.x - viewportWidth/2) / zoom;
    pos.y = focusWorldBefore.y - (focusScreenPos.y - viewportHeight/2) / zoom;
    getTransform().setPosition(pos);
    
    clampToBounds();
}
```

**1.3 添加世界边界约束**

```java
private Rect worldBounds;  // 世界边界（可选）

public void setWorldBounds(Rect bounds) {
    this.worldBounds = bounds;
}

public void clampToBounds() {
    if (worldBounds == null) return;
    
    // zoom 不能小于"刚好装下整个世界"
    float fitX = viewportWidth / worldBounds.width;
    float fitY = viewportHeight / worldBounds.height;
    zoom = max(zoom, max(fitX, fitY));
    zoom = min(zoom, maxZoom);
    
    // 限制摄像机位置，确保不会看到世界外面
    float visibleW = viewportWidth / zoom;
    float visibleH = viewportHeight / zoom;
    Vector2 pos = getTransform().getPosition();
    pos.x = constrain(pos.x, worldBounds.x + visibleW/2, worldBounds.x + worldBounds.width - visibleW/2);
    pos.y = constrain(pos.y, worldBounds.y + visibleH/2, worldBounds.y + worldBounds.height - visibleH/2);
    getTransform().setPosition(pos);
}
```

**1.4 更新坐标转换公式**

```java
public Vector2 worldToScreen(Vector2 worldPos) {
    Vector2 screenPos = worldPos.copy();
    screenPos.sub(getTransform().getPosition());
    screenPos.mult(zoom);
    screenPos.add(viewportWidth/2, viewportHeight/2);
    return screenPos;
}

public Vector2 screenToWorld(Vector2 screenPos) {
    Vector2 worldPos = screenPos.copy();
    worldPos.sub(viewportWidth/2, viewportHeight/2);
    worldPos.div(zoom);
    worldPos.add(getTransform().getPosition());
    return worldPos;
}
```

**1.5 更新视口计算**

```java
public Rect getViewport() {
    Vector2 pos = getTransform().getPosition();
    float visibleW = viewportWidth / zoom;
    float visibleH = viewportHeight / zoom;
    return new Rect(
        pos.x - visibleW/2,
        pos.y - visibleH/2,
        visibleW,
        visibleH
    );
}
```

### Phase 2: 分辨率自适应 — DisplayManager

**2.1 设计分辨率概念**

引入"设计分辨率"（Design Resolution），所有游戏逻辑坐标基于设计分辨率，渲染时自动映射到实际窗口大小。

```java
public class DisplayConfig {
    private int designWidth = 1920;   // 设计参考分辨率
    private int designHeight = 1080;
    private ScaleMode scaleMode = ScaleMode.FIT;
    private boolean resizable = true;
    private boolean fullscreen = false;
}

public enum ScaleMode {
    NO_SCALE,   // 1:1 像素，无缩放
    STRETCH,    // 拉伸填满，可能变形
    FIT,        // 等比缩放，保持宽高比，可能有黑边
    FILL        // 等比填充，保持宽高比，可能裁切
}
```

**2.2 Processing 窗口 Resize 支持**

Processing 4 支持：
```java
surface.setResizable(true);
```

以及 `windowResize()` 回调（需 override）：
```java
@Override
public void windowResize(int newW, int newH) {
    engine.getDisplayManager().onWindowResize(newW, newH);
}
```

**2.3 DisplayManager 核心逻辑**

```java
public class DisplayManager {
    private int designWidth, designHeight;
    private int actualWidth, actualHeight;
    private ScaleMode scaleMode;
    
    // 实际到设计的缩放因子
    private float scaleX = 1f, scaleY = 1f;
    private float uniformScale = 1f;
    
    // 黑边偏移（FIT 模式下）
    private float offsetX = 0f, offsetY = 0f;
    
    public void onWindowResize(int w, int h) {
        this.actualWidth = w;
        this.actualHeight = h;
        recalculate();
    }
    
    private void recalculate() {
        switch (scaleMode) {
            case NO_SCALE:
                scaleX = scaleY = uniformScale = 1f;
                offsetX = offsetY = 0f;
                break;
            case STRETCH:
                scaleX = (float) actualWidth / designWidth;
                scaleY = (float) actualHeight / designHeight;
                uniformScale = 1f;
                offsetX = offsetY = 0f;
                break;
            case FIT:
                uniformScale = min((float) actualWidth / designWidth,
                                    (float) actualHeight / designHeight);
                scaleX = scaleY = uniformScale;
                offsetX = (actualWidth - designWidth * uniformScale) / 2f;
                offsetY = (actualHeight - designHeight * uniformScale) / 2f;
                break;
            case FILL:
                uniformScale = max((float) actualWidth / designWidth,
                                    (float) actualHeight / designHeight);
                scaleX = scaleY = uniformScale;
                offsetX = (actualWidth - designWidth * uniformScale) / 2f;
                offsetY = (actualHeight - designHeight * uniformScale) / 2f;
                break;
        }
    }
}
```

**2.4 渲染时的缩放应用**

在 `P5Engine.render()` 中，如果是 FIT/FILL 模式：

```java
public void render(int backgroundColor) {
    DisplayManager dm = getDisplayManager();
    
    // 清屏（包括黑边区域）
    renderer.clear(backgroundColor);
    
    // 应用显示缩放
    renderer.pushTransform();
    renderer.translate(dm.getOffsetX(), dm.getOffsetY());
    renderer.scale(dm.getUniformScale(), dm.getUniformScale());
    
    // 渲染场景（所有坐标都是设计分辨率下的）
    Scene activeScene = sceneManager.getActiveScene();
    if (activeScene != null) {
        activeScene.render(renderer);
    }
    
    renderer.popTransform();
    
    // 后处理（可选，在实际分辨率上应用）
    if (postProcessor != null) {
        postProcessor.apply(applet.g);
    }
}
```

> ⚠️ 这里需要仔细设计层级：游戏世界用缩放后的坐标系，UI 也可以基于设计分辨率，或者直接在实际分辨率上渲染（不缩放）。

**2.5 全屏切换**

```java
public void setFullscreen(boolean fullscreen) {
    if (fullscreen) {
        surface.setSize(displayWidth, displayHeight);
    } else {
        surface.setSize(windowedWidth, windowedHeight);
    }
}
```

### Phase 3: UI 自适应系统

**3.1 锚点布局系统**

参考 RTS_p5 的 `UISystem` 动态布局模式，引入 `Anchor` 枚举：

```java
public enum Anchor {
    TOP_LEFT, TOP_CENTER, TOP_RIGHT,
    MIDDLE_LEFT, CENTER, MIDDLE_RIGHT,
    BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT,
    STRETCH_LEFT, STRETCH_RIGHT, STRETCH_TOP, STRETCH_BOTTOM, STRETCH_ALL
}
```

**3.2 UIComponent 基类**

```java
public abstract class UIComponent extends Component implements Renderable {
    protected Anchor anchor = Anchor.TOP_LEFT;
    protected float offsetX, offsetY;        // 相对于锚点的偏移（设计分辨率像素）
    protected float width, height;           // 设计分辨率下的尺寸
    protected boolean useDesignResolution = true;
    
    // 每帧根据锚点和当前屏幕大小计算实际像素位置
    protected float actualX, actualY, actualW, actualH;
    
    @Override
    public void update(float deltaTime) {
        recalculateLayout();
    }
    
    protected void recalculateLayout() {
        DisplayManager dm = P5Engine.getInstance().getDisplayManager();
        
        // 计算基于设计分辨率的实际像素位置
        float screenW = dm.getDesignWidth();
        float screenH = dm.getDesignHeight();
        
        switch (anchor) {
            case TOP_LEFT:
                actualX = offsetX;
                actualY = offsetY;
                break;
            case TOP_RIGHT:
                actualX = screenW - width - offsetX;
                actualY = offsetY;
                break;
            case BOTTOM_LEFT:
                actualX = offsetX;
                actualY = screenH - height - offsetY;
                break;
            case BOTTOM_RIGHT:
                actualX = screenW - width - offsetX;
                actualY = screenH - height - offsetY;
                break;
            case CENTER:
                actualX = (screenW - width) / 2 + offsetX;
                actualY = (screenH - height) / 2 + offsetY;
                break;
            // ... 其他锚点
        }
        
        actualW = width;
        actualH = height;
    }
    
    @Override
    public void render(IRenderer renderer) {
        // UI 在屏幕空间渲染，不受 Camera2D 影响
        // 通过 renderLayer = 1000 确保在相机变换之后渲染
        // 或者 Scene.render() 中 Camera2D end() 之后再渲染 UI 层
    }
}
```

**3.3 UI 渲染层级**

Scene 的渲染管线需要区分"世界层"和"屏幕层"：

```java
public void render(IRenderer renderer) {
    // ... collect & cull world objects ...
    
    // 1. 渲染世界层（受 Camera2D 影响）
    List<RenderCommand> worldCommands = commands.stream()
        .filter(c -> c.layer < UI_LAYER_START)
        .collect(...);
    
    // 2. 渲染屏幕层（不受 Camera2D 影响）
    List<RenderCommand> screenCommands = commands.stream()
        .filter(c -> c.layer >= UI_LAYER_START)
        .collect(...);
    
    if (camera != null) camera.begin(renderer);
    for (RenderCommand cmd : worldCommands) cmd.renderable.render(renderer);
    if (camera != null) camera.end(renderer);
    
    for (RenderCommand cmd : screenCommands) cmd.renderable.render(renderer);
}
```

定义 `UI_LAYER_START = 100`：
- `renderLayer < 100`：世界层，受 Camera2D 变换
- `renderLayer >= 100`：屏幕层，不受 Camera2D 变换

**3.4 事件分发 — UI 优先**

参考 RTS_p5 的 `isPointInUI(mx, my)`：

```java
public boolean isPointInUI(int screenX, int screenY) {
    for (GameObject go : getGameObjects()) {
        if (go.getRenderLayer() >= UI_LAYER_START && go.isActive()) {
            if (go.getRenderBounds().contains(screenX, screenY)) {
                return true;
            }
        }
    }
    return false;
}
```

输入系统需要优先把事件发给 UI，如果 UI 消费了，不再传给世界。

### Phase 4: 小地图系统 — Minimap

**4.1 Minimap 组件设计**

```java
public class Minimap extends UIComponent {
    private Rect worldBounds;           // 世界总范围
    private float minimapScale;         // 世界 → 小地图的缩放比
    private float drawW, drawH;         // 小地图内实际绘制区域的尺寸
    private float drawOffsetX, drawOffsetY;  // 居中偏移
    
    // 缓存
    private PGraphics cache;            // 地形缓存（静态）
    private boolean cacheDirty = true;
    
    // 渲染内容开关
    private boolean showTerrain = true;
    private boolean showUnits = true;
    private boolean showBuildings = true;
    private boolean showViewportRect = true;
    
    public void setWorldBounds(Rect bounds) {
        this.worldBounds = bounds;
        cacheDirty = true;
        recalculateScale();
    }
    
    private void recalculateScale() {
        if (worldBounds == null) return;
        float scaleX = width / worldBounds.width;
        float scaleY = height / worldBounds.height;
        minimapScale = min(scaleX, scaleY);
        drawW = worldBounds.width * minimapScale;
        drawH = worldBounds.height * minimapScale;
        drawOffsetX = (width - drawW) / 2f;
        drawOffsetY = (height - drawH) / 2f;
    }
}
```

**4.2 静态地形缓存**

参考 RTS_p5 的简化地形渲染，但用 `PGraphics` 缓存避免每帧重绘：

```java
private void rebuildCache(PApplet applet, TileMap map) {
    if (cache == null || cache.width != (int)width || cache.height != (int)height) {
        cache = applet.createGraphics((int)width, (int)height);
    }
    cache.beginDraw();
    cache.background(18);
    
    // 绘制地形（简化版）
    if (map != null) {
        int step = 2;  // 采样步长，减少绘制量
        for (int ty = 0; ty < map.heightTiles; ty += step) {
            for (int tx = 0; tx < map.widthTiles; tx += step) {
                int terrain = map.getTerrain(tx, ty);
                cache.fill(getTerrainColor(terrain));
                float px = drawOffsetX + tx * map.tileSize * minimapScale;
                float py = drawOffsetY + ty * map.tileSize * minimapScale;
                cache.rect(px, py, map.tileSize * minimapScale * step, 
                           map.tileSize * minimapScale * step);
            }
        }
    }
    
    cache.endDraw();
    cacheDirty = false;
}
```

**4.3 动态渲染（单位、建筑、视口矩形）**

```java
@Override
public void render(IRenderer renderer) {
    PGraphics g = renderer.getGraphics();
    
    // 背景
    g.noStroke();
    g.fill(10, 10, 10, 170);
    g.rect(actualX, actualY, width, height);
    
    // 贴静态缓存
    if (cache != null && !cacheDirty) {
        g.image(cache, actualX, actualY);
    }
    
    // 绘制建筑
    if (showBuildings) {
        for (GameObject go : scene.getGameObjects()) {
            if (go.hasComponent(BuildingRenderer.class)) {
                Vector2 pos = go.getTransform().getPosition();
                float mx = actualX + drawOffsetX + (pos.x - worldBounds.x) * minimapScale;
                float my = actualY + drawOffsetY + (pos.y - worldBounds.y) * minimapScale;
                g.fill(getFactionColor(go));
                g.rect(mx, my, 4, 4);  // 简化表示
            }
        }
    }
    
    // 绘制视口矩形
    if (showViewportRect && camera != null) {
        Rect viewport = camera.getViewport();
        float vx = actualX + drawOffsetX + (viewport.x - worldBounds.x) * minimapScale;
        float vy = actualY + drawOffsetY + (viewport.y - worldBounds.y) * minimapScale;
        float vw = viewport.width * minimapScale;
        float vh = viewport.height * minimapScale;
        
        g.noFill();
        g.stroke(120, 255, 120);
        g.rect(vx, vy, vw, vh);
    }
}
```

**4.4 点击跳转**

```java
public Vector2 minimapToWorld(float minimapScreenX, float minimapScreenY) {
    // 转换为小地图本地坐标
    float localX = minimapScreenX - actualX - drawOffsetX;
    float localY = minimapScreenY - actualY - drawOffsetY;
    
    // 归一化
    float nx = constrain(localX / drawW, 0, 1);
    float ny = constrain(localY / drawH, 0, 1);
    
    // 映射到世界坐标
    return new Vector2(
        worldBounds.x + nx * worldBounds.width,
        worldBounds.y + ny * worldBounds.height
    );
}

// 在鼠标点击事件中调用
public void onClick(float screenX, float screenY, Camera2D camera) {
    if (!contains(screenX, screenY)) return;
    
    Vector2 worldPos = minimapToWorld(screenX, screenY);
    camera.getTransform().setPosition(worldPos);
    // 或 camera.jumpCenterTo(worldPos.x, worldPos.y);
}
```

**4.5 输入事件分发 — UI 优先**

参考 RTS_p5 的 `InputSystem`：

```java
void mousePressed() {
    // 1. 先检查 UI（包括小地图）
    if (uiSystem.beginClick(state, mouseX, mouseY)) {
        return;  // UI 消费了事件
    }
    
    // 2. 检查小地图点击
    if (minimap.contains(mouseX, mouseY)) {
        Vector2 worldPos = minimap.minimapToWorld(mouseX, mouseY);
        camera.jumpCenterTo(worldPos.x, worldPos.y);
        return;
    }
    
    // 3. 世界空间事件
    Vector2 worldPos = camera.screenToWorld(new Vector2(mouseX, mouseY));
    handleWorldClick(worldPos);
}
```

### Phase 5: 整合到 RenderDemo

更新 RenderDemo 以展示所有新特性：

1. 滚轮 zoom（以鼠标为中心）
2. `]` 键增加 zoom，`[` 键减小 zoom
3. `F11` 切换全屏
4. `R` 键切换分辨率自适应模式（NO_SCALE / FIT / FILL / STRETCH）
5. HUD 使用 Anchor 布局（左下角信息面板、右上角 FPS）
6. 添加 Minimap（右下角）
7. 点击小地图跳转
8. 世界边界约束（星星分布在有限范围内）

## 验收标准

- [ ] Camera2D `begin()` 正确应用 zoom 变换
- [ ] 滚轮以鼠标为中心缩放，缩放后鼠标指向的世界位置不变
- [ ] 摄像机位置被约束在世界边界内，不会看到世界外面
- [ ] 窗口 resize 后，游戏画面自动适配，UI 保持比例
- [ ] 全屏/窗口切换正常工作
- [ ] UI 元素使用 Anchor 布局，不同分辨率下位置正确
- [ ] 小地图正确显示世界缩略图、单位位置和视口矩形
- [ ] 点击小地图可将摄像机跳转到对应位置
- [ ] UI 区域（包括小地图）优先消费输入事件，不穿透到世界
- [ ] RenderDemo 示例完整展示上述所有功能

## 相关文件

- `src/main/java/shenyf/p5engine/rendering/Camera2D.java`
- `src/main/java/shenyf/p5engine/rendering/DisplayManager.java`（新增）
- `src/main/java/shenyf/p5engine/rendering/DisplayConfig.java`（新增）
- `src/main/java/shenyf/p5engine/rendering/Minimap.java`（新增）
- `src/main/java/shenyf/p5engine/rendering/UIComponent.java`（新增）
- `src/main/java/shenyf/p5engine/scene/Scene.java`
- `src/main/java/shenyf/p5engine/core/P5Engine.java`
- `src/main/java/shenyf/p5engine/core/P5Config.java`
- `examples/RenderDemo/RenderDemo.pde`
- `E:\projects\opencode\RTS_p5_copy\RTS_p5\Camera.pde`（参考）
- `E:\projects\opencode\RTS_p5_copy\RTS_p5\Minimap.pde`（参考）
- `E:\projects\opencode\RTS_p5_copy\RTS_p5\UISystem.pde`（参考）
