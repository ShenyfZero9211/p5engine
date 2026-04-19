/** Absolute layout for null-layout UIManager root (same idea as ImageLab). */
static final class TdUiLayout {

  private TdUiLayout() {
  }

  static void layout(TowerDefenseMin a) {
    Panel root = a.ui.getRoot();
    if (a.width != root.getWidth() || a.height != root.getHeight()) {
      root.setSize(a.width, a.height);
    }
    a.panelMenu.setBounds(0, 0, a.width, a.height);
    int titleW = min(920, a.width - 80);
    a.lblMenuHint.setBounds((a.width - titleW) / 2, a.height / 2 - 148, titleW, 44);
    a.btnStart.setBounds((a.width - 220) / 2, a.height / 2 - 88, 220, 40);
    a.btnLoad.setBounds((a.width - 220) / 2, a.height / 2 - 40, 220, 40);
    a.btnSettings.setBounds((a.width - 220) / 2, a.height / 2 + 8, 220, 40);
    a.btnQuit.setBounds((a.width - 220) / 2, a.height / 2 + 56, 220, 40);
    a.lblLoadMsg.setBounds((a.width - 400) / 2, a.height / 2 + 108, 400, 24);

    a.panelSettings.setBounds(0, 0, a.width, a.height);

    a.panelTopHud.setBounds(0, 0, a.width - TdConfig.RIGHT_W, TdConfig.TOP_HUD);
    a.lblHudLine.setBounds(8, 6, a.width - TdConfig.RIGHT_W - 160, 28);
    a.btnSave.setBounds(a.width - TdConfig.RIGHT_W - 156, 6, 72, 28);
    a.btnToMenu.setBounds(a.width - TdConfig.RIGHT_W - 80, 6, 72, 28);

    a.panelRight.setBounds(a.width - TdConfig.RIGHT_W, TdConfig.TOP_HUD, TdConfig.RIGHT_W, a.height - TdConfig.TOP_HUD);
    int ry = 32;
    for (UIComponent c : a.panelRight.getChildren()) {
      if (c == a.lblTowerHint) {
        c.setBounds(8, ry, TdConfig.RIGHT_W - 12, 120);
        ry += 128;
      } else {
        c.setBounds(8, ry, TdConfig.RIGHT_W - 24, 36);
        ry += 42;
      }
    }

    if (a.panelEndOverlay != null) {
      a.panelEndOverlay.setBounds(0, 0, a.width, a.height);
      if (a.lblEndMsg != null) {
        a.lblEndMsg.setBounds((a.width - 400) / 2, a.height / 2 - 40, 400, 40);
      }
      a.btnEndMenu.setBounds((a.width - 200) / 2, a.height / 2 + 10, 200, 40);
    }

    int sxs = (a.width - 280) / 2;
    int sys = a.height / 2 - 140;
    if (a.settingsTitle != null) a.settingsTitle.setBounds(sxs, sys, 280, 28);
    sys += 40;
    if (a.settingsLblEnemy != null) a.settingsLblEnemy.setBounds(sxs, sys, 280, 22);
    sys += 26;
    if (a.sliderEnemyMult != null) a.sliderEnemyMult.setBounds(sxs, sys, 260, 28);
    sys += 38;
    if (a.settingsLblFps != null) a.settingsLblFps.setBounds(sxs, sys, 280, 22);
    sys += 26;
    if (a.sliderTargetFps != null) a.sliderTargetFps.setBounds(sxs, sys, 260, 28);
    sys += 40;
    if (a.lblSettingsNote != null) a.lblSettingsNote.setBounds(sxs, sys, 420, 44);
    sys += 52;
    if (a.btnSettingsBack != null) a.btnSettingsBack.setBounds((a.width - 160) / 2, sys, 160, 36);

    root.invalidateLayout();
    a.panelMenu.layout(a);
    a.panelSettings.layout(a);
    a.panelTopHud.layout(a);
    a.panelRight.layout(a);
    if (a.panelEndOverlay != null) {
      a.panelEndOverlay.layout(a);
    }
  }
}
