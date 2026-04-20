/**
 * TowerDefenseMin — minimal tower defense sketch to stress-test p5engine:
 * P5Engine + SceneManager + GameObject/Component (towers) + UIManager.
 * Custom battlefield drawing; engine.update() only (no engine.render()).
 */

import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.ui.*;

import processing.data.*;
import java.util.*;

// —— layout ——
final int TOP_HUD = 40;
final int RIGHT_W = 240;
final int GRID = 40;
final int INITIAL_ORBS = 3;
final int INITIAL_MONEY = 420;
final int TOTAL_WAVES = 5;
final float PICKUP_R = 48f;
final float ROLL_SPEED = 70f;

static TowerDefenseMin inst;

P5Engine engine;
UIManager ui;

// scenes
Scene sceneMenu;
Scene sceneGame;

// mode
int appMode; // 0 menu 1 settings 2 game 3 win 4 lose

// menu / settings UI
Panel panelMenu;
Panel panelSettings;
Panel panelEndOverlay;
Label lblMenuHint;
Label lblEndMsg;
Label settingsTitle;
Label settingsLblEnemy;
Label settingsLblFps;
Button btnStart;
Button btnLoad;
Button btnSettings;
Button btnQuit;
Button btnSettingsBack;
Slider sliderEnemyMult;
Slider sliderTargetFps;
Label lblSettingsNote;

// game UI
Panel panelTopHud;
Panel panelRight;
Label lblHudLine;
Label lblLoadMsg;
Button btnTowerMg;
Button btnTowerMissile;
Button btnTowerLaser;
Button btnTowerSlow;
Label lblTowerHint;
Button btnSave;
Button btnToMenu;
Button btnEndMenu;

// game state
TdPath path;
int baseVertexIndex = 4;
float[] vertexDist;
float pathTotal;

ArrayList<TdEnemy> enemies = new ArrayList<TdEnemy>();
ArrayList<TdRollingOrb> rolling = new ArrayList<TdRollingOrb>();

int money = INITIAL_MONEY;
int baseOrbs = INITIAL_ORBS;
int lostOrbs = 0;
int currentWave = 0;
int toSpawnInWave = 0;
float spawnCooldown = 0;
float matchElapsed = 0;
float enemyHpMult = 1f;

TowerKind buildSelected = TowerKind.MG;

int nextTowerId = 1;

boolean betweenWaves = false;
float interWaveDelay = 0;
boolean allWavesSpawned = false;

void settings() {
  size(1280, 720, P2D);
  smooth(8);
  P5Engine.applyRecommendedPixelDensity(this);
}

void setup() {
  surface.setTitle("TowerDefenseMin (p5engine)");
  inst = this;
  engine = P5Engine.create(this);
  ui = new UIManager(this);
  ui.attach();

  SceneManager sm = engine.getSceneManager();
  sceneMenu = sm.createScene("Menu");
  sceneGame = sm.createScene("Game");
  sm.loadScene("Menu");

  buildPath();
  buildUi();
}

void buildPath() {
  float pw = width - RIGHT_W;
  float ph = height - TOP_HUD;
  path = new TdPath(new Vector2[] {
    new Vector2(48, ph * 0.12f),
    new Vector2(pw * 0.18f, ph * 0.22f),
    new Vector2(pw * 0.32f, ph * 0.38f),
    new Vector2(pw * 0.44f, ph * 0.52f),
    new Vector2(pw * 0.52f, ph * 0.48f),
    new Vector2(pw * 0.66f, ph * 0.62f),
    new Vector2(pw * 0.82f, ph * 0.78f),
    new Vector2(pw - 40, ph - 36)
  });
  vertexDist = path.vertexDistances();
  pathTotal = path.totalLength;
  baseVertexIndex = min(4, path.points.length - 2);
}

