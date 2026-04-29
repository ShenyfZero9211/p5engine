/**
 * Win/Lose text animation: each character pops in with scale bounce,
 * holds, then fades out before menu appears.
 */
static class WinLoseTextAnimator {
    enum Phase { REVEALING, HOLDING, FADING, DONE }
    Phase phase = Phase.REVEALING;
    String text;
    float charDelay = 0.08f;
    float charAnimDuration = 0.3f;
    float holdDuration = 1.8f;
    float fadeDuration = 0.6f;
    float timer = 0;
    int revealedCount = 0;
    Runnable onDone;
    static final float SLIDE_OFFSET = 60;
    static final int DIM_ALPHA = 180;

    WinLoseTextAnimator(String text, Runnable onDone) {
        this.text = text;
        this.onDone = onDone;
    }

    void update(float dt) {
        if (phase == Phase.DONE) return;
        timer += dt;
        switch (phase) {
            case REVEALING:
                int target = Math.min(text.length(), (int)(timer / charDelay) + 1);
                if (target > revealedCount) revealedCount = target;
                float totalReveal = text.length() * charDelay + charAnimDuration;
                if (timer >= totalReveal) {
                    phase = Phase.HOLDING;
                    timer = 0;
                }
                break;
            case HOLDING:
                if (timer >= holdDuration) {
                    phase = Phase.FADING;
                    timer = 0;
                }
                break;
            case FADING:
                if (timer >= fadeDuration) {
                    phase = Phase.DONE;
                    timer = 0;
                    if (onDone != null) onDone.run();
                }
                break;
        }
    }

    void render(PGraphics g, float cx, float cy) {
        if (phase == Phase.DONE || text == null || text.isEmpty()) return;

        // Dim overlay
        int dimAlpha;
        if (phase == Phase.REVEALING) {
            float revealProgress = Math.min(1, timer / (text.length() * charDelay + charAnimDuration));
            dimAlpha = (int)(DIM_ALPHA * revealProgress);
        } else if (phase == Phase.HOLDING) {
            dimAlpha = DIM_ALPHA;
        } else {
            dimAlpha = (int)(DIM_ALPHA * (1 - timer / fadeDuration));
        }
        g.noStroke();
        g.fill(0xFF000000, dimAlpha);
        g.rect(0, 0, 1280, 720);

        // Text characters slide in from above
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        g.textSize(56);
        float totalW = g.textWidth(text);
        float startX = cx - totalW * 0.5f;
        for (int i = 0; i < revealedCount && i < text.length(); i++) {
            float charT;
            if (phase == Phase.REVEALING) {
                float rawT = (timer - i * charDelay) / charAnimDuration;
                charT = Math.max(0, Math.min(1, rawT));
            } else {
                charT = 1;
            }

            // Slide from above + fade in
            float slideY = cy - SLIDE_OFFSET * (1 - charT);
            int alpha = (int)(255 * charT);
            if (phase == Phase.FADING) {
                alpha = (int)(255 * (1 - timer / fadeDuration));
            }

            char c = text.charAt(i);
            float charW = g.textWidth(String.valueOf(c));
            float x = startX + g.textWidth(text.substring(0, i)) + charW * 0.5f;
            g.fill(0xFFFFFFFF, alpha);
            g.text(String.valueOf(c), x, slideY);
        }
    }

    boolean isDone() { return phase == Phase.DONE; }
}

/**
 * Scene flow controller: Menu -> LevelSelect -> Playing -> Win/Lose.
 */
static final class TdFlow {

    static WinLoseTextAnimator winLoseAnimator = null;

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
        win.setResizable(false);
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
        int windowW = app.engine.getDisplayManager().getDesignWidth();
        int windowH = app.engine.getDisplayManager().getDesignHeight();
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
        btnSettings.setAction(() -> TdFlow.showSettings(app, true));
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
        win.setResizable(false);
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

    static void showSettings(TowerDefenseMin2 app, boolean animated) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("settings_win");
        win.setBounds(340, 160, 600, 480);
        win.setTitle(TdAssets.i18n("settings.title"));
        win.setMovable(false);
        win.setResizable(false);
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
        if (animated) lblMaster.appear(rowDelay);
        panel.add(lblMaster);

