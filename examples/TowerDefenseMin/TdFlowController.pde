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
    loadSettings();
    playBgmMenu();
    animateMenuFadeIn();
  }

  void enterSettings(boolean on) {
    app.appMode = on ? 1 : 0;
    app.panelSettings.setVisible(on);
    app.panelMenu.setVisible(!on);
    if (!on) {
      saveSettings();
    }
  }

  void enterLevelSelect(boolean on) {
    println("[TweenDebug] enterLevelSelect(" + on + ")");
    app.panelLevelSelect.setVisible(on);
    app.panelMenu.setVisible(!on);
    if (on) {
      app.panelLevelSelect.setAlpha(0f);
      TweenManager tm = P5Engine.getInstance().getTweenManager();
      tm.toAlpha(app.panelLevelSelect, 1f, 0.8f)
        .ease(shenyf.p5engine.tween.Ease::outQuad)
        .start();
      // 子元素依次淡入
      java.util.List<UIComponent> children = app.panelLevelSelect.getChildren();
      for (int i = 0; i < children.size(); i++) {
        UIComponent c = children.get(i);
        c.setAlpha(0f);
        tm.toAlpha(c, 1f, 0.5f)
          .ease(shenyf.p5engine.tween.Ease::outQuad)
          .delay(0.2f + i * 0.12f)
          .start();
      }
    }
    if (!on) {
      app.panelMenu.setVisible(true);
      animateMenuFadeIn();
    }
  }

  void applyAudioSettings() {
    if (app.sliderMasterVol != null) {
      float v = app.sliderMasterVol.getValue();
      app.lblMasterVal.setText(Math.round(v * 100) + "%");
      app.engine.getAudio().setMasterVolume(v);
    }
    if (app.sliderBgmVol != null) {
      float v = app.sliderBgmVol.getValue();
      app.lblBgmVal.setText(Math.round(v * 100) + "%");
      app.engine.getAudio().setGroupVolume("bgm", v);
    }
    if (app.sliderSfxVol != null) {
      float v = app.sliderSfxVol.getValue();
      app.lblSfxVal.setText(Math.round(v * 100) + "%");
      app.engine.getAudio().setGroupVolume("sfx", v);
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
    playBgmGame();
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
    playBgmMenu();
    animateMenuFadeIn();
  }

  String i18n(String key) { return app.engine.getI18n().get(key); }

  void tryLoadGame() {
    File f = new File(app.sketchPath("save.json"));
    if (!f.exists()) {
      app.lblLoadMsg.setText(i18n("msg.noSave"));
      return;
    }
    try {
      JSONObject o = app.loadJSONObject(f);
      if (o == null) {
        app.lblLoadMsg.setText(i18n("msg.parseFail"));
        return;
      }
      app.world.applyEconomyAndWavesFromJson(o);
      startNewGame(true);
      app.world.loadTowersFromJson(o.getJSONArray("towers"));
      app.lblLoadMsg.setText(i18n("msg.loaded"));
    } catch (Exception e) {
      println("[TD] load failed: " + e.getMessage());
      app.lblLoadMsg.setText(i18n("msg.loadError"));
    }
  }

  // ===== Settings persistence (separate from game progress) =====

  void saveSettings() {
    try {
      JSONObject o = new JSONObject();
      o.setFloat("sliderEnemyMult", app.sliderEnemyMult != null ? app.sliderEnemyMult.getValue() : 0.5f);
      o.setFloat("sliderTargetFps", app.sliderTargetFps != null ? app.sliderTargetFps.getValue() : 0.33f);
      o.setFloat("sliderMasterVol", app.sliderMasterVol != null ? app.sliderMasterVol.getValue() : 1.0f);
      o.setFloat("sliderBgmVol", app.sliderBgmVol != null ? app.sliderBgmVol.getValue() : 0.8f);
      o.setFloat("sliderSfxVol", app.sliderSfxVol != null ? app.sliderSfxVol.getValue() : 1.0f);
      o.setString("locale", app.engine.getI18n().getLocale());
      app.saveJSONObject(o, app.sketchPath("settings.json"));
    } catch (Exception e) {
      println("[TD] save settings failed: " + e.getMessage());
    }
  }

  void loadSettings() {
    File f = new File(app.sketchPath("settings.json"));
    if (!f.exists()) return;
    try {
      JSONObject o = app.loadJSONObject(f);
      if (o == null) return;
      if (o.hasKey("sliderEnemyMult") && app.sliderEnemyMult != null) {
        app.sliderEnemyMult.setValue(o.getFloat("sliderEnemyMult", 0.5f));
      }
      if (o.hasKey("sliderTargetFps") && app.sliderTargetFps != null) {
        app.sliderTargetFps.setValue(o.getFloat("sliderTargetFps", 0.33f));
      }
      if (o.hasKey("sliderMasterVol") && app.sliderMasterVol != null) {
        app.sliderMasterVol.setValue(o.getFloat("sliderMasterVol", 1.0f));
      }
      if (o.hasKey("sliderBgmVol") && app.sliderBgmVol != null) {
        app.sliderBgmVol.setValue(o.getFloat("sliderBgmVol", 0.8f));
      }
      if (o.hasKey("sliderSfxVol") && app.sliderSfxVol != null) {
        app.sliderSfxVol.setValue(o.getFloat("sliderSfxVol", 1.0f));
      }
      if (o.hasKey("locale")) {
        app.engine.getI18n().setLocale(o.getString("locale", "zh"));
      }
      applyAudioSettings();
      applySettingsMultipliers();
    } catch (Exception e) {
      println("[TD] load settings failed: " + e.getMessage());
    }
  }

  // ===== Game progress save/load (to be expanded later) =====

  void saveGame() {
    if (app.appMode != 2 && app.appMode != 3 && app.appMode != 4) return;
    try {
      JSONObject o = new JSONObject();
      o.setInt("version", 1);
      app.world.fillSaveJson(o);
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
      app.lblLoadMsg.setText(i18n("msg.saved"));
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
    String rngLabel = h == TowerKind.SLOW ? i18n("tower.aoe") : i18n("tower.range");
    app.lblTowerHint.setText(i18n(d.name) + "\n" + i18n("tower.cost") + " " + d.cost + "  |  " + rngLabel + " " + rng
      + "\n" + i18n(d.blurb) + "\n" + i18n("tower.placeHint"));
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

  int bgmRestartAt = -1;

  void drawFrame() {
    float dt = app.engine.getGameTime().getDeltaTime();
    app.background(14, 18, 30);
    drawHudBackdrop();

    app.engine.update();

    if (app.appMode == 2) {
      int end = app.world.tick(dt, app.lblHudLine);
      if (app.lblHudLine != null) {
        app.lblHudLine.setText(app.lblHudLine.getText()
          + (app.showTowerRangeOverlay ? "  |  " + i18n("hud.rangeOn") : "  |  " + i18n("hud.rangeOff")));
      }
      if (end == 1) showEnd(false);
      else if (end == 2) showEnd(true);
    }

    boolean ghostPreview = app.appMode == 2 && app.buildArmed
      && app.mouseX < app.width - TdConfig.RIGHT_W
      && app.mouseY >= TdConfig.TOP_HUD;
    app.world.drawBattlefield(app.buildSelected, app.appMode, app.showTowerRangeOverlay || ghostPreview, app.buildArmed);

    // 延迟重启 BGM（设置面板调完音量后）
    if (bgmRestartAt > 0 && app.millis() >= bgmRestartAt) {
      bgmRestartAt = -1;
      playBgmMenu();
    }

    TdUiLayout.layout(app);
    sketchUi.updateFrame(dt);
    if (app.appMode == 2 || app.appMode == 3 || app.appMode == 4) {
      updateTowerHint();
    }
    sketchUi.renderFrame();
    app.engine.renderDebugOverlay();
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

  private void animateMenuFadeIn() {
    println("[TweenDebug] animateMenuFadeIn called");
    if (app.panelMenu == null) return;
    TweenManager tm = P5Engine.getInstance().getTweenManager();

    // 先把所有元素设为透明
    app.panelMenu.setAlpha(0f);
    if (app.lblMenuHint != null) app.lblMenuHint.setAlpha(0f);
    UIComponent[] menuButtons = {app.btnStart, app.btnLoad, app.btnSettings, app.btnQuit};
    for (UIComponent btn : menuButtons) {
      if (btn != null) btn.setAlpha(0f);
    }
    if (app.lblLoadMsg != null) app.lblLoadMsg.setAlpha(0f);

    // 面板背景立即开始淡入（快速铺底）
    tm.toAlpha(app.panelMenu, 1f, 0.6f)
      .ease(shenyf.p5engine.tween.Ease::outQuad)
      .start();

    // 标题立即开始缓慢显现（1.2s）
    if (app.lblMenuHint != null) {
      tm.toAlpha(app.lblMenuHint, 1f, 1.2f)
        .ease(shenyf.p5engine.tween.Ease::outQuad)
        .start();
    }

    // 等标题显现完毕后，按钮依次淡入（整体 1.5s）
    float titleDur = 1.2f;
    float btnDur = 1.5f;
    float btnStagger = 0.15f;
    for (int i = 0; i < menuButtons.length; i++) {
      if (menuButtons[i] != null) {
        tm.toAlpha(menuButtons[i], 1f, btnDur)
          .ease(shenyf.p5engine.tween.Ease::outQuad)
          .delay(titleDur + i * btnStagger)
          .start();
      }
    }

    // 载入提示在按钮之后淡入
    if (app.lblLoadMsg != null) {
      tm.toAlpha(app.lblLoadMsg, 1f, 0.5f)
        .ease(shenyf.p5engine.tween.Ease::outQuad)
        .delay(titleDur + btnDur + 0.2f)
        .start();
    }
  }

  void showEnd(boolean win) {
    println("[TweenDebug] showEnd(" + win + ")");
    app.buildArmed = false;
    app.appMode = win ? 3 : 4;
    playSfx(win ? "data/sounds/resonant-flute.wav" : "data/sounds/vocal-boo.wav");
    if (app.lblEndMsg != null) {
      app.lblEndMsg.setText(win ? i18n("game.victory") : i18n("game.defeat"));
    }
    if (app.panelEndOverlay != null) {
      app.panelEndOverlay.setAlpha(0f);
      app.panelEndOverlay.setVisible(true);
      TweenManager tm = P5Engine.getInstance().getTweenManager();
      tm.toAlpha(app.panelEndOverlay, 1f, 0.8f)
        .ease(shenyf.p5engine.tween.Ease::outSine)
        .start();

      // 文字先淡入
      if (app.lblEndMsg != null) {
        app.lblEndMsg.setAlpha(0f);
        tm.toAlpha(app.lblEndMsg, 1f, 0.6f)
          .ease(shenyf.p5engine.tween.Ease::outQuad)
          .delay(0.2f)
          .start();
      }

      // 可见按钮延迟淡入
      UIComponent[] endButtons = {app.btnNextLevel, app.btnReplayLevel, app.btnEndMenu};
      for (int i = 0; i < endButtons.length; i++) {
        if (endButtons[i] != null && endButtons[i].isVisible()) {
          endButtons[i].setAlpha(0f);
          tm.toAlpha(endButtons[i], 1f, 0.5f)
            .ease(shenyf.p5engine.tween.Ease::outQuad)
            .delay(0.5f + i * 0.15f)
            .start();
        }
      }
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

  // ===== Audio helpers =====

  void playSfx(String path) {
    try {
      app.engine.getAudio().playOneShot(path, "sfx");
    } catch (Exception e) {
      // ignore audio errors during development
    }
  }

  void restartBgmMenuDelayed() {
    // 只移除当前 BGM GameObject，不要 shutdown 整个 TinySound
    //（stopAll 会关闭音频系统，导致 sfxCache 里的 Sound 对象全部失效）
    app.sceneMenu.removeGameObjects("bgm_menu");
    bgmRestartAt = app.millis() + 800;
  }

  void playBgmMenu() {
    try {
      // 清理旧的 BGM GameObject，避免重复
      // （removeGameObjects 会触发 BackgroundMusic.onDestroy 停止旧 BGM，不需要 stopAll）
      app.sceneMenu.removeGameObjects("bgm_menu");
      GameObject bgmGo = GameObject.create("bgm_menu");
      BackgroundMusic bgm = bgmGo.addComponent(BackgroundMusic.class);
      bgm.clipPath = "data/music/TopGun.ogg";
      bgm.loop = true;
      bgm.volume = 0.4f;
      app.sceneMenu.addGameObject(bgmGo);
    } catch (Exception e) {
      // ignore
    }
  }

  void playBgmGame() {
    try {
      // 停止菜单 BGM，不要 shutdown 整个音频系统（避免 sfxCache 失效）
      app.sceneMenu.removeGameObjects("bgm_menu");
      // 游戏 BGM 暂不播放
    } catch (Exception e) {
      // ignore
    }
  }
}