void buildUi() {
  Panel root = ui.getRoot();
  root.removeAllChildren();
  root.setLayoutManager(null);

  panelMenu = new Panel("menu_root");
  panelMenu.setLayoutManager(null);
  panelMenu.setPaintBackground(true);

  lblMenuHint = new Label("menu_hint");
  lblMenuHint.setText("TowerDefenseMin — p5engine smoke test");
  lblMenuHint.setSize(520, 28);
  panelMenu.add(lblMenuHint);

  btnStart = new Button("m_start");
  btnStart.setLabel("开始游戏");
  btnStart.setSize(220, 40);
  btnStart.setAction(() -> startNewGame(false));
  panelMenu.add(btnStart);

  btnLoad = new Button("m_load");
  btnLoad.setLabel("载入游戏");
  btnLoad.setSize(220, 40);
  btnLoad.setAction(() -> tryLoadGame());
  panelMenu.add(btnLoad);

  btnSettings = new Button("m_set");
  btnSettings.setLabel("设置");
  btnSettings.setSize(220, 40);
  btnSettings.setAction(() -> enterSettings(true));
  panelMenu.add(btnSettings);

  btnQuit = new Button("m_quit");
  btnQuit.setLabel("退出");
  btnQuit.setSize(220, 40);
  btnQuit.setAction(() -> exit());
  panelMenu.add(btnQuit);

  lblLoadMsg = new Label("load_msg");
  lblLoadMsg.setText("");
  lblLoadMsg.setSize(400, 24);
  panelMenu.add(lblLoadMsg);

  root.add(panelMenu);

  panelSettings = new Panel("settings_root");
  panelSettings.setLayoutManager(null);
  panelSettings.setPaintBackground(true);
  panelSettings.setVisible(false);

  settingsTitle = new Label("st_title");
  settingsTitle.setText("设置（占位）");
  settingsTitle.setSize(280, 28);
  panelSettings.add(settingsTitle);

  settingsLblEnemy = new Label("st_l1");
  settingsLblEnemy.setText("敌人生成 / 强度倍率");
  settingsLblEnemy.setSize(280, 22);
  panelSettings.add(settingsLblEnemy);

  sliderEnemyMult = new Slider("st_em");
  sliderEnemyMult.setSize(260, 28);
  sliderEnemyMult.setValue(0.5f);
  panelSettings.add(sliderEnemyMult);

  settingsLblFps = new Label("st_l2");
  settingsLblFps.setText("目标帧率（占位，仅保存）");
  settingsLblFps.setSize(280, 22);
  panelSettings.add(settingsLblFps);

  sliderTargetFps = new Slider("st_fps");
  sliderTargetFps.setSize(260, 28);
  sliderTargetFps.setValue((60f - 30f) / (120f - 30f));
  panelSettings.add(sliderTargetFps);

  lblSettingsNote = new Label("st_note");
  lblSettingsNote.setText("音量等可后续接入；当前写入 save.json 的 meta。");
  lblSettingsNote.setSize(420, 44);
  panelSettings.add(lblSettingsNote);

  btnSettingsBack = new Button("st_back");
  btnSettingsBack.setLabel("返回");
  btnSettingsBack.setSize(160, 36);
  btnSettingsBack.setAction(() -> enterSettings(false));
  panelSettings.add(btnSettingsBack);

  root.add(panelSettings);

  panelTopHud = new Panel("top_hud");
  panelTopHud.setLayoutManager(null);
  panelTopHud.setPaintBackground(true);
  lblHudLine = new Label("hud");
  lblHudLine.setText("");
  lblHudLine.setSize(width - RIGHT_W - 160, 28);
  panelTopHud.add(lblHudLine);

  btnSave = new Button("save");
  btnSave.setLabel("保存");
  btnSave.setSize(72, 28);
  btnSave.setAction(() -> saveGame());
  panelTopHud.add(btnSave);

  btnToMenu = new Button("to_menu");
  btnToMenu.setLabel("菜单");
  btnToMenu.setSize(72, 28);
  btnToMenu.setAction(() -> goMenuFromGame());
  panelTopHud.add(btnToMenu);

  root.add(panelTopHud);

  panelRight = new Panel("right");
  panelRight.setLayoutManager(null);
  panelRight.setPaintBackground(true);

  Label lr = new Label("lr_title");
  lr.setText("建造");
  lr.setSize(RIGHT_W - 16, 24);
  panelRight.add(lr);

  btnTowerMg = mkTowerBtn("t_mg", "机枪", TowerKind.MG);
  btnTowerMissile = mkTowerBtn("t_ms", "导弹", TowerKind.MISSILE);
  btnTowerLaser = mkTowerBtn("t_lz", "激光", TowerKind.LASER);
  btnTowerSlow = mkTowerBtn("t_sl", "减速", TowerKind.SLOW);

  lblTowerHint = new Label("t_hint");
  lblTowerHint.setText("");
  lblTowerHint.setSize(RIGHT_W - 12, 120);
  panelRight.add(lblTowerHint);

  root.add(panelRight);

  panelTopHud.setVisible(false);
  panelRight.setVisible(false);

  panelEndOverlay = new Panel("end_overlay");
  panelEndOverlay.setLayoutManager(null);
  panelEndOverlay.setPaintBackground(true);
  panelEndOverlay.setVisible(false);

  lblEndMsg = new Label("end_lbl");
  lblEndMsg.setText("");
  lblEndMsg.setSize(400, 40);
  panelEndOverlay.add(lblEndMsg);

  btnEndMenu = new Button("end_menu");
  btnEndMenu.setLabel("回主菜单");
  btnEndMenu.setSize(200, 40);
  btnEndMenu.setAction(() -> {
    panelEndOverlay.setVisible(false);
    goMenuFromGame();
  });
  panelEndOverlay.add(btnEndMenu);
  panelEndOverlay.setZOrder(200);
  root.add(panelEndOverlay);

  root.invalidateLayout();
}

