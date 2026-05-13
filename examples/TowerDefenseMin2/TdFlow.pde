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
        g.pushMatrix();
        g.resetMatrix();
        g.rect(0, 0, g.width, g.height);
        g.popMatrix();

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
    static int briefingLevelId = -1;
    static int difficultySelectLevelId = -1;
    static int resumeDialogLevelId = -1;

    static void showMainMenuLoadError(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        Label lbl = new Label("lbl_mainmenu_error");
        lbl.setText(TdAssets.i18n("game.loadFailed"));
        lbl.setBounds(0, 0, 400, 40);
        lbl.setTextAlign(PApplet.CENTER);
        lbl.setTextColor(0xFFFF5B5B);
        lbl.setAlpha(0);
        // Center in screen (same as showLoadSuccessToast)
        DisplayManager dm = app.engine.getDisplayManager();
        float sw = dm.getActualWidth() / dm.getUniformScale();
        float sh = dm.getActualHeight() / dm.getUniformScale();
        lbl.setPosition((sw - 400) * 0.5f, sh * 0.45f);
        root.add(lbl);

        TweenManager tm = app.engine.getTweenManager();
        java.util.function.Consumer<Float> setter = v -> lbl.setAlpha(v);
        tm.toFloat(0f, 1f, 0.4f, setter).ease(Ease::outQuad).start();
        tm.toFloat(1f, 0f, 0.5f, setter).ease(Ease::inQuad).delay(1.8f).onComplete(() -> {
            root.remove(lbl);
        }).start();
    }

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

        TdMenuBg.resetMenuFade();

        Window win = new Window("menu_win");
        int windowH = 280;
        float scale = app.engine.getDisplayManager().getUniformScale();
        int actualH = app.engine.getDisplayManager().getActualHeight();
        int actualW = app.engine.getDisplayManager().getActualWidth();
        float aspectRatio = (float)actualW / actualH;
        float baseAspectRatio = 21.0f / 9.0f; // 21:9 基准
        float spacing = actualH * 0.1f * (baseAspectRatio / aspectRatio);
        int windowY = (int)((actualH - spacing) / scale) - windowH + 20;
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_TOP);
        win.setBounds(0, windowY, 320, windowH);
        win.setTitle(TdAssets.i18n("menu.title"));
        win.setMovable(false);
        win.setResizable(false);
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.hideTitleBar();
        win.fadeIn(0f);
        root.add(win);

        // Version panel - fixed at bottom-right of the entire window
        Panel versionPanel = new Panel("version_panel");
        versionPanel.setPaintBackground(false);
        versionPanel.setZOrder(100);
        int labelW = 80;
        int labelH = 20;
        int margin = 12;
        DisplayManager dm = app.engine.getDisplayManager();
        float fullH = dm.getActualHeight() / dm.getUniformScale();
        versionPanel.setAnchor(UIComponent.ANCHOR_RIGHT);
        versionPanel.setBounds(0, fullH - labelH - margin, labelW, labelH);
        versionPanel.fadeIn(0.6f);
        Label lblVersion = new Label("lbl_version");
        lblVersion.setText(app.GAME_VERSION);
        lblVersion.setBounds(0, 0, labelW, labelH);
        lblVersion.setAlpha(0.4f);
        lblVersion.fadeIn(0.7f);
        versionPanel.add(lblVersion);
        root.add(versionPanel);

        Panel panel = new Panel("menu_panel");
        panel.setBounds(0, 0, 320, 280);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.setPaintBackground(false);
        panel.fadeIn(0.1f);
        win.add(panel);

        // Buttons start invisible; TdMenuBg will trigger their fade-in
        Button btnStart = new Button("btn_start");
        btnStart.setLabel(TdAssets.i18n("menu.start"));
        btnStart.setBounds(40, 90, 240, 52);
        btnStart.setAlpha(0);
        btnStart.setAction(() -> TdFlow.showLevelSelect(app));
        btnStart.setSfxPath(TdSound.SFX_CLICK);
        panel.add(btnStart);
        TdMenuBg.btnStartRef = btnStart;

        Button btnSettings = new Button("btn_settings");
        btnSettings.setLabel(TdAssets.i18n("menu.settings"));
        btnSettings.setBounds(40, 160, 240, 52);
        btnSettings.setAlpha(0);
        btnSettings.setAction(() -> TdFlow.showSettings(app, true));
        btnSettings.setSfxPath(TdSound.SFX_CLICK);
        panel.add(btnSettings);
        TdMenuBg.btnSettingsRef = btnSettings;

        Button btnQuit = new Button("btn_quit");
        btnQuit.setLabel(TdAssets.i18n("menu.quit"));
        btnQuit.setBounds(40, 230, 240, 52);
        btnQuit.setAlpha(0);
        btnQuit.setAction(() -> showExitSaveDialog(app, () -> app.exit()));
        btnQuit.setSfxPath(TdSound.SFX_CLICK);
        panel.add(btnQuit);
        TdMenuBg.btnQuitRef = btnQuit;

        // Staggered slide-up + fade-in (start after title begins moving)
        float btnDelay = 0.3f;
        tm.toY(btnStart, 60, 0.6f).ease(Ease::outBack).delay(btnDelay).start();
        tm.toAlpha(btnStart, 1f, 0.6f).ease(Ease::outBack).delay(btnDelay).start();

        tm.toY(btnSettings, 130, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.15f).start();
        tm.toAlpha(btnSettings, 1f, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.15f).start();

        tm.toY(btnQuit, 200, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.30f).start();
        tm.toAlpha(btnQuit, 1f, 0.6f).ease(Ease::outBack).delay(btnDelay + 0.30f).start();

        // println("[DEBUG] buildMainMenu done, titleProgress=" + TdMenuBg.titleProgress);
        app.state = TdState.MENU;
        // println("[DEBUG] buildMainMenu set state=MENU");
        TdSound.playBgmMenu();
    }

    static void showLevelSelect(TowerDefenseMin2 app) {
        difficultySelectLevelId = -1;
        resumeDialogLevelId = -1;
        app.state = TdState.LEVEL_SELECT;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        // Centered level select window, no title bar, no background
        Window win = new Window("level_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 640, 400);
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
        int startX = (640 - gridW) / 2;
        int startY = (panelH - gridH) / 2;

        Panel panel = new Panel("level_panel");
        panel.setBounds(0, 0, 640, panelH);
        panel.setPaintBackground(false);
        panel.fadeIn(0f);
        win.add(panel);

        int count = TdAssets.getLevelCount();
        int maxReached = TdSaveData.getMaxLevelReached();
        for (int i = 1; i <= count; i++) {
            final int lid = i;
            int col = (i - 1) % cols;
            int row = (i - 1) / cols;
            int bx = startX + col * (btnW + hgap);
            int by = startY + row * (btnH + vgap);
            LevelButton btn = new LevelButton("btn_level_" + i);
            btn.setBounds(bx, by, btnW, btnH);
            btn.setLabel(TdAssets.i18n("levelSelect.level", i));
            boolean unlocked = lid <= maxReached;
            btn.locked = !unlocked;
            btn.cleared = unlocked && TdCompletion.hasAnyCompletion(lid);
            if (unlocked) {
                btn.setSfxPath(TdSound.SFX_CLICK);
                btn.setAction(() -> {
                    if (TdSaveLoad.hasSave(app, lid)) {
                        TdFlow.showLevelResumeDialog(app, lid);
                    } else {
                        TdFlow.showDifficultySelect(app, lid);
                    }
                });
            } else {
                btn.setEnabled(false);
            }
            btn.appear(0.05f * i, 16f, 0.4f);
            panel.add(btn);
        }

        // Back button centered below the level grid
        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("menu.back"));
        btnBack.setBounds((640 - 200) / 2, 340, 200, 44);
        btnBack.setAction(() -> TdFlow.buildMainMenu(app));
        btnBack.setSfxPath(TdSound.SFX_CLICK);
        btnBack.appear(0.05f * (count + 1), 16f, 0.4f);
        win.add(btnBack);
    }

    static void showSettings(TowerDefenseMin2 app, boolean animated) {
        app.state = TdState.SETTINGS;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("settings_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 600, 480);
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
                // Camera viewport fixed to design game area; no need to resize
            }
        });
        if (animated) ddRes.appear(rowDelay + 0.03f);
        panel.add(ddRes);

        // Link fullscreen button action to resolution dropdown state
        btnFullscreenToggle.setAction(() -> {
        btnFullscreenToggle.setSfxPath(TdSound.SFX_CLICK);
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
        btnZh.setSfxPath(TdSound.SFX_CLICK);
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
        btnEn.setSfxPath(TdSound.SFX_CLICK);
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
        btnZoomToggle.setSfxPath(TdSound.SFX_CLICK);
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
        btnBack.setSfxPath(TdSound.SFX_CLICK);
            TdSaveData.saveSettings();
            TdFlow.buildMainMenu(app);
        });
        panel.add(btnBack);
    }

    static void showDifficultySelect(TowerDefenseMin2 app, int levelId) {
        difficultySelectLevelId = levelId;
        resumeDialogLevelId = -1;
        app.state = TdState.LEVEL_SELECT;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("difficulty_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 400, 380);
        win.hideTitleBar();
        win.setResizable(false);
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("difficulty_panel");
        panel.setBounds(0, 0, 400, 380);
        panel.setPaintBackground(false);
        panel.fadeIn(0f);
        win.add(panel);

        // Title
        Label lblTitle = new Label("lbl_diff_title");
        lblTitle.setText(TdAssets.i18n("difficulty.selectTitle"));
        lblTitle.setBounds(0, 20, 400, 40);
        lblTitle.setTextAlign(PApplet.CENTER);
        panel.add(lblTitle);

        // Difficulty buttons
        String[] diffKeys = { "easy", "normal", "hard", "challenge" };
        int btnW = 280;
        int btnH = 48;
        int startY = 75;
        int gap = 12;
        for (int i = 0; i < diffKeys.length; i++) {
            final String dKey = diffKeys[i];
            DifficultyDef diff = TdAssets.getDifficulty(dKey);
            String label = (diff != null && diff.nameKey != null) ? TdAssets.i18n(diff.nameKey) : dKey;
            BadgeButton btn = new BadgeButton("btn_diff_" + dKey);
            btn.setBounds((400 - btnW) / 2, startY + i * (btnH + gap), btnW, btnH);
            btn.setLabel(label);
            btn.setShowBadge(TdCompletion.isCompleted(levelId, dKey));
            btn.setAction(() -> showBriefing(app, levelId, dKey));
            btn.setSfxPath(TdSound.SFX_CLICK);
            btn.appear(0.05f * (i + 1), 16f, 0.4f);
            panel.add(btn);
        }

        // Back button (same width as difficulty buttons)
        int backY = startY + diffKeys.length * (btnH + gap) + 8;
        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("menu.back"));
        btnBack.setBounds((400 - btnW) / 2, backY, btnW, btnH);
        btnBack.setAction(() -> {
        btnBack.setSfxPath(TdSound.SFX_CLICK);
            if (TdSaveLoad.hasSave(app, levelId)) {
                showLevelResumeDialog(app, levelId);
            } else {
                showLevelSelect(app);
            }
        });
        btnBack.appear(0.3f, 16f, 0.4f);
        panel.add(btnBack);
    }

    static void showBriefing(TowerDefenseMin2 app, int levelId, String difficultyKey) {
        briefingLevelId = levelId;
        app.state = TdState.BRIEFING;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        // Get briefing font from theme
        processing.core.PFont briefingFont = null;
        Theme theme = app.ui.getTheme();
        if (theme instanceof TdTheme) {
            briefingFont = ((TdTheme) theme).getBriefingFont();
        }

        shenyf.p5engine.rendering.DisplayManager dm = app.engine.getDisplayManager();
        float designW = dm.getDesignWidth();
        float designH = dm.getDesignHeight();
        float scale = dm.getUniformScale();
        float fullW = dm.getActualWidth() / scale;
        float fullH = dm.getActualHeight() / scale;

        int winW = 840;
        int winH = 520;
        // Use fullW/fullH instead of designW/designH so the window is centered
        // relative to the actual window area (accounting for root's -ox/-oy offset).
        int winX = (int)(fullW - winW) / 2;
        int winY = (int)(fullH - winH) / 2;

        Window win = new Window("briefing_win");
        win.setBounds(winX, winY, winW, winH);
        win.hideTitleBar();
        win.setResizable(false);
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("briefing_panel");
        panel.setBounds(0, 0, winW, winH);
        panel.setPaintBackground(false);
        panel.fadeIn(0f);
        win.add(panel);

        // Title: level name
        String levelName = TdAssets.i18n("level." + levelId + ".name");
        Label lblTitle = new Label("lbl_briefing_title");
        lblTitle.setText(levelName);
        lblTitle.setBounds(0, 4, winW, 32);
        lblTitle.setTextAlign(PApplet.CENTER);
        if (briefingFont != null) lblTitle.setFont(briefingFont);
        panel.add(lblTitle);

        // Difficulty label
        DifficultyDef diff = TdAssets.getDifficulty(difficultyKey);
        String diffLabel = (diff != null && diff.nameKey != null) ? TdAssets.i18n(diff.nameKey) : difficultyKey;
        Label lblDiff = new Label("lbl_briefing_diff");
        lblDiff.setText(diffLabel);
        lblDiff.setBounds(0, 36, winW, 24);
        lblDiff.setTextAlign(PApplet.CENTER);
        if (briefingFont != null) lblDiff.setFont(briefingFont);
        panel.add(lblDiff);

        // Briefing text: load from locale-specific txt file
        String locale = P5Engine.getInstance().getI18n().getLocale();
        String briefingText = TdAssets.loadBriefingText(levelId, locale);

        float contentW = 740;

        ScrollPane sp = new ScrollPane("briefing_scroll");
        sp.setBounds(30, 60, 780, 450);
        sp.setShowVerticalBar(true);
        sp.setBackgroundColor(0x801A2035);

        // Use BriefingText component for native P2D text rendering (fixes HiDPI issues)
        BriefingText bt = new BriefingText("lbl_briefing_text", briefingText,
            briefingFont, TdAssets.getFontSizeBriefing(), 0xFFE0E6F0);
        bt.setBounds(0, 0, (int) contentW, 100);
        bt.measure(app);
        float actualH = bt.getHeight();
        bt.setBounds(0, 0, (int) contentW, (int) actualH);

        sp.getViewport().setPaintBackground(false);
        sp.getViewport().setSize((int) contentW, (int) actualH);
        sp.getViewport().add(bt);
        panel.add(sp);

        // Buttons placed outside the window, horizontally aligned
        int btnW = 200;
        int btnH = 48;
        int btnGap = 20;
        int btnY = winY + winH + 16;
        int btnBaseX = winX + (winW - btnW * 2 - btnGap) / 2;

        Button btnBack = new Button("btn_briefing_back");
        btnBack.setLabel(TdAssets.i18n("briefing.back"));
        btnBack.setBounds(btnBaseX, btnY, btnW, btnH);
        btnBack.setAction(() -> showDifficultySelect(app, levelId));
        btnBack.setSfxPath(TdSound.SFX_CLICK);
        btnBack.setZOrder(11);
        btnBack.appear(0.15f, 16f, 0.4f);
        root.add(btnBack);

        Button btnStart = new Button("btn_briefing_start");
        btnStart.setLabel(TdAssets.i18n("briefing.start"));
        btnStart.setBounds(btnBaseX + btnW + btnGap, btnY, btnW, btnH);
        btnStart.setAction(() -> startLevel(app, levelId, difficultyKey));
        btnStart.setSfxPath(TdSound.SFX_CLICK);
        btnStart.setZOrder(11);
        btnStart.appear(0.25f, 16f, 0.4f);
        root.add(btnStart);
    }

    static void startLevel(TowerDefenseMin2 app, int levelId) {
        startLevel(app, levelId, "normal");
    }

    static void startLevel(TowerDefenseMin2 app, int levelId, String difficultyKey) {
        TdSaveData.incGamesPlayed();
        app.state = TdState.PLAYING;
        app.ui.getRoot().removeAllChildren();
        clearStarCaches();
        try {
            boolean ok = TdGameWorld.startLevel(app, levelId, difficultyKey);
            if (!ok) {
                buildMainMenu(app);
                showMainMenuLoadError(app);
                return;
            }
        } catch (Exception e) {
            buildMainMenu(app);
            showMainMenuLoadError(app);
            return;
        }
        app.setupWorldViewport();
        app.setupHud();
        TdSound.playBgmGame();
        String tutorialKey = TdTutorial.getTutorialKeyForLevel(levelId);
        if (tutorialKey != null) {
            TdTutorial.start(tutorialKey);
        }
    }

    static void buildWinMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("win_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 500, 240);
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
        btnNext.setSfxPath(TdSound.SFX_CLICK);
            int next = TdGameWorld.level != null ? TdGameWorld.level.id + 1 : 1;
            if (next <= TdAssets.getLevelCount()) showDifficultySelect(app, next);
            else buildMainMenu(app);
        });
        btnNext.appear(0.1f);
        panel.add(btnNext);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(150, 120, 200, 44);
        btnMenu.setAction(() -> {
        btnMenu.setSfxPath(TdSound.SFX_CLICK);
            TdFlow.buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
    }

    static void showWin(TowerDefenseMin2 app) {
        TdTutorial.stop();
        TdSaveData.saveSettings();
        // Update max level reached
        int currentMax = TdSaveData.getMaxLevelReached();
        if (TdGameWorld.level != null && TdGameWorld.level.id >= currentMax) {
            TdSaveData.setMaxLevelReached(TdGameWorld.level.id + 1);
            TdSaveData.saveSettings();
        }
        // Record completion for this level & difficulty
        if (TdGameWorld.level != null && TdGameWorld.currentDifficultyKey != null) {
            TdCompletion.setCompleted(TdGameWorld.level.id, TdGameWorld.currentDifficultyKey);
            TdCompletion.save(app);
        }
        app.state = TdState.WIN;
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);
        // Check if there is a next level; if not, skip win menu and go straight to main menu
        int nextId = (TdGameWorld.level != null) ? TdGameWorld.level.id + 1 : 1;
        boolean hasNextLevel = nextId <= TdAssets.getLevelCount();
        winLoseAnimator = new WinLoseTextAnimator(TdAssets.i18n("game.win"), () -> {
            Panel root = app.ui.getRoot();
            root.removeAllChildren();
            if (hasNextLevel) {
                buildWinMenu(app);
            } else {
                buildMainMenu(app);
            }
        });
    }

    static void setFocusableRecursive(UIComponent c, boolean focusable) {
        if (c instanceof shenyf.p5engine.ui.Container) {
            for (UIComponent child : ((shenyf.p5engine.ui.Container) c).getChildren()) {
                setFocusableRecursive(child, focusable);
            }
        }
        c.setFocusable(focusable);
    }

    static void showPauseMenu(TowerDefenseMin2 app) {
        app.state = TdState.PAUSED;
        Panel root = app.ui.getRoot();
        // Remove any load-success toast before killing tweens (prevents orphaned label)
        for (UIComponent c : new java.util.ArrayList<>(root.getChildren())) {
            if ("lbl_load_success".equals(c.getId())) {
                root.remove(c);
            }
        }
        // Disable focus on HUD elements so pause-menu navigation only cycles menu buttons
        if (app.hudTopBar != null) setFocusableRecursive(app.hudTopBar, false);
        if (app.hudBuildPanel != null) setFocusableRecursive(app.hudBuildPanel, false);
        if (app.hudMinimap != null) setFocusableRecursive(app.hudMinimap, false);
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
        DisplayManager dm = app.engine.getDisplayManager();
        float w = dm.getActualWidth() / dm.getUniformScale();
        float h = dm.getActualHeight() / dm.getUniformScale();
        overlay.setBounds(0, 0, w, h);
        overlay.setPaintBackground(false);
        overlay.setZOrder(50);
        overlay.fadeIn(0f);
        root.add(overlay);

        Window win = new Window("pause_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 400, 300);
        win.setTitle(TdAssets.i18n("game.pause"));
        win.setMovable(false);
        win.setResizable(false);
        win.setZOrder(51);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("pause_panel");
        panel.setBounds(0, 0, 400, 300);
        panel.setLayoutManager(new AbsoluteLayout());
        panel.setPaintBackground(false);
        panel.fadeIn(0f);
        win.add(panel);

        // Level + difficulty info label above buttons
        String levelText = (TdGameWorld.level != null)
            ? TdAssets.i18n("levelSelect.level", TdGameWorld.level.id) : "";
        DifficultyDef diff = TdAssets.getDifficulty(TdGameWorld.currentDifficultyKey);
        String diffText = (diff != null && diff.nameKey != null) ? TdAssets.i18n(diff.nameKey) : "";
        Label lblInfo = new Label("lbl_pause_info");
        lblInfo.setText(levelText + " - " + diffText);
        lblInfo.setBounds(0, 10, 400, 28);
        lblInfo.setTextAlign(PApplet.CENTER);
        lblInfo.setTextColor(0xFF8899AA);
        panel.add(lblInfo);

        int btnX = 100, btnW = 200, btnH = 36, gap = 12;
        int y = 46;

        Button btnResume = new Button("btn_resume");
        btnResume.setLabel(TdAssets.i18n("game.resume"));
        btnResume.setBounds(btnX, y, btnW, btnH);
        btnResume.setAction(() -> hidePauseMenu(app));
        btnResume.setSfxPath(TdSound.SFX_CLICK);
        btnResume.appear(0.1f);
        panel.add(btnResume);
        y += btnH + gap;

        // Save progress
        Label lblSaveHint = new Label("lbl_save_hint");
        lblSaveHint.setText("");
        lblSaveHint.setBounds(0, -20, 400, 28);
        lblSaveHint.setTextAlign(PApplet.CENTER);
        lblSaveHint.setTextColor(0xFF4ADE80);
        lblSaveHint.setAlpha(0);
        panel.add(lblSaveHint);

        java.util.function.Consumer<Float> saveHintAlphaSetter = v -> lblSaveHint.setAlpha(v);

        Button btnSave = new Button("btn_save");
        btnSave.setLabel(TdAssets.i18n("game.saveProgress"));
        btnSave.setBounds(btnX, y, btnW, btnH);
        btnSave.setAction(() -> {
        btnSave.setSfxPath(TdSound.SFX_CLICK);
            boolean ok = TdSaveLoad.saveGame(app);
            TweenManager tm = app.engine.getTweenManager();
            tm.killTarget(saveHintAlphaSetter);
            if (ok) {
                lblSaveHint.setTextColor(0xFF4ADE80);
                lblSaveHint.setText(TdAssets.i18n("game.saved"));
            } else {
                lblSaveHint.setTextColor(0xFFFF5B5B);
                lblSaveHint.setText(TdAssets.i18n("game.saveFailed"));
            }
            lblSaveHint.setAlpha(0);
            tm.toFloat(0f, 1f, 0.4f, saveHintAlphaSetter).ease(Ease::outQuad).start();
            tm.toFloat(1f, 0f, 0.5f, saveHintAlphaSetter).ease(Ease::inQuad).delay(1.8f).start();
        });
        btnSave.appear(0.13f);
        panel.add(btnSave);
        y += btnH + gap;

        // Load progress
        Label lblLoadHint = new Label("lbl_load_hint");
        lblLoadHint.setText("");
        lblLoadHint.setBounds(btnX + btnW + 8, y, 90, btnH);
        lblLoadHint.setTextAlign(PApplet.LEFT);
        lblLoadHint.setTextColor(0xFFFF5B5B);
        lblLoadHint.setAlpha(0);
        panel.add(lblLoadHint);

        java.util.function.Consumer<Float> loadHintAlphaSetter = v -> lblLoadHint.setAlpha(v);

        Button btnLoad = new Button("btn_load");
        btnLoad.setLabel(TdAssets.i18n("game.loadProgress"));
        btnLoad.setBounds(btnX, y, btnW, btnH);
        btnLoad.setAction(() -> {
            try {
                btnLoad.setSfxPath(TdSound.SFX_CLICK);
                if (TdGameWorld.level != null) {
                    boolean ok = TdSaveLoad.loadGame(app, TdGameWorld.level.id);
                    if (ok) {
                        hidePauseMenu(app);
                        showLoadSuccessToast(app);
                    } else {
                        lblLoadHint.setText(TdAssets.i18n("game.loadFailed"));
                        lblLoadHint.setAlpha(0);
                        TweenManager tm = app.engine.getTweenManager();
                        tm.killTarget(loadHintAlphaSetter);
                        tm.toFloat(0f, 1f, 0.4f, loadHintAlphaSetter).ease(Ease::outQuad).start();
                        tm.toFloat(1f, 0f, 0.5f, loadHintAlphaSetter).ease(Ease::inQuad).delay(1.8f).start();
                    }
                }
            } catch (Exception e) {
                println("[DEBUG] Exception in pause load action: " + e.getMessage());
                e.printStackTrace();
                lblLoadHint.setText(TdAssets.i18n("game.loadFailed"));
                lblLoadHint.setAlpha(0);
                TweenManager tm = app.engine.getTweenManager();
                tm.killTarget(loadHintAlphaSetter);
                tm.toFloat(0f, 1f, 0.4f, loadHintAlphaSetter).ease(Ease::outQuad).start();
                tm.toFloat(1f, 0f, 0.5f, loadHintAlphaSetter).ease(Ease::inQuad).delay(1.8f).start();
            }
        });
        btnLoad.appear(0.16f);
        panel.add(btnLoad);
        y += btnH + gap;

        Button btnRetry = new Button("btn_retry");
        btnRetry.setLabel(TdAssets.i18n("game.retry"));
        btnRetry.setBounds(btnX, y, btnW, btnH);
        btnRetry.setAction(() -> {
        btnRetry.setSfxPath(TdSound.SFX_CLICK);
            hidePauseMenu(app);
            if (TdGameWorld.level != null) {
                TdGameWorld.startLevel(app, TdGameWorld.level.id, TdGameWorld.currentDifficultyKey);
                app.state = TdState.PLAYING;
            }
        });
        btnRetry.appear(0.19f);
        panel.add(btnRetry);
        y += btnH + gap;

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(btnX, y, btnW, btnH);
        btnMenu.setAction(() -> {
        btnMenu.setSfxPath(TdSound.SFX_CLICK);
            hidePauseMenu(app);
            showExitSaveDialog(app, () -> {
                buildMainMenu(app);
            });
        });
        btnMenu.appear(0.22f);
        panel.add(btnMenu);
    }

    static void hidePauseMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        // Remove both pause overlay and pause window
        for (UIComponent c : new java.util.ArrayList<>(root.getChildren())) {
            String id = c.getId();
            if ("pause_overlay".equals(id) || "pause_win".equals(id)) {
                root.remove(c);
            }
        }
        // Restore focus on HUD elements
        if (app.hudTopBar != null) setFocusableRecursive(app.hudTopBar, true);
        if (app.hudBuildPanel != null) setFocusableRecursive(app.hudBuildPanel, true);
        if (app.hudMinimap != null) setFocusableRecursive(app.hudMinimap, true);
        app.state = TdState.PLAYING;
    }

    static void showLevelResumeDialog(TowerDefenseMin2 app, int levelId) {
        app.state = TdState.LEVEL_SELECT;
        difficultySelectLevelId = -1;
        resumeDialogLevelId = levelId;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("resume_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 400, 280);
        win.hideTitleBar();
        win.setResizable(false);
        win.setZOrder(10);
        win.setPaintBackground(false);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("resume_panel");
        panel.setBounds(0, 0, 400, 280);
        panel.setPaintBackground(false);
        win.add(panel);

        Label lblTitle = new Label("lbl_resume_title");
        lblTitle.setText(TdAssets.i18n("levelSelect.level", levelId));
        lblTitle.setBounds(0, 20, 400, 40);
        lblTitle.setTextAlign(PApplet.CENTER);
        panel.add(lblTitle);

        Label lblHint = new Label("lbl_resume_hint");
        lblHint.setText(TdAssets.i18n("game.hasSaveHint"));
        lblHint.setBounds(0, 58, 400, 28);
        lblHint.setTextAlign(PApplet.CENTER);
        lblHint.setTextColor(0xFF8899AA);
        panel.add(lblHint);

        Button btnRestart = new Button("btn_restart");
        btnRestart.setLabel(TdAssets.i18n("game.restart"));
        btnRestart.setBounds(60, 96, 280, 44);
        btnRestart.setAction(() -> showDifficultySelect(app, levelId));
        btnRestart.setSfxPath(TdSound.SFX_CLICK);
        btnRestart.appear(0.1f);
        panel.add(btnRestart);

        Label lblLoadHint = new Label("lbl_load_hint_save");
        lblLoadHint.setText("");
        lblLoadHint.setBounds(348, 148, 90, 44);
        lblLoadHint.setTextAlign(PApplet.LEFT);
        lblLoadHint.setTextColor(0xFFFF5B5B);
        lblLoadHint.setAlpha(0);
        panel.add(lblLoadHint);

        java.util.function.Consumer<Float> loadHintAlphaSetter2 = v -> lblLoadHint.setAlpha(v);

        Button btnLoad = new Button("btn_load_save");
        btnLoad.setLabel(TdAssets.i18n("game.loadProgress"));
        btnLoad.setBounds(60, 148, 280, 44);
        btnLoad.setAction(() -> {
            try {
                btnLoad.setSfxPath(TdSound.SFX_CLICK);
                boolean ok = TdSaveLoad.loadGame(app, levelId);
                if (ok) {
                    app.ui.getRoot().removeAllChildren();
                    app.state = TdState.PLAYING;
                    app.setupWorldViewport();
                    app.setupHud();
                    TdSound.playBgmGame();
                    showLoadSuccessToast(app);
                } else {
                    lblLoadHint.setText(TdAssets.i18n("game.loadFailed"));
                    lblLoadHint.setAlpha(0);
                    TweenManager tm = app.engine.getTweenManager();
                    tm.killTarget(loadHintAlphaSetter2);
                    tm.toFloat(0f, 1f, 0.4f, loadHintAlphaSetter2).ease(Ease::outQuad).start();
                    tm.toFloat(1f, 0f, 0.5f, loadHintAlphaSetter2).ease(Ease::inQuad).delay(1.8f).start();
                }
            } catch (Exception e) {
                println("[DEBUG] Exception in levelSelect load action: " + e.getMessage());
                e.printStackTrace();
                lblLoadHint.setText(TdAssets.i18n("game.loadFailed"));
                lblLoadHint.setAlpha(0);
                TweenManager tm = app.engine.getTweenManager();
                tm.killTarget(loadHintAlphaSetter2);
                tm.toFloat(0f, 1f, 0.4f, loadHintAlphaSetter2).ease(Ease::outQuad).start();
                tm.toFloat(1f, 0f, 0.5f, loadHintAlphaSetter2).ease(Ease::inQuad).delay(1.8f).start();
            }
        });
        btnLoad.appear(0.15f);
        panel.add(btnLoad);

        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("menu.back"));
        btnBack.setBounds(60, 200, 280, 44);
        btnBack.setAction(() -> showLevelSelect(app));
        btnBack.setSfxPath(TdSound.SFX_CLICK);
        btnBack.appear(0.2f);
        panel.add(btnBack);
    }

    static void showExitSaveDialog(TowerDefenseMin2 app, Runnable onExit) {
        if (TdGameWorld.level == null || (app.state != TdState.PLAYING && app.state != TdState.PAUSED)) {
            onExit.run();
            return;
        }

        Panel root = app.ui.getRoot();
        app.engine.getTweenManager().killAll();

        Window win = new Window("exit_save_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 440, 240);
        win.setTitle(TdAssets.i18n("game.exitSaveTitle"));
        win.hideTitleBar();
        win.setMovable(false);
        win.setResizable(false);
        win.setZOrder(100);
        win.fadeIn(0f);
        root.add(win);

        Panel panel = new Panel("exit_save_panel");
        panel.setBounds(0, 0, 440, 240);
        panel.setLayoutManager(new AbsoluteLayout());
        win.add(panel);

        Label lblHint = new Label("lbl_exit_save_hint");
        lblHint.setText(TdAssets.i18n("game.exitSaveHint"));
        lblHint.setBounds(20, 50, 400, 60);
        lblHint.setTextAlign(PApplet.CENTER);
        lblHint.setTextColor(0xFFCCCCCC);
        panel.add(lblHint);

        Button btnSaveExit = new Button("btn_save_exit");
        btnSaveExit.setLabel(TdAssets.i18n("game.saveAndExit"));
        btnSaveExit.setBounds(40, 130, 120, 40);
        btnSaveExit.setAction(() -> {
        btnSaveExit.setSfxPath(TdSound.SFX_CLICK);
            TdSaveLoad.saveGame(app);
            onExit.run();
        });
        panel.add(btnSaveExit);

        Button btnExit = new Button("btn_exit_no_save");
        btnExit.setLabel(TdAssets.i18n("game.exitWithoutSave"));
        btnExit.setBounds(170, 130, 120, 40);
        btnExit.setAction(() -> onExit.run());
        btnExit.setSfxPath(TdSound.SFX_CLICK);
        panel.add(btnExit);

        Button btnCancel = new Button("btn_exit_cancel");
        btnCancel.setLabel(TdAssets.i18n("ui.cancel"));
        btnCancel.setBounds(300, 130, 100, 40);
        btnCancel.setAction(() -> {
            root.remove(win);
            showPauseMenu(app);
        });
        btnCancel.setSfxPath(TdSound.SFX_CLICK);
        panel.add(btnCancel);
    }

    static void showLoadSuccessToast(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        Label lbl = new Label("lbl_load_success");
        lbl.setText(TdAssets.i18n("game.loadSuccess"));
        lbl.setBounds(0, 0, 400, 40);
        lbl.setTextAlign(PApplet.CENTER);
        lbl.setTextColor(0xFF4ADE80);
        lbl.setAlpha(0);
        // Center in screen
        DisplayManager dm = app.engine.getDisplayManager();
        float sw = dm.getActualWidth() / dm.getUniformScale();
        float sh = dm.getActualHeight() / dm.getUniformScale();
        lbl.setPosition((sw - 400) * 0.5f, sh * 0.45f);
        root.add(lbl);

        TweenManager tm = app.engine.getTweenManager();
        java.util.function.Consumer<Float> alphaSetter = v -> lbl.setAlpha(v);
        tm.toFloat(0f, 1f, 0.4f, alphaSetter).ease(Ease::outQuad).start();
        tm.toFloat(1f, 0f, 0.5f, alphaSetter).ease(Ease::inQuad).delay(1.8f).onComplete(() -> {
            root.remove(lbl);
        }).start();
    }

    static void buildLoseMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();
        app.engine.getTweenManager().killAll();
        app.engine.getTweenManager().setUseUnscaledTime(true);

        Window win = new Window("lose_win");
        win.setAnchor(UIComponent.ANCHOR_HCENTER | UIComponent.ANCHOR_VCENTER);
        win.setBounds(0, 0, 500, 240);
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
        btnRetry.setSfxPath(TdSound.SFX_CLICK);
            int id = TdGameWorld.level != null ? TdGameWorld.level.id : 1;
            showDifficultySelect(app, id);
        });
        btnRetry.appear(0.1f);
        panel.add(btnRetry);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setBounds(150, 120, 200, 44);
        btnMenu.setAction(() -> {
        btnMenu.setSfxPath(TdSound.SFX_CLICK);
            TdFlow.buildMainMenu(app);
        });
        btnMenu.appear(0.2f);
        panel.add(btnMenu);
    }

    static void showLose(TowerDefenseMin2 app) {
        TdTutorial.stop();
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

/**
 * Custom UI component for briefing text rendering using P2D offscreen buffer.
 * Text is rendered once into a cached PGraphics, then drawn via image() with
 * source-rectangle clipping. Completely avoids glScissor / clip() conflicts.
 */
static class BriefingText extends UIComponent {
    String[] rawLines;
    String[] wrappedLines;
    PFont font;
    float fontSize;
    int textColor;
    float lineHeight;

    BriefingText(String id, String text, PFont font, float fontSize, int textColor) {
        super(id);
        this.rawLines = (text != null) ? text.split("\n") : new String[0];
        this.font = font;
        this.fontSize = fontSize;
        this.textColor = textColor;
        this.lineHeight = fontSize * 1.5f + 4;
    }

    void measure(PApplet applet) {
        float maxW = Math.max(1, getWidth() - 8);
        applet.pushStyle();
        if (font != null) applet.textFont(font);
        applet.textSize(fontSize);
        ArrayList<String> all = new ArrayList<String>();
        for (String line : rawLines) {
            String[] wrapped = wrapLine(line, maxW, applet);
            for (String w : wrapped) all.add(w);
        }
        wrappedLines = all.toArray(new String[0]);
        applet.popStyle();
        float totalH = wrappedLines.length * lineHeight + 8;
        setSize(maxW + 8, totalH);
    }

    void paint(PApplet applet, Theme theme) {
        if (wrappedLines == null || wrappedLines.length == 0) return;

        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float viewTop = clipTop;
        float viewBottom = clipBottom;

        applet.pushStyle();
        if (font != null) applet.textFont(font);
        applet.textSize(fontSize);
        applet.textAlign(LEFT, TOP);
        applet.fill(textColor);
        applet.noStroke();

        float y = ay + 4;
        for (String line : wrappedLines) {
            // Strict clipping: only draw lines fully inside the viewport
            // (avoids spilling over ScrollPane edges since P2D clip() is incompatible with text())
            if (y >= viewTop && y + lineHeight <= viewBottom) {
                applet.text(line, ax + 4, y);
            }
            y += lineHeight;
        }
        applet.popStyle();
    }

    String[] wrapLine(String line, float maxW, PApplet applet) {
        if (line == null || line.isEmpty()) return new String[]{""};
        if (applet.textWidth(line) <= maxW) return new String[]{line};
        ArrayList<String> result = new ArrayList<String>();
        StringBuilder current = new StringBuilder();
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            String test = current.toString() + c;
            if (applet.textWidth(test) > maxW) {
                if (current.length() == 0) {
                    result.add(String.valueOf(c));
                } else {
                    result.add(current.toString());
                    current = new StringBuilder();
                    current.append(c);
                }
            } else {
                current.append(c);
            }
        }
        if (current.length() > 0) {
            result.add(current.toString());
        }
        return result.toArray(new String[0]);
    }
}