        Slider sldMaster = new Slider("sld_master");
        sldMaster.setBounds(ctrlX, y, ctrlW, rowH);
        sldMaster.setValue(app.engine.getAudio().getMasterVolume());
        sldMaster.setOnChange(() -> {
            TdAssets.setMasterVolume(sldMaster.getValue());
            TdSaveData.setMasterVolume(sldMaster.getValue());
        });
        if (animated) sldMaster.appear(rowDelay + 0.03f);
        panel.add(sldMaster);
        y += rowH + 12;
        rowDelay += rowDelayStep;

        // BGM Volume
        Label lblBgm = new Label("lbl_bgm");
        lblBgm.setText(TdAssets.i18n("settings.bgmVolume"));
        lblBgm.setBounds(20, y, lblW, rowH);
        if (animated) lblBgm.appear(rowDelay);
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
        if (animated) sldBgm.appear(rowDelay + 0.03f);
        panel.add(sldBgm);
        y += rowH + 12;
        rowDelay += rowDelayStep;

        // SFX Volume
        Label lblSfx = new Label("lbl_sfx");
        lblSfx.setText(TdAssets.i18n("settings.sfxVolume"));
        lblSfx.setBounds(20, y, lblW, rowH);
        if (animated) lblSfx.appear(rowDelay);
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
        if (animated) sldSfx.appear(rowDelay + 0.03f);
        panel.add(sldSfx);
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Fullscreen toggle
        Label lblFullscreen = new Label("lbl_fullscreen");
        lblFullscreen.setText(TdAssets.i18n("settings.fullscreen"));
        lblFullscreen.setBounds(20, y, lblW, rowH);
        if (animated) lblFullscreen.appear(rowDelay);
        panel.add(lblFullscreen);

        Button btnFullscreenToggle = new Button("btn_fullscreen_toggle");
        btnFullscreenToggle.setLabel(TdSaveData.isFullscreen() ? "ON" : "OFF");
        btnFullscreenToggle.setBounds(ctrlX, y, 80, rowH);
        if (animated) btnFullscreenToggle.appear(rowDelay + 0.03f);
        panel.add(btnFullscreenToggle);

        Label lblFullscreenHint = new Label("lbl_fullscreen_hint");
        lblFullscreenHint.setText("全屏选项修改后需要重启应用！");
        lblFullscreenHint.setBounds(ctrlX + 90, y, 300, rowH);
        lblFullscreenHint.setTextColor(0xFFFF5555);
        lblFullscreenHint.setVisible(TdSaveData.isFullscreen() != TdSaveData.startupFullscreen);
        if (animated) lblFullscreenHint.appear(rowDelay + 0.03f);
        panel.add(lblFullscreenHint);
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Resolution
        Label lblRes = new Label("lbl_res");
        lblRes.setText(TdAssets.i18n("settings.resolution"));
        lblRes.setBounds(20, y, lblW, rowH);
        if (animated) lblRes.appear(rowDelay);
        panel.add(lblRes);

        // Resolution dropdown (3A-game style combo box)
        int[] screenSize = shenyf.p5engine.core.WindowManager.getScreenSize();
        int screenW = screenSize[0];
        int screenH = screenSize[1];
        final java.util.List allRes = shenyf.p5engine.core.WindowManager.listAvailableResolutions();
        // Filter out resolutions larger than the physical screen (windowed mode limitation)
        final java.util.ArrayList filteredRes = new java.util.ArrayList();
        for (int i = 0; i < allRes.size(); i++) {
            shenyf.p5engine.rendering.ResolutionInfo info =
                (shenyf.p5engine.rendering.ResolutionInfo) allRes.get(i);
            if (info.width <= screenW && info.height <= screenH) {
                filteredRes.add(info);
            }
        }
        final java.util.List resList = filteredRes;

