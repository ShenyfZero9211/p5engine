/**
 * TowerDefenseMin — p5engine v0.4.1 showcase
 * Features: YAML config, Camera2D, Minimap, Time Scaling, DisplayManager, AnchorLayout
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.audio.*;
import shenyf.p5engine.rendering.*;

import processing.data.*;
import java.io.File;
import java.util.*;

static TowerDefenseMin inst;

// ── World size (larger than screen, camera can pan/zoom) ──
static final int WORLD_W = 2400;
static final int WORLD_H = 1600;

P5Engine engine;
UIManager ui;
TdGameWorld world;
TdFlowController flow;

Scene sceneMenu;
Scene sceneGame;
Camera2D camera;
Minimap minimap;

// WorldViewport UI components (manage world rendering inside UI system)
SceneViewport worldViewport;
MinimapViewport minimapViewport;

// Debug: last zoom anchor position (world coords)
Vector2 debugZoomFocusWorld = null;
int debugZoomFocusTimer = 0;

int appMode;

Panel panelMenu;
Panel panelSettings;
Panel panelLevelSelect;
Panel panelEndOverlay;
Label lblMenuHint;
Label lblEndMsg;
Label settingsTitle;
Label settingsLblEnemy;
Label settingsLblFps;
Slider sliderMasterVol;
Slider sliderBgmVol;
Slider sliderSfxVol;
Label lblMasterTitle;
Label lblBgmTitle;
Label lblSfxTitle;
Label lblMasterVal;
Label lblBgmVal;
Label lblSfxVal;
Button btnStart;
Button btnLoad;
Button btnSettings;
Button btnQuit;
Button btnSettingsBack;
Button btnLangZh;
Button btnLangEn;
Slider sliderEnemyMult;
Slider sliderTargetFps;
Label lblSettingsNote;

Panel panelTopHud;
Panel panelRight;
Label lblHudLine;
Label lblLoadMsg;
Label lblTowerHint;
Button btnTowerMg;
Button btnTowerMissile;
Button btnTowerLaser;
Button btnTowerSlow;
Button btnSave;
Button btnToMenu;
Button btnEndMenu;
Button btnNextLevel;
Button btnReplayLevel;

TowerKind buildSelected = TowerKind.MG;
boolean buildArmed;
boolean showTowerRangeOverlay;

int lastPlayedLevel = 1;

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
  inst = this;
  surface.setResizable(true);

  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
  engine.setApplicationTitle("TowerDefenseMin");
  engine.setSketchVersion("0.1.0");

  // 启用 Camera / Minimap 调试日志（必须同时设级别为 DEBUG，否则被 INFO 过滤）
  shenyf.p5engine.util.Logger.setLevel(shenyf.p5engine.util.Logger.Level.DEBUG);
  shenyf.p5engine.util.Logger.setDebugEnabled(true);
  shenyf.p5engine.util.Logger.setTagFilter("Camera", "Minimap", "TdFlow");

  // ── Load YAML configs first ──
  TdYamlConfig.load(this);

  ui = new UIManager(this);
  ui.attach();

  SceneManager sm = engine.getSceneManager();
  sceneMenu = sm.createScene("Menu");
  sceneGame = sm.createScene("Game");
  sm.loadScene("Menu");

  // UI tweens should use real time so menus stay responsive during pause
  engine.getTweenManager().setUseUnscaledTime(true);

  world = new TdGameWorld(this, engine);
  TdLevelPath.initPaths(this, WORLD_W, WORLD_H);

  flow = new TdFlowController(this);
  flow.finishSetup();

  // CRITICAL FIX: sync DisplayManager to actual window size.
  // P5Engine.create() may have captured the default 800x600 size before
  // settings()/size() took effect. Force a resize sync now.
  engine.getDisplayManager().onWindowResize(width, height);
}

boolean keyScrollUp, keyScrollDown, keyScrollLeft, keyScrollRight;

void keyPressed() {
  flow.onKeyPressed();

  // Time-scale controls
  P5GameTime gt = engine.getGameTime();
  if (key == '1') gt.setTargetTimeScale(0.1f);
  if (key == '2') gt.setTargetTimeScale(0.5f);
  if (key == '3') gt.setTargetTimeScale(1.0f);
  if (key == '4') gt.setTargetTimeScale(2.0f);
  if (key == '5') gt.setTargetTimeScale(5.0f);
  if (key == 'p' || key == 'P') gt.togglePause();

  // Camera scroll keys
  if (keyCode == UP) keyScrollUp = true;
  if (keyCode == DOWN) keyScrollDown = true;
  if (keyCode == LEFT) keyScrollLeft = true;
  if (keyCode == RIGHT) keyScrollRight = true;

  // Camera zoom keys (centered on viewport center)
  if (camera != null && (appMode == 2 || appMode == 3 || appMode == 4)) {
    if (key == '+' || key == '=') {
      Vector2 center = new Vector2((1280 - TdConfig.RIGHT_W) * 0.5f, TdConfig.TOP_HUD + (720 - TdConfig.TOP_HUD) * 0.5f);
      camera.zoomAt(1, center);
      shenyf.p5engine.util.Logger.debug("Mouse", String.format("keyZoom IN  center=(%.1f,%.1f) camPos=(%.1f,%.1f) zoom=%.2f", center.x, center.y, camera.getTransform().getPosition().x, camera.getTransform().getPosition().y, camera.getZoom()));
    }
    if (key == '-') {
      Vector2 center = new Vector2((1280 - TdConfig.RIGHT_W) * 0.5f, TdConfig.TOP_HUD + (720 - TdConfig.TOP_HUD) * 0.5f);
      camera.zoomAt(-1, center);
      shenyf.p5engine.util.Logger.debug("Mouse", String.format("keyZoom OUT center=(%.1f,%.1f) camPos=(%.1f,%.1f) zoom=%.2f", center.x, center.y, camera.getTransform().getPosition().x, camera.getTransform().getPosition().y, camera.getZoom()));
    }
  }
}

void keyReleased() {
  if (keyCode == UP) keyScrollUp = false;
  if (keyCode == DOWN) keyScrollDown = false;
  if (keyCode == LEFT) keyScrollLeft = false;
  if (keyCode == RIGHT) keyScrollRight = false;
}

void draw() {
  flow.drawFrame();
}

void mousePressed() {
  flow.onMousePressed();
}

/** Returns true if actual mouse position is inside the world viewport area. */
boolean isMouseInWorldViewport() {
  if (engine == null) return false;
  Vector2 tl = engine.getDisplayManager().designToActual(new Vector2(0, TdConfig.TOP_HUD));
  Vector2 br = engine.getDisplayManager().designToActual(new Vector2(1280 - TdConfig.RIGHT_W, 720));
  return mouseX >= tl.x && mouseX <= br.x && mouseY >= tl.y && mouseY <= br.y;
}

