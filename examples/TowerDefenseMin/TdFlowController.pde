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
    TdLevelPath.initPaths(app, WORLD_W, WORLD_H);
    
    app.engine.getSceneManager().loadScene("Game");
    Scene g = app.engine.getSceneManager().getActiveScene();
    
    // Recreate camera, minimap and placement ghost for the Game scene
    GameObject camGo = GameObject.create("camera");
    app.camera = camGo.addComponent(Camera2D.class);
    app.camera.setViewportSize(1280 - TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
    app.camera.setViewportOffset(0, TdConfig.TOP_HUD);
    app.camera.setWorldBounds(new Rect(0, 0, WORLD_W, WORLD_H));
    app.camera.setFollowSpeed(0);
    app.camera.jumpCenterTo(WORLD_W * 0.5f, WORLD_H * 0.5f);
    g.addGameObject(camGo);
    g.setCamera(app.camera);
    
    GameObject minimapGo = GameObject.create("minimap");
    minimapGo.setRenderLayer(110);
    minimapGo.setZIndex(500);
    app.minimap = minimapGo.addComponent(Minimap.class);
    app.minimap.setWorldBounds(new Rect(0, 0, WORLD_W, WORLD_H));
    float mmW = TdConfig.RIGHT_W - 16;
    float mmH = 180;
    float mmX = 1280 - TdConfig.RIGHT_W + 8;
    float mmY = 720 - mmH - 8;
    app.minimap.setRect(mmX, mmY, mmW, mmH);
    app.minimap.setColors(app.color(21, 26, 37), app.color(58, 80, 107), app.color(74, 222, 128), app.color(56, 189, 248));
    app.minimap.clearTrackedNames();
    app.minimap.addTrackedName("Tower_", app.color(56, 189, 248), 5);
    app.minimap.addTrackedName("Enemy_", app.color(248, 113, 104), 4);
    app.minimap.addTrackedName("Orb_", app.color(250, 204, 21), 4);
    app.minimap.setScene(g);
    app.minimap.setCamera(app.camera);

    // ── WorldViewport: main world view ──
    if (app.worldViewport != null) {
      app.ui.getRoot().remove(app.worldViewport);
    }
    app.worldViewport = new SceneViewport("world_viewport");
    app.worldViewport.setBounds(0, TdConfig.TOP_HUD, 1280 - TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
    app.worldViewport.setScene(g);
    app.worldViewport.setCamera(app.camera);
    app.worldViewport.setZOrder(-1);
    app.worldViewport.setVisible(true);
    app.ui.getRoot().add(app.worldViewport);

    // ── MinimapViewport: minimap inside right panel ──
    if (app.minimapViewport != null) {
      app.panelRight.remove(app.minimapViewport);
    }
    app.minimapViewport = new MinimapViewport("minimap_view", app.minimap);
    app.minimapViewport.setScene(g);
    app.minimapViewport.setCamera(app.camera);
    app.minimapViewport.setVisible(true);
    app.panelRight.add(app.minimapViewport);
    // 保留 minimap 的原始 rect（用于可能的回退），MinimapViewport 会临时覆盖它

    GameObject ghostGo = GameObject.create("placement_ghost");
    ghostGo.setRenderLayer(30);
    ghostGo.setCullEnabled(false);
    ghostGo.addComponent(new PlacementGhostController(app));
    g.addGameObject(ghostGo);
    // Remove old towers and world_bg only; keep camera/minimap/placement ghost
    for (GameObject go : new ArrayList<>(g.getGameObjects())) {
      if (go.getComponent(TowerController.class) != null
          || "world_bg".equals(go.getName())) {
        g.markForDestroy(go);
      }
    }
    app.world.clearEntities();
    
    // 设置关卡并初始化路径
    app.world.setLevel(level);
    
    if (!fromLoad) {
      applySettingsMultipliers();
      app.world.resetEconomyForNewMatch();
    }
    app.world.resetTowerNaming();
    app.world.configurePath();
    if (app.minimap != null && app.world.path != null) {
      app.minimap.setPathPoints(app.world.path.points);
      app.minimap.setBasePosition(app.world.path.points[app.world.baseVertexIndex]);
      app.minimap.setExitPosition(app.world.path.points[app.world.path.points.length - 1]);
    }
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
    if (nextLevel <= TdLevelConfig.getTotalLevels()) {
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
    if (app.worldViewport != null) {
      app.worldViewport.setVisible(false);
    }
    if (app.minimapViewport != null) {
      app.minimapViewport.setVisible(false);
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
      Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
      UIComponent hit = app.ui.getRoot().hitTest((int)dm.x, (int)dm.y);
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
    app.lblTowerHint.setText(i18n(d.nameKey) + "\n" + i18n("tower.cost") + " " + d.cost + "  |  " + rngLabel + " " + rng
      + "\n" + i18n(d.blurbKey) + "\n" + i18n("tower.placeHint"));
  }

  void onTowerBuildPick(TowerKind k) {
    app.buildSelected = k;
    app.buildArmed = true;
    updateTowerHint();
  }

  void updateCameraScroll(float dt) {
    if (app.camera == null) return;
    if (app.appMode != 2 && app.appMode != 3 && app.appMode != 4) return;
    if (!app.focused) return;

    float speed = 520 * dt; // design pixels per second

    float dx = 0;
    float dy = 0;

    // Keyboard scroll
    if (app.keyScrollLeft) dx -= speed;
    if (app.keyScrollRight) dx += speed;
    if (app.keyScrollUp) dy -= speed;
    if (app.keyScrollDown) dy += speed;

    // Edge scroll (actual pixels margin)
    int margin = 20;
    if (app.mouseX < margin) dx -= speed;
    if (app.mouseX > app.width - margin) dx += speed;
    if (app.mouseY < margin) dy -= speed;
    if (app.mouseY > app.height - margin) dy += speed;

    if (dx != 0 || dy != 0) {
      app.camera.getTransform().translate(dx / app.camera.getZoom(), dy / app.camera.getZoom());
      app.camera.clampToBounds();
    }
  }

  void drawMinimapOverUi() {
    if (app.minimap == null) return;
    shenyf.p5engine.rendering.IRenderer r = app.engine.getRenderer();
    r.pushTransform();
    app.engine.getDisplayManager().begin(r);
    app.minimap.render(r);
    app.engine.getDisplayManager().end(r);
    r.popTransform();
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
    // drawHudBackdrop() 不再需要，网格线已移到 SceneViewport 内部

    updateCameraScroll(dt);
    app.engine.update();
    if (app.camera != null) {
      app.camera.clampToBounds();
      // 强制限制：确保相机不会看到世界外面
      Vector2 p = app.camera.getTransform().getPosition();
      float vw = app.camera.getViewportWidth();
      float vh = app.camera.getViewportHeight();
      float z = app.camera.getZoom();
      float halfVisW = (vw / z) * 0.5f;
      float halfVisH = (vh / z) * 0.5f;
      p.x = Math.max(halfVisW, Math.min(WORLD_W - halfVisW, p.x));
      p.y = Math.max(halfVisH, Math.min(WORLD_H - halfVisH, p.y));
      app.camera.getTransform().setPosition(p);
      // shenyf.p5engine.util.Logger.debug("TdFlow", String.format("drawFrame camPos=(%.1f,%.1f) zoom=%.2f vp=%.0fx%.0f offset=(%.0f,%.0f)",
      //   p.x, p.y, z, vw, vh, app.camera.getViewportOffsetX(), app.camera.getViewportOffsetY()));
    }

    if (app.appMode == 2) {
      int end = app.world.tick(dt, app.lblHudLine);
      if (app.lblHudLine != null) {
        String extra = (app.showTowerRangeOverlay ? "  |  " + i18n("hud.rangeOn") : "  |  " + i18n("hud.rangeOff"));
        // Append time-scale info
        P5GameTime gt = app.engine.getGameTime();
        String timeInfo = String.format(" | Time: %.1fx", gt.getTimeScale());
        if (gt.isPaused()) timeInfo += " [PAUSED]";
        app.lblHudLine.setText(app.lblHudLine.getText() + extra + timeInfo);
      }
      if (end == 1) showEnd(false);
      else if (end == 2) showEnd(true);
    }

    // 每 60 帧输出一次 camera 状态日志（避免日志过多）
    if (app.camera != null && app.frameCount % 60 == 0) {
      Vector2 cp = app.camera.getTransform().getPosition();
      Rect cvp = app.camera.getViewport();
      shenyf.p5engine.util.Logger.debug("TdFlow", String.format("frame=%d camPos=(%.1f,%.1f) zoom=%.3f viewport=(%.1f,%.1f %.1fx%.1f)",
        app.frameCount, cp.x, cp.y, app.camera.getZoom(), cvp.x, cvp.y, cvp.width, cvp.height));
    }

    // World 渲染现在由 WorldViewport 在 UI render 阶段完成
    // 不再需要 app.engine.render() 和手动覆盖矩形

    // 延迟重启 BGM（设置面板调完音量后）
    if (bgmRestartAt > 0 && app.millis() >= bgmRestartAt) {
      bgmRestartAt = -1;
      playBgmMenu();
    }

    TdUiLayout.layout(app);
    // UI updates use real time so menus stay responsive during pause
    sketchUi.updateFrame(app.engine.getGameTime().getRealDeltaTime());
    if (app.appMode == 2 || app.appMode == 3 || app.appMode == 4) {
      updateTowerHint();
    }
    sketchUi.renderFrame();

    // Debug: verify ghost placement coordinate chain
    if (app.buildArmed && app.camera != null) {
      Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
      Vector2 worldMouse = app.camera.screenToWorld(designMouse);
      Vector2 backDesign = app.camera.worldToScreen(worldMouse);
      Vector2 backActual = app.engine.getDisplayManager().designToActual(backDesign);
      app.stroke(255, 0, 255);
      app.strokeWeight(3);
      app.noFill();
      app.ellipse(backActual.x, backActual.y, 20, 20);
      app.line(backActual.x - 12, backActual.y, backActual.x + 12, backActual.y);
      app.line(backActual.x, backActual.y - 12, backActual.x, backActual.y + 12);
      app.noStroke();
      app.fill(255, 0, 255);
      app.textAlign(PApplet.CENTER, PApplet.CENTER);
      app.text("V", backActual.x, backActual.y);
      app.textAlign(PApplet.LEFT, PApplet.BASELINE);
    }

    app.engine.renderDebugOverlay();

    // Debug: draw zoom anchor focus point on screen
    if (app.debugZoomFocusWorld != null && app.camera != null) {
      Vector2 screenDesign = app.camera.worldToScreen(app.debugZoomFocusWorld);
      Vector2 screenActual = app.engine.getDisplayManager().designToActual(screenDesign);
      app.stroke(255, 0, 0);
      app.strokeWeight(3);
      app.noFill();
      app.ellipse(screenActual.x, screenActual.y, 24, 24);
      app.line(screenActual.x - 16, screenActual.y, screenActual.x + 16, screenActual.y);
      app.line(screenActual.x, screenActual.y - 16, screenActual.x, screenActual.y + 16);
      app.noStroke();
      app.fill(255, 0, 0);
      app.textAlign(PApplet.CENTER, PApplet.CENTER);
      app.text("Z", screenActual.x, screenActual.y);
      app.textAlign(PApplet.LEFT, PApplet.BASELINE);
      app.debugZoomFocusTimer--;
      if (app.debugZoomFocusTimer <= 0) app.debugZoomFocusWorld = null;
    }
  }

  void drawHudBackdrop() {
    app.stroke(40, 90, 120, 22);
    app.strokeWeight(1);
    int step = 48;
    // 只画在地图区域内（扣除顶部 HUD 和右侧面板）
    shenyf.p5engine.rendering.DisplayManager dm = app.engine.getDisplayManager();
    Vector2 tl = dm.designToActual(new Vector2(0, TdConfig.TOP_HUD));
    Vector2 br = dm.designToActual(new Vector2(1280 - TdConfig.RIGHT_W, 720));
    for (float x = tl.x; x < br.x; x += step) {
      app.line(x, tl.y, x, br.y);
    }
    for (float y = tl.y; y < br.y; y += step) {
      app.line(tl.x, y, br.x, y);
    }
    app.noStroke();
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
    // 小地图点击跳转（优先处理，不限制 appMode）
    if (app.minimap != null && app.camera != null) {
      Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
      if (app.minimap.contains(designMouse.x, designMouse.y)) {
        Vector2 worldPos = app.minimap.minimapToWorld(designMouse.x, designMouse.y);
        app.camera.jumpCenterTo(worldPos.x, worldPos.y);
        shenyf.p5engine.util.Logger.debug("TdFlow", String.format("minimap click design=(%.1f,%.1f) -> world=(%.1f,%.1f)",
          designMouse.x, designMouse.y, worldPos.x, worldPos.y));
        return;
      }
    }

    if (app.appMode == 2) {
      if (app.mouseButton == RIGHT) {
        app.buildArmed = false;
        return;
      }
      if (!app.buildArmed || app.mouseButton != LEFT) return;

      float mx = app.mouseX;
      float my = app.mouseY;
      if (app.camera != null) {
        Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(mx, my));
        Vector2 worldMouse = app.camera.screenToWorld(designMouse);
        mx = worldMouse.x;
        my = worldMouse.y;
        shenyf.p5engine.util.Logger.debug("Mouse", String.format("mousePressed actual=(%d,%d) design=(%.1f,%.1f) world=(%.1f,%.1f) camPos=(%.1f,%.1f) zoom=%.2f",
          app.mouseX, app.mouseY, designMouse.x, designMouse.y, worldMouse.x, worldMouse.y,
          app.camera.getTransform().getPosition().x, app.camera.getTransform().getPosition().y, app.camera.getZoom()));
      }

      if (mx >= 0 && mx < WORLD_W && my >= 0 && my < WORLD_H) {
        float px = TdGameWorld.snapGrid(mx);
        float py = TdGameWorld.snapGrid(my);
        shenyf.p5engine.util.Logger.debug("Mouse", String.format("placeTower snapped=(%.1f,%.1f)", px, py));
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
