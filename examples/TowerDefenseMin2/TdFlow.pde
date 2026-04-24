/**
 * Scene flow controller: Menu -> LevelSelect -> Playing -> Win/Lose.
 */
static final class TdFlow {

    static void buildMainMenu(TowerDefenseMin2 app) {
        TdSaveData.saveSettings();
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("menu_win");
        win.setBounds(340, 200, 600, 360);
        win.setTitle(TdAssets.i18n("menu.title"));
        win.setZOrder(10);
        win.setPaintBackground(false);
        root.add(win);

        Panel panel = new Panel("menu_panel");
        panel.setBounds(0, 0, 600, 320);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.setPaintBackground(false);
        win.add(panel);

        Button btnStart = new Button("btn_start");
        btnStart.setLabel(TdAssets.i18n("menu.start"));
        btnStart.setBounds(180, 40, 240, 52);
        btnStart.setAlpha(0);
        btnStart.setAction(() -> TdFlow.showLevelSelect(app));
        panel.add(btnStart);

        Button btnSettings = new Button("btn_settings");
        btnSettings.setLabel(TdAssets.i18n("menu.settings"));
        btnSettings.setBounds(180, 110, 240, 52);
        btnSettings.setAlpha(0);
        btnSettings.setAction(() -> TdFlow.showSettings(app));
        panel.add(btnSettings);

        Button btnQuit = new Button("btn_quit");
        btnQuit.setLabel(TdAssets.i18n("menu.quit"));
        btnQuit.setBounds(180, 180, 240, 52);
        btnQuit.setAlpha(0);
        btnQuit.setAction(() -> app.exit());
        panel.add(btnQuit);

        // Staggered fade-in animation
        TweenManager tm = app.engine.getTweenManager();
        tm.setUseUnscaledTime(true);
        tm.toAlpha(btnStart, 1f, 0.6f).ease(Ease::outBack).delay(0.1f).start();
        tm.toAlpha(btnSettings, 1f, 0.6f).ease(Ease::outBack).delay(0.25f).start();
        tm.toAlpha(btnQuit, 1f, 0.6f).ease(Ease::outBack).delay(0.4f).start();

        TdSound.playBgmMenu();
    }