Button mkTowerBtn(String id, String text, TowerKind k) {
  Button b = new Button(id);
  b.setLabel(text);
  b.setSize(RIGHT_W - 24, 36);
  b.setAction(() -> {
    buildSelected = k;
    syncTowerHint();
  });
  panelRight.add(b);
  return b;
}

void enterSettings(boolean on) {
  appMode = on ? 1 : 0;
  panelSettings.setVisible(on);
  panelMenu.setVisible(!on);
}

void startNewGame(boolean fromLoad) {
  lblLoadMsg.setText("");
  if (panelEndOverlay != null) {
    panelEndOverlay.setVisible(false);
  }
  engine.getSceneManager().loadScene("Game");
  Scene g = engine.getSceneManager().getActiveScene();
  g.clear();
  enemies.clear();
  rolling.clear();
  if (!fromLoad) {
    money = INITIAL_MONEY;
    baseOrbs = INITIAL_ORBS;
    lostOrbs = 0;
    matchElapsed = 0;
    betweenWaves = false;
    allWavesSpawned = false;
    interWaveDelay = 0;
    applySettingsMultipliers();
    beginWave(1);
    spawnCooldown = 1.2f;
  }
  appMode = 2;
  panelMenu.setVisible(false);
  panelSettings.setVisible(false);
  panelTopHud.setVisible(true);
  panelRight.setVisible(true);
  nextTowerId = 1;
  syncTowerHint();
}

void beginWave(int w) {
  currentWave = w;
  toSpawnInWave = 4 + w * 2;
  spawnCooldown = 1.5f;
}

void applySettingsMultipliers() {
  float t = sliderEnemyMult != null ? sliderEnemyMult.getValue() : 0.5f;
  enemyHpMult = 0.65f + t * 1.1f;
}

float settingsTargetFps() {
  if (sliderTargetFps == null) return 60f;
  return 30f + sliderTargetFps.getValue() * 90f;
}

void goMenuFromGame() {
  engine.getSceneManager().loadScene("Menu");
  appMode = 0;
  panelTopHud.setVisible(false);
  panelRight.setVisible(false);
  panelMenu.setVisible(true);
  panelSettings.setVisible(false);
  if (panelEndOverlay != null) {
    panelEndOverlay.setVisible(false);
  }
}

void tryLoadGame() {
  File f = new File(sketchPath("save.json"));
  if (!f.exists()) {
    lblLoadMsg.setText("未找到 save.json");
    return;
  }
  try {
    JSONObject o = loadJSONObject(f);
    if (o == null) {
      lblLoadMsg.setText("save.json 解析失败");
      return;
    }
    money = o.getInt("money", INITIAL_MONEY);
    baseOrbs = o.getInt("baseOrbs", INITIAL_ORBS);
    lostOrbs = o.getInt("lostOrbs", 0);
    matchElapsed = o.getFloat("matchElapsed", 0);
    currentWave = max(1, min(TOTAL_WAVES, o.getInt("wave", 1)));
    if (o.hasKey("toSpawn")) {
      toSpawnInWave = max(0, o.getInt("toSpawn", 0));
      betweenWaves = o.getInt("betweenWaves", 0) != 0;
      interWaveDelay = o.getFloat("interWaveDelay", 0f);
      allWavesSpawned = o.getInt("allWavesSpawned", 0) != 0;
      spawnCooldown = o.getFloat("spawnCooldown", 1f);
    } else {
      betweenWaves = false;
      allWavesSpawned = false;
      interWaveDelay = 0f;
      beginWave(currentWave);
      spawnCooldown = 1.2f;
    }
    if (o.hasKey("sliderEnemyMult") && sliderEnemyMult != null) {
      sliderEnemyMult.setValue(o.getFloat("sliderEnemyMult", 0.5f));
    }
    if (o.hasKey("sliderTargetFps") && sliderTargetFps != null) {
      sliderTargetFps.setValue(o.getFloat("sliderTargetFps", 0.33f));
    }
    applySettingsMultipliers();
    startNewGame(true);
    JSONArray ta = o.getJSONArray("towers");
    if (ta != null) {
      Scene g = engine.getSceneManager().getActiveScene();
      for (int i = 0; i < ta.size(); i++) {
        JSONObject t = ta.getJSONObject(i);
        String ks = t.hasKey("kind") ? t.getString("kind") : "MG";
        TowerKind k = TowerKind.MG;
        try {
          k = TowerKind.valueOf(ks);
        } catch (IllegalArgumentException ex) {
          k = TowerKind.MG;
        }
        float px = t.getFloat("x");
        float py = t.getFloat("y");
        spawnTowerObject(g, k, px, py);
      }
    }
    lblLoadMsg.setText("已载入");
  } catch (Exception e) {
    println("[TD] load failed: " + e.getMessage());
    lblLoadMsg.setText("载入失败（见控制台）");
  }
}

