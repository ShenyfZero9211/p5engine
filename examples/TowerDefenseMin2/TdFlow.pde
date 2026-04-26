/**
 * Scene flow controller: Menu -> LevelSelect -> Playing -> Win/Lose.
 */
static final class TdFlow {

    static void buildMainMenu(TowerDefenseMin2 app) {
        // println("[DEBUG] buildMainMenu called, current state=" + app.state);
        TdSaveData.saveSettings();
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        // println("[DEBUG] root.removeAllChildren done");

        TweenManager tm = app.engine.getTweenManager();
        // println("[DEBUG] tween active count before killAll=" + tm.getActiveCount());
        tm.killAll();
        // println("[DEBUG] tween active count after killAll=" + tm.getActiveCount());
        tm.setUseUnscaledTime(true);

        Window win = new Window("menu_win");
        win.setBounds(340, 300, 600, 360);
        win.setTitle(TdAssets.i18n("menu.title"));
        win.setMovable(false);
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        // Version panel - fixed at bottom-right of the entire window
        Panel versionPanel = new Panel("version_panel");
        versionPanel.setPaintBackground(false);
        versionPanel.setZOrder(100);
        int labelW = 80;
        int labelH = 20;
        int margin = 12;
        int windowW = app.width;
        int windowH = app.height;
        versionPanel.setBounds(windowW - labelW - margin, windowH - labelH - margin, labelW, labelH);
        versionPanel.fadeIn(0.6f);
        Label lblVersion = new Label("lbl_version");
        lblVersion.setText(app.GAME_VERSION);
        lblVersion.setBounds(0, 0, labelW, labelH);
        lblVersion.setAlpha(0.4f);
        lblVersion.fadeIn(0.7f);
        versionPanel.add(lblVersion);
        root.add(versionPanel);

        Panel panel = new Panel("menu_panel");
        panel.setBounds(0, 0, 600, 320);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.setPaintBackground(false);
        panel.fadeIn(0.1f);
        win.add(panel);

        // Title animation: start from center, float up with outBack
        // println("[DEBUG] titleProgress before=" + TdMenuBg.titleProgress);
        TdMenuBg.titleProgress = 0f;
        // println("[DEBUG] titleProgress after reset=" + TdMenuBg.titleProgress);
        tm.toFloat(0f, 1f, 0.8f, v -> {
            TdMenuBg.titleProgress = v;
        }).ease(Ease::outBack).start();
        // println("[DEBUG] title tween started, active count=" + tm.getActiveCount());

        // Buttons start below their final position (keep existing staggered animation)
        Button btnStart = new Button("btn_start");
        btnStart.setLabel(TdAssets.i18n("menu.start"));
        btnStart.setBounds(180, 70, 240, 52);
        btnStart.setAlpha(0);
        btnStart.setAction(() -> TdFlow.showLevelSelect(app));
        panel.add(btnStart);

        Button btnSettings = new Button("btn_settings");
        btnSettings.setLabel(TdAssets.i18n("menu.settings"));
        btnSettings.setBounds(180, 140, 240, 52);
        btnSettings.setAlpha(0);
        btnSettings.setAction(() -> TdFlow.showSettings(app));
        panel.add(btnSettings);

        Button btnQuit = new Button("btn_quit");
        btnQuit.setLabel(TdAssets.i18n("menu.quit"));
        btnQuit.setBounds(180, 210, 240, 52);
        btnQuit.setAlpha(0);
        btnQuit.setAction(() -> app.exit());
        panel.add(btnQuit);

        // Staggered slide-up + fade-in (start after title begins moving)
        float btnDelay = 0.3f;
        tm.toY(btnStart, 40, 0.6f).ease(Ease::outBack).delay(btnDelay).start();
        tm.toAlpha(btnStart, 1f, 0.6f).ease(Ease::outBack).delay(btnDelay).start();

        tm.toY(btnSettings, 110, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.15f).start();
        tm.toAlpha(btnSettings, 1f, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.15f).start();

        tm.toY(btnQuit, 180, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.30f).start();
        tm.toAlpha(btnQuit, 1f, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.30f).start();

        // println("[DEBUG] buildMainMenu done, titleProgress=" + TdMenuBg.titleProgress);
        app.state = TdState.MENU;
        // println("[DEBUG] buildMainMenu set state=MENU");
        TdSound.playBgmMenu();
    }

