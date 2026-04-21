/** Absolute layout for null-layout UIManager root (same idea as ImageLab). */
static final class TdUiLayout {

  private TdUiLayout() {
  }

  private static UIComponent findChildById(Panel parent, String id) {
    if (parent == null) return null;
    for (UIComponent c : parent.getChildren()) {
      if (id.equals(c.getId())) return c;
    }
    return null;
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

    // 关卡选择面板布局
    a.panelLevelSelect.setBounds(0, 0, a.width, a.height);
    int lsx = (a.width - 320) / 2;
    int lsy = a.height / 2 - 120;
    a.panelLevelSelect.getChildren().get(0).setBounds(lsx, lsy, 280, 28);
    lsy += 40;
    for (int i = 1; i <= 3; i++) {
      a.panelLevelSelect.getChildren().get(i).setBounds(lsx, lsy, 300, 44);
      lsy += 52;
    }
    a.panelLevelSelect.getChildren().get(4).setBounds(lsx + 70, lsy, 160, 36);

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
      int cx = a.width / 2;
      int cy = a.height / 2;
      if (a.lblEndMsg != null) {
        a.lblEndMsg.setBounds(cx - 200, cy - 60, 400, 40);
      }
      // 根据当前状态显示/隐藏按钮
      boolean isWin = (a.appMode == 3);
      boolean isLastLevel = (a.lastPlayedLevel >= TdLevelConfig.TOTAL_LEVELS);
      
      // 胜利时显示下一关按钮（不是最后一关），失败时显示重玩按钮
      if (a.btnNextLevel != null) {
        a.btnNextLevel.setVisible(isWin && !isLastLevel);
        a.btnNextLevel.setBounds(cx - 80, cy + 10, 160, 40);
      }
      if (a.btnReplayLevel != null) {
        a.btnReplayLevel.setVisible(!isWin);
        a.btnReplayLevel.setBounds(cx - 80, cy + 10, 160, 40);
      }
      if (a.btnEndMenu != null) {
        a.btnEndMenu.setBounds(cx - 80, cy + 60, 160, 40);
      }
    }

    int sxs = (a.width - 280) / 2;
    int sys = a.height / 2 - 180;
    if (a.settingsTitle != null) a.settingsTitle.setBounds(sxs, sys, 280, 28);
    sys += 32;
    // Master volume
    if (a.lblMasterTitle != null) a.lblMasterTitle.setBounds(sxs, sys, 100, 22);
    if (a.sliderMasterVol != null) a.sliderMasterVol.setBounds(sxs + 100, sys + 2, 140, 28);
    if (a.lblMasterVal != null) a.lblMasterVal.setBounds(sxs + 248, sys, 60, 22);
    sys += 32;
    // BGM volume
    if (a.lblBgmTitle != null) a.lblBgmTitle.setBounds(sxs, sys, 100, 22);
    if (a.sliderBgmVol != null) a.sliderBgmVol.setBounds(sxs + 100, sys + 2, 140, 28);
    if (a.lblBgmVal != null) a.lblBgmVal.setBounds(sxs + 248, sys, 60, 22);
    sys += 32;
    // SFX volume
    if (a.lblSfxTitle != null) a.lblSfxTitle.setBounds(sxs, sys, 100, 22);
    if (a.sliderSfxVol != null) a.sliderSfxVol.setBounds(sxs + 100, sys + 2, 140, 28);
    if (a.lblSfxVal != null) a.lblSfxVal.setBounds(sxs + 248, sys, 60, 22);
    sys += 40;
    // Enemy mult
    if (a.settingsLblEnemy != null) a.settingsLblEnemy.setBounds(sxs, sys, 280, 22);
    sys += 26;
    if (a.sliderEnemyMult != null) a.sliderEnemyMult.setBounds(sxs, sys, 260, 28);
    sys += 32;
    // Target FPS
    if (a.settingsLblFps != null) a.settingsLblFps.setBounds(sxs, sys, 280, 22);
    sys += 26;
    if (a.sliderTargetFps != null) a.sliderTargetFps.setBounds(sxs, sys, 260, 28);
    sys += 32;
    if (a.lblSettingsNote != null) a.lblSettingsNote.setBounds(sxs, sys, 420, 20);
    sys += 28;
    // Language selector
    UIComponent stLang = findChildById(a.panelSettings, "st_lang");
    if (stLang != null) stLang.setBounds(sxs, sys, 200, 22);
    sys += 24;
    if (a.btnLangZh != null) a.btnLangZh.setBounds(sxs, sys, 80, 32);
    if (a.btnLangEn != null) a.btnLangEn.setBounds(sxs + 90, sys, 80, 32);
    sys += 38;
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
