/**
 * RenderDemo — p5engine rendering system showcase v0.4.0
 *
 * Demonstrates:
 *   - P5Config display configuration (P2D, pixelDensity, design resolution)
 *   - Camera2D with smooth follow, zoom, world bounds clamping
 *   - Scene render pipeline: collect → cull → sort → draw
 *   - GameObject renderLayer / zIndex / cullEnabled
 *   - Screen-space layer (layer >= 100) bypasses camera transform
 *   - RenderLayer static PGraphics cache for backgrounds
 *   - PostProcessor warm tint effect
 *   - DisplayManager resolution adaptation (NO_SCALE / STRETCH / FIT / FILL)
 *   - AnchorLayout UI positioning
 *   - Minimap with click-to-jump
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.math.*;

// ── Engine & Scene ──
P5Engine engine;
Scene scene;

// ── Ship state ──
Vector2 shipPos = new Vector2(0, 0);
Vector2 shipVel = new Vector2(0, 0);
float shipAngle = 0;
float shipSpeed = 0;

// ── Toggle switches ──
boolean cameraFollow = false;
boolean cullingEnabled = true;
boolean postFxEnabled = false;
boolean skipClear = false;
int scaleModeIndex = 2;  // FIT

// ── Assets ──
PImage imgStar;
PImage imgAsteroid;

// ── Design resolution (matches displayConfig) ──
final int DESIGN_W = 1280;
final int DESIGN_H = 720;

void settings() {
  P5Engine.configureDisplay(this, P5Config.defaults()
    .width(1280).height(720)
    .renderer(P5Config.RenderMode.P2D)
    .displayConfig(DisplayConfig.defaults()
      .designWidth(DESIGN_W)
      .designHeight(DESIGN_H)
      .scaleMode(ScaleMode.FIT)
      .resizable(true)));
}

void setup() {
  surface.setResizable(true);
  engine = P5Engine.create(this);
  engine.setBackgroundColor(color(8, 10, 18));

  imgStar = createStarImage(6);
  imgAsteroid = createAsteroidImage(24);
  scene = engine.getSceneManager().getActiveScene();

  // ── Camera2D ──
  GameObject camGo = GameObject.create("camera");
  Camera2D cam = camGo.addComponent(Camera2D.class);
  cam.setViewportSize(width, height);
  cam.setFollowSpeed(3.0f);
  cam.setSmoothFollow(true);
  scene.addGameObject(camGo);
  scene.setCamera(cam);

  // ── Player ship ──
  GameObject ship = GameObject.create("ship");
  ship.setRenderLayer(15);
  ship.setZIndex(100);
  ship.getTransform().setPosition(shipPos);
  ship.addComponent(new ShipRenderer());
  scene.addGameObject(ship);

  // ── Stars (5000, far away) ──
  for (int i = 0; i < 5000; i++) {
    GameObject s = GameObject.create("star_" + i);
    s.setRenderLayer(5);
    s.setZIndex(random(0, 1));
    s.getTransform().setPosition(random(-5000, 5000), random(-5000, 5000));
    SpriteRenderer sr = s.addComponent(SpriteRenderer.class);
    sr.setImage(imgStar);
    scene.addGameObject(s);
  }

  // ── Asteroids (50, closer) ──
  for (int i = 0; i < 50; i++) {
    GameObject a = GameObject.create("asteroid_" + i);
    a.setRenderLayer(10);
    a.setZIndex(random(0, 1));
    a.getTransform().setPosition(random(-2000, 2000), random(-2000, 2000));
    a.getTransform().setRotation(random(TWO_PI));
    a.getTransform().setScale(random(0.5f, 2.0f), random(0.5f, 2.0f));
    SpriteRenderer sr = a.addComponent(SpriteRenderer.class);
    sr.setImage(imgAsteroid);
    scene.addGameObject(a);
  }

  // ── World bounds ──
  cam.setWorldBounds(new Rect(-6000, -6000, 12000, 12000));

  // ── HUD (screen-space, auto-scaled by DisplayManager) ──
  GameObject hudGo = GameObject.create("hud");
  hudGo.setRenderLayer(100);
  hudGo.setZIndex(1000);
  hudGo.setCullEnabled(false);
  hudGo.addComponent(new HUDRenderer());
  scene.addGameObject(hudGo);

  // ── Minimap (screen-space, bottom-right) ──
  GameObject minimapGo = GameObject.create("minimap");
  minimapGo.setRenderLayer(100);
  minimapGo.setZIndex(500);
  minimapGo.setCullEnabled(false);
  Minimap minimap = minimapGo.addComponent(Minimap.class);
  minimap.setWorldBounds(new Rect(-6000, -6000, 12000, 12000));
  minimap.setRect(1080, 520, 180, 180);
  // Use opaque colors only — P2D's fill(int) fails on negative ARGB values (alpha >= 128 produces 0xC8... which is negative in signed int)
  minimap.setColors(color(30, 30, 35), color(90, 90, 90), color(120, 255, 120), color(80, 200, 255));
  scene.addGameObject(minimapGo);
}

// ── Image factories ──

PImage createStarImage(int size) {
  PImage img = createImage(size, size, ARGB);
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    float dx = (i % size) - size / 2;
    float dy = (i / size) - size / 2;
    float d = sqrt(dx * dx + dy * dy);
    float a = map(d, 0, size / 2, 255, 0);
    img.pixels[i] = color(255, 255, 255, constrain(a, 0, 255));
  }
  img.updatePixels();
  return img;
}

PImage createAsteroidImage(int size) {
  PImage img = createImage(size, size, ARGB);
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    float dx = (i % size) - size / 2;
    float dy = (i / size) - size / 2;
    float d = sqrt(dx * dx + dy * dy);
    float a = map(d, 0, size / 2, 255, 0);
    img.pixels[i] = color(180, 160, 140, constrain(a, 0, 255));
  }
  img.updatePixels();
  return img;
}

// ── Minimap interaction ──

boolean isMouseOverMinimap() {
  if (scene == null || engine == null) return false;
  DisplayManager dm = engine.getDisplayManager();
  Vector2 designMouse = dm.actualToDesign(new Vector2(mouseX, mouseY));
  GameObject minimapGo = scene.findGameObject("minimap");
  if (minimapGo != null) {
    Minimap minimap = minimapGo.getComponent(Minimap.class);
    if (minimap != null) {
      return minimap.contains(designMouse.x, designMouse.y);
    }
  }
  return false;
}

// ── Ship logic ──

void updateShip() {
  if (isMouseOverMinimap()) return;

  Vector2 shipScreen = new Vector2(shipPos.x, shipPos.y);
  if (scene != null && scene.getCamera() != null) {
    shipScreen = scene.getCamera().worldToScreen(shipPos);
  }
  float targetAngle = atan2(mouseY - shipScreen.y, mouseX - shipScreen.x);
  float diff = targetAngle - shipAngle;
  while (diff > PI) diff -= TWO_PI;
  while (diff < -PI) diff += TWO_PI;
  shipAngle += diff * 0.1f;

  if (mousePressed && mouseButton == LEFT) {
    shipSpeed = lerp(shipSpeed, 400, 0.02f);
  } else {
    shipSpeed = lerp(shipSpeed, 0, 0.03f);
  }

  shipVel.x = cos(shipAngle) * shipSpeed;
  shipVel.y = sin(shipAngle) * shipSpeed;
  shipPos.x += shipVel.x * engine.getGameTime().getDeltaTime();
  shipPos.y += shipVel.y * engine.getGameTime().getDeltaTime();

  GameObject ship = scene.findGameObject("ship");
  if (ship != null) {
    ship.getTransform().setPosition(shipPos);
    ship.getTransform().setRotation(shipAngle);
  }
}

// ── Main loop ──

void draw() {
  updateShip();

  // Toggle culling
  for (GameObject go : scene.getGameObjects()) {
    go.setCullEnabled(cullingEnabled);
  }

  // Camera follow
  Camera2D cam = scene.getCamera();
  if (cam != null) {
    if (cameraFollow) {
      GameObject ship = scene.findGameObject("ship");
      if (ship != null) cam.follow(ship.getTransform());
    } else {
      cam.stopFollow();
    }
  }

  // Post-processing
  if (postFxEnabled) {
    engine.getPostProcessor().clear();
    engine.getPostProcessor().add(gfx -> {
      gfx.noStroke();
      gfx.fill(255, 200, 120, 15);
      gfx.rect(0, 0, gfx.width, gfx.height);
    });
  } else {
    engine.getPostProcessor().clear();
  }

  engine.update();

  if (skipClear) {
    noStroke();
    fill(8, 10, 18, 30);
    rect(0, 0, width, height);
    engine.renderSkipBackground();
  } else {
    engine.render();
  }

  // ── Minimap debug overlay (drawn directly on main canvas after engine.render) ──
  drawMinimapDebug();
}

// ── HUD Renderer (screen-space, design-resolution coordinates) ──

class HUDRenderer extends Component implements Renderable {
  @Override
  public void render(IRenderer renderer) {
    PGraphics g = renderer.getGraphics();
    Camera2D cam = scene.getCamera();

    float[] r = AnchorLayout.calcRect(
      Anchor.TOP_LEFT, 10, 10, 280, 230, DESIGN_W, DESIGN_H);

    g.noStroke();
    g.fill(0, 0, 0, 160);
    g.rect(r[0], r[1], r[2], r[3], 8);

    g.fill(255);
    g.textSize(14);
    g.textAlign(LEFT, TOP);

    int y = 32;
    g.text("RenderDemo — p5engine v0.4.0", 24, y);            y += 22;
    g.text("FPS: " + String.format("%.1f", frameRate), 24, y);  y += 20;
    g.text("Objects: " + scene.getObjectCount(), 24, y);         y += 20;
    g.text("Ship: " + fmt(shipPos.x) + ", " + fmt(shipPos.y), 24, y); y += 20;
    g.text("Follow [C]: " + on(cameraFollow), 24, y);            y += 20;
    g.text("Cull [V]: " + on(cullingEnabled), 24, y);            y += 20;
    g.text("PostFX [B]: " + on(postFxEnabled), 24, y);           y += 20;
    g.text("Trails [S]: " + on(skipClear), 24, y);               y += 20;
    g.text("Zoom: " + fmt(cam != null ? cam.getZoom() : 1.0) + "  [Wheel / +/-]", 24, y); y += 20;
    ScaleMode[] modes = ScaleMode.values();
    g.text("Scale [M]: " + modes[scaleModeIndex] + "  " + width + "x" + height, 24, y); y += 20;
    // Time-scale display
    P5GameTime gt = engine.getGameTime();
    String timeLabel = String.format("Time [1-5/P]: %.1fx", gt.getTimeScale());
    if (gt.isPaused()) timeLabel += " [PAUSED]";
    g.text(timeLabel, 24, y); y += 20;
    g.text("Minimap click = jump", 24, y);
  }

  String on(boolean v) { return v ? "ON" : "OFF"; }
  String fmt(float v) { return String.format("%.0f", v); }
}

// ── Input ──

void keyPressed() {
  if (key == 'c' || key == 'C') cameraFollow = !cameraFollow;
  if (key == 'v' || key == 'V') cullingEnabled = !cullingEnabled;
  if (key == 'b' || key == 'B') postFxEnabled = !postFxEnabled;
  if (key == 's' || key == 'S') skipClear = !skipClear;

  Camera2D cam = scene.getCamera();
  if (cam != null) {
    if (key == '+' || key == '=') cam.zoomAt(3, new Vector2(width / 2, height / 2));
    if (key == '-' || key == '_') cam.zoomAt(-3, new Vector2(width / 2, height / 2));
    if (key == '0') cam.setZoom(1.0);
  }

  if (key == 'm' || key == 'M') {
    scaleModeIndex = (scaleModeIndex + 1) % 4;
    engine.getDisplayManager().setScaleMode(ScaleMode.values()[scaleModeIndex]);
  }

  // Time-scale controls
  P5GameTime gt = engine.getGameTime();
  if (key == '1') gt.setTargetTimeScale(0.1f);
  if (key == '2') gt.setTargetTimeScale(0.5f);
  if (key == '3') gt.setTargetTimeScale(1.0f);
  if (key == '4') gt.setTargetTimeScale(2.0f);
  if (key == '5') gt.setTargetTimeScale(5.0f);
  if (key == 'p' || key == 'P') gt.togglePause();
}

void windowResize(int newW, int newH) {
  if (engine != null) {
    engine.getDisplayManager().onWindowResize(newW, newH);
  }
}

void mousePressed() {
  if (scene == null || engine == null) return;

  DisplayManager dm = engine.getDisplayManager();
  Vector2 designMouse = dm.actualToDesign(new Vector2(mouseX, mouseY));

  GameObject minimapGo = scene.findGameObject("minimap");
  if (minimapGo != null) {
    Minimap minimap = minimapGo.getComponent(Minimap.class);
    if (minimap != null && minimap.contains(designMouse.x, designMouse.y)) {
      Vector2 worldPos = minimap.minimapToWorld(designMouse.x, designMouse.y);
      Camera2D cam = scene.getCamera();
      if (cam != null) cam.jumpCenterTo(worldPos.x, worldPos.y);
      return;
    }
  }
}

void mouseWheel(processing.event.MouseEvent event) {
  Camera2D cam = scene.getCamera();
  if (cam != null) {
    cam.zoomAt(-event.getCount(), new Vector2(mouseX, mouseY));
  }
}

// ── Minimap debug overlay ──

void drawMinimapDebug() {
  GameObject minimapGo = scene.findGameObject("minimap");
  if (minimapGo == null) return;
  Minimap minimap = minimapGo.getComponent(Minimap.class);
  if (minimap == null) return;

  float mx = minimap.getX();
  float my = minimap.getY();
  float mw = minimap.getW();
  float mh = minimap.getH();

  Rect wb = minimap.getWorldBounds();
  if (wb == null) return;

  float scaleX = mw / wb.width;
  float scaleY = mh / wb.height;
  float minimapScale = min(scaleX, scaleY);
  float drawW = wb.width * minimapScale;
  float drawH = wb.height * minimapScale;
  float ox = mx + (mw - drawW) * 0.5;
  float oy = my + (mh - drawH) * 0.5;

  // Camera viewport on minimap
  Camera2D cam = scene.getCamera();
  Rect vp = (cam != null) ? cam.getViewport() : null;
  float vx = 0, vy = 0, vw = 0, vh = 0;
  if (vp != null) {
    vx = ox + (vp.x - wb.x) * minimapScale;
    vy = oy + (vp.y - wb.y) * minimapScale;
    vw = max(4, vp.width * minimapScale);
    vh = max(4, vp.height * minimapScale);
  }

  // Ship on minimap
  GameObject ship = scene.findGameObject("ship");
  float sx = 0, sy = 0;
  if (ship != null) {
    Vector2 sp = ship.getTransform().getPosition();
    sx = ox + (sp.x - wb.x) * minimapScale;
    sy = oy + (sp.y - wb.y) * minimapScale;
  }

  // ── Draw debug visuals directly on main canvas ──
  pushStyle();
  rectMode(CORNER);
  noStroke();
  textAlign(LEFT, TOP);
  textSize(12);

  // 1) Minimap outer border (magenta, 3px thick via stroke)
  noFill();
  stroke(255, 0, 255);
  strokeWeight(3);
  rect(mx, my, mw, mh);

  // 2) World area inside minimap (white outline)
  noFill();
  stroke(255, 255, 255);
  strokeWeight(2);
  rect(ox, oy, drawW, drawH);

  // 3) Viewport rect (green fill)
  if (vp != null) {
    noStroke();
    fill(0, 255, 0);
    rect(vx, vy, vw, vh);
  }

  // 4) Ship dot (red fill, 10px)
  if (ship != null) {
    noStroke();
    fill(255, 0, 0);
    ellipse(sx, sy, 12, 12);
  }

  // 5) Text labels
  fill(255, 255, 0);
  text(String.format("mm: %.0f,%.0f %.0fx%.0f", mx, my, mw, mh), mx, my - 55);
  text(String.format("world: %.0f,%.0f %.0fx%.0f scale=%.4f", ox, oy, drawW, drawH, minimapScale), mx, my - 40);
  if (vp != null) text(String.format("vp: %.1f,%.1f %.1fx%.1f", vx, vy, vw, vh), mx, my - 25);
  if (ship != null) text(String.format("ship: %.1f,%.1f", sx, sy), mx, my - 10);

  popStyle();
}

// ── Custom ship renderer ──

static class ShipRenderer extends Component implements Renderable {
  @Override
  public void render(IRenderer renderer) {
    renderer.setTransform(getGameObject().getTransform());
    PGraphics g = renderer.getGraphics();
    g.pushStyle();
    g.noStroke();

    // Main body — bright cyan triangle
    g.fill(80, 200, 255);
    g.triangle(16, 0, -12, 10, -12, -10);

    // Engine glow
    g.fill(255, 120, 60, 180);
    g.ellipse(-14, 0, 10, 6);

    // Debug marker — large red circle so we can see it even if tiny
    g.fill(255, 0, 0);
    g.ellipse(0, 0, 8, 8);

    g.popStyle();
    renderer.resetTransform();
  }
}