    static void showLevelSelect(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        // Centered level select window, no title bar, no background
        int winW = 640;
        int winH = 400;
        int winX = (1280 - winW) / 2;
        int winY = (720 - winH) / 2;
        Window win = new Window("level_win");
        win.setBounds(winX, winY, winW, winH);
        win.hideTitleBar();
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        // Level buttons: 5:2 aspect ratio, 2 rows x 4 cols, centered in panel
        int btnW = 140;   // 5
        int btnH = 56;    // 2
        int cols = 4;
        int rows = 2;
        int hgap = 16;
        int vgap = 16;
        int gridW = cols * btnW + (cols - 1) * hgap;
        int gridH = rows * btnH + (rows - 1) * vgap;
        int panelH = 320;
        int startX = (winW - gridW) / 2;
        int startY = (panelH - gridH) / 2;

        Panel panel = new Panel("level_panel");
        panel.setBounds(0, 0, winW, panelH);
        panel.setPaintBackground(false);
        panel.fadeIn(0f);
        win.add(panel);

        int count = TdAssets.getLevelCount();
        for (int i = 1; i <= count; i++) {
            final int lid = i;
            int col = (i - 1) % cols;
            int row = (i - 1) / cols;
            int bx = startX + col * (btnW + hgap);
            int by = startY + row * (btnH + vgap);
            Button btn = new Button("btn_level_" + i);
            btn.setBounds(bx, by, btnW, btnH);
            btn.setLabel(TdAssets.i18n("levelSelect.level", i));
            btn.setAction(() -> TdFlow.startLevel(app, lid));
            btn.appear(0.05f * i, 16f, 0.4f);
            panel.add(btn);
        }

        // Back button centered below the level grid
        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("menu.back"));
        btnBack.setBounds((winW - 200) / 2, 340, 200, 44);
        btnBack.setAction(() -> TdFlow.buildMainMenu(app));
        btnBack.appear(0.05f * (count + 1), 16f, 0.4f);
        win.add(btnBack);
    }

    static void showSettings(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("settings_win");
        win.setBounds(340, 160, 600, 480);
        win.setTitle(TdAssets.i18n("settings.title"));
        win.setMovable(false);
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("settings_panel");
        panel.setBounds(0, 0, 600, 480);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.fadeIn(0f);
        win.add(panel);

        int y = 20;
        int lblW = 160, ctrlX = 180, ctrlW = 280, rowH = 36;
        float rowDelay = 0f;
        float rowDelayStep = 0.08f;

        // Master Volume
        Label lblMaster = new Label("lbl_master");
        lblMaster.setText(TdAssets.i18n("settings.masterVolume"));
        lblMaster.setBounds(20, y, lblW, rowH);
        lblMaster.appear(rowDelay);
        panel.add(lblMaster);

        Slider sldMaster = new Slider("sld_master");
        sldMaster.setBounds(ctrlX, y, ctrlW, rowH);
        sldMaster.setValue(app.engine.getAudio().getMasterVolume());
        sldMaster.setOnChange(() -> {
            TdAssets.setMasterVolume(sldMaster.getValue());
            TdSaveData.setMasterVolume(sldMaster.getValue());
        });
        sldMaster.appear(rowDelay + 0.03f);
        panel.add(sldMaster);
        y += rowH + 12;
        rowDelay += rowDelayStep;

        // BGM Volume
        Label lblBgm = new Label("lbl_bgm");
        lblBgm.setText(TdAssets.i18n("settings.bgmVolume"));
        lblBgm.setBounds(20, y, lblW, rowH);
        lblBgm.appear(rowDelay);
        panel.add(lblBgm);

        Slider sldBgm = new Slider("sld_bgm");
        sldBgm.setBounds(ctrlX, y, ctrlW, rowH);
        float bgmVol = 1.0f;
        try { bgmVol = app.engine.getAudio().getGroup("bgm").getVolume(); } catch (Exception e) { }
        sldBgm.setValue(bgmVol);
        sldBgm.setOnChange(() -> {
            TdAssets.setBgmVolume(sldBgm.getValue());
            TdSaveData.setBgmVolume(sldBgm.getValue());
        });
        sldBgm.appear(rowDelay + 0.03f);
        panel.add(sldBgm);
        y += rowH + 12;
        rowDelay += rowDelayStep;

        // SFX Volume
        Label lblSfx = new Label("lbl_sfx");
        lblSfx.setText(TdAssets.i18n("settings.sfxVolume"));
        lblSfx.setBounds(20, y, lblW, rowH);
        lblSfx.appear(rowDelay);
        panel.add(lblSfx);

        Slider sldSfx = new Slider("sld_sfx");
        sldSfx.setBounds(ctrlX, y, ctrlW, rowH);
        float sfxVol = 1.0f;
        try { sfxVol = app.engine.getAudio().getGroup("sfx").getVolume(); } catch (Exception e) { }
        sldSfx.setValue(sfxVol);
        sldSfx.setOnChange(() -> {
            TdAssets.setSfxVolume(sldSfx.getValue());
            TdSaveData.setSfxVolume(sldSfx.getValue());
        });
        sldSfx.appear(rowDelay + 0.03f);
        panel.add(sldSfx);
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Resolution
        Label lblRes = new Label("lbl_res");
        lblRes.setText(TdAssets.i18n("settings.resolution"));
        lblRes.setBounds(20, y, lblW, rowH);
        lblRes.appear(rowDelay);
        panel.add(lblRes);

        int[][] resOptions = { {1280, 720}, {1600, 900}, {1920, 1080} };
        int bx = ctrlX;
        for (int[] res : resOptions) {
            final int rw = res[0];
            final int rh = res[1];
            Button btnRes = new Button("btn_res_" + rw);
            btnRes.setLabel(rw + "x" + rh);
            btnRes.setBounds(bx, y, 80, rowH);
            btnRes.setAction(() -> {
                app.surface.setSize(rw, rh);
                app.engine.getDisplayManager().onWindowResize(rw, rh);
                app.worldWindow.setBounds(0, TdConfig.TOP_HUD, rw - TdConfig.RIGHT_W, rh - TdConfig.TOP_HUD);
                app.worldViewport.setBounds(1, 1, app.worldWindow.getWidth() - 2, app.worldWindow.getHeight() - 2);
                app.camera.setViewportSize(app.worldWindow.getWidth() - 2, app.worldWindow.getHeight() - 2);
                app.camera.setViewportOffset(app.worldWindow.getAbsoluteX() + 1, app.worldWindow.getAbsoluteY() + 1);
            });
            btnRes.appear(rowDelay + 0.03f + (bx - ctrlX) / 90f * 0.03f);
            panel.add(btnRes);
            bx += 90;
        }
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Language
        Label lblLang = new Label("lbl_lang");
        lblLang.setText(TdAssets.i18n("settings.language"));
        lblLang.setBounds(20, y, lblW, rowH);
        lblLang.appear(rowDelay);
        panel.add(lblLang);

        Button btnZh = new Button("btn_zh");
        btnZh.setLabel(TdAssets.i18n("settings.lang.zh"));
        btnZh.setBounds(ctrlX, y, 80, rowH);
        btnZh.setAction(() -> {
            app.engine.getI18n().setLocale("zh");
            TdSaveData.setLanguage("zh");
            TdFlow.showSettings(app);
        });
        btnZh.appear(rowDelay + 0.03f);
        panel.add(btnZh);

        Button btnEn = new Button("btn_en");
        btnEn.setLabel(TdAssets.i18n("settings.lang.en"));
        btnEn.setBounds(ctrlX + 90, y, 80, rowH);
        btnEn.setAction(() -> {
            app.engine.getI18n().setLocale("en");
            TdSaveData.setLanguage("en");
            TdFlow.showSettings(app);
        });
        btnEn.appear(rowDelay + 0.06f);
        panel.add(btnEn);
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Zoom at mouse toggle
        Label lblZoom = new Label("lbl_zoom");
        lblZoom.setText(TdAssets.i18n("settings.zoomAtMouse"));
        lblZoom.setBounds(20, y, lblW, rowH);
        lblZoom.appear(rowDelay);
        panel.add(lblZoom);

        Button btnZoomToggle = new Button("btn_zoom_toggle");
        btnZoomToggle.setLabel(TdSaveData.isZoomAtMouse() ? "ON" : "OFF");
        btnZoomToggle.setBounds(ctrlX, y, 80, rowH);
        btnZoomToggle.setAction(() -> {
            TdSaveData.setZoomAtMouse(!TdSaveData.isZoomAtMouse());
            TdFlow.showSettings(app);
        });
        btnZoomToggle.appear(rowDelay + 0.03f);
        panel.add(btnZoomToggle);
        y += rowH + 30;
        rowDelay += rowDelayStep;

        // Back
        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("settings.back"));
        btnBack.setBounds(200, y, 200, 44);
        btnBack.setAction(() -> {
            TdSaveData.saveSettings();
            TdFlow.buildMainMenu(app);
        });
        panel.add(btnBack);
    }

    static void startLevel(TowerDefenseMin2 app, int levelId) {
        TdSaveData.incGamesPlayed();
        app.state = TdState.PLAYING;
        app.ui.getRoot().removeAllChildren();
        TdGameWorld.startLevel(app, levelId);
        app.setupWorldViewport();
        app.setupHud();
        TdSound.playBgmGame();
    }

    static void showWin(TowerDefenseMin2 app) {
        TdSaveData.saveSettings();
        app.state = TdState.WIN;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("win_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.win"));
        win.setMovable(false);
        win.setZOrder(20);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("win_panel");
        panel.setBounds(0, 0, 500, 240);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.fadeIn(0f);
        win.add(panel);

        Button btnNext = new Button("btn_next");
        btnNext.setLabel(TdAssets.i18n("game.nextLevel"));
        btnNext.setBounds(150, 60, 200, 44);
        btnNext.setAction(() -> {
            int next = TdGameWorld.level != null ? TdGameWorld.level.id + 1 : 1;
            if (next <= TdAssets.getLevelCount()) startLevel(app, next);
            else buildMainMenu(app);
        });
        btnNext.appear(0.1f);
        panel.add(btnNext);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(150, 120, 200, 44);
        btnMenu.setAction(() -> {
            // println("[DEBUG] WIN btnMenu clicked");
            TdFlow.buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
    }

    static void showPauseMenu(TowerDefenseMin2 app) {
        app.state = TdState.PAUSED;
        Panel root = app.ui.getRoot();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        // Semi-transparent overlay to block clicks
        Panel overlay = new Panel("pause_overlay") {
            @Override
            public void paint(PApplet applet, Theme theme) {
                applet.fill(0x66000000);
                applet.noStroke();
                applet.rect(getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight());
                super.paint(applet, theme);
            }
        };
        overlay.setBounds(0, 0, 1280, 720);
        overlay.setPaintBackground(false);
        overlay.setZOrder(50);
        overlay.fadeIn(0f);
        root.add(overlay);

        Window win = new Window("pause_win");
        win.setBounds(440, 260, 400, 240);
        win.setTitle(TdAssets.i18n("game.pause"));
        win.setMovable(false);
        win.setZOrder(51);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        overlay.add(win);

        Panel panel = new Panel("pause_panel");
        panel.setBounds(0, 0, 400, 240);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.setPaintBackground(false);
        panel.fadeIn(0f);
        win.add(panel);

        Button btnResume = new Button("btn_resume");
        btnResume.setLabel(TdAssets.i18n("game.resume"));
        btnResume.setBounds(100, 60, 200, 44);
        btnResume.setAction(() -> hidePauseMenu(app));
        btnResume.appear(0.1f);
        panel.add(btnResume);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(100, 120, 200, 44);
        btnMenu.setAction(() -> {
            hidePauseMenu(app);
            buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
    }

    static void hidePauseMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        // Find and remove the pause overlay (it contains the pause window)
        for (UIComponent c : new java.util.ArrayList<>(root.getChildren())) {
            if ("pause_overlay".equals(c.getId())) {
                root.remove(c);
                break;
            }
        }
        app.state = TdState.PLAYING;
    }

    static void showLose(TowerDefenseMin2 app) {
        // println("[DEBUG] showLose called");
        TdSaveData.incGamesLost();
        TdSaveData.saveSettings();
        app.state = TdState.LOSE;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("lose_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.lose"));
        win.setMovable(false);
        win.setZOrder(20);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("lose_panel");
        panel.setBounds(0, 0, 500, 240);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.fadeIn(0f);
        win.add(panel);

        Button btnRetry = new Button("btn_retry");
        btnRetry.setLabel(TdAssets.i18n("game.retry"));
        btnRetry.setBounds(150, 60, 200, 44);
        btnRetry.setAction(() -> {
            int id = TdGameWorld.level != null ? TdGameWorld.level.id : 1;
            startLevel(app, id);
        });
        btnRetry.appear(0.1f);
        panel.add(btnRetry);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(150, 120, 200, 44);
        btnMenu.setAction(() -> {
            // println("[DEBUG] btnMenu clicked, calling buildMainMenu");
            TdFlow.buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
        // println("[DEBUG] showLose done");
    }
}
