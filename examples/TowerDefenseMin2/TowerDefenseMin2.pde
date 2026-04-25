import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.audio.*;
import shenyf.p5engine.tween.*;

static TowerDefenseMin2 inst;

P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;
Scene gameScene;
Camera2D camera;
SceneViewport worldViewport;
Window worldWindow;

static int WORLD_W = 2400;
static int WORLD_H = 1600;

static final String GAME_VERSION = "v0.0.6";

TdState state = TdState.MENU;
TdBuildMode buildMode = TdBuildMode.NONE;
boolean keyScrollUp, keyScrollDown, keyScrollLeft, keyScrollRight;
boolean wasKeyP;
boolean wasKeyR;
boolean showTowerRanges = false;

// HUD UI components (managed by p5engine UI library)
TdTopBar hudTopBar;
TdBuildPanel hudBuildPanel;
TdMinimapComponent hudMinimap;

// Bullet object pools (zero-GC)
shenyf.p5engine.pool.GenericObjectPool<Bullet> bulletDataPool;
shenyf.p5engine.pool.GenericObjectPool<GameObject> bulletGoPool;

public void settings() {
  P5Engine.configureDisplay(this, P5Config.defaults()
    .width(1280).height(720)
    .renderer(P5Config.RenderMode.P2D)
    .centerWindow(true)
    .displayConfig(DisplayConfig.defaults()
      .designWidth(1280).designHeight(720).scaleMode(ScaleMode.FIT).resizable(true)));
}

public void setup() {
  inst = this;
  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));

  // Center window and confine mouse (must be called before setResizable on P2D)
  engine.centerWindow();
  engine.setMouseConfined(true);
  engine.setApplicationTitle("TowerDefenseMin2");
  engine.getDebugOverlay().toggle();
  // Logger debug enabled for development
  // shenyf.p5engine.util.Logger.setDebugEnabled(true);
  // shenyf.p5engine.util.Logger.setLevel(shenyf.p5engine.util.Logger.Level.DEBUG);
  ui = new UIManager(this);
  ui.attach();
  sketchUi = new SketchUiCoordinator(this, ui);
  TdTheme theme = new TdTheme();
  PFont cnFont = createFont("Microsoft YaHei", 48);
  theme.setFont(cnFont);
  TdMenuBg.setFont(cnFont);
  ui.setTheme(theme);

  gameScene = engine.getSceneManager().getActiveScene();
  setupCamera();

  // World background renderer (grid, path, base, exit) — lives in Scene
  GameObject bgGo = GameObject.create("world_bg");
  WorldBgRenderer bgR = new WorldBgRenderer();
  bgGo.addComponent(bgR);
  bgGo.setRenderLayer(0);
  bgGo.setCullEnabled(false);
  gameScene.addGameObject(bgGo);

  // Initialize bullet object pools
  bulletDataPool = engine.createPool(
    () -> new Bullet(),
    b -> { b.dead = true; b.gameObject = null; }
  );
  bulletDataPool.preload(100);

  bulletGoPool = engine.createPool(() -> {
    GameObject go = GameObject.create("Bullet");
    go.setTag("pooled_bullet");
    go.setRenderLayer(15);
    go.addComponent(new BulletRenderer());
    gameScene.addGameObject(go);
    return go;
  });
  bulletGoPool.preload(100);

  TdAssets.loadAll(this);
  TdSound.initTracks(this);
  TdSaveData.load(this);
  // Restore persisted audio & language settings
  TdAssets.setMasterVolume(TdSaveData.getMasterVolume());
  TdAssets.setBgmVolume(TdSaveData.getBgmVolume());
  TdAssets.setSfxVolume(TdSaveData.getSfxVolume());
  engine.getI18n().setLocale(TdSaveData.getLanguage());
  engine.addOnDisposeListener(() -> TdSaveData.saveSettings());
  TdFlow.buildMainMenu(this);
}

void setupCamera() {
  GameObject camGo = GameObject.create("camera");
  camera = camGo.addComponent(Camera2D.class);
  camera.setWorldBounds(new Rect(0, 0, WORLD_W, WORLD_H));
  camera.jumpCenterTo(WORLD_W * 0.5f, WORLD_H * 0.5f);
  gameScene.setCamera(camera);
  gameScene.addGameObject(camGo);
}

