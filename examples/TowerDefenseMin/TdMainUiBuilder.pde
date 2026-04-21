/**
 * Constructs all {@link UIManager} root panels/widgets for {@link TowerDefenseMin}.
 * Keeps the main sketch tab focused on lifecycle and gameplay glue.
 */
static final class TdMainUiBuilder {

  static void build(TowerDefenseMin app, UIManager ui, TdFlowController flow) {
    Panel root = ui.getRoot();
    root.removeAllChildren();
    root.setLayoutManager(null);

    app.panelMenu = new Panel("menu_root");
    app.panelMenu.setLayoutManager(null);
    app.panelMenu.setPaintBackground(true);

    app.lblMenuHint = new Label("menu_hint");
    app.lblMenuHint.setI18nKey("menu.title");
    app.lblMenuHint.setSize(920, 44);
    app.panelMenu.add(app.lblMenuHint);

    app.btnStart = new Button("m_start");
    app.btnStart.setI18nKey("menu.start");
    app.btnStart.setSize(220, 40);
    app.btnStart.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.enterLevelSelect(true); });
    app.panelMenu.add(app.btnStart);

    app.btnLoad = new Button("m_load");
    app.btnLoad.setI18nKey("menu.load");
    app.btnLoad.setSize(220, 40);
    app.btnLoad.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.tryLoadGame(); });
    app.panelMenu.add(app.btnLoad);

    app.btnSettings = new Button("m_set");
    app.btnSettings.setI18nKey("menu.settings");
    app.btnSettings.setSize(220, 40);
    app.btnSettings.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.enterSettings(true); });
    app.panelMenu.add(app.btnSettings);

    app.btnQuit = new Button("m_quit");
    app.btnQuit.setI18nKey("menu.quit");
    app.btnQuit.setSize(220, 40);
    app.btnQuit.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); app.exit(); });
    app.panelMenu.add(app.btnQuit);

    app.lblLoadMsg = new Label("load_msg");
    app.lblLoadMsg.setText("");
    app.lblLoadMsg.setSize(400, 24);
    app.panelMenu.add(app.lblLoadMsg);

    root.add(app.panelMenu);

    // 关卡选择面板
    app.panelLevelSelect = new Panel("level_select");
    app.panelLevelSelect.setLayoutManager(null);
    app.panelLevelSelect.setPaintBackground(true);
    app.panelLevelSelect.setVisible(false);

    Label lblSelectTitle = new Label("select_title");
    lblSelectTitle.setI18nKey("level.select");
    lblSelectTitle.setSize(280, 28);
    app.panelLevelSelect.add(lblSelectTitle);

    // 关卡1按钮
    Button btnLevel1 = new Button("level_1");
    btnLevel1.setI18nKey("level.1");
    btnLevel1.setSize(300, 44);
    btnLevel1.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.startNewGameWithLevel(1); });
    app.panelLevelSelect.add(btnLevel1);

    // 关卡2按钮
    Button btnLevel2 = new Button("level_2");
    btnLevel2.setI18nKey("level.2");
    btnLevel2.setSize(300, 44);
    btnLevel2.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.startNewGameWithLevel(2); });
    app.panelLevelSelect.add(btnLevel2);

    // 关卡3按钮
    Button btnLevel3 = new Button("level_3");
    btnLevel3.setI18nKey("level.3");
    btnLevel3.setSize(300, 44);
    btnLevel3.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.startNewGameWithLevel(3); });
    app.panelLevelSelect.add(btnLevel3);

    Button btnLevelBack = new Button("level_back");
    btnLevelBack.setI18nKey("common.back");
    btnLevelBack.setSize(160, 36);
    btnLevelBack.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.enterLevelSelect(false); });
    app.panelLevelSelect.add(btnLevelBack);

    root.add(app.panelLevelSelect);

    app.panelSettings = new Panel("settings_root");
    app.panelSettings.setLayoutManager(null);
    app.panelSettings.setPaintBackground(true);
    app.panelSettings.setVisible(false);

    app.settingsTitle = new Label("st_title");
    app.settingsTitle.setI18nKey("settings.title");
    app.settingsTitle.setSize(280, 28);
    app.panelSettings.add(app.settingsTitle);

    // Master volume
    app.lblMasterTitle = new Label("st_mt");
    app.lblMasterTitle.setI18nKey("settings.master");
    app.lblMasterTitle.setSize(200, 22);
    app.panelSettings.add(app.lblMasterTitle);
    app.sliderMasterVol = new Slider("st_mv");
    app.sliderMasterVol.setSize(200, 28);
    app.sliderMasterVol.setValue(1.0f);
    app.panelSettings.add(app.sliderMasterVol);
    app.lblMasterVal = new Label("st_mvv");
    app.lblMasterVal.setText("100%");
    app.lblMasterVal.setSize(60, 22);
    app.panelSettings.add(app.lblMasterVal);

    // BGM volume
    app.lblBgmTitle = new Label("st_bt");
    app.lblBgmTitle.setI18nKey("settings.bgm");
    app.lblBgmTitle.setSize(200, 22);
    app.panelSettings.add(app.lblBgmTitle);
    app.sliderBgmVol = new Slider("st_bv");
    app.sliderBgmVol.setSize(200, 28);
    app.sliderBgmVol.setValue(0.8f);
    app.panelSettings.add(app.sliderBgmVol);
    app.lblBgmVal = new Label("st_bvv");
    app.lblBgmVal.setText("80%");
    app.lblBgmVal.setSize(60, 22);
    app.panelSettings.add(app.lblBgmVal);

    // SFX volume
    app.lblSfxTitle = new Label("st_st");
    app.lblSfxTitle.setI18nKey("settings.sfx");
    app.lblSfxTitle.setSize(200, 22);
    app.panelSettings.add(app.lblSfxTitle);
    app.sliderSfxVol = new Slider("st_sv");
    app.sliderSfxVol.setSize(200, 28);
    app.sliderSfxVol.setValue(1.0f);
    app.panelSettings.add(app.sliderSfxVol);
    app.lblSfxVal = new Label("st_svv");
    app.lblSfxVal.setText("100%");
    app.lblSfxVal.setSize(60, 22);
    app.panelSettings.add(app.lblSfxVal);

    app.settingsLblEnemy = new Label("st_l1");
    app.settingsLblEnemy.setI18nKey("settings.enemy");
    app.settingsLblEnemy.setSize(280, 22);
    app.panelSettings.add(app.settingsLblEnemy);

    app.sliderEnemyMult = new Slider("st_em");
    app.sliderEnemyMult.setSize(260, 28);
    app.sliderEnemyMult.setValue(0.5f);
    app.panelSettings.add(app.sliderEnemyMult);

    app.settingsLblFps = new Label("st_l2");
    app.settingsLblFps.setI18nKey("settings.fps");
    app.settingsLblFps.setSize(280, 22);
    app.panelSettings.add(app.settingsLblFps);

    app.sliderTargetFps = new Slider("st_fps");
    app.sliderTargetFps.setSize(260, 28);
    app.sliderTargetFps.setValue((60f - 30f) / (120f - 30f));
    app.panelSettings.add(app.sliderTargetFps);

    app.lblSettingsNote = new Label("st_note");
    app.lblSettingsNote.setText("");
    app.lblSettingsNote.setSize(420, 20);
    app.panelSettings.add(app.lblSettingsNote);

    Label lblLang = new Label("st_lang");
    lblLang.setI18nKey("settings.lang");
    lblLang.setSize(200, 22);
    app.panelSettings.add(lblLang);

    app.btnLangZh = new Button("lang_zh");
    app.btnLangZh.setLabel("中文");
    app.btnLangZh.setSize(80, 32);
    app.btnLangZh.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); app.engine.getI18n().setLocale("zh"); flow.saveSettings(); });
    app.panelSettings.add(app.btnLangZh);

    app.btnLangEn = new Button("lang_en");
    app.btnLangEn.setLabel("English");
    app.btnLangEn.setSize(80, 32);
    app.btnLangEn.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); app.engine.getI18n().setLocale("en"); flow.saveSettings(); });
    app.panelSettings.add(app.btnLangEn);

    app.btnSettingsBack = new Button("st_back");
    app.btnSettingsBack.setI18nKey("common.back");
    app.btnSettingsBack.setSize(160, 36);
    app.btnSettingsBack.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.enterSettings(false); });
    app.panelSettings.add(app.btnSettingsBack);

    // Bind volume sliders
    java.util.function.Consumer<Float> updateMaster = v -> {
      app.lblMasterVal.setText(Math.round(v * 100) + "%");
      app.engine.getAudio().setMasterVolume(v);
    };
    app.sliderMasterVol.setOnChange(() -> updateMaster.accept(app.sliderMasterVol.getValue()));

    java.util.function.Consumer<Float> updateBgm = v -> {
      app.lblBgmVal.setText(Math.round(v * 100) + "%");
      app.engine.getAudio().setGroupVolume("bgm", v);
      flow.restartBgmMenuDelayed();
    };
    app.sliderBgmVol.setOnChange(() -> updateBgm.accept(app.sliderBgmVol.getValue()));

    java.util.function.Consumer<Float> updateSfx = v -> {
      app.lblSfxVal.setText(Math.round(v * 100) + "%");
      app.engine.getAudio().setGroupVolume("sfx", v);
    };
    app.sliderSfxVol.setOnChange(() -> updateSfx.accept(app.sliderSfxVol.getValue()));

    root.add(app.panelSettings);

    app.panelTopHud = new Panel("top_hud");
    app.panelTopHud.setLayoutManager(null);
    app.panelTopHud.setPaintBackground(true);
    app.lblHudLine = new Label("hud");
    app.lblHudLine.setText("");
    app.lblHudLine.setSize(app.width - TdConfig.RIGHT_W - 160, 28);
    app.panelTopHud.add(app.lblHudLine);

    app.btnSave = new Button("save");
    app.btnSave.setI18nKey("hud.save");
    app.btnSave.setSize(72, 28);
    app.btnSave.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.saveGame(); });
    app.panelTopHud.add(app.btnSave);

    app.btnToMenu = new Button("to_menu");
    app.btnToMenu.setI18nKey("hud.menu");
    app.btnToMenu.setSize(72, 28);
    app.btnToMenu.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.goMenuFromGame(); });
    app.panelTopHud.add(app.btnToMenu);

    root.add(app.panelTopHud);

    app.panelRight = new Panel("right");
    app.panelRight.setLayoutManager(null);
    app.panelRight.setPaintBackground(true);

    Label lr = new Label("lr_title");
    lr.setI18nKey("hud.build");
    lr.setSize(TdConfig.RIGHT_W - 16, 24);
    app.panelRight.add(lr);

    app.btnTowerMg = addTowerBuildButton(app, flow, "t_mg", "tower.mg", TowerKind.MG);
    app.btnTowerMissile = addTowerBuildButton(app, flow, "t_ms", "tower.missile", TowerKind.MISSILE);
    app.btnTowerLaser = addTowerBuildButton(app, flow, "t_lz", "tower.laser", TowerKind.LASER);
    app.btnTowerSlow = addTowerBuildButton(app, flow, "t_sl", "tower.slow", TowerKind.SLOW);
    app.btnTowerMg.setZOrder(20);
    app.btnTowerMissile.setZOrder(20);
    app.btnTowerLaser.setZOrder(20);
    app.btnTowerSlow.setZOrder(20);

    app.lblTowerHint = new Label("t_hint");
    app.lblTowerHint.setText("");
    app.lblTowerHint.setSize(TdConfig.RIGHT_W - 12, 120);
    app.lblTowerHint.setZOrder(0);
    app.panelRight.add(app.lblTowerHint);

    root.add(app.panelRight);

    app.panelTopHud.setVisible(false);
    app.panelRight.setVisible(false);

    app.panelEndOverlay = new Panel("end_overlay");
    app.panelEndOverlay.setLayoutManager(null);
    app.panelEndOverlay.setPaintBackground(true);
    app.panelEndOverlay.setVisible(false);

    app.lblEndMsg = new Label("end_lbl");
    app.lblEndMsg.setText("");
    app.lblEndMsg.setSize(400, 40);
    app.panelEndOverlay.add(app.lblEndMsg);

    app.btnEndMenu = new Button("end_menu");
    app.btnEndMenu.setI18nKey("game.toMenu");
    app.btnEndMenu.setSize(160, 40);
    app.btnEndMenu.setAction(() -> {
      app.panelEndOverlay.setVisible(false);
      flow.goMenuFromGame();
    });
    app.panelEndOverlay.add(app.btnEndMenu);

    // 下一关按钮（胜利时显示）
    app.btnNextLevel = new Button("next_level");
    app.btnNextLevel.setI18nKey("game.next");
    app.btnNextLevel.setSize(160, 40);
    app.btnNextLevel.setAction(() -> {
      app.panelEndOverlay.setVisible(false);
      flow.goNextLevel();
    });
    app.panelEndOverlay.add(app.btnNextLevel);

    // 重玩当前关卡按钮（失败时显示）
    app.btnReplayLevel = new Button("replay_level");
    app.btnReplayLevel.setI18nKey("game.replay");
    app.btnReplayLevel.setSize(160, 40);
    app.btnReplayLevel.setAction(() -> {
      app.panelEndOverlay.setVisible(false);
      flow.replayCurrentLevel();
    });
    app.panelEndOverlay.add(app.btnReplayLevel);
    app.panelEndOverlay.setZOrder(200);
    root.add(app.panelEndOverlay);

    root.invalidateLayout();
  }

  private static Button addTowerBuildButton(TowerDefenseMin app, TdFlowController flow, String id, String i18nKey, TowerKind k) {
    Button b = new Button(id);
    b.setI18nKey(i18nKey);
    b.setSize(TdConfig.RIGHT_W - 24, 36);
    b.setAction(() -> { flow.playSfx("data/sounds/percussive-knock.wav"); flow.onTowerBuildPick(k); });
    app.panelRight.add(b);
    return b;
  }
}
