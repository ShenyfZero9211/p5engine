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

TdState state = TdState.MENU;
TdBuildMode buildMode = TdBuildMode.NONE;
boolean keyScrollUp, keyScrollDown, keyScrollLeft, keyScrollRight;
boolean wasKeyP;

public void settings() {
  P5Engine.configureDisplay(this, P5Config.defaults()
    .width(1280).height(720)
    .renderer(P5Config.RenderMode.P2D)
    .displayConfig(DisplayConfig.defaults()
      .designWidth(1280).designHeight(720).scaleMode(ScaleMode.FIT).resizable(true)));
}

public void setup() {
  inst = this;
  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
  engine.setApplicationTitle("TowerDefenseMin2");
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
      TdCamera.updateEdgeScroll(dt);
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

  if (state == TdState.PLAYING) {
    TdHUD.drawTopBar();
    TdHUD.drawBuildPanel();
    TdHUD.drawMinimap();
  }

  if (state == TdState.PLAYING && buildMode != TdBuildMode.NONE) {
    TdGhost.update();
    TdGhost.draw();
  }

  if (state == TdState.PAUSED) {
    TdHUD.drawPauseOverlay();
  }

  if (state == TdState.MENU) {
    TdMenuBg.drawTitle(this, TdAssets.i18n("menu.title"));
  }
}

void handleKeyboardInput(InputManager im) {
  keyScrollUp    = im.isKeyDown(PApplet.UP);
  keyScrollDown  = im.isKeyDown(PApplet.DOWN);
  keyScrollLeft  = im.isKeyDown(PApplet.LEFT);
  keyScrollRight = im.isKeyDown(PApplet.RIGHT);

  boolean isP = im.isKeyDown(java.awt.event.KeyEvent.VK_P);
  if (isP && !wasKeyP) {
    if (state == TdState.PLAYING) state = TdState.PAUSED;
    else if (state == TdState.PAUSED) state = TdState.PLAYING;
  }
  wasKeyP = isP;
}

void handleMouseInput(InputManager im) {
  if (state != TdState.PLAYING || camera == null) return;
  handleMouseWheelZoom(im);
  handleMouseDragPan(im);
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

void handleMouseClick(InputManager im) {
  if (!im.isMouseJustPressed()) return;
  Vector2 dm = getDesignMousePos(im);
  if (im.getMouseButton() == PApplet.LEFT) {
    if (TdHUD.isPauseButtonHit(dm.x, dm.y)) {
      state = TdState.PAUSED;
    } else {
      TdBuildMode clicked = TdHUD.getBuildModeAt(dm.x, dm.y);
      if (clicked != null) {
        buildMode = clicked;
      } else if (TdMinimap.isMouseOver()) {
        TdHUD.handleMinimapClick();
      } else if (buildMode != TdBuildMode.NONE && TdGhost.isValid) {
        TdGameWorld.tryPlaceTower(buildMode, TdGhost.gridX, TdGhost.gridY);
        buildMode = TdBuildMode.NONE;
      }
    }
  } else if (im.getMouseButton() == PApplet.RIGHT) {
    buildMode = TdBuildMode.NONE;
  }
}

Vector2 getDesignMousePos(InputManager im) {
  return engine.getDisplayManager().actualToDesign(new Vector2((int)im.getMouseX(), (int)im.getMouseY()));
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
