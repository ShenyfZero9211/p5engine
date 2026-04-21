/**
 * TowerDefenseMin — p5engine smoke-test sketch (thin main tab).
 * Gameplay: {@link TdGameWorld}; towers: {@link TowerController}; layout: {@link TdUiLayout};
 * UI tree: {@link TdMainUiBuilder}; flow: {@link TdFlowController}.
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.audio.*;

import processing.data.*;
import java.io.File;
import java.util.*;

static TowerDefenseMin inst;

P5Engine engine;
UIManager ui;
TdGameWorld world;
TdFlowController flow;

Scene sceneMenu;
Scene sceneGame;

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
/** After clicking a tower build button; false = not placing (no map preview / no LMB place). */
boolean buildArmed;
/** Toggle with Q: draw attack / slow radii for all operational towers. */
boolean showTowerRangeOverlay;

/** 上一次游玩的关卡编号，用于胜利/失败后重玩或进入下一关 */
int lastPlayedLevel = 1;

void settings() {
  size(1280, 720, P2D);
  smooth(8);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  inst = this;
  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
  engine.setApplicationTitle("TowerDefenseMin");
  engine.setSketchVersion("0.0.1");
  ui = new UIManager(this);
  ui.attach();

  SceneManager sm = engine.getSceneManager();
  sceneMenu = sm.createScene("Menu");
  sceneGame = sm.createScene("Game");
  sm.loadScene("Menu");

  world = new TdGameWorld(this, engine);
  
  // 初始化关卡路径配置
  TdLevelPath.initPaths(this);
  world.configurePath();

  flow = new TdFlowController(this);
  flow.finishSetup();
}

void keyPressed() {
  flow.onKeyPressed();
}

void draw() {
  flow.drawFrame();
}

void mousePressed() {
  flow.onMousePressed();
}