void setupWorldViewport() {
  if (worldWindow != null) {
    ui.getRoot().remove(worldWindow);
  }
  worldWindow = new Window("world_win");
  worldWindow.setBounds(0, TdConfig.TOP_HUD, 1280 - TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
  worldWindow.setZOrder(0);
  worldWindow.hideTitleBar();
  worldWindow.setResizable(false);
  ui.getRoot().add(worldWindow);

  worldViewport = new SceneViewport("world_vp");
  worldViewport.setBounds(1, 1, worldWindow.getWidth() - 2, worldWindow.getHeight() - 2);
  worldViewport.setScene(gameScene);
  worldViewport.setCamera(camera);
  worldWindow.add(worldViewport);

  int vpW = (int)(worldWindow.getWidth() - 2);
  int vpH = (int)(worldWindow.getHeight() - 2);
  camera.setViewportSize(vpW, vpH);
  camera.setViewportOffset(worldWindow.getAbsoluteX() + 1, worldWindow.getAbsoluteY() + 1);
}

public void draw() {
  engine.update();
  float dt = engine.getGameTime().getDeltaTime();
  float dtReal = engine.getGameTime().getRealDeltaTime();

  if (state == TdState.PLAYING || state == TdState.PAUSED) {
    background(14, 18, 34);
  } else {
    TdMenuBg.update(dtReal);
    TdMenuBg.draw(this);
  }

  InputManager im = engine.getInput();
  handleKeyboardInput(im);

  switch (state) {
    case PLAYING:
      TdGameWorld.update(dt);
      TdCamera.updateEdgeScroll(dtReal);
      syncCameraToWindow();
      break;
    case PAUSED:
      // freeze game logic
      break;
    default:
      break;
  }

  handleMouseInput(im);

  sketchUi.updateFrame(dtReal);
  sketchUi.renderFrame();

  if (state == TdState.PLAYING && buildMode != TdBuildMode.NONE) {
    TdGhost.update();
  }

  // DEBUG: minimap hit test (disabled for release)
  // if (state == TdState.PLAYING && hudMinimap != null) {
  //   boolean hit = hudMinimap.containsPoint(mouseX, mouseY);
  //   UIComponent rootHit = ui.getRoot().hitTest(mouseX, mouseY);
  //   println("[DEBUG] mouse=" + mouseX + "," + mouseY + " minimapBounds=" + hudMinimap.getAbsoluteX() + "," + hudMinimap.getAbsoluteY() + "," + hudMinimap.getWidth() + "," + hudMinimap.getHeight() + " contains=" + hit + " rootHit=" + (rootHit != null ? rootHit.getId() : "null"));
  // }

  if (state == TdState.PAUSED) {
    // Only show "PAUSED" text when pause menu is NOT open (ESC menu has its own UI)
    boolean hasPauseMenu = false;
    for (UIComponent c : ui.getRoot().getChildren()) {
      if ("pause_overlay".equals(c.getId())) {
        hasPauseMenu = true;
        break;
      }
    }
    if (!hasPauseMenu) {
      TdHUD.drawPauseOverlay();
    }
  }

  if (state == TdState.MENU) {
    println("[DEBUG] draw() MENU titleProgress=" + TdMenuBg.titleProgress);
    TdMenuBg.drawTitle(this, TdAssets.i18n("menu.title"));
  }

  // Render debug overlay
  engine.renderDebugOverlay();
}

void handleKeyboardInput(InputManager im) {
  keyScrollUp    = im.isKeyDown(PApplet.UP);
  keyScrollDown  = im.isKeyDown(PApplet.DOWN);
  keyScrollLeft  = im.isKeyDown(PApplet.LEFT);
  keyScrollRight = im.isKeyDown(PApplet.RIGHT);

  boolean isP = im.isKeyDown(java.awt.event.KeyEvent.VK_P);
  if (isP && !wasKeyP) {
    if (state == TdState.PLAYING) {
      TdFlow.showPauseMenu(this);
    } else if (state == TdState.PAUSED) {
      TdFlow.hidePauseMenu(this);
    }
  }
  wasKeyP = isP;

  boolean isR = im.isKeyDown(java.awt.event.KeyEvent.VK_R);
  if (isR && !wasKeyR) {
    showTowerRanges = !showTowerRanges;
  }
  wasKeyR = isR;
}

public void keyPressed() {
  if (key == ESC) {
    key = 0; // Block Processing default quit behavior
    if (state == TdState.PLAYING) {
      TdFlow.showPauseMenu(this);
    } else if (state == TdState.PAUSED) {
      TdFlow.hidePauseMenu(this);
    }
    return;
  }

  // Time scale controls (only during gameplay)
  if (state == TdState.PLAYING) {
    switch (key) {
      case '1': engine.getGameTime().setTargetTimeScale(0.2f); break;
      case '2': engine.getGameTime().setTargetTimeScale(0.5f); break;
      case '3': engine.getGameTime().setTargetTimeScale(1.0f); break;
      case '4': engine.getGameTime().setTargetTimeScale(2.0f); break;
      case '5': engine.getGameTime().setTargetTimeScale(5.0f); break;
    }
  }
}

void handleMouseInput(InputManager im) {
  if (state != TdState.PLAYING || camera == null) return;
  handleMouseWheelZoom(im);
  handleMouseClick(im);
}

void handleMouseWheelZoom(InputManager im) {
  if (!TdCamera.isMouseInViewport()) return;
  float wheel = im.getMouseWheelDelta();
  if (wheel == 0) return;
  Vector2 focus;
  if (TdSaveData.isZoomAtMouse()) {
    focus = engine.getDisplayManager().actualToDesign(new Vector2((int)im.getMouseX(), (int)im.getMouseY()));
  } else {
    float cx = worldWindow.getAbsoluteX() + worldWindow.getWidth() * 0.5f;
    float cy = worldWindow.getAbsoluteY() + worldWindow.getHeight() * 0.5f;
    focus = new Vector2(cx, cy);
  }
  camera.zoomAt(-wheel * 0.24f, focus);
}

void handleMouseDragPan(InputManager im) {
  if (!im.isMousePressed() || im.getMouseButton() != PApplet.LEFT) return;
  if (!TdCamera.isMouseInViewport()) return;
  float ddx = im.getMouseDragDX();
  float ddy = im.getMouseDragDY();
  if (ddx != 0 || ddy != 0) {
    camera.getTransform().translate(-ddx / camera.getZoom(), -ddy / camera.getZoom());
    camera.clampToBounds();
  }
}

void setupHud() {
  Panel root = ui.getRoot();

  hudTopBar = new TdTopBar("hud_top");
  hudTopBar.setZOrder(5);
  root.add(hudTopBar);

  hudBuildPanel = new TdBuildPanel("hud_build");
  hudBuildPanel.setZOrder(5);
  root.add(hudBuildPanel);

  hudMinimap = new TdMinimapComponent("hud_minimap");
  hudMinimap.setPosition(1280 - TdConfig.RIGHT_W + 16, 720 - TdMinimapComponent.MH - 16);
  hudMinimap.setZOrder(10);  // higher zOrder so hitTest finds it before hud_build
  root.add(hudMinimap);
}

void handleMouseClick(InputManager im) {
  Vector2 dm = getDesignMousePos(im);

  // Place tower on world viewport click
  if (im.isMouseJustPressed() && im.getMouseButton() == PApplet.LEFT) {
    if (buildMode != TdBuildMode.NONE && TdGhost.isValid && !isMouseOverHud()) {
      TdGameWorld.tryPlaceTower(buildMode, TdGhost.gridX, TdGhost.gridY);
      buildMode = TdBuildMode.NONE;
      TdGhost.cleanup(this);
    }
  }

  // Right-click cancel
  if (im.isMouseJustPressed() && im.getMouseButton() == PApplet.RIGHT) {
    buildMode = TdBuildMode.NONE;
    TdGhost.cleanup(this);
  }
}

Vector2 getDesignMousePos(InputManager im) {
  return engine.getDisplayManager().actualToDesign(new Vector2((int)im.getMouseX(), (int)im.getMouseY()));
}

boolean isMouseOverHud() {
  if (ui == null) return false;
  UIComponent hit = ui.getRoot().hitTest(mouseX, mouseY);
  if (hit == null) return false;
  String id = hit.getId();
  return !id.equals("world_win") && !id.equals("world_vp") && !id.equals("ui_root");
}

void syncCameraToWindow() {
  if (worldWindow == null || camera == null) return;
  float newX = worldWindow.getAbsoluteX() + 1;
  float newY = worldWindow.getAbsoluteY() + 1;
  if (newX != camera.getViewportOffsetX() || newY != camera.getViewportOffsetY()) {
    camera.setViewportOffset(newX, newY);
  }
  float newW = worldWindow.getWidth() - 2;
  float newH = worldWindow.getHeight() - 2;
  if (newW != camera.getViewportWidth() || newH != camera.getViewportHeight()) {
    camera.setViewportSize(newW, newH);
  }
}



enum TdState { MENU, LEVEL_SELECT, PLAYING, PAUSED, WIN, LOSE }
enum TdBuildMode { NONE, MG, MISSILE, LASER, SLOW }
