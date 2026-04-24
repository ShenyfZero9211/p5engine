# WorldViewport UI 组件方案

## 目标
将当前全屏渲染的 World 层（摄像机画面）嵌入到一个 UI Panel 组件 `WorldViewport` 中，由 UI 系统统一管理其位置、尺寸、可见性和层级。World 只在该组件的矩形区域内渲染，不再通过 `engine.render()` 全屏绘制。

## 背景与现状分析

### 当前渲染流程（`TdFlowController.drawFrame`）
1. `app.background(14, 18, 30)` — 设背景色
2. `drawHudBackdrop()` — 画网格线（实际像素坐标）
3. `app.engine.update()` — 更新逻辑
4. `app.engine.render()` — **全屏清黑**，然后 `displayManager.begin` → `scene.render` → `displayManager.end`
   - `scene.render()` 内部：先渲染 world layer（`< 100`，套 camera transform），再渲染 screen layer（`>= 100`，不套 camera）
5. 手动画黑色矩形覆盖 UI 区域（遮 world 溢出）
6. `sketchUi.renderFrame()` — 渲染 UI
7. `drawMinimapOverUi()` — 手动渲染小地图

### 关键问题
- `engine.render()` 会 `clear(backgroundColor=纯黑)` 清屏，world 在其上全屏绘制。
- 为了不把 world 画到右侧面板和顶部 HUD，代码在 `engine.render()` 之后手动用黑色矩形覆盖。
- 这种方式 world 和 UI 是割裂的，world 区域无法被 UI 系统布局/嵌套。

### UI 系统架构
- `Container.paint()` → `paintSelf()` + `paintChildren()`，按 z-order 排序绘制。
- `Panel` 继承 `Container`，`paintSelf()` 调用 `theme.drawPanel()` 画背景。
- 子组件后绘制，会覆盖父组件。只要 `WorldViewport` 的 z-order 低于 `panelTopHud` 和 `panelRight`，它们就能正确覆盖边缘。

## 方案设计（唯一推荐）

### 核心思路
1. 新增 `WorldViewport extends Panel`，内部维护 `PGraphics` 离屏 buffer。
2. `WorldViewport.paintSelf()` 中：
   - 把 buffer 大小设为组件宽高
   - `buffer.beginDraw()` → `background(14,18,30)` → 画网格线 → `scene.renderWorld(buffer, camera)` → `buffer.endDraw()`
   - 将 buffer 以 `applet.image()` 贴到组件绝对坐标位置
3. 修改 `Scene.render()`，提取出 `renderWorld()` 和 `renderScreen()` 两个公共方法。
4. `TdFlowController.drawFrame()` 中：
   - 移除 `app.engine.render()`
   - 移除手动黑色覆盖矩形
   - 保留 `app.engine.update()`
   - `sketchUi.renderFrame()` 会触发 `WorldViewport` 的 world 渲染
   - 保留 `drawMinimapOverUi()`（小地图仍手动绘制在 UI 之上）

### 需要新增/修改的文件

#### 1. `src/main/java/shenyf/p5engine/rendering/OffscreenRenderer.java`（新增）
实现 `IRenderer`，直接向指定的 `PGraphics` 绘制。

```java
package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Transform;

public class OffscreenRenderer implements IRenderer {
    private final PGraphics g;
    private final int width;
    private final int height;

    public OffscreenRenderer(PGraphics g, int width, int height) {
        this.g = g;
        this.width = width;
        this.height = height;
    }

    @Override public void initialize() { }
    @Override public void clear(int color) { g.background(color); }
    @Override public void drawImage(processing.core.PImage img, float x, float y, float w, float h) { g.image(img, x, y, w, h); }
    @Override public void setTransform(Transform t) { g.pushMatrix(); Vector2 p = t.getPosition(); g.translate(p.x, p.y); g.rotate(t.getRotation()); Vector2 s = t.getScale(); g.scale(s.x, s.y); }
    @Override public void resetTransform() { g.popMatrix(); }
    @Override public void pushTransform() { g.pushMatrix(); }
    @Override public void popTransform() { g.popMatrix(); }
    @Override public void translate(float x, float y) { g.translate(x, y); }
    @Override public void rotate(float angle) { g.rotate(angle); }
    @Override public void scale(float x, float y) { g.scale(x, y); }
    @Override public void setColor(int color) { g.tint(color); }
    @Override public int getWidth() { return width; }
    @Override public int getHeight() { return height; }
    @Override public PGraphics getGraphics() { return g; }
}
```

