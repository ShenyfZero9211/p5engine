/**
 * RenderDemo — p5engine rendering system showcase.
 * Demonstrates: configureDisplay, Camera2D, zIndex/layer sorting,
 * viewport culling, RenderLayer cache, PostProcessor.
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.math.*;

P5Engine engine;
Scene scene;

// Ship state
Vector2 shipPos = new Vector2(0, 0);
Vector2 shipVel = new Vector2(0, 0);
float shipAngle = 0;
float shipSpeed = 0;

// Toggle switches
boolean cameraFollow = false;  // default OFF so ship moves on screen
boolean cullingEnabled = true;
boolean postFxEnabled = false;
boolean skipClear = false;

// Cached background layer
RenderLayer starfieldLayer;

// Images
PImage imgStar;
PImage imgAsteroid;

void settings() {
  P5Engine.configureDisplay(this, P5Config.defaults()
    .width(1280).height(720)
    .renderer(P5Config.RenderMode.P2D));
}

void setup() {
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
  scene.addGameObject(camGo);   // must add to scene so update() is called
  scene.setCamera(cam);

  // ── Player ship ──
  GameObject ship = GameObject.create("ship");
  ship.setRenderLayer(15);
  ship.setZIndex(100);
  ship.getTransform().setPosition(shipPos);
  ship.addComponent(new ShipRenderer());
  scene.addGameObject(ship);

  // ── Stars (2000, far away) ──
  for (int i = 0; i < 2000; i++) {
    GameObject s = GameObject.create("star_" + i);
    s.setRenderLayer(5);
    s.setZIndex(random(0, 1));
    float sx = random(-5000, 5000);
    float sy = random(-5000, 5000);
    s.getTransform().setPosition(sx, sy);
    SpriteRenderer sr = s.addComponent(SpriteRenderer.class);
    sr.setImage(imgStar);
    scene.addGameObject(s);
  }

  // ── Asteroids (50, closer) ──
  for (int i = 0; i < 50; i++) {
    GameObject a = GameObject.create("asteroid_" + i);
    a.setRenderLayer(10);
    a.setZIndex(random(0, 1));
    float ax = random(-2000, 2000);
    float ay = random(-2000, 2000);
    a.getTransform().setPosition(ax, ay);
    a.getTransform().setRotation(random(TWO_PI));
    a.getTransform().setScale(random(0.5f, 2.0f), random(0.5f, 2.0f));
    SpriteRenderer sr = a.addComponent(SpriteRenderer.class);
    sr.setImage(imgAsteroid);
    scene.addGameObject(a);
  }

  // ── Static starfield background (RenderLayer cached as a sprite) ──
  starfieldLayer = new RenderLayer(width, height);
  starfieldLayer.init(this);
  rebuildStarfield();

  // Add cached background as a GameObject at layer -1 so it participates in scene sorting
  GameObject bg = GameObject.create("bg");
  bg.setRenderLayer(-1);
  bg.setZIndex(-1000);
  SpriteRenderer sr = bg.addComponent(SpriteRenderer.class);
  sr.setImage(starfieldLayer.getCache());
  scene.addGameObject(bg);
}

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

void rebuildStarfield() {
  starfieldLayer.invalidate();
  starfieldLayer.rebuild(pg -> {
    pg.background(8, 10, 18);
    pg.noStroke();
    for (int i = 0; i < 800; i++) {
      float x = random(pg.width);
      float y = random(pg.height);
      float s = random(1, 3);
      pg.fill(200, 220, 255, random(60, 180));
      pg.ellipse(x, y, s, s);
    }
  });
}

void updateShip() {
  // Steering towards mouse (use ship's actual screen position, not assumed center)
  Vector2 shipScreen = new Vector2(shipPos.x, shipPos.y);
  if (scene != null && scene.getCamera() != null) {
    shipScreen = scene.getCamera().worldToScreen(shipPos);
  }
  float targetAngle = atan2(mouseY - shipScreen.y, mouseX - shipScreen.x);
  float diff = targetAngle - shipAngle;
  while (diff > PI) diff -= TWO_PI;
  while (diff < -PI) diff += TWO_PI;
  shipAngle += diff * 0.1f;

  // Thrust
  if (mousePressed && mouseButton == LEFT) {
    shipSpeed = lerp(shipSpeed, 400, 0.02f);
  } else {
    shipSpeed = lerp(shipSpeed, 0, 0.03f);
  }

  shipVel.x = cos(shipAngle) * shipSpeed;
  shipVel.y = sin(shipAngle) * shipSpeed;
  shipPos.x += shipVel.x * engine.getGameTime().getDeltaTime();
  shipPos.y += shipVel.y * engine.getGameTime().getDeltaTime();

  // Sync to GameObject
  Scene scene = engine.getSceneManager().getActiveScene();
  GameObject ship = scene.findGameObject("ship");
  if (ship != null) {
    ship.getTransform().setPosition(shipPos);
    ship.getTransform().setRotation(shipAngle);
  }
}

void draw() {
  updateShip();

  Scene scene = engine.getSceneManager().getActiveScene();

  // Toggle culling on all objects
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
    // Sync background to camera viewport so it always fills the screen
    GameObject bg = scene.findGameObject("bg");
    if (bg != null) {
      Vector2 camPos = cam.getTransform().getPosition();
      bg.getTransform().setPosition(camPos.x - width/2, camPos.y - height/2);
    }
  }

  // Post-processing
  if (postFxEnabled) {
    engine.getPostProcessor().clear();
    engine.getPostProcessor().add(gfx -> {
      gfx.noStroke();
      gfx.fill(255, 200, 120, 15); // warm overlay
      gfx.rect(0, 0, gfx.width, gfx.height);
    });
  } else {
    engine.getPostProcessor().clear();
  }

  engine.update();
  if (skipClear) {
    // Trail effect: fade previous frame with a semi-transparent overlay
    noStroke();
    fill(8, 10, 18, 30);
    rect(0, 0, width, height);
    engine.renderSkipBackground();
  } else {
    engine.render();
  }

  // ── HUD (screen space, not affected by camera) ──
  drawHUD();
}

void drawHUD() {
  noStroke();
  fill(0, 0, 0, 160);
  rect(10, 10, 280, 170, 8);

  fill(255);
  textSize(14);
  int y = 32;
  text("RenderDemo — p5engine rendering system", 24, y); y += 22;
  text("FPS: " + nf(frameRate, 0, 1), 24, y); y += 20;
  text("Objects: " + scene.getObjectCount(), 24, y); y += 20;
  text("Ship pos: " + nf(shipPos.x, 0, 0) + ", " + nf(shipPos.y, 0, 0), 24, y); y += 20;
  text("Camera follow [C]: " + (cameraFollow ? "ON" : "OFF"), 24, y); y += 20;
  text("Viewport cull [V]: " + (cullingEnabled ? "ON" : "OFF"), 24, y); y += 20;
  text("PostFX warm [B]: " + (postFxEnabled ? "ON" : "OFF"), 24, y); y += 20;
  text("Skip clear [S]: " + (skipClear ? "ON (trails)" : "OFF"), 24, y); y += 20;
  text("Regen bg [R] | Left click = thrust", 24, y);
}

void keyPressed() {
  if (key == 'c' || key == 'C') cameraFollow = !cameraFollow;
  if (key == 'v' || key == 'V') cullingEnabled = !cullingEnabled;
  if (key == 'b' || key == 'B') postFxEnabled = !postFxEnabled;
  if (key == 's' || key == 'S') skipClear = !skipClear;
  if (key == 'r' || key == 'R') rebuildStarfield();
}

// ── Custom ship renderer (draws a triangle) ──
static class ShipRenderer extends Component implements Renderable {
  @Override
  public void render(IRenderer renderer) {
    renderer.setTransform(getGameObject().getTransform());
    PGraphics g = renderer.getGraphics();
    g.pushStyle();
    g.noStroke();
    g.fill(80, 200, 255);
    g.triangle(16, 0, -12, 10, -12, -10);
    // Engine glow
    g.fill(255, 120, 60, 180);
    g.ellipse(-14, 0, 10, 6);
    g.popStyle();
    renderer.resetTransform();
  }
}
