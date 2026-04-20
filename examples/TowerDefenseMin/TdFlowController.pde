/**
 * Menu / settings / save-load / in-game HUD flow and per-frame glue for {@link TowerDefenseMin}.
 * Keeps the main sketch tab to Processing entrypoints only.
 */
static final class TdFlowController {

  final TowerDefenseMin app;
  final SketchUiCoordinator sketchUi;

  TdFlowController(TowerDefenseMin app) {
    this.app = app;
    this.sketchUi = new SketchUiCoordinator(app, app.ui);
    this.sketchUi.setPreRenderHook(() -> TdUiFonts.ensureFont(app));
  }

  void finishSetup() {
    TdUiFonts.init(app, app.ui);
    TdMainUiBuilder.build(app, app.ui, this);
    app.ui.setTheme(new TdSciFiTheme());
  }

  void enterSettings(boolean on) {
    app.appMode = on ? 1 : 0;
    app.panelSettings.setVisible(on);
    app.panelMenu.setVisible(!on);
  }

  void enterLevelSelect(boolean on) {
    app.panelLevelSelect.setVisible(on);
    app.panelMenu.setVisible(!on);
    if (!on) {
      app.panelMenu.setVisible(true);
    }
  }

  void applySettingsMultipliers() {
    float t = app.sliderEnemyMult != null ? app.sliderEnemyMult.getValue() : 0.5f;
    app.world.setEnemyHpMultFromSlider(t);
  }

  float settingsTargetFps() {
    if (app.sliderTargetFps == null) return 60f;
    return 30f + app.sliderTargetFps.getValue() * 90f;
  }

  void startNewGame(boolean fromLoad) {
    startNewGameWithLevel(1, fromLoad);
  }

  void startNewGameWithLevel(int level) {
    startNewGameWithLevel(level, false);
  }

  void startNewGameWithLevel(int level, boolean fromLoad) {
    app.showTowerRangeOverlay = false;
    app.buildArmed = false;
    app.lblLoadMsg.setText("");
    if (app.panelEndOverlay != null) {
      app.panelEndOverlay.setVisible(false);
    }
    
    // 记录当前关卡
    app.lastPlayedLevel = level;
    
    // 初始化关卡路径配置
    TdLevelPath.initPaths(app);
    
    app.engine.getSceneManager().loadScene("Game");
    Scene g = app.engine.getSceneManager().getActiveScene();
    g.clear();
    app.world.clearEntities();
    
    // 设置关卡并初始化路径
    app.world.setLevel(level);
    
    if (!fromLoad) {
      applySettingsMultipliers();
      app.world.resetEconomyForNewMatch();
    }
    app.world.resetTowerNaming();
    app.world.configurePath();
    app.appMode = 2;
    app.panelMenu.setVisible(false);
    app.panelLevelSelect.setVisible(false);
    app.panelSettings.setVisible(false);
    app.panelTopHud.setVisible(true);
    app.panelRight.setVisible(true);
    updateTowerHint();
  }

  /** 进入下一关 */
  void goNextLevel() {
    int nextLevel = app.lastPlayedLevel + 1;
    if (nextLevel <= TdLevelConfig.TOTAL_LEVELS) {
      startNewGameWithLevel(nextLevel);
    } else {
      // 已经通关所有关卡，返回主菜单
      goMenuFromGame();
    }
  }

  /** 重玩当前关卡 */
  void replayCurrentLevel() {
    startNewGameWithLevel(app.lastPlayedLevel);
  }

  void goMenuFromGame() {
    app.buildArmed = false;
    app.engine.getSceneManager().loadScene("Menu");
    app.appMode = 0;
    app.panelTopHud.setVisible(false);
    app.panelRight.setVisible(false);
    app.panelMenu.setVisible(true);
    app.panelLevelSelect.setVisible(false);
    app.panelSettings.setVisible(false);
    if (app.panelEndOverlay != null) {
      app.panelEndOverlay.setVisible(false);
    }
  }

  void tryLoadGame() {
    File f = new File(app.sketchPath("save.json"));
    if (!f.exists()) {
      app.lblLoadMsg.setText("未找到 save.json");
      return;
    }
    try {
      JSONObject o = app.loadJSONObject(f);
      if (o == null) {
        app.lblLoadMsg.setText("save.json 解析失败");
        return;
      }
      app.world.applyEconomyAndWavesFromJson(o);
      if (o.hasKey("sliderEnemyMult") && app.sliderEnemyMult != null) {
        app.sliderEnemyMult.setValue(o.getFloat("sliderEnemyMult", 0.5f));
      }
      if (o.hasKey("sliderTargetFps") && app.sliderTargetFps != null) {
        app.sliderTargetFps.setValue(o.getFloat("sliderTargetFps", 0.33f));
      }
      applySettingsMultipliers();
      startNewGame(true);
      app.world.loadTowersFromJson(o.getJSONArray("towers"));
      app.lblLoadMsg.setText("已载入");
    } catch (Exception e) {
      println("[TD] load failed: " + e.getMessage());
      app.lblLoadMsg.setText("载入失败（见控制台）");
    }
  }