#### 2. `src/main/java/shenyf/p5engine/scene/Scene.java`（修改）
将 `render()` 内部分解为两个公共方法，保持 `render()` 行为不变。

修改点：
- 把 worldCommands 收集 + 排序 + camera begin/end 提取为 `public void renderWorld(IRenderer renderer, Camera2D camera)`
- 把 screenCommands 收集 + 排序 + 绘制提取为 `public void renderScreen(IRenderer renderer)`
- `render(IRenderer)` 改为调用 `renderWorld(renderer, camera)` + `renderScreen(renderer)`

> 注：`renderWorld` 需要传入 `Camera2D` 参数，因为 WorldViewport 可能使用独立 camera。

#### 3. `src/main/java/shenyf/p5engine/ui/WorldViewport.java`（新增）
```java
package shenyf.p5engine.ui;

import processing.core.PApplet;
import processing.core.PGraphics;
import shenyf.p5engine.rendering.Camera2D;
import shenyf.p5engine.rendering.OffscreenRenderer;
import shenyf.p5engine.scene.Scene;

public class WorldViewport extends Panel {
    private Scene scene;
    private Camera2D camera;
    private PGraphics buffer;
    private int bgColor = 0xFF0E1222; // 14, 18, 30
    private boolean drawGrid = true;

    public WorldViewport(String id) {
        super(id);
        setPaintBackground(false);
    }

    public void setScene(Scene scene) { this.scene = scene; }
    public Scene getScene() { return scene; }
    public void setCamera(Camera2D camera) { this.camera = camera; }
    public Camera2D getCamera() { return camera; }
    public void setDrawGrid(boolean drawGrid) { this.drawGrid = drawGrid; }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        if (scene == null || !scene.isRunning()) {
            super.paintSelf(applet, theme);
            return;
        }

        int w = Math.max(1, (int) getWidth());
        int h = Math.max(1, (int) getHeight());
        ensureBuffer(applet, w, h);

        Camera2D cam = (camera != null) ? camera : scene.getCamera();
        if (cam != null) {
            float oldVpW = cam.getViewportWidth();
            float oldVpH = cam.getViewportHeight();
            float oldOffX = cam.getViewportOffsetX();
            float oldOffY = cam.getViewportOffsetY();

            cam.setViewportSize(w, h);
            cam.setViewportOffset(0, 0);

            buffer.beginDraw();
            buffer.background(bgColor);

            if (drawGrid) {
                buffer.stroke(40, 90, 120, 22);
                buffer.strokeWeight(1);
                int step = 48;
                for (float x = 0; x < w; x += step) buffer.line(x, 0, x, h);
                for (float y = 0; y < h; y += step) buffer.line(0, y, w, y);
                buffer.noStroke();
            }

            OffscreenRenderer offscreen = new OffscreenRenderer(buffer, w, h);
            scene.renderWorld(offscreen, cam);
            buffer.endDraw();

            cam.setViewportSize(oldVpW, oldVpH);
            cam.setViewportOffset(oldOffX, oldOffY);
        } else {
            buffer.beginDraw();
            buffer.background(bgColor);
            buffer.endDraw();
        }

        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float alpha = getEffectiveAlpha();

        applet.pushStyle();
        try {
            if (alpha < 1f) {
                applet.tint(255, Math.round(255 * alpha));
            }
            applet.image(buffer, ax, ay);
        } finally {
            applet.popStyle();
        }
    }

    private void ensureBuffer(PApplet applet, int w, int h) {
        if (buffer == null || buffer.width != w || buffer.height != h) {
            buffer = applet.createGraphics(w, h, PApplet.P2D);
        }
    }
}
```