void saveGame() {
  if (appMode != 2 && appMode != 3 && appMode != 4) return;
  try {
    JSONObject o = new JSONObject();
    o.setInt("version", 1);
    o.setInt("money", money);
    o.setInt("baseOrbs", baseOrbs);
    o.setInt("lostOrbs", lostOrbs);
    o.setInt("wave", currentWave);
    o.setInt("toSpawn", toSpawnInWave);
    o.setInt("betweenWaves", betweenWaves ? 1 : 0);
    o.setFloat("interWaveDelay", interWaveDelay);
    o.setInt("allWavesSpawned", allWavesSpawned ? 1 : 0);
    o.setFloat("spawnCooldown", spawnCooldown);
    o.setFloat("matchElapsed", matchElapsed);
    o.setFloat("sliderEnemyMult", sliderEnemyMult != null ? sliderEnemyMult.getValue() : 0.5f);
    o.setFloat("sliderTargetFps", sliderTargetFps != null ? sliderTargetFps.getValue() : 0.33f);
    o.setFloat("targetFps", settingsTargetFps());
    JSONArray ta = new JSONArray();
    Scene g = engine.getSceneManager().getActiveScene();
    if (g != null) {
      for (GameObject go : g.getGameObjects()) {
        TowerController tc = go.getComponent(TowerController.class);
        if (tc == null) continue;
        JSONObject t = new JSONObject();
        t.setString("kind", tc.kind.name());
        Vector2 p = go.getTransform().getPosition();
        t.setFloat("x", p.x);
        t.setFloat("y", p.y);
        ta.append(t);
      }
    }
    o.setJSONArray("towers", ta);
    saveJSONObject(o, sketchPath("save.json"));
    lblLoadMsg.setText("已保存 save.json");
  } catch (Exception e) {
    println("[TD] save failed: " + e.getMessage());
  }
}

void spawnTowerObject(Scene scene, TowerKind k, float px, float py) {
  GameObject go = GameObject.create("Tower_" + (nextTowerId++));
  go.getTransform().setPosition(px, py);
  TowerController tc = go.addComponent(TowerController.class);
  tc.kind = k;
  scene.addGameObject(go);
}

void syncTowerHint() {
  TowerDef d = TowerDef.forKind(buildSelected);
  lblTowerHint.setText(d.name + "\n花费 " + d.cost + "  |  射程 " + (int) d.range
    + "\n" + d.blurb + "\n在战场区点击放置。");
}

void draw() {
  float dt = engine.getGameTime().getDeltaTime();
  background(14, 18, 30);

  engine.update();

  if (appMode == 2) {
    updateGame(dt);
  }

  drawBattlefield();

  layoutUi();
  ui.update(dt);
  ui.render();
}

