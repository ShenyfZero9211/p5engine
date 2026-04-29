import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.audio.*;
import shenyf.p5engine.tween.*;

// ============================================
//  实例与核心引用
// ============================================
static TowerDefenseMin2 inst;
P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;
Scene gameScene;
Camera2D camera;
SceneViewport worldViewport;
Window worldWindow;

// ============================================
//  游戏常量与状态
// ============================================
static int WORLD_W = 2400;
static int WORLD_H = 1600;
static final String GAME_VERSION = "v0.0.6";

TdState state = TdState.MENU;
TdBuildMode buildMode = TdBuildMode.NONE;
boolean showTowerRanges = false;

// ============================================
//  输入状态
// ============================================
boolean keyScrollUp, keyScrollDown, keyScrollLeft, keyScrollRight;
boolean wasKeyP, wasKeyT, wasKeyQ, wasKeyW, wasKeyE, wasKeyR, wasKeySpace;

// ============================================
//  HUD 组件
// ============================================
TdTopBar hudTopBar;
TdBuildPanel hudBuildPanel;
TdMinimapComponent hudMinimap;
Panel sellMenuPanel;
Tower hoveredTower;

// ============================================
//  子系统
// ============================================
TdLightingSystem lighting;
shenyf.p5engine.pool.GenericObjectPool<Bullet> bulletDataPool;
shenyf.p5engine.pool.GenericObjectPool<GameObject> bulletGoPool;

// ============================================
//  Lifecycle
// ============================================
public void settings() {
  // Window size/position are managed by P5Engine via p5engine.ini.
  // P5Config defaults define the initial size when no saved state exists.
  P5Config p5cfg = P5Config.defaults()
    .renderer(P5Config.RenderMode.P2D)
    .width(1280).height(720)
    .centerWindow(true)
    .displayConfig(DisplayConfig.defaults()
    .designWidth(1280).designHeight(720)
    .resolutionPreset(shenyf.p5engine.rendering.ResolutionPreset.CUSTOM)
    .scaleMode(ScaleMode.FIT)
    .resizable(true));

  // Load saved window size from p5engine.ini so resolution changes persist across restarts
  String p5ini = sketchPath("p5engine.ini");
  shenyf.p5engine.config.SketchConfig p5cfgFile = new shenyf.p5engine.config.SketchConfig(p5ini);
  String savedW = p5cfgFile.get("window_size", "width");
  String savedH = p5cfgFile.get("window_size", "height");
  if (savedW != null && savedH != null) {
    int w = Integer.parseInt(savedW);
    int h = Integer.parseInt(savedH);
    p5cfg.width(w).height(h);
    p5cfg.getDisplayConfig().windowedSize(w, h);
  }

  P5Engine.configureDisplay(this, p5cfg);
}

public void setup() {
  inst = this;
  // Load config before any fullscreen check
  TdSaveData.load(this);
  // setResizable interferes with fullScreen() on some platforms
  if (!TdSaveData.isFullscreen()) {
    surface.setResizable(true);
  }
  new TdAppSetup().run();
}

public void draw() {
  TdAppLoop.run(this);
}

void windowResize(int newW, int newH) {
  if (engine != null) {
    engine.getDisplayManager().onWindowResize(newW, newH);
  }
}

public void keyPressed() {
  TdAppInput.keyPressed(this);
}

// Delegates for external callers (e.g. TdFlow)
void setupWorldViewport() {
  new TdAppSetup().setupWorldViewport();
}
void setupHud() {
  new TdAppSetup().setupHud();
}
