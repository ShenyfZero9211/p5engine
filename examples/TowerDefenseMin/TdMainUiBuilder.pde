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
    app.lblMenuHint.setText("p5engine 塔防游戏");
    app.lblMenuHint.setSize(920, 44);
    app.panelMenu.add(app.lblMenuHint);

    app.btnStart = new Button("m_start");
    app.btnStart.setLabel("开始游戏");
    app.btnStart.setSize(220, 40);
    app.btnStart.setAction(() -> flow.startNewGame(false));
    app.panelMenu.add(app.btnStart);

    app.btnLoad = new Button("m_load");
    app.btnLoad.setLabel("载入游戏");
    app.btnLoad.setSize(220, 40);
    app.btnLoad.setAction(() -> flow.tryLoadGame());
    app.panelMenu.add(app.btnLoad);

    app.btnSettings = new Button("m_set");
    app.btnSettings.setLabel("设置");
    app.btnSettings.setSize(220, 40);
    app.btnSettings.setAction(() -> flow.enterSettings(true));
    app.panelMenu.add(app.btnSettings);

    app.btnQuit = new Button("m_quit");
    app.btnQuit.setLabel("退出");
    app.btnQuit.setSize(220, 40);
    app.btnQuit.setAction(() -> app.exit());
    app.panelMenu.add(app.btnQuit);

    app.lblLoadMsg = new Label("load_msg");
    app.lblLoadMsg.setText("");
    app.lblLoadMsg.setSize(400, 24);
    app.panelMenu.add(app.lblLoadMsg);

    root.add(app.panelMenu);

    app.panelSettings = new Panel("settings_root");
    app.panelSettings.setLayoutManager(null);
    app.panelSettings.setPaintBackground(true);
    app.panelSettings.setVisible(false);

    app.settingsTitle = new Label("st_title");
    app.settingsTitle.setText("设置（占位）");
    app.settingsTitle.setSize(280, 28);
    app.panelSettings.add(app.settingsTitle);

    app.settingsLblEnemy = new Label("st_l1");
    app.settingsLblEnemy.setText("敌人生成 / 强度倍率");
    app.settingsLblEnemy.setSize(280, 22);
    app.panelSettings.add(app.settingsLblEnemy);

    app.sliderEnemyMult = new Slider("st_em");
    app.sliderEnemyMult.setSize(260, 28);
    app.sliderEnemyMult.setValue(0.5f);
    app.panelSettings.add(app.sliderEnemyMult);

    app.settingsLblFps = new Label("st_l2");
    app.settingsLblFps.setText("目标帧率（占位，仅保存）");
    app.settingsLblFps.setSize(280, 22);
    app.panelSettings.add(app.settingsLblFps);

    app.sliderTargetFps = new Slider("st_fps");
    app.sliderTargetFps.setSize(260, 28);
    app.sliderTargetFps.setValue((60f - 30f) / (120f - 30f));
    app.panelSettings.add(app.sliderTargetFps);

    app.lblSettingsNote = new Label("st_note");
    app.lblSettingsNote.setText("音量等可后续接入；当前写入 save.json 的 meta。");
    app.lblSettingsNote.setSize(420, 44);
    app.panelSettings.add(app.lblSettingsNote);

    app.btnSettingsBack = new Button("st_back");
    app.btnSettingsBack.setLabel("返回");
    app.btnSettingsBack.setSize(160, 36);
    app.btnSettingsBack.setAction(() -> flow.enterSettings(false));
    app.panelSettings.add(app.btnSettingsBack);

    root.add(app.panelSettings);

    app.panelTopHud = new Panel("top_hud");
    app.panelTopHud.setLayoutManager(null);
    app.panelTopHud.setPaintBackground(true);
    app.lblHudLine = new Label("hud");
    app.lblHudLine.setText("");
    app.lblHudLine.setSize(app.width - TdConfig.RIGHT_W - 160, 28);
    app.panelTopHud.add(app.lblHudLine);

    app.btnSave = new Button("save");
    app.btnSave.setLabel("保存");
    app.btnSave.setSize(72, 28);
    app.btnSave.setAction(() -> flow.saveGame());
    app.panelTopHud.add(app.btnSave);

    app.btnToMenu = new Button("to_menu");
    app.btnToMenu.setLabel("菜单");
    app.btnToMenu.setSize(72, 28);
    app.btnToMenu.setAction(() -> flow.goMenuFromGame());
    app.panelTopHud.add(app.btnToMenu);

    root.add(app.panelTopHud);

    app.panelRight = new Panel("right");
    app.panelRight.setLayoutManager(null);
    app.panelRight.setPaintBackground(true);

    Label lr = new Label("lr_title");
    lr.setText("建造");
    lr.setSize(TdConfig.RIGHT_W - 16, 24);
    app.panelRight.add(lr);

    app.btnTowerMg = addTowerBuildButton(app, flow, "t_mg", "机枪", TowerKind.MG);
    app.btnTowerMissile = addTowerBuildButton(app, flow, "t_ms", "导弹", TowerKind.MISSILE);
    app.btnTowerLaser = addTowerBuildButton(app, flow, "t_lz", "激光", TowerKind.LASER);
    app.btnTowerSlow = addTowerBuildButton(app, flow, "t_sl", "减速", TowerKind.SLOW);
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
    app.btnEndMenu.setLabel("回主菜单");
    app.btnEndMenu.setSize(200, 40);
    app.btnEndMenu.setAction(() -> {
      app.panelEndOverlay.setVisible(false);
      flow.goMenuFromGame();
    });
    app.panelEndOverlay.add(app.btnEndMenu);
    app.panelEndOverlay.setZOrder(200);
    root.add(app.panelEndOverlay);

    root.invalidateLayout();
  }

  private static Button addTowerBuildButton(TowerDefenseMin app, TdFlowController flow, String id, String text, TowerKind k) {
    Button b = new Button(id);
    b.setLabel(text);
    b.setSize(TdConfig.RIGHT_W - 24, 36);
    b.setAction(() -> flow.onTowerBuildPick(k));
    app.panelRight.add(b);
    return b;
  }
}