void layoutUi() {
  Panel root = ui.getRoot();
  if (width != root.getWidth() || height != root.getHeight()) {
    root.setSize(width, height);
  }
  panelMenu.setBounds(0, 0, width, height);
  lblMenuHint.setBounds((width - 520) / 2, height / 2 - 120, 520, 28);
  btnStart.setBounds((width - 220) / 2, height / 2 - 72, 220, 40);
  btnLoad.setBounds((width - 220) / 2, height / 2 - 24, 220, 40);
  btnSettings.setBounds((width - 220) / 2, height / 2 + 24, 220, 40);
  btnQuit.setBounds((width - 220) / 2, height / 2 + 72, 220, 40);
  lblLoadMsg.setBounds((width - 400) / 2, height / 2 + 124, 400, 24);

  panelSettings.setBounds(0, 0, width, height);

  panelTopHud.setBounds(0, 0, width - RIGHT_W, TOP_HUD);
  lblHudLine.setBounds(8, 6, width - RIGHT_W - 160, 28);
  btnSave.setBounds(width - RIGHT_W - 156, 6, 72, 28);
  btnToMenu.setBounds(width - RIGHT_W - 80, 6, 72, 28);

  panelRight.setBounds(width - RIGHT_W, TOP_HUD, RIGHT_W, height - TOP_HUD);
  int ry = 32;
  for (UIComponent c : panelRight.getChildren()) {
    if (c == lblTowerHint) {
      c.setBounds(8, ry, RIGHT_W - 12, 120);
      ry += 128;
    } else {
      c.setBounds(8, ry, RIGHT_W - 24, 36);
      ry += 42;
    }
  }

  if (panelEndOverlay != null) {
    panelEndOverlay.setBounds(0, 0, width, height);
    if (lblEndMsg != null) {
      lblEndMsg.setBounds((width - 400) / 2, height / 2 - 40, 400, 40);
    }
    btnEndMenu.setBounds((width - 200) / 2, height / 2 + 10, 200, 40);
  }

  int sxs = (width - 280) / 2;
  int sys = height / 2 - 140;
  if (settingsTitle != null) settingsTitle.setBounds(sxs, sys, 280, 28);
  sys += 40;
  if (settingsLblEnemy != null) settingsLblEnemy.setBounds(sxs, sys, 280, 22);
  sys += 26;
  if (sliderEnemyMult != null) sliderEnemyMult.setBounds(sxs, sys, 260, 28);
  sys += 38;
  if (settingsLblFps != null) settingsLblFps.setBounds(sxs, sys, 280, 22);
  sys += 26;
  if (sliderTargetFps != null) sliderTargetFps.setBounds(sxs, sys, 260, 28);
  sys += 40;
  if (lblSettingsNote != null) lblSettingsNote.setBounds(sxs, sys, 420, 44);
  sys += 52;
  if (btnSettingsBack != null) btnSettingsBack.setBounds((width - 160) / 2, sys, 160, 36);

  root.invalidateLayout();
  panelMenu.layout(this);
  panelSettings.layout(this);
  panelTopHud.layout(this);
  panelRight.layout(this);
  if (panelEndOverlay != null) {
    panelEndOverlay.layout(this);
  }
}

void drawBattlefield() {
  if (appMode == 0 || appMode == 1) return;

  pushStyle();
  pushMatrix();
  int px0 = 0;
  int py0 = TOP_HUD;
  int pw = width - RIGHT_W;
  int ph = height - TOP_HUD;
  clip(px0, py0, pw, ph);
  translate(0, TOP_HUD);
  fill(26, 32, 48);
  noStroke();
  rect(0, 0, pw, ph);

  stroke(60, 90, 130);
  strokeWeight(3);
  noFill();
  beginShape();
  for (Vector2 p : path.points) {
    vertex(p.x, p.y);
  }
  endShape();

  Vector2 baseP = path.points[baseVertexIndex];
  fill(40, 200, 120, 90);
  ellipse(baseP.x, baseP.y, 52, 52);
  fill(200, 230, 255);
  textAlign(CENTER, CENTER);
  text("基地 " + baseOrbs + " 球", baseP.x, baseP.y - 36);

  Vector2 exitP = path.points[path.points.length - 1];
  fill(255, 80, 80, 70);
  ellipse(exitP.x, exitP.y, 44, 44);
  fill(255, 200, 200);
  text("撤离", exitP.x, exitP.y - 34);

  for (TdRollingOrb r : rolling) {
    Vector2 p = path.sample(r.s);
    fill(255, 220, 60);
    ellipse(p.x, p.y, 16, 16);
  }

  for (TdEnemy e : enemies) {
    if (!e.alive) continue;
    Vector2 p = path.sample(e.s);
    fill(e.carriedOrb ? color(255, 120, 200) : color(200, 80, 80));
    ellipse(p.x, p.y, 22, 22);
    float t = e.hp / e.hpMax;
    noFill();
    stroke(40, 40, 60);
    rect(p.x - 14, p.y - 22, 28, 4);
    fill(80, 220, 120);
    noStroke();
    rect(p.x - 14, p.y - 22, 28 * t, 4);
  }

  Scene g = engine.getSceneManager().getActiveScene();
  if (g != null) {
    for (GameObject go : g.getGameObjects()) {
      TowerController tc = go.getComponent(TowerController.class);
      if (tc == null) continue;
      Vector2 p = go.getTransform().getPosition();
      TowerDef def = TowerDef.forKind(tc.kind);
      float rRing = def.kind == TowerKind.SLOW ? def.aoeRadius : def.range;
      stroke(120, 180, 255, 120);
      noFill();
      ellipse(p.x, p.y, rRing * 2, rRing * 2);
      noStroke();
      fill(def.iconColor);
      rectMode(CENTER);
      rect(p.x, p.y, 28, 28, 4);
      rectMode(CORNER);
    }
  }

  int mx = mouseX;
  int my = mouseY - TOP_HUD;
  if (appMode == 2 && mx < pw && mouseY >= TOP_HUD) {
    TowerDef d = TowerDef.forKind(buildSelected);
    if (money >= d.cost) {
      int gx = (int) snapGrid(mx);
      int gy = (int) snapGrid(my);
      float showR = d.kind == TowerKind.SLOW ? d.aoeRadius : d.range;
      stroke(255, 255, 0, 100);
      noFill();
      ellipse(gx, gy, showR * 2, showR * 2);
    }
  }

  noClip();
  popMatrix();
  popStyle();
}