void mouseWheel(processing.event.MouseEvent event) {
  if (camera != null && (appMode == 2 || appMode == 3 || appMode == 4)) {
    if (!isMouseInWorldViewport()) return;
    Vector2 designMouse = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
    Vector2 focusWorld = camera.screenToWorld(designMouse);
    debugZoomFocusWorld = focusWorld;
    debugZoomFocusTimer = 120; // show for ~2 seconds at 60fps
    shenyf.p5engine.util.Logger.debug("Mouse", String.format("mouseWheel actual=(%d,%d) design=(%.1f,%.1f) focusWorld=(%.1f,%.1f) zoom=%.2f", mouseX, mouseY, designMouse.x, designMouse.y, focusWorld.x, focusWorld.y, camera.getZoom()));
    camera.zoomAt(-event.getCount(), designMouse);
    Vector2 p = camera.getTransform().getPosition();
    shenyf.p5engine.util.Logger.debug("Mouse", String.format("mouseWheel after camPos=(%.1f,%.1f) zoom=%.2f", p.x, p.y, camera.getZoom()));
  }
}

void mouseDragged() {
  if (camera != null && mouseButton == CENTER && (appMode == 2 || appMode == 3 || appMode == 4)) {
    Vector2 curr = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
    Vector2 prev = engine.getDisplayManager().actualToDesign(new Vector2(pmouseX, pmouseY));
    float dx = curr.x - prev.x;
    float dy = curr.y - prev.y;
    camera.getTransform().translate(-dx / camera.getZoom(), -dy / camera.getZoom());
    camera.clampToBounds();
  }
}

void windowResized() {
  if (engine != null) {
    engine.getDisplayManager().onWindowResize(width, height);
    if (camera != null) {
      camera.setViewportSize(engine.getDisplayManager().getDesignWidth() - TdConfig.RIGHT_W, engine.getDisplayManager().getDesignHeight() - TdConfig.TOP_HUD);
      camera.setViewportOffset(0, TdConfig.TOP_HUD);
    }
  }
}

/** Renders the tower placement ghost preview in world space. */
public static class PlacementGhostController extends Component implements Renderable {

    final TowerDefenseMin app;

    PlacementGhostController(TowerDefenseMin app) {
        this.app = app;
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(30);
    }

    @Override
    public void render(IRenderer renderer) {
        if (!app.buildArmed || app.appMode != 2) return;

        PGraphics g = renderer.getGraphics();
        float mx = app.mouseX;
        float my = app.mouseY;
        if (app.camera != null) {
            Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(mx, my));
            Vector2 w = app.camera.screenToWorld(designMouse);
            mx = w.x;
            my = w.y;
            shenyf.p5engine.util.Logger.debug("Ghost", String.format("render actual=(%d,%d) design=(%.1f,%.1f) world=(%.1f,%.1f)", app.mouseX, app.mouseY, designMouse.x, designMouse.y, mx, my));
        }

        if (mx < 0 || mx > WORLD_W || my < 0 || my > WORLD_H) return;

        TowerDef d = TowerDef.forKind(app.buildSelected);
        if (d == null) return;

        int gx = (int) TdGameWorld.snapGrid(mx);
        int gy = (int) TdGameWorld.snapGrid(my);
        boolean ok = app.world.money >= d.cost && app.world.canPlaceTower(gx, gy);
        float planR = d.kind == TowerKind.SLOW ? d.aoeRadius : d.range;

        g.noFill();
        g.strokeWeight(2);
        g.stroke(255, 210, 90, ok ? 175 : 100);
        TdGameWorld.strokeRangeRing(g, gx, gy, planR);
        g.rectMode(PGraphics.CENTER);
        float cr = g.red(d.iconColor);
        float cg = g.green(d.iconColor);
        float cb = g.blue(d.iconColor);
        g.fill(cr, cg, cb, ok ? 110 : 55);
        g.stroke(ok ? 140 : 90, ok ? 220 : 120, 255, ok ? 200 : 90);
        g.strokeWeight(2);
        g.rect(gx, gy, 28, 28, 4);
        g.rectMode(PGraphics.CORNER);
        g.noStroke();
    }
}
