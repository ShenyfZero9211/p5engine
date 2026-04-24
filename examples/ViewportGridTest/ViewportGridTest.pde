import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.rendering.*;

P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;
SceneViewport worldViewport;
Camera2D camera;
Window worldWindow;

final int WORLD_W = 2400;
final int WORLD_H = 1600;
final int GRID_SIZE = 80;

// Highlight state (written by draw(), read by HighlightRenderer)
float highlightX = 0;
float highlightY = 0;

// For tracking worldWindow position/size changes
float lastWinX = -1;
float lastWinY = -1;
float lastWinW = -1;
float lastWinH = -1;

void settings() {
  size(1280, 720, P2D);
  smooth(8);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  P5Config config = P5Config.defaults()
    .displayConfig(shenyf.p5engine.rendering.DisplayConfig.defaults()
      .designWidth(1280).designHeight(720).scaleMode(shenyf.p5engine.rendering.ScaleMode.FIT));
  engine = P5Engine.create(this, config);
  engine.setApplicationTitle("ViewportGridTest");
  engine.setSketchVersion("0.0.1");

  ui = new UIManager(this);
  ui.attach();
  sketchUi = new SketchUiCoordinator(this, ui);

  Scene scene = engine.getSceneManager().getActiveScene();

  // Camera
  GameObject camGo = GameObject.create("camera");
  camera = camGo.addComponent(Camera2D.class);
  camera.setWorldBounds(new Rect(0, 0, WORLD_W, WORLD_H));
  camera.jumpCenterTo(WORLD_W * 0.5f, WORLD_H * 0.5f);
  scene.setCamera(camera);
  scene.addGameObject(camGo);

  // Grid
  GameObject gridGo = GameObject.create("grid");
  gridGo.setCullEnabled(false);
  gridGo.addComponent(new GridRenderer());
  scene.addGameObject(gridGo);

  // Highlight
  GameObject hlGo = GameObject.create("highlight");
  hlGo.setCullEnabled(false);
  hlGo.addComponent(new HighlightRenderer());
  scene.addGameObject(hlGo);

  // Floating window containing the world viewport
  worldWindow = new Window("world_window");
  worldWindow.setBounds(100, 60, 800, 520);
  worldWindow.setTitle("World View (drag title)");
  worldWindow.setZOrder(10);
  worldWindow.setLayoutManager(null);
  worldWindow.setOnClose(() -> exit());
  ui.getRoot().add(worldWindow);

  // World viewport inside the floating window with 1px padding to preserve border
  syncWorldViewportToWindow();

  // CRITICAL FIX: sync DisplayManager to actual window size.
  engine.getDisplayManager().onWindowResize(width, height);
}

/** Resize worldViewport to fit inside worldWindow with 1px border padding. */
void syncWorldViewportToWindow() {
  if (worldWindow == null || camera == null) return;
  float tbh = worldWindow.getTitleBarHeight();
  int ww = (int) worldWindow.getWidth();
  int wh = (int) worldWindow.getHeight();
  // 1px padding on each side to avoid covering Window border
  int vpW = Math.max(1, ww - 2);
  int vpH = Math.max(1, (int) (wh - tbh - 2));

  if (worldViewport == null) {
    worldViewport = new SceneViewport("world");
    worldViewport.setScene(engine.getSceneManager().getActiveScene());
    worldViewport.setCamera(camera);
    worldWindow.add(worldViewport);
  }
  worldViewport.setBounds(1, 1, vpW, vpH);
  camera.setViewportSize(vpW, vpH);
}

void draw() {
  background(14, 18, 34);

  engine.update();

  // Sync camera viewport offset & size to the floating window
  if (camera != null && worldWindow != null) {
    float newX = worldWindow.getAbsoluteX();
    float newY = worldWindow.getAbsoluteY() + worldWindow.getTitleBarHeight();
    float newW = worldWindow.getWidth();
    float newH = worldWindow.getHeight();
    if (newX != lastWinX || newY != lastWinY || newW != lastWinW || newH != lastWinH) {
      syncWorldViewportToWindow();
      camera.setViewportOffset(newX, newY);
      lastWinX = newX;
      lastWinY = newY;
      lastWinW = newW;
      lastWinH = newH;
    }
  }

  if (camera != null) {
    Vector2 designMouse = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
    Vector2 worldMouse = camera.screenToWorld(designMouse);
    highlightX = floor(worldMouse.x / GRID_SIZE) * GRID_SIZE;
    highlightY = floor(worldMouse.y / GRID_SIZE) * GRID_SIZE;
  }

  sketchUi.updateFrame(engine.getGameTime().getRealDeltaTime());
  sketchUi.renderFrame();

  drawVerificationOverlay();
  drawExpectedHighlightOverlay();

  // Debug print every 30 frames to avoid spam
  if (frameCount % 30 == 0 && camera != null) {
    shenyf.p5engine.rendering.DisplayManager dm = engine.getDisplayManager();
    println("--- Frame " + frameCount + " ---");
    println("applet=" + width + "x" + height);
    println("worldViewport=" + worldViewport.getWidth() + "x" + worldViewport.getHeight() + " @(" + worldViewport.getAbsoluteX() + "," + worldViewport.getAbsoluteY() + ")");
    println("appCamera vp=" + camera.getViewportWidth() + "x" + camera.getViewportHeight() + " offset=(" + camera.getViewportOffsetX() + "," + camera.getViewportOffsetY() + ")");
    println("appCamera pos=" + camera.getTransform().getPosition() + " zoom=" + camera.getZoom());
    println("DisplayManager scale=" + dm.getScaleX() + " offset=(" + dm.getOffsetX() + "," + dm.getOffsetY() + ")");
  }
}