    static void showLevelSelect(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("level_win");
        win.setBounds(240, 160, 800, 440);
        win.setTitle(TdAssets.i18n("levelSelect.title"));
        win.setZOrder(10);
        win.setPaintBackground(false);
        root.add(win);

        Panel panel = new Panel("level_panel");
        panel.setBounds(0, 0, 800, 440);
        panel.setLayoutManager(new GridLayout(2, 4, 12, 12));
        win.add(panel);

        int count = TdAssets.getLevelCount();
        for (int i = 1; i <= count; i++) {
            final int lid = i;
            Button btn = new Button("btn_level_" + i);
            btn.setLabel(TdAssets.i18n("levelSelect.level", i));
            btn.setAction(() -> TdFlow.startLevel(app, lid));
            panel.add(btn);
        }

        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("menu.back"));
        btnBack.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnBack);
    }

    static void showSettings(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("settings_win");
        win.setBounds(340, 160, 600, 480);
        win.setTitle(TdAssets.i18n("settings.title"));
        win.setZOrder(10);
        win.setPaintBackground(false);
        root.add(win);

        Panel panel = new Panel("settings_panel");
        panel.setBounds(0, 0, 600, 480);
        panel.setLayoutManager(new AbsoluteLayout());
        win.add(panel);

        int y = 20;
        int lblW = 160, ctrlX = 180, ctrlW = 280, rowH = 36;

        // Master Volume
        Label lblMaster = new Label("lbl_master");
        lblMaster.setText(TdAssets.i18n("settings.masterVolume"));
        lblMaster.setBounds(20, y, lblW, rowH);
        panel.add(lblMaster);

        Slider sldMaster = new Slider("sld_master");
        sldMaster.setBounds(ctrlX, y, ctrlW, rowH);
        sldMaster.setValue(app.engine.getAudio().getMasterVolume());
        sldMaster.setOnChange(() -> {
            TdAssets.setMasterVolume(sldMaster.getValue());
            TdSaveData.setMasterVolume(sldMaster.getValue());
        });
        panel.add(sldMaster);
        y += rowH + 12;

        // BGM Volume
        Label lblBgm = new Label("lbl_bgm");
        lblBgm.setText(TdAssets.i18n("settings.bgmVolume"));
        lblBgm.setBounds(20, y, lblW, rowH);
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
        panel.add(sldBgm);
        y += rowH + 12;

        // SFX Volume
        Label lblSfx = new Label("lbl_sfx");
        lblSfx.setText(TdAssets.i18n("settings.sfxVolume"));
        lblSfx.setBounds(20, y, lblW, rowH);
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
        panel.add(sldSfx);
        y += rowH + 20;

        // Resolution
        Label lblRes = new Label("lbl_res");
        lblRes.setText(TdAssets.i18n("settings.resolution"));
        lblRes.setBounds(20, y, lblW, rowH);
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
            panel.add(btnRes);
            bx += 90;
        }
        y += rowH + 20;

        // Language
        Label lblLang = new Label("lbl_lang");
        lblLang.setText(TdAssets.i18n("settings.language"));
        lblLang.setBounds(20, y, lblW, rowH);
        panel.add(lblLang);

        Button btnZh = new Button("btn_zh");
        btnZh.setLabel(TdAssets.i18n("settings.lang.zh"));
        btnZh.setBounds(ctrlX, y, 80, rowH);
        btnZh.setAction(() -> {
            app.engine.getI18n().setLocale("zh");
            TdSaveData.setLanguage("zh");
            TdFlow.showSettings(app);
        });
        panel.add(btnZh);

        Button btnEn = new Button("btn_en");
        btnEn.setLabel(TdAssets.i18n("settings.lang.en"));
        btnEn.setBounds(ctrlX + 90, y, 80, rowH);
        btnEn.setAction(() -> {
            app.engine.getI18n().setLocale("en");
            TdSaveData.setLanguage("en");
            TdFlow.showSettings(app);
        });
        panel.add(btnEn);
        y += rowH + 20;

        // Zoom at mouse toggle
        Label lblZoom = new Label("lbl_zoom");
        lblZoom.setText(TdAssets.i18n("settings.zoomAtMouse"));
        lblZoom.setBounds(20, y, lblW, rowH);
        panel.add(lblZoom);

        Button btnZoomToggle = new Button("btn_zoom_toggle");
        btnZoomToggle.setLabel(TdSaveData.isZoomAtMouse() ? "ON" : "OFF");
        btnZoomToggle.setBounds(ctrlX, y, 80, rowH);
        btnZoomToggle.setAction(() -> {
            TdSaveData.setZoomAtMouse(!TdSaveData.isZoomAtMouse());
            TdFlow.showSettings(app);
        });
        panel.add(btnZoomToggle);
        y += rowH + 30;

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
        TdSound.playBgmGame();
    }

    static void showWin(TowerDefenseMin2 app) {
        TdSaveData.saveSettings();
        app.state = TdState.WIN;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("win_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.win"));
        win.setZOrder(20);
        win.setPaintBackground(false);
        root.add(win);

        Panel panel = new Panel("win_panel");
        panel.setBounds(0, 0, 500, 240);
        panel.setLayoutManager(new AbsoluteLayout());
        win.add(panel);

        Button btnNext = new Button("btn_next");
        btnNext.setLabel(TdAssets.i18n("game.nextLevel"));
        btnNext.setBounds(150, 60, 200, 44);
        btnNext.setAction(() -> {
            int next = TdGameWorld.level != null ? TdGameWorld.level.id + 1 : 1;
            if (next <= TdAssets.getLevelCount()) startLevel(app, next);
            else buildMainMenu(app);
        });
        panel.add(btnNext);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(150, 120, 200, 44);
        btnMenu.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnMenu);
    }

    static void showLose(TowerDefenseMin2 app) {
        TdSaveData.incGamesLost();
        TdSaveData.saveSettings();
        app.state = TdState.LOSE;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("lose_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.lose"));
        win.setZOrder(20);
        win.setPaintBackground(false);
        root.add(win);

        Panel panel = new Panel("lose_panel");
        panel.setBounds(0, 0, 500, 240);
        panel.setLayoutManager(new AbsoluteLayout());
        win.add(panel);

        Button btnRetry = new Button("btn_retry");
        btnRetry.setLabel(TdAssets.i18n("game.retry"));
        btnRetry.setBounds(150, 60, 200, 44);
        btnRetry.setAction(() -> {
            int id = TdGameWorld.level != null ? TdGameWorld.level.id : 1;
            startLevel(app, id);
        });
        panel.add(btnRetry);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(150, 120, 200, 44);
        btnMenu.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnMenu);
    }
}