        Dropdown ddRes = new Dropdown("dd_res");
        ddRes.setBounds(ctrlX, y, 220, rowH);
        for (int i = 0; i < resList.size(); i++) {
            shenyf.p5engine.rendering.ResolutionInfo info =
                (shenyf.p5engine.rendering.ResolutionInfo) resList.get(i);
            ddRes.addItem(info.getLabel());
        }
        // Select current resolution
        int currentIdx = -1;
        for (int i = 0; i < resList.size(); i++) {
            shenyf.p5engine.rendering.ResolutionInfo info =
                (shenyf.p5engine.rendering.ResolutionInfo) resList.get(i);
            if (info.width == app.width && info.height == app.height) {
                currentIdx = i;
                break;
            }
        }
        ddRes.setSelectedIndex(currentIdx);
        ddRes.setEnabled(!TdSaveData.isFullscreen());
        ddRes.setOnSelect(() -> {
            int idx = ddRes.getSelectedIndex();
            if (idx < 0 || idx >= resList.size()) return;
            shenyf.p5engine.rendering.ResolutionInfo info =
                (shenyf.p5engine.rendering.ResolutionInfo) resList.get(idx);
            int targetW = info.width;
            int targetH = info.height;
            // Clamp to screen size just in case
            targetW = Math.min(targetW, screenW);
            targetH = Math.min(targetH, screenH);
            // Always persist to p5engine.ini so it takes effect on next launch
            String p5ini = app.sketchPath("p5engine.ini");
            shenyf.p5engine.config.SketchConfig p5cfg =
                new shenyf.p5engine.config.SketchConfig(p5ini);
            p5cfg.setWindowSize(targetW, targetH);
            // Sync to engine's sketchConfig so destroy() doesn't overwrite it
            if (app.engine != null) {
                app.engine.getSketchConfig().setWindowSize(targetW, targetH);
            }
            // Only apply immediately if currently in windowed mode
            if (app.engine.getWindowManager() != null && !app.engine.getWindowManager().isFullscreen()) {
                app.engine.getWindowManager().setWindowSize(targetW, targetH);
                app.engine.recenterWindow(targetW, targetH);
                // Delay re-applying mouse confinement so NEWT has time to process setSize
                java.util.Timer t = new java.util.Timer();
                t.schedule(new java.util.TimerTask() {
                    public void run() {
                        t.cancel();
                        app.engine.refreshMouseConfinement();
                    }
                }, 150);
                app.engine.getDisplayManager().onWindowResize(targetW, targetH);
                if (app.camera != null) {
                    app.camera.setViewportSize(targetW, targetH);
                    app.camera.setViewportOffset(0, 0);
                }
            }
        });
        if (animated) ddRes.appear(rowDelay + 0.03f);
        panel.add(ddRes);

        // Link fullscreen button action to resolution dropdown state
        btnFullscreenToggle.setAction(() -> {
            boolean next = !TdSaveData.isFullscreen();
            TdSaveData.setFullscreen(next);
            btnFullscreenToggle.setLabel(next ? "ON" : "OFF");
            ddRes.setEnabled(!next);
            lblFullscreenHint.setVisible(next != TdSaveData.startupFullscreen);
            if (next) {
                // Fullscreen: select screen resolution
                for (int i = 0; i < resList.size(); i++) {
                    shenyf.p5engine.rendering.ResolutionInfo info =
                        (shenyf.p5engine.rendering.ResolutionInfo) resList.get(i);
                    if (info.width == screenW && info.height == screenH) {
                        ddRes.setSelectedIndex(i);
                        break;
                    }
                }
            } else {
                // Windowed: restore saved window resolution from p5engine.ini
                String p5ini = app.sketchPath("p5engine.ini");
                shenyf.p5engine.config.SketchConfig p5cfgFile = new shenyf.p5engine.config.SketchConfig(p5ini);
                String savedW = p5cfgFile.get("window_size", "width");
                String savedH = p5cfgFile.get("window_size", "height");
                int targetW = savedW != null ? Integer.parseInt(savedW) : 1280;
                int targetH = savedH != null ? Integer.parseInt(savedH) : 720;
                for (int i = 0; i < resList.size(); i++) {
                    shenyf.p5engine.rendering.ResolutionInfo info =
                        (shenyf.p5engine.rendering.ResolutionInfo) resList.get(i);
                    if (info.width == targetW && info.height == targetH) {
                        ddRes.setSelectedIndex(i);
                        break;
                    }
                }
            }
        });
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Language
        Label lblLang = new Label("lbl_lang");
        lblLang.setText(TdAssets.i18n("settings.language"));
        lblLang.setBounds(20, y, lblW, rowH);
        if (animated) lblLang.appear(rowDelay);
        panel.add(lblLang);