// Draw a magenta crosshair on the MAIN screen at the location obtained by
// designMouse -> screenToWorld -> worldToScreen -> designToActual.
// If the camera math is correct, this must sit exactly on top of the mouse cursor.
void drawVerificationOverlay() {
  if (camera == null) return;
  Vector2 designMouse = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
  Vector2 worldMouse = camera.screenToWorld(designMouse);
  Vector2 backDesign = camera.worldToScreen(worldMouse);
  Vector2 backActual = engine.getDisplayManager().designToActual(backDesign);

  stroke(255, 0, 255);
  strokeWeight(2);
  line(backActual.x - 12, backActual.y, backActual.x + 12, backActual.y);
  line(backActual.x, backActual.y - 12, backActual.x, backActual.y + 12);
  noStroke();

  fill(255, 0, 255);
  textAlign(LEFT, TOP);
  text(String.format("mouse=(%d,%d) design=(%.0f,%.0f) world=(%.0f,%.0f) backDesign=(%.0f,%.0f) backActual=(%.0f,%.0f)",
    mouseX, mouseY, designMouse.x, designMouse.y, worldMouse.x, worldMouse.y,
    backDesign.x, backDesign.y, backActual.x, backActual.y), 10, 10);
}

// Draw a yellow cross at the screen position where the HIGHLIGHT CELL CENTER
// should appear according to app.camera. If this doesn't match the red cell,
// renderCam and app.camera have different transforms.
void drawExpectedHighlightOverlay() {
  if (camera == null) return;

  // Cell centre in world space
  float cxWorld = highlightX + GRID_SIZE * 0.5f;
  float cyWorld = highlightY + GRID_SIZE * 0.5f;
  Vector2 cellCenterScreenDesign = camera.worldToScreen(new Vector2(cxWorld, cyWorld));
  Vector2 cellCenterScreenActual = engine.getDisplayManager().designToActual(cellCenterScreenDesign);

  // Yellow cross at expected cell centre
  stroke(255, 255, 0);
  strokeWeight(2);
  line(cellCenterScreenActual.x - 10, cellCenterScreenActual.y, cellCenterScreenActual.x + 10, cellCenterScreenActual.y);
  line(cellCenterScreenActual.x, cellCenterScreenActual.y - 10, cellCenterScreenActual.x, cellCenterScreenActual.y + 10);
  noStroke();

  // Cyan hollow rect at expected cell top-left (scaled by display manager)
  Vector2 tlDesign = camera.worldToScreen(new Vector2(highlightX, highlightY));
  Vector2 tlActual = engine.getDisplayManager().designToActual(tlDesign);
  float scale = engine.getDisplayManager().getScaleX();
  stroke(0, 255, 255);
  strokeWeight(2);
  noFill();
  rect(tlActual.x, tlActual.y, GRID_SIZE * scale, GRID_SIZE * scale);
  noStroke();
}

/** Returns true if the design-resolution mouse is inside the world viewport content area. */
boolean isMouseInWorldViewport() {
  if (worldViewport == null) return false;
  Vector2 dm = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
  return worldViewport.containsPoint(dm.x, dm.y);
}

void mouseDragged() {
  if (mouseButton == LEFT && camera != null && isMouseInWorldViewport()) {
    float dx = mouseX - pmouseX;
    float dy = mouseY - pmouseY;
    camera.getTransform().translate(-dx / camera.getZoom(), -dy / camera.getZoom());
  }
}

void mouseWheel(MouseEvent e) {
  if (camera == null || !isMouseInWorldViewport()) return;
  float c = -e.getCount(); // invert: scroll up = zoom in
  Vector2 designMouse = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
  camera.zoomAt(c, designMouse);
}

// ---------------------------------------------------------------------------
// Renderables
// ---------------------------------------------------------------------------

public class GridRenderer extends Component implements Renderable {
  @Override
  public void render(IRenderer renderer) {
    PGraphics g = renderer.getGraphics();
    g.stroke(51, 68, 85, 120);
    g.strokeWeight(1);
    for (float x = 0; x < WORLD_W; x += GRID_SIZE) {
      g.line(x, 0, x, WORLD_H);
    }
    for (float y = 0; y < WORLD_H; y += GRID_SIZE) {
      g.line(0, y, WORLD_W, y);
    }
    g.noStroke();
  }
}

public class HighlightRenderer extends Component implements Renderable {
  @Override
  public void render(IRenderer renderer) {
    ViewportGridTest sketch = (ViewportGridTest) P5Engine.getInstance().getApplet();
    if (sketch == null) return;

    PGraphics g = renderer.getGraphics();
    g.noStroke();
    g.fill(255, 60, 60, 140);
    g.rect(sketch.highlightX, sketch.highlightY, GRID_SIZE, GRID_SIZE);

    // Precision cross at cell centre
    g.stroke(255, 0, 0);
    g.strokeWeight(2);
    float cx = sketch.highlightX + GRID_SIZE * 0.5f;
    float cy = sketch.highlightY + GRID_SIZE * 0.5f;
    g.line(cx - 10, cy, cx + 10, cy);
    g.line(cx, cy - 10, cx, cy + 10);
    g.noStroke();
  }
}