float snapGrid(float v) {
  return round(v / GRID) * GRID;
}

boolean canPlaceTower(float px, float py) {
  if (px < GRID || py < GRID || px > width - RIGHT_W - GRID || py > height - TOP_HUD - GRID) return false;
  if (path.minDistanceToPolyline(new Vector2(px, py)) < 26f) return false;
  Scene g = engine.getSceneManager().getActiveScene();
  if (g != null) {
    for (GameObject go : g.getGameObjects()) {
      if (go.getComponent(TowerController.class) == null) continue;
      Vector2 tp = go.getTransform().getPosition();
      float dx = tp.x - px;
      float dy = tp.y - py;
      if (dx * dx + dy * dy < 36f * 36f) return false;
    }
  }
  return true;
}

void updateGame(float dt) {
  matchElapsed += dt;
  if (lostOrbs >= INITIAL_ORBS) {
    showEnd(false);
    return;
  }

  applyEnemySlows();
  updateSpawns(dt);
  updateEnemies(dt);
  updateRolling(dt);
  towerCombat(dt);

  int alive = 0;
  for (TdEnemy e : enemies) if (e.alive) alive++;

  lblHudLine.setText(String.format(Locale.US,
    "时间 %.0fs  |  波次 %d/%d  |  敌人 %d  |  基地球 %d  |  已失 %d  |  $%d",
    matchElapsed, currentWave, TOTAL_WAVES, alive, baseOrbs, lostOrbs, money));

  if (allWavesSpawned && alive == 0 && lostOrbs < INITIAL_ORBS) {
    showEnd(true);
  }
}

void showEnd(boolean win) {
  appMode = win ? 3 : 4;
  if (lblEndMsg != null) {
    lblEndMsg.setText(win ? "胜利 — 仍有能量球在控制下" : "失败 — 全部能量球已撤离");
  }
  if (panelEndOverlay != null) {
    panelEndOverlay.setVisible(true);
  }
}

void applyEnemySlows() {
  Scene g = engine.getSceneManager().getActiveScene();
  if (g == null) return;
  for (TdEnemy e : enemies) e.slowMul = 1f;
  for (GameObject go : g.getGameObjects()) {
    TowerController tc = go.getComponent(TowerController.class);
    if (tc == null || tc.kind != TowerKind.SLOW) continue;
    Vector2 p = go.getTransform().getPosition();
    float r = TowerDef.forKind(TowerKind.SLOW).aoeRadius;
    for (TdEnemy e : enemies) {
      if (!e.alive) continue;
      Vector2 ep = path.sample(e.s);
      if (ep.distanceSq(p) < r * r) {
        e.slowMul = min(e.slowMul, TowerDef.forKind(TowerKind.SLOW).slowFactor);
      }
    }
  }
}

void updateSpawns(float dt) {
  if (allWavesSpawned) return;
  if (betweenWaves) {
    interWaveDelay -= dt;
    if (interWaveDelay <= 0) {
      betweenWaves = false;
      beginWave(currentWave + 1);
      spawnCooldown = 0.5f;
    }
    return;
  }
  if (toSpawnInWave > 0) {
    spawnCooldown -= dt;
    if (spawnCooldown <= 0) {
      enemies.add(new TdEnemy(currentWave));
      toSpawnInWave--;
      spawnCooldown = 1.1f / enemyHpMult;
      if (toSpawnInWave == 0) {
        if (currentWave >= TOTAL_WAVES) {
          allWavesSpawned = true;
        } else {
          betweenWaves = true;
          interWaveDelay = 2.4f;
        }
      }
    }
  }
}