#### 4. `examples/TowerDefenseMin/TdFlowController.pde`（修改）

**`startNewGameWithLevel()` 中：**
- 创建 `WorldViewport`：
  ```java
  WorldViewport worldViewport = new WorldViewport("world_viewport");
  worldViewport.setBounds(0, TdConfig.TOP_HUD, 1280 - TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
  worldViewport.setScene(g);
  worldViewport.setCamera(app.camera);
  worldViewport.setVisible(true);
  app.ui.getRoot().add(worldViewport, 0); // z-order 0，最底层
  ```
- camera/minimap/placement ghost 保持现有创建逻辑（camera 仍加入 scene 供 WorldViewport 使用）。

**`drawFrame()` 中：**
```java
void drawFrame() {
    float dt = app.engine.getGameTime().getDeltaTime();
    app.background(14, 18, 30);
    // drawHudBackdrop() 不再需要，网格线已移到 WorldViewport 内部

    updateCameraScroll(dt);
    app.engine.update();
    // 强制 camera clamp（保留）
    if (app.camera != null) {
        app.camera.clampToBounds();
        ...
    }

    if (app.appMode == 2) {
        int end = app.world.tick(dt, app.lblHudLine);
        ...
    }

    // 不再调用 app.engine.render()
    // 不再手动画黑色覆盖矩形

    TdUiLayout.layout(app);
    sketchUi.updateFrame(app.engine.getGameTime().getRealDeltaTime());
    if (app.appMode == 2 || app.appMode == 3 || app.appMode == 4) {
        updateTowerHint();
    }
    sketchUi.renderFrame(); // WorldViewport 在这里渲染 world

    drawMinimapOverUi();    // 小地图仍手动绘制在 UI 之上
    app.engine.renderDebugOverlay();
}
```

**`goMenuFromGame()` 中：**
- `WorldViewport.setVisible(false)`

#### 5. `examples/TowerDefenseMin/TdMainUiBuilder.pde`（可选修改）
如果 `TdMainUiBuilder` 中已创建 `WorldViewport`，则 `startNewGameWithLevel()` 中只需设置 scene/camera/visible。

## 实施步骤
1. 创建 `OffscreenRenderer.java`。
2. 修改 `Scene.java`，提取 `renderWorld()` 和 `renderScreen()`。
3. 创建 `WorldViewport.java`。
4. 修改 `TdFlowController.pde`：
   - 在 `startNewGameWithLevel()` 中创建/配置 `WorldViewport` 并加入 UI root。
   - 修改 `drawFrame()`，移除 `app.engine.render()` 和手动覆盖矩形，移除 `drawHudBackdrop()`（或保留但会被 WorldViewport 覆盖）。
   - 在 `goMenuFromGame()` 中隐藏 `WorldViewport`。
5. 编译 `p5engine.jar`（`Scene.java` 修改需要编译）。
6. 编译验证 TowerDefenseMin PDE。
7. 运行测试：确认 world 只在红框区域渲染，UI 面板正确覆盖边缘，小地图正常显示，camera 平移/缩放正常。

## 验收标准
- [ ] `WorldViewport` 作为 UI Panel 参与布局，位置尺寸由 UI 系统管理。
- [ ] World 层只在该组件矩形内渲染，不会溢出到右侧面板或顶部 HUD。
- [ ] 不再需要手动黑色矩形覆盖。
- [ ] 网格线作为 `WorldViewport` 内部背景的一部分。
- [ ] Camera 平移、缩放、边界限制功能不受影响。
- [ ] 小地图仍正常显示在 UI 之上。
- [ ] `compile-jar.ps1` 编译通过，PDE 示例编译通过。

## 相关文件
- `src/main/java/shenyf/p5engine/rendering/OffscreenRenderer.java`（新增）
- `src/main/java/shenyf/p5engine/scene/Scene.java`
- `src/main/java/shenyf/p5engine/ui/WorldViewport.java`（新增）
- `examples/TowerDefenseMin/TdFlowController.pde`
- `examples/TowerDefenseMin/TdMainUiBuilder.pde`（可选）