  void saveGame() {
    if (app.appMode != 2 && app.appMode != 3 && app.appMode != 4) return;
    try {
      JSONObject o = new JSONObject();
      o.setInt("version", 1);
      app.world.fillSaveJson(o);
      o.setFloat("sliderEnemyMult", app.sliderEnemyMult != null ? app.sliderEnemyMult.getValue() : 0.5f);
      o.setFloat("sliderTargetFps", app.sliderTargetFps != null ? app.sliderTargetFps.getValue() : 0.33f);
      o.setFloat("targetFps", settingsTargetFps());
      JSONArray ta = new JSONArray();
      Scene g = app.engine.getSceneManager().getActiveScene();
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
      app.saveJSONObject(o, app.sketchPath("save.json"));
      app.lblLoadMsg.setText("已保存 save.json");
    } catch (Exception e) {
      println("[TD] save failed: " + e.getMessage());
    }
  }

  TowerKind hoveredTowerBuildButtonKindOrNull() {
    if (app.panelRight != null && app.panelRight.isVisible() && (app.appMode == 2 || app.appMode == 3 || app.appMode == 4)) {
      UIComponent hit = app.ui.getRoot().hitTest(app.mouseX, app.mouseY);
      while (hit != null) {
        if (hit == app.btnTowerMg) return TowerKind.MG;
        if (hit == app.btnTowerMissile) return TowerKind.MISSILE;
        if (hit == app.btnTowerLaser) return TowerKind.LASER;
        if (hit == app.btnTowerSlow) return TowerKind.SLOW;
        hit = hit.getParent();
      }
    }
    return null;
  }

  void updateTowerHint() {
    TowerKind h = hoveredTowerBuildButtonKindOrNull();
    if (h == null) {
      app.lblTowerHint.setText("");
      return;
    }
    TowerDef d = TowerDef.forKind(h);
    int rng = (int) (h == TowerKind.SLOW ? d.aoeRadius : d.range);
    app.lblTowerHint.setText(d.name + "\n花费 " + d.cost + "  |  " + (h == TowerKind.SLOW ? "光环 " : "射程 ") + rng
      + "\n" + d.blurb + "\n在战场区点击放置。");
  }

  void onTowerBuildPick(TowerKind k) {
    app.buildSelected = k;
    app.buildArmed = true;
    updateTowerHint();
  }

  void onKeyPressed() {
    if (app.key == 'q' || app.key == 'Q') {
      if (app.appMode == 2 || app.appMode == 3 || app.appMode == 4) {
        app.showTowerRangeOverlay = !app.showTowerRangeOverlay;
      }
    }
  }

  void drawFrame() {
    float dt = app.engine.getGameTime().getDeltaTime();
    app.background(14, 18, 30);
    drawHudBackdrop();

    app.engine.update();

    if (app.appMode == 2) {
      int end = app.world.tick(dt, app.lblHudLine);
      if (app.lblHudLine != null) {
        app.lblHudLine.setText(app.lblHudLine.getText()
          + (app.showTowerRangeOverlay ? "  |  塔范围 [Q] 开" : "  |  塔范围 [Q] 关"));
      }
      if (end == 1) showEnd(false);
      else if (end == 2) showEnd(true);
    }

    boolean ghostPreview = app.appMode == 2 && app.buildArmed
      && app.mouseX < app.width - TdConfig.RIGHT_W
      && app.mouseY >= TdConfig.TOP_HUD;
    app.world.drawBattlefield(app.buildSelected, app.appMode, app.showTowerRangeOverlay || ghostPreview, app.buildArmed);

    TdUiLayout.layout(app);
    sketchUi.updateFrame(dt);
    if (app.appMode == 2 || app.appMode == 3 || app.appMode == 4) {
      updateTowerHint();
    }
    sketchUi.renderFrame();
  }

  void drawHudBackdrop() {
    app.pushStyle();
    app.stroke(40, 90, 120, 22);
    app.strokeWeight(1);
    int step = 48;
    for (int x = 0; x < app.width; x += step) {
      app.line(x, 0, x, app.height);
    }
    for (int y = 0; y < app.height; y += step) {
      app.line(0, y, app.width, y);
    }
    app.popStyle();
  }

  void showEnd(boolean win) {
    app.buildArmed = false;
    app.appMode = win ? 3 : 4;
    if (app.lblEndMsg != null) {
      app.lblEndMsg.setText(win ? "胜利 — 仍有能量球在控制下" : "失败 — 全部能量球已撤离");
    }
    if (app.panelEndOverlay != null) {
      app.panelEndOverlay.setVisible(true);
    }
  }

  void onMousePressed() {
    if (app.appMode == 2) {
      if (app.mouseButton == RIGHT) {
        app.buildArmed = false;
        return;
      }
      if (!app.buildArmed || app.mouseButton != LEFT) return;
      int pw = app.width - TdConfig.RIGHT_W;
      if (app.mouseX >= 0 && app.mouseX < pw && app.mouseY >= TdConfig.TOP_HUD) {
        float px = TdGameWorld.snapGrid(app.mouseX);
        float py = TdGameWorld.snapGrid(app.mouseY - TdConfig.TOP_HUD);
        app.world.tryBuyAndPlaceTower(app.buildSelected, px, py);
      }
    }
  }
}