void updateEnemies(float dt) {
  float dBase = vertexDist[baseVertexIndex];
  float dEnd = pathTotal;
  Iterator<TdEnemy> it = enemies.iterator();
  while (it.hasNext()) {
    TdEnemy e = it.next();
    if (!e.alive) continue;
    float v = e.speed * e.slowMul;
    e.s += v * dt;
    if (e.phase == 0) {
      if (!e.stoleTriggered && e.s >= dBase) {
        e.stoleTriggered = true;
        if (baseOrbs > 0) {
          baseOrbs--;
          e.carriedOrb = true;
        }
        e.phase = 1;
      }
    } else if (e.phase == 1) {
      if (e.s >= dEnd - 0.5f) {
        if (e.carriedOrb) {
          lostOrbs++;
          e.carriedOrb = false;
        }
        e.alive = false;
      }
    }
    tryPickupRolling(e);
  }
}

void tryPickupRolling(TdEnemy e) {
  if (!e.alive || e.carriedOrb) return;
  if (e.phase != 1) return;
  Vector2 ep = path.sample(e.s);
  Iterator<TdRollingOrb> it = rolling.iterator();
  while (it.hasNext()) {
    TdRollingOrb r = it.next();
    Vector2 rp = path.sample(r.s);
    if (ep.distanceSq(rp) < PICKUP_R * PICKUP_R) {
      e.carriedOrb = true;
      it.remove();
      return;
    }
  }
}

void updateRolling(float dt) {
  float dBase = vertexDist[baseVertexIndex];
  Iterator<TdRollingOrb> it = rolling.iterator();
  while (it.hasNext()) {
    TdRollingOrb r = it.next();
    r.s -= ROLL_SPEED * dt;
    if (r.s <= dBase) {
      baseOrbs++;
      it.remove();
    }
  }
}

void towerCombat(float dt) {
  Scene g = engine.getSceneManager().getActiveScene();
  if (g == null) return;
  for (GameObject go : g.getGameObjects()) {
    TowerController tc = go.getComponent(TowerController.class);
    if (tc == null) continue;
    tc.tick(this, dt, go.getTransform().getPosition());
  }
}

void onEnemyKilled(TdEnemy e) {
  if (!e.alive) return;
  e.alive = false;
  if (e.carriedOrb) {
    e.carriedOrb = false;
    rolling.add(new TdRollingOrb(min(e.s, pathTotal - 0.1f)));
  }
}

void damageEnemyNearest(Vector2 from, float range, float dmg, float aoe, boolean aoeMode) {
  TdEnemy best = null;
  float bestD = 1e9f;
  for (TdEnemy e : enemies) {
    if (!e.alive) continue;
    float d = path.sample(e.s).distance(from);
    if (d < range && d < bestD) {
      bestD = d;
      best = e;
    }
  }
  if (best == null) return;
  if (!aoeMode) {
    applyDamage(best, dmg);
    return;
  }
  Vector2 hit = path.sample(best.s);
  for (TdEnemy e : enemies) {
    if (!e.alive) continue;
    if (path.sample(e.s).distance(hit) <= aoe) {
      applyDamage(e, dmg);
    }
  }
}

void applyDamage(TdEnemy e, float dmg) {
  e.hp -= dmg;
  if (e.hp <= 0) onEnemyKilled(e);
}

// —— input ——
void mousePressed() {
  if (appMode == 2) {
    int pw = width - RIGHT_W;
    if (mouseX >= 0 && mouseX < pw && mouseY >= TOP_HUD && mouseButton == LEFT) {
      TowerDef d = TowerDef.forKind(buildSelected);
      if (money < d.cost) return;
      float px = snapGrid(mouseX);
      float py = snapGrid(mouseY - TOP_HUD);
      if (!canPlaceTower(px, py)) return;
      money -= d.cost;
      spawnTowerObject(engine.getSceneManager().getActiveScene(), buildSelected, px, py);
    }
  }
}

// —— nested game types ——

public enum TowerKind {
  MG, MISSILE, LASER, SLOW
}

public static final class TowerDef {
  final TowerKind kind;
  final String name;
  final String blurb;
  final int cost;
  final float range;
  final float firePeriod;
  final float damage;
  final float aoeRadius;
  final float laserBonus;
  final float slowFactor;
  final int iconColor;