        Button btnZh = new Button("btn_zh");
        btnZh.setLabel(TdAssets.i18n("settings.lang.zh"));
        btnZh.setBounds(ctrlX, y, 80, rowH);
        btnZh.setAction(() -> {
            app.engine.getI18n().setLocale("zh");
            TdSaveData.setLanguage("zh");
            TdFlow.showSettings(app, false);
        });
        if (animated) btnZh.appear(rowDelay + 0.03f);
        panel.add(btnZh);

        Button btnEn = new Button("btn_en");
        btnEn.setLabel(TdAssets.i18n("settings.lang.en"));
        btnEn.setBounds(ctrlX + 90, y, 80, rowH);
        btnEn.setAction(() -> {
            app.engine.getI18n().setLocale("en");
            TdSaveData.setLanguage("en");
            TdFlow.showSettings(app, false);
        });
        if (animated) btnEn.appear(rowDelay + 0.06f);
        panel.add(btnEn);
        y += rowH + 20;
        rowDelay += rowDelayStep;

        // Zoom at mouse toggle
        Label lblZoom = new Label("lbl_zoom");
        lblZoom.setText(TdAssets.i18n("settings.zoomAtMouse"));
        lblZoom.setBounds(20, y, lblW, rowH);
        if (animated) lblZoom.appear(rowDelay);
        panel.add(lblZoom);

        Button btnZoomToggle = new Button("btn_zoom_toggle");
        btnZoomToggle.setLabel(TdSaveData.isZoomAtMouse() ? "ON" : "OFF");
        btnZoomToggle.setBounds(ctrlX, y, 80, rowH);
        btnZoomToggle.setAction(() -> {
            boolean next = !TdSaveData.isZoomAtMouse();
            TdSaveData.setZoomAtMouse(next);
            btnZoomToggle.setLabel(next ? "ON" : "OFF");
        });
        if (animated) btnZoomToggle.appear(rowDelay + 0.03f);
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

    static void buildWinMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("win_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.win"));
        win.setMovable(false);
        win.setResizable(false);
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
            TdFlow.buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
    }

    static void showWin(TowerDefenseMin2 app) {
        TdSaveData.saveSettings();
        app.state = TdState.WIN;
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);
        winLoseAnimator = new WinLoseTextAnimator(TdAssets.i18n("game.win"), () -> {
            Panel root = app.ui.getRoot();
            root.removeAllChildren();
            buildWinMenu(app);
        });
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
        win.setResizable(false);
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
        btnResume.setBounds(100, 50, 200, 40);
        btnResume.setAction(() -> hidePauseMenu(app));
        btnResume.appear(0.1f);
        panel.add(btnResume);

        Button btnRetry = new Button("btn_retry");
        btnRetry.setLabel(TdAssets.i18n("game.retry"));
        btnRetry.setBounds(100, 100, 200, 40);
        btnRetry.setAction(() -> {
            hidePauseMenu(app);
            if (TdGameWorld.level != null) {
                TdGameWorld.startLevel(app, TdGameWorld.level.id);
                app.state = TdState.PLAYING;
            }
        });
        btnRetry.appear(0.15f);
        panel.add(btnRetry);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(100, 150, 200, 40);
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

    static void buildLoseMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("lose_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.lose"));
        win.setMovable(false);
        win.setResizable(false);
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
            TdFlow.buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
    }

    static void showLose(TowerDefenseMin2 app) {
        TdSaveData.incGamesLost();
        TdSaveData.saveSettings();
        app.state = TdState.LOSE;
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);
        winLoseAnimator = new WinLoseTextAnimator(TdAssets.i18n("game.lose"), () -> {
            Panel root = app.ui.getRoot();
            root.removeAllChildren();
            buildLoseMenu(app);
        });
    }
}