  TowerDef(TowerKind kind, String name, String blurb, int cost, float range,
    float firePeriod, float damage, float aoeRadius, float laserBonus, float slowFactor, int iconColor) {
    this.kind = kind;
    this.name = name;
    this.blurb = blurb;
    this.cost = cost;
    this.range = range;
    this.firePeriod = firePeriod;
    this.damage = damage;
    this.aoeRadius = aoeRadius;
    this.laserBonus = laserBonus;
    this.slowFactor = slowFactor;
    this.iconColor = iconColor;
  }

  static TowerDef forKind(TowerKind k) {
    switch (k) {
      case MG:
        return new TowerDef(k, "机枪", "高射速，单体最近。", 80, 190f, 0.11f, 7f, 0, 0, 1f, inst.color(120, 200, 255));
      case MISSILE:
        return new TowerDef(k, "导弹", "远程小范围溅射。", 150, 300f, 0.85f, 38f, 52f, 0, 1f, inst.color(255, 180, 80));
      case LASER:
        return new TowerDef(k, "激光", "长冷却，高单发。", 200, 400f, 2.1f, 115f, 0, 0, 1f, inst.color(255, 80, 220));
      default:
        return new TowerDef(k, "减速", "范围内时间减速。", 100, 0, 0, 0, 130f, 0, 0.38f, inst.color(160, 255, 200));
    }
  }
}

public static final class TdPath {
  final Vector2[] points;
  float totalLength;
  float[] segLen;

  TdPath(Vector2[] pts) {
    this.points = pts;
    int n = pts.length;
    segLen = new float[max(0, n - 1)];
    totalLength = 0;
    for (int i = 0; i < n - 1; i++) {
      float d = pts[i].distance(pts[i + 1]);
      segLen[i] = d;
      totalLength += d;
    }
  }

  float[] vertexDistances() {
    float[] vd = new float[points.length];
    vd[0] = 0;
    for (int i = 1; i < points.length; i++) {
      vd[i] = vd[i - 1] + segLen[i - 1];
    }
    return vd;
  }

  Vector2 sample(float distAlong) {
    distAlong = constrain(distAlong, 0, totalLength - 0.0001f);
    float acc = 0;
    for (int i = 0; i < segLen.length; i++) {
      if (acc + segLen[i] >= distAlong) {
        float t = (distAlong - acc) / segLen[i];
        return Vector2.lerp(points[i], points[i + 1], t);
      }
      acc += segLen[i];
    }
    return points[points.length - 1].copy();
  }

  float minDistanceToPolyline(Vector2 p) {
    float best = 1e9f;
    for (int i = 0; i < points.length - 1; i++) {
      float d = distPointSegment(p, points[i], points[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  static float distPointSegment(Vector2 p, Vector2 a, Vector2 b) {
    float abx = b.x - a.x;
    float aby = b.y - a.y;
    float apx = p.x - a.x;
    float apy = p.y - a.y;
    float ab2 = abx * abx + aby * aby;
    float t = ab2 < 1e-6f ? 0 : constrain((apx * abx + apy * aby) / ab2, 0, 1);
    float qx = a.x + abx * t;
    float qy = a.y + aby * t;
    float dx = p.x - qx;
    float dy = p.y - qy;
    return (float) Math.sqrt(dx * dx + dy * dy);
  }
}

public static final class TdEnemy {
  float s;
  float speed = 62f;
  float hp;
  float hpMax;
  boolean alive = true;
  int phase;
  boolean stoleTriggered;
  boolean carriedOrb;
  float slowMul = 1f;

  TdEnemy(int spawnWave) {
    s = 0;
    hpMax = 55f + spawnWave * 14f;
    hp = hpMax * inst.enemyHpMult;
  }
}

public static final class TdRollingOrb {
  float s;
  TdRollingOrb(float s0) {
    this.s = s0;
  }
}

public static class TowerController extends Component {
  TowerKind kind = TowerKind.MG;
  float cooldown;

  void tick(TowerDefenseMin g, float dt, Vector2 pos) {
    if (kind == TowerKind.SLOW) return;
    TowerDef d = TowerDef.forKind(kind);
    cooldown -= dt;
    if (cooldown > 0) return;
    if (kind == TowerKind.MISSILE) {
      g.damageEnemyNearest(pos, d.range, d.damage, d.aoeRadius, true);
      cooldown = d.firePeriod;
    } else if (kind == TowerKind.LASER) {
      g.damageEnemyNearest(pos, d.range, d.damage, 0, false);
      cooldown = d.firePeriod;
    } else {
      g.damageEnemyNearest(pos, d.range, d.damage, 0, false);
      cooldown = d.firePeriod;
    }
  }
}
