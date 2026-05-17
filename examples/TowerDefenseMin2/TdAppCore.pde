/**
 * TdAppCore — 游戏应用核心逻辑
 *
 * 从 TowerDefenseMin2.pde 迁移而来的所有初始化、主循环、输入处理和工具函数。
 * 主 PDE 仅保留 settings/setup/draw/keyPressed 四个框架函数作为入口委托。
 */

// ============================================
//  TdAppSetup — 游戏初始化（非 static，可访问外层字段）
// ============================================
final class TdAppSetup {

    void run() {
        // Load save data early so fullscreen config is available before window ops
        TdSaveData.load(TowerDefenseMin2.this);

        P5Config p5cfg = P5Config.defaults()
            .logToFile(true)
            .displayConfig(DisplayConfig.defaults()
                .designWidth(1280).designHeight(720)
                .resolutionPreset(shenyf.p5engine.rendering.ResolutionPreset.CUSTOM)
                .scaleMode(ScaleMode.FIT));

        engine = P5Engine.create(TowerDefenseMin2.this, p5cfg);

        // Center window when no saved position exists (engine auto-management handles p5engine.ini)
        if (!TdSaveData.isFullscreen()) {
            engine.centerWindow();
        }
        if (!TdSaveData.isFullscreen()) {
            engine.setMouseConfined(true);
        }
        engine.setApplicationTitle("TowerDefenseMin2");

        ui = new UIManager(TowerDefenseMin2.this);
        ui.attach();
        ui.setImeHwnd(engine.getImeHwnd());
        sketchUi = new SketchUiCoordinator(TowerDefenseMin2.this, ui);

        // Load configs early so font sizes from game_settings.yaml are available
        TdAssets.loadAll(TowerDefenseMin2.this);

        TdTheme theme = new TdTheme();
        int fontSizeSmall = TdAssets.getFontSizeSmall();
        int fontSizeLarge = TdAssets.getFontSizeLarge();
        PFont cnFontSmall = createFont("Microsoft YaHei", fontSizeSmall);
        PFont cnFontLarge = createFont("Microsoft YaHei", fontSizeLarge);
        int fontSizeBriefing = TdAssets.getFontSizeBriefing();
        PFont cnFontBriefing = createFont("Microsoft YaHei", 64, true);
        theme.setFont(cnFontSmall);
        theme.setBriefingFont(cnFontBriefing);
        PFont cardFont = createFont("Microsoft YaHei Bold", 64);
        if (cardFont != null) {
            TdLevelCard.setCardFont(cardFont);
        }
        TdMenuBg.setFont(cnFontSmall);
        TdMenuBg.setTitleFont(cnFontLarge);
        ui.setTheme(theme);
        TdTutorial.init(ui);

        // Load custom cursor
        PImage cursorImg = loadImage("cur/cursor_optimized.png");
        if (cursorImg != null) {
            ui.setCustomCursor(cursorImg);
            float cursorScale = engine.getSketchConfig().getFloat(SketchConfig.SECTION_UI, SketchConfig.KEY_CURSOR_SCALE, 0.65f);
            ui.setCursorScale(cursorScale);
        }

        gameScene = engine.getSceneManager().getActiveScene();
        setupCamera();

        // Connect UI to DisplayManager for design-resolution scaling
        ui.setDisplayManager(engine.getDisplayManager());

        // Layer 0: Far stars (parallax 0.08)
        GameObject bgFar = GameObject.create("world_bg_far");
        bgFar.addComponent(new WorldBgRenderer(0));
        bgFar.setRenderLayer(0);
        bgFar.setCullEnabled(false);
        gameScene.addGameObject(bgFar);

        // Layer 1: Mid nebula + stars (parallax 0.25)
        GameObject bgMid = GameObject.create("world_bg_mid");
        bgMid.addComponent(new WorldBgRenderer(1));
        bgMid.setRenderLayer(1);
        bgMid.setCullEnabled(false);
        gameScene.addGameObject(bgMid);

        // Layer 2: Near bright stars (parallax 0.45)
        GameObject bgNear = GameObject.create("world_bg_near");
        bgNear.addComponent(new WorldBgRenderer(2));
        bgNear.setRenderLayer(2);
        bgNear.setCullEnabled(false);
        gameScene.addGameObject(bgNear);

        // Layer 3: Platforms, path, base (parallax 1.0)
        GameObject bgPlat = GameObject.create("world_bg_plat");
        bgPlat.addComponent(new WorldBgRenderer(3));
        bgPlat.setRenderLayer(3);
        bgPlat.setCullEnabled(false);
        gameScene.addGameObject(bgPlat);

        // Configure parallax layer groups
        gameScene.clearLayerGroups();
        gameScene.addLayerGroup(0, 0, 0.08f, 0.08f);
        gameScene.addLayerGroup(1, 1, 0.25f, 0.25f);
        gameScene.addLayerGroup(2, 2, 0.45f, 0.45f);
        gameScene.addLayerGroup(3, 99, 1.0f, 1.0f);

        // Tutorial grid highlight renderer (layer 96) — draws above platforms, below effects
        GameObject tutorialGo = GameObject.create("tutorial_grid");
        tutorialGo.addComponent(new TutorialGridRenderer());
        tutorialGo.setRenderLayer(96);
        tutorialGo.setCullEnabled(false);
        gameScene.addGameObject(tutorialGo);

        // Visual effects renderer — tracers, explosions, lasers, slow waves (layer 95)
        GameObject fxGo = GameObject.create("effects");
        fxGo.addComponent(new EffectRenderer());
        fxGo.setRenderLayer(95);
        fxGo.setCullEnabled(false);
        gameScene.addGameObject(fxGo);

        // Enemy HP bar renderer — drawn on top of all world objects (layer 99)
        GameObject hpGo = GameObject.create("enemy_hp_bars");
        hpGo.addComponent(new EnemyHpBarRenderer());
        hpGo.setRenderLayer(99);
        hpGo.setCullEnabled(false);
        gameScene.addGameObject(hpGo);

        // Initialize bullet object pools
        bulletDataPool = engine.createPool(
            () -> new Bullet(),
            b -> { b.dead = true; b.gameObject = null; }
        );
        bulletDataPool.preload(100);

        bulletGoPool = engine.createPool(() -> {
            GameObject go = GameObject.create("Bullet");
            go.setTag("pooled_bullet");
            go.setRenderLayer(15);
            go.addComponent(new BulletRenderer());
            gameScene.addGameObject(go);
            return go;
        });
        bulletGoPool.preload(100);

        lighting = new TdLightingSystem(TowerDefenseMin2.this);

        TdAssets.loadRuinsTextures(engine.getImages());
        TdSound.initTracks(TowerDefenseMin2.this);
        // Restore persisted audio & language settings
        TdAssets.setMasterVolume(TdSaveData.getMasterVolume());
        TdAssets.setBgmVolume(TdSaveData.getBgmVolume());
        TdAssets.setSfxVolume(TdSaveData.getSfxVolume());
        engine.getI18n().setLocale(TdSaveData.getLanguage());
        engine.addOnDisposeListener(() -> TdSaveData.saveSettings());

        // Ensure p5engine.ini window position is (0,0) for fullscreen,
        // so P5Engine.init() does not position the window elsewhere before toggleFullscreen.
        if (TdSaveData.isFullscreen()) {
            try {
                String p5ini = TowerDefenseMin2.this.sketchPath("p5engine.ini");
                shenyf.p5engine.config.SketchConfig p5iniCfg = new shenyf.p5engine.config.SketchConfig(p5ini);
                p5iniCfg.setWindowPosition(0, 0);
            } catch (Exception e) {
                // p5engine.ini may not exist yet
            }
        }

        // Borderless fullscreen: delay toggleFullscreen to avoid draw-cycle deadlock.
        // NEWT setSize() does not reliably trigger Processing's windowResize() callback,
        // so we manually sync DisplayManager and Camera after the toggle.
        if (TdSaveData.isFullscreen()) {
            java.util.Timer t = new java.util.Timer();
            t.schedule(new java.util.TimerTask() {
                public void run() {
                    t.cancel();
                    if (engine.getWindowManager() == null) return;
                    engine.getWindowManager().toggleFullscreen();
                    // Give NEWT a moment to settle, then manually sync
                    java.util.Timer t2 = new java.util.Timer();
                    t2.schedule(new java.util.TimerTask() {
                        public void run() {
                            t2.cancel();
                            int w = TowerDefenseMin2.this.width;
                            int h = TowerDefenseMin2.this.height;
                            engine.getDisplayManager().onWindowResize(w, h);
                            // Camera viewport fixed to design game area; no need to resize on window change
                        }
                    }, 100);
                }
            }, 200);
        }

        // Setup intro sequence
        if (TdSaveData.isPlayIntro()) {
            IntroSequence intro = new IntroSequence();
            float introDelay = TdAssets.getIntroDelay();
            float introPostDelay = TdAssets.getIntroPostDelay();
            intro.add(new FadeTextSegment(
                new String[]{"SharpEye  Presents", "Achieved With P5Engine"},
                0.6f, 0.2f, 1.5f, 0.8f, introDelay, introPostDelay,
                0xFFFFFFFF, 0xFF000000, 72f, 0f
            ));
            intro.onComplete(() -> {
                TowerDefenseMin2.this.state = TdState.MENU;
                TdFlow.buildMainMenu(TowerDefenseMin2.this);
            });
            engine.setIntroSequence(intro);
            TowerDefenseMin2.this.state = TdState.INTRO;
            intro.start();
        } else {
            TowerDefenseMin2.this.state = TdState.MENU;
            TdFlow.buildMainMenu(TowerDefenseMin2.this);
        }
    }

    void setupCamera() {
        GameObject camGo = GameObject.create("camera");
        camera = camGo.addComponent(Camera2D.class);
        camera.setMinZoom(TdAssets.getCameraMinZoom());
        camera.setMaxZoom(TdAssets.getCameraMaxZoom());
        camera.setWorldBounds(new Rect(0, 0, TowerDefenseMin2.WORLD_W, TowerDefenseMin2.WORLD_H));
        camera.jumpCenterTo(TowerDefenseMin2.WORLD_W * 0.5f, TowerDefenseMin2.WORLD_H * 0.5f);
        // Camera viewport will be synced to actual render area in syncCameraToWindow()
        gameScene.setCamera(camera);
        gameScene.addGameObject(camGo);
    }

    void setupWorldViewport() {
        // Remove old world window from UI root if present (legacy cleanup)
        if (worldWindow != null) {
            ui.getRoot().remove(worldWindow);
            worldWindow = null;
        }

        // World viewport renders independently (not through UI tree) for layered rendering
        worldViewport = new SceneViewport("world_vp");
        worldViewport.setScene(gameScene);
        worldViewport.setCamera(camera);

        // Camera viewport already set in setupCamera() to design game area
    }

    void setupHud() {
        Panel root = ui.getRoot();
        int designW = engine.getDisplayManager().getDesignWidth();
        int designH = engine.getDisplayManager().getDesignHeight();

        hudTopBar = new TdTopBar("hud_top");
        hudTopBar.setZOrder(5);
        root.add(hudTopBar);

        hudBuildPanel = new TdBuildPanel("hud_build");
        hudBuildPanel.setZOrder(5);
        root.add(hudBuildPanel);

        hudMinimap = new TdMinimapComponent("hud_minimap");
        TdMinimapComponent.MW = TdConfig.RIGHT_W - 16;
        TdMinimapComponent.MH = TdMinimapComponent.MW * 120f / 180f;
        hudMinimap.setSize(TdMinimapComponent.MW, TdMinimapComponent.MH);
        hudMinimap.setZOrder(10);
        root.add(hudMinimap);

        // Dev mode wave info label (world viewport top-left)
        devWaveLabel = new TdLabel("dev_wave_label");
        devWaveLabel.setBounds(4, TdConfig.TOP_HUD + 4, 200, 60);
        devWaveLabel.setLabelStyle(TdLabel.Style.STATUS);
        devWaveLabel.setCustomTextSize(12);
        devWaveLabel.setTextAlign(PApplet.LEFT);
        devWaveLabel.setVisible(false);
        devWaveLabel.setZOrder(20);
        root.add(devWaveLabel);
    }
}

// ============================================
//  TdAppLoop — 主循环（static，不创建 PDE 内部类）
// ============================================
static final class TdAppLoop {

    static void run(TowerDefenseMin2 app) {
        TdSound.update();
        app.engine.update();
        float dt = app.engine.getGameTime().getDeltaTime();
        float dtReal = app.engine.getGameTime().getRealDeltaTime();
        DisplayManager dm = app.engine.getDisplayManager();

        // === Intro sequence (plays before any menu/game logic) ===
        shenyf.p5engine.intro.IntroSequence intro = app.engine.getIntroSequence();
        if (intro != null && !intro.isComplete()) {
            app.background(0);
            intro.update(dtReal);
            intro.render(app);
            // Any key press or mouse click skips the entire intro
            if (app.introSkipRequested || app.mousePressed) {
                app.introSkipRequested = false;
                intro.skipAll();
            }
            return;
        }

        // === Layer 1: Background & World (actual screen pixels, no scaling) ===
        if (app.state == TdState.PLAYING || app.state == TdState.PAUSED) {
            app.background(14, 18, 34);
        }

        InputManager im = app.engine.getInput();
        TdAppInput.handleKeyboardInput(app, im);

        // During gameplay, navigation keys control camera scroll, not UI focus
        app.ui.setGameInputActive(app.state == TdState.PLAYING);

        TdAppUtils.syncCameraToWindow(app);

        switch (app.state) {
            case PLAYING:
                TdGameWorld.update(dt);
                if (app.sellMenuPanel == null) {
                    TdCamera.updateEdgeScroll(dtReal);
                }
                break;
            case PAUSED:
                // freeze game logic
                break;
            default:
                break;
        }

        // Sell menu only exists during PLAYING state
        if (app.state != TdState.PLAYING && app.sellMenuPanel != null) {
            TdAppUtils.closeSellMenu(app);
        }

        TdAppInput.handleMouseInput(app, im);
        TowerButton.postUpdateTooltipTimer(dtReal);

        // Tutorial system update
        TdTutorial.update(dt);

        // Tower hover detection (keep highlight when sell menu is open)
        if (app.state == TdState.PLAYING && app.sellMenuPanel == null && !TdAppUtils.isMouseOverHud(app)) {
            app.hoveredTower = TdAppUtils.getTowerAtMouse(app, im);
        } else if (app.sellMenuPanel == null) {
            app.hoveredTower = null;
        }

        // World layer: render only to the game area (excluding HUD panels)
        if (app.worldViewport != null && (app.state == TdState.PLAYING || app.state == TdState.PAUSED)) {
            float scale = dm.getUniformScale();
            float gameX = 0;
            float gameY = TdConfig.TOP_HUD * scale;
            float gameW = dm.getActualWidth() - TdConfig.RIGHT_W * scale;
            float gameH = dm.getActualHeight() - gameY;
            app.worldViewport.renderDirect(app, gameX, gameY, gameW, gameH);
        }

        // Lighting overlay: render to the same game area
        if ((app.state == TdState.PLAYING || app.state == TdState.PAUSED) && app.worldViewport != null) {
            app.lighting.update(dt);
            float scale = dm.getUniformScale();
            float gameX = 0;
            float gameY = TdConfig.TOP_HUD * scale;
            float gameW = dm.getActualWidth() - TdConfig.RIGHT_W * scale;
            float gameH = dm.getActualHeight() - gameY;
            app.lighting.render(app.g, app.camera, gameX, gameY, gameW, gameH);
        }

        if (app.state == TdState.PLAYING && app.buildMode != TdBuildMode.NONE) {
            TdGhost.update();
        }

        // Menu background covers entire actual window (before FIT scaling)
        if (app.state == TdState.MENU || app.state == TdState.LEVEL_SELECT || app.state == TdState.SETTINGS || app.state == TdState.BRIEFING) {
            TdMenuBg.update(dtReal);
            TdMenuBg.draw(app);
        }

        // === Layer 2: UI & Overlays (FIT scaled design coordinates) ===
        app.pushMatrix();
        app.translate(dm.getOffsetX(), dm.getOffsetY());
        app.scale(dm.getUniformScale(), dm.getUniformScale());

        // Update dev mode wave info
        if (app.devWaveLabel != null) {
            boolean showDev = app.devMode && (app.state == TdState.PLAYING || app.state == TdState.PAUSED);
            app.devWaveLabel.setVisible(showDev);
            if (showDev && TdGameWorld.level != null && TdGameWorld.level.waves != null) {
                int totalWaves = TdGameWorld.level.waves.length;
                int cw = TdGameWorld.currentWave;
                int si = TdGameWorld.waveSpawnIndex + 1;
                int sc = TdGameWorld.waveSpawnCount;
                int totalInSpawn = 0;
                int remaining = 0;
                if (!TdGameWorld.activeSpawns.isEmpty()) {
                    TdGameWorld.ActiveSpawn first = TdGameWorld.activeSpawns.get(0);
                    totalInSpawn = first.spawn.count;
                    remaining = first.remaining;
                }
                StringBuilder sb = new StringBuilder();
                sb.append("Wave: ").append(cw).append(" / ").append(totalWaves).append("\n");
                sb.append("Spawn: ").append(si).append("  Total: ").append(totalInSpawn).append("\n");
                sb.append("Spawned: ").append(sc).append("  Remain: ").append(remaining);
                app.devWaveLabel.setText(sb.toString());
            }
        }

        app.sketchUi.updateFrame(dtReal);
        app.sketchUi.renderFrame();

        // Dev mode title (drawn in physical screen coords, above UI)
        if (app.devMode && (app.state == TdState.PLAYING || app.state == TdState.PAUSED)) {
            ScreenOverlay.begin(app.g);
            ScreenOverlay.anchoredLabel(app.g, "开发者模式 [D 切换]",
                ScreenAnchor.TOP_CENTER, 4 + (int)(TdConfig.TOP_HUD * dm.getUniformScale()),
                160, 26, 0x88FF4444, 0xFFFFFFFF, 14);
            ScreenOverlay.end(app.g);
        }

        // Sync DisplayManager if window was manually resized (windowResize callback is unreliable in P2D)
        if (app.frameCount % 30 == 0 && (app.width != dm.getActualWidth() || app.height != dm.getActualHeight())) {
            dm.onWindowResize(app.width, app.height);
        }

        if (app.sellMenuPanel != null) {
            app.sellMenuPanel.paint(app, app.ui.getTheme());
        }

        // Win/Lose text animation
        if (TdFlow.winLoseAnimator != null) {
            TdFlow.winLoseAnimator.update(dtReal);
            TdFlow.winLoseAnimator.render(app.g, dm.getDesignWidth() * 0.5f, dm.getDesignHeight() * 0.5f - 40);
            if (TdFlow.winLoseAnimator.isDone()) {
                TdFlow.winLoseAnimator = null;
            }
        }

        if (app.state == TdState.PAUSED) {
            // Only show "PAUSED" text when pause menu is NOT open (ESC menu has its own UI)
            boolean hasPauseMenu = false;
            for (UIComponent c : app.ui.getRoot().getChildren()) {
                if ("pause_overlay".equals(c.getId())) {
                    hasPauseMenu = true;
                    break;
                }
            }
            if (!hasPauseMenu) {
                TdHUD.drawPauseOverlay();
            }
        }

        if (app.state == TdState.MENU) {
            TdMenuBg.drawTitle(app, TdAssets.i18n("menu.title"));
        }

        app.popMatrix();

        // Render debug overlay
        app.engine.renderDebugOverlay();
    }
}

// ============================================
//  TdAppInput — 输入处理（static）
// ============================================
static final class TdAppInput {
    static boolean isDraggingCamera = false;
    static boolean dragConsumedClick = false;
    static float dragAnchorScreenX, dragAnchorScreenY;
    static float dragAnchorCameraX, dragAnchorCameraY;

    static void keyPressed(TowerDefenseMin2 app) {
        // ESC is a system-level shortcut: always handle pause/menu first,
        // then let the tutorial skip itself if active.
        if (app.key == PApplet.ESC) {
            app.key = 0; // Block Processing default quit behavior
            // Check if exit-save dialog is open — close it first
            boolean hasExitDialog = false;
            for (UIComponent c : app.ui.getRoot().getChildren()) {
                if ("exit_save_win".equals(c.getId())) {
                    hasExitDialog = true;
                    break;
                }
            }
            if (hasExitDialog) {
                for (UIComponent c : new java.util.ArrayList<>(app.ui.getRoot().getChildren())) {
                    if ("exit_save_win".equals(c.getId())) {
                        app.ui.getRoot().remove(c);
                    }
                }
                TdFlow.showPauseMenu(app);
            } else if (app.sellMenuPanel != null) {
                TdAppUtils.closeSellMenu(app);
                if (app.state == TdState.PLAYING) {
                    TdFlow.showPauseMenu(app);
                }
            } else if (app.state == TdState.BRIEFING) {
                TdFlow.showDifficultySelect(app, TdFlow.briefingLevelId);
            } else if (app.state == TdState.PLAYING) {
                TdFlow.showPauseMenu(app);
            } else if (app.state == TdState.PAUSED) {
                TdFlow.hidePauseMenu(app);
            } else if (app.state == TdState.SETTINGS) {
                TdFlow.buildMainMenu(app);
            } else if (app.state == TdState.LEVEL_SELECT) {
                if (TdFlow.resumeDialogLevelId != null) {
                    // In level-resume dialog → back to level select
                    TdFlow.showLevelSelect(app);
                } else if (TdFlow.difficultySelectLevelId != null) {
                    String lid = TdFlow.difficultySelectLevelId;
                    if (TdSaveLoad.hasSave(app, lid)) {
                        TdFlow.showLevelResumeDialog(app, lid);
                    } else {
                        TdFlow.showLevelSelect(app);
                    }
                } else {
                    TdFlow.buildMainMenu(app);
                }
            }
            // If tutorial is active, ESC also skips it
            if (TdTutorial.isActive()) {
                TdTutorial.onKeyPressed(app.keyCode);
            }
            return;
        }

        // Non-ESC keys: tutorial has first dibs
        if (TdTutorial.isActive()) {
            if (TdTutorial.onKeyPressed(app.keyCode)) {
                return;
            }
        }

        // Dev mode toggle: press D while debug overlay is open
        if (app.engine.getDebugOverlay().isEnabled()
                && (app.key == 'd' || app.key == 'D')) {
            app.devMode = !app.devMode;
            return;
        }

        // Time scale controls (only during gameplay)
        if (app.state == TdState.PLAYING) {
            switch (app.key) {
                case '1': app.engine.getGameTime().setTargetTimeScale(0.2f); break;
                case '2': app.engine.getGameTime().setTargetTimeScale(0.5f); break;
                case '3': app.engine.getGameTime().setTargetTimeScale(1.0f); break;
                case '4': app.engine.getGameTime().setTargetTimeScale(2.0f); break;
                case '5': app.engine.getGameTime().setTargetTimeScale(5.0f); break;
            }

            if (app.devMode) {
                float ts = app.engine.getGameTime().getTimeScale();
                float[] speeds = {0.05f, 0.1f, 0.2f, 0.5f, 1.0f, 2.0f, 5.0f, 10.0f, 20.0f};
                if (app.key == '+' || app.key == '=') {
                    for (int i = 0; i < speeds.length; i++) {
                        if (ts < speeds[i] - 0.01f) {
                            app.engine.getGameTime().setTargetTimeScale(speeds[i]);
                            break;
                        }
                    }
                } else if (app.key == '-' || app.key == '_') {
                    for (int i = speeds.length - 1; i >= 0; i--) {
                        if (ts > speeds[i] + 0.01f) {
                            app.engine.getGameTime().setTargetTimeScale(speeds[i]);
                            break;
                        }
                    }
                }
            }
        }

        // Level select keyboard navigation
        if (app.state == TdState.LEVEL_SELECT) {
            if (TdFlow.resumeDialogLevelId == null && TdFlow.difficultySelectLevelId == null) {
                if (app.keyCode == PApplet.LEFT) {
                    if (TdFlow.levelCarouselRef != null) {
                        TdFlow.levelCarouselRef.prev();
                    }
                } else if (app.keyCode == PApplet.RIGHT) {
                    if (TdFlow.levelCarouselRef != null) {
                        TdFlow.levelCarouselRef.next();
                    }
                } else if (app.keyCode == PApplet.ENTER || app.key == ' ') {
                    if (TdFlow.levelCarouselRef != null) {
                        String lid = TdFlow.levelCarouselRef.getSelectedLevelId();
                        if (lid != null && TdFlow.levelCarouselRef.isSelectedUnlocked()) {
                            if (TdSaveLoad.hasSave(app, lid)) {
                                TdFlow.showLevelResumeDialog(app, lid);
                            } else {
                                TdFlow.showDifficultySelect(app, lid);
                            }
                        }
                    }
                }
            }
        }
    }

    static void handleKeyboardInput(TowerDefenseMin2 app, InputManager im) {
        app.keyScrollUp    = im.isKeyDown(PApplet.UP);
        app.keyScrollDown  = im.isKeyDown(PApplet.DOWN);
        app.keyScrollLeft  = im.isKeyDown(PApplet.LEFT);
        app.keyScrollRight = im.isKeyDown(PApplet.RIGHT);

        boolean isP = im.isKeyDown(java.awt.event.KeyEvent.VK_P);
        if (isP && !app.wasKeyP) {
            if (app.state == TdState.PLAYING) {
                TdFlow.showPauseMenu(app);
            } else if (app.state == TdState.PAUSED) {
                TdFlow.hidePauseMenu(app);
            }
        }
        app.wasKeyP = isP;

        // Tower range toggle (F)
        boolean isF = im.isKeyDown(java.awt.event.KeyEvent.VK_F);
        if (isF && !app.wasKeyF) {
            app.showTowerRanges = !app.showTowerRanges;
        }
        app.wasKeyF = isF;

        // Space: jump camera to most dangerous enemy
        boolean isSpace = im.isKeyDown(java.awt.event.KeyEvent.VK_SPACE);
        if (isSpace && !app.wasKeySpace) {
            TdAppUtils.jumpToMostDangerousEnemy(app);
        }
        app.wasKeySpace = isSpace;

        // Dev mode: Ctrl + hover tower to instant upgrade, or Ctrl + build mode to instant place
        boolean isCtrl = im.isKeyDown(java.awt.event.KeyEvent.VK_CONTROL);
        if (isCtrl && !app.wasKeyCtrl && app.devMode && app.state == TdState.PLAYING) {
            Tower hover = TdAppUtils.getTowerAtMouse(app, im);
            if (hover != null && hover.built && hover.upgradeLevel < 2 && !hover.isUpgrading) {
                if (TdAppUtils.isUpgradeAllowed(hover)) {
                    int cost = (hover.upgradeLevel == 0) ? hover.def.upgradeCost : hover.def.upgrade2Cost;
                    TdGameWorld.money -= cost;
                    hover.isUpgrading = true;
                    hover.upgradeProgress = 0;
                }
            } else if (app.buildMode != TdBuildMode.NONE && TdGhost.isValid && !TdAppUtils.isMouseOverHud(app)) {
                TdGameWorld.tryPlaceTower(app.buildMode, TdGhost.gridX, TdGhost.gridY);
            }
        }
        app.wasKeyCtrl = isCtrl;

        // Dev mode: Alt + build mode to batch-place in 5x5 area
        boolean isAlt = im.isKeyDown(java.awt.event.KeyEvent.VK_ALT);
        if (isAlt && !app.wasKeyAlt && app.devMode && app.state == TdState.PLAYING
                && app.buildMode != TdBuildMode.NONE && TdGhost.isValid) {
            int cx = TdGhost.gridX;
            int cy = TdGhost.gridY;
            for (int dy = -2; dy <= 2; dy++) {
                for (int dx = -2; dx <= 2; dx++) {
                    int gx = cx + dx;
                    int gy = cy + dy;
                    if (TdGameWorld.canPlaceTower(gx, gy)) {
                        TdGameWorld.tryPlaceTower(app.buildMode, gx, gy);
                    }
                }
            }
        }
        app.wasKeyAlt = isAlt;

        // Build hotkeys (Q/W/E/R/T) — check money before entering build mode (skip in dev mode)
        boolean isQ = im.isKeyDown(java.awt.event.KeyEvent.VK_Q);
        if (isQ && !app.wasKeyQ && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.MG)) {
            TowerDef defQ = TdAssets.loadTowerDef(TowerType.MG);
            if (defQ != null && (app.devMode || TdGameWorld.money >= defQ.cost)) {
                app.buildMode = TdBuildMode.MG;
                TdSound.playTowerSelect();
            } else if (defQ != null) {
                app.hudBuildPanel.flashButton(TowerType.MG);
            }
        }
        app.wasKeyQ = isQ;

        boolean isW = im.isKeyDown(java.awt.event.KeyEvent.VK_W);
        if (isW && !app.wasKeyW && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.MISSILE)) {
            TowerDef defW = TdAssets.loadTowerDef(TowerType.MISSILE);
            if (defW != null && (app.devMode || TdGameWorld.money >= defW.cost)) {
                app.buildMode = TdBuildMode.MISSILE;
                TdSound.playTowerSelect();
            } else if (defW != null) {
                app.hudBuildPanel.flashButton(TowerType.MISSILE);
            }
        }
        app.wasKeyW = isW;

        boolean isE = im.isKeyDown(java.awt.event.KeyEvent.VK_E);
        if (isE && !app.wasKeyE && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.LASER)) {
            TowerDef defE = TdAssets.loadTowerDef(TowerType.LASER);
            if (defE != null && (app.devMode || TdGameWorld.money >= defE.cost)) {
                app.buildMode = TdBuildMode.LASER;
                TdSound.playTowerSelect();
            } else if (defE != null) {
                app.hudBuildPanel.flashButton(TowerType.LASER);
            }
        }
        app.wasKeyE = isE;

        boolean isR2 = im.isKeyDown(java.awt.event.KeyEvent.VK_R);
        if (isR2 && !app.wasKeyR && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.SLOW)) {
            TowerDef defR = TdAssets.loadTowerDef(TowerType.SLOW);
            if (defR != null && (app.devMode || TdGameWorld.money >= defR.cost)) {
                app.buildMode = TdBuildMode.SLOW;
                TdSound.playTowerSelect();
            } else if (defR != null) {
                app.hudBuildPanel.flashButton(TowerType.SLOW);
            }
        }
        app.wasKeyR = isR2;

        boolean isT = im.isKeyDown(java.awt.event.KeyEvent.VK_T);
        if (isT && !app.wasKeyT && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.POISON)) {
            TowerDef defT = TdAssets.loadTowerDef(TowerType.POISON);
            if (defT != null && (app.devMode || TdGameWorld.money >= defT.cost)) {
                app.buildMode = TdBuildMode.POISON;
                TdSound.playTowerSelect();
            } else if (defT != null) {
                app.hudBuildPanel.flashButton(TowerType.POISON);
            }
        }
        app.wasKeyT = isT;

        boolean isY = im.isKeyDown(java.awt.event.KeyEvent.VK_Y);
        if (isY && !app.wasKeyY && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.COMMAND)) {
            TowerDef defY = TdAssets.loadTowerDef(TowerType.COMMAND);
            if (defY != null && (app.devMode || TdGameWorld.money >= defY.cost)) {
                app.buildMode = TdBuildMode.COMMAND;
                TdSound.playTowerSelect();
            } else if (defY != null) {
                app.hudBuildPanel.flashButton(TowerType.COMMAND);
            }
        }
        app.wasKeyY = isY;

        boolean isU = im.isKeyDown(java.awt.event.KeyEvent.VK_U);
        if (isU && !app.wasKeyU && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.TESLA)) {
            TowerDef defU = TdAssets.loadTowerDef(TowerType.TESLA);
            if (defU != null && (app.devMode || TdGameWorld.money >= defU.cost)) {
                app.buildMode = TdBuildMode.TESLA;
                TdSound.playTowerSelect();
            } else if (defU != null) {
                app.hudBuildPanel.flashButton(TowerType.TESLA);
            }
        }
        app.wasKeyU = isU;

        boolean isI = im.isKeyDown(java.awt.event.KeyEvent.VK_I);
        if (isI && !app.wasKeyI && app.state == TdState.PLAYING && app.hudBuildPanel != null && TdAppUtils.isTowerAllowed(app, TdBuildMode.PIERCER)) {
            TowerDef defI = TdAssets.loadTowerDef(TowerType.PIERCER);
            if (defI != null && (app.devMode || TdGameWorld.money >= defI.cost)) {
                app.buildMode = TdBuildMode.PIERCER;
                TdSound.playTowerSelect();
            } else if (defI != null) {
                app.hudBuildPanel.flashButton(TowerType.PIERCER);
            }
        }
        app.wasKeyI = isI;
    }

    static void handleMouseInput(TowerDefenseMin2 app, InputManager im) {
        if (app.state != TdState.PLAYING || app.camera == null) return;
        handleMouseWheelZoom(app, im);
        handleMouseDragPan(app, im);
        handleMouseClick(app, im);
    }

    static void handleMouseWheelZoom(TowerDefenseMin2 app, InputManager im) {
        if (!TdCamera.isMouseInViewport()) return;
        float wheel = im.getMouseWheelDelta();
        if (wheel == 0) return;
        Vector2 focus;
        DisplayManager dm = app.engine.getDisplayManager();
        if (TdSaveData.isZoomAtMouse()) {
            // Zoom at mouse cursor (screen coordinates)
            focus = new Vector2(im.getMouseX(), im.getMouseY());
        } else {
            // Zoom centered on world viewport (screen coordinates)
            float scale = dm.getUniformScale();
            float gameX = 0;
            float gameY = TdConfig.TOP_HUD * scale;
            float gameW = dm.getActualWidth() - TdConfig.RIGHT_W * scale;
            float gameH = dm.getActualHeight() - gameY;
            float cx = gameX + gameW * 0.5f;
            float cy = gameY + gameH * 0.5f;
            focus = new Vector2(cx, cy);
        }
        app.camera.zoomAt(-wheel * 0.24f, focus);
    }

    static void handleMouseDragPan(TowerDefenseMin2 app, InputManager im) {
        if (!im.isMousePressed() || im.getMouseButton() != PApplet.LEFT) {
            isDraggingCamera = false;
            return;
        }
        if (!TdCamera.isMouseInViewport()) {
            isDraggingCamera = false;
            return;
        }

        float ddx = im.getMouseDragDX();
        float ddy = im.getMouseDragDY();

        if (!isDraggingCamera) {
            if (PApplet.abs(ddx) < 3f && PApplet.abs(ddy) < 3f) return;
            isDraggingCamera = true;
            dragConsumedClick = true;
            // Anchor at mouse position before this frame's drag delta
            dragAnchorScreenX = im.getMouseX() - ddx;
            dragAnchorScreenY = im.getMouseY() - ddy;
            Vector2 camPos = app.camera.getTransform().getPosition();
            dragAnchorCameraX = camPos.x;
            dragAnchorCameraY = camPos.y;
        }

        float mx = im.getMouseX();
        float my = im.getMouseY();
        float idealX = dragAnchorCameraX - (mx - dragAnchorScreenX) / app.camera.getZoom();
        float idealY = dragAnchorCameraY - (my - dragAnchorScreenY) / app.camera.getZoom();
        app.camera.getTransform().setPosition(idealX, idealY);
        app.camera.clampToBounds();

        // If clamping moved the camera, adjust the anchor so the mouse-to-camera
        // relationship stays correct on subsequent frames.
        Vector2 clamped = app.camera.getTransform().getPosition();
        dragAnchorCameraX = clamped.x + (mx - dragAnchorScreenX) / app.camera.getZoom();
        dragAnchorCameraY = clamped.y + (my - dragAnchorScreenY) / app.camera.getZoom();
    }

    static void handleMouseClick(TowerDefenseMin2 app, InputManager im) {
        Vector2 dm = TdAppUtils.getActualMousePos(app, im);

        // Left press: place tower or close sell menu
        if (im.isMouseJustPressed() && im.getMouseButton() == PApplet.LEFT) {
            if (app.sellMenuPanel != null) {
                Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
                UIComponent hit = app.ui.getRoot().hitTest(designMouse.x, designMouse.y);
                if (hit == null || !"sell_menu".equals(hit.getId()) && !hit.getId().startsWith("btn_")) {
                    TdAppUtils.closeSellMenu(app);
                }
            }
            if (app.buildMode != TdBuildMode.NONE && TdGhost.isValid && !TdAppUtils.isMouseOverHud(app)) {
                TdGameWorld.tryPlaceTower(app.buildMode, TdGhost.gridX, TdGhost.gridY);
                if (!app.devMode) {
                    app.buildMode = TdBuildMode.NONE;
                    TdGhost.cleanup(app);
                }
            }
        }

        // Left release: open sell menu if no drag occurred
        if (im.isMouseJustReleased() && im.getMouseButton() == PApplet.LEFT) {
            if (!dragConsumedClick && app.buildMode == TdBuildMode.NONE && app.sellMenuPanel == null && !TdAppUtils.isMouseOverHud(app)) {
                Tower clicked = TdAppUtils.getTowerAtMouse(app, im);
                if (clicked != null && clicked.built) {
                    TdAppUtils.showSellMenu(app, clicked);
                }
            }
            dragConsumedClick = false;
        }

        // Right press: cancel build mode
        if (im.isMouseJustPressed() && im.getMouseButton() == PApplet.RIGHT) {
            if (app.buildMode != TdBuildMode.NONE) {
                app.buildMode = TdBuildMode.NONE;
                TdGhost.cleanup(app);
            }
        }

        // Right release: open/close sell menu
        if (im.isMouseJustReleased() && im.getMouseButton() == PApplet.RIGHT) {
            if (!dragConsumedClick && app.buildMode == TdBuildMode.NONE && !TdAppUtils.isMouseOverHud(app)) {
                Tower clicked = TdAppUtils.getTowerAtMouse(app, im);
                if (clicked != null && clicked.built) {
                    TdAppUtils.showSellMenu(app, clicked);
                } else {
                    TdAppUtils.closeSellMenu(app);
                }
            }
            dragConsumedClick = false;
        }
    }
}

// ============================================
//  TdAppUtils — 工具函数（static）
// ============================================
static final class TdAppUtils {

    static void jumpToMostDangerousEnemy(TowerDefenseMin2 app) {
        Enemy best = null;
        float bestScore = Float.MAX_VALUE;
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp <= 0) continue;
            float score = Tower.getThreatScore(e);
            if (score < bestScore) {
                bestScore = score;
                best = e;
            }
        }
        if (best != null) {
            app.camera.jumpCenterTo(best.pos.x, best.pos.y);
        }
    }

    static boolean isTowerAllowed(TowerDefenseMin2 app, TdBuildMode mode) {
        if (TdGameWorld.level == null || TdGameWorld.level.allowedTowers == null) return true;
        TowerType tt = TowerType.fromBuildMode(mode);
        for (TowerType a : TdGameWorld.level.allowedTowers) {
            if (a == tt) return true;
        }
        return false;
    }

    static boolean isUpgradeAllowed(Tower tower) {
        if (TdGameWorld.level == null || TdGameWorld.level.allowedUpgrades == null) return true;
        for (TowerType a : TdGameWorld.level.allowedUpgrades) {
            if (a == tower.def.type) return true;
        }
        return false;
    }

    static Tower getTowerAtMouse(TowerDefenseMin2 app, InputManager im) {
        if (app.camera == null) return null;
        Vector2 dm = getActualMousePos(app, im);
        Vector2 world = app.camera.screenToWorld(dm);
        int gx = Math.round(world.x / TdConfig.GRID - 0.5f);
        int gy = Math.round(world.y / TdConfig.GRID - 0.5f);
        for (Tower t : TdGameWorld.towers) {
            if (t.gridX == gx && t.gridY == gy) return t;
        }
        return null;
    }

    static void closeSellMenu(TowerDefenseMin2 app) {
        if (app.sellMenuPanel != null) {
            Panel panel = app.sellMenuPanel;
            app.sellMenuPanel = null; // clear early to avoid re-trigger during animation

            var tm = app.engine.getTweenManager();
            if (tm != null) {
                tm.toAlpha(panel, 0f, 0.1f)
                  .ease(shenyf.p5engine.tween.Ease::outQuad)
                  .onComplete(() -> {
                      Panel root = app.ui.getRoot();
                      root.remove(panel);
                  })
                  .start();
            } else {
                Panel root = app.ui.getRoot();
                root.remove(panel);
            }
        }
    }

    static void showSellMenu(TowerDefenseMin2 app, Tower tower) {
        closeSellMenu(app);
        Panel root = app.ui.getRoot();
        app.sellMenuPanel = new Panel("sell_menu");
        // Use UiCoords to convert mouse position to UI-framework correct coordinates
        Vector2 uiPos = UiCoords.fromMouse(app.engine.getDisplayManager(), app.mouseX, app.mouseY);
        app.sellMenuPanel.setBounds((int)uiPos.x, (int)uiPos.y, 100, 120);
        app.sellMenuPanel.setZOrder(999);
        app.sellMenuPanel.setPaintBackground(true);
        app.sellMenuPanel.setAlpha(0);
        app.sellMenuPanel.appear(0f, 6f, 0.15f);

        // Tooltip panel for upgrade details (child of sell_menu so it auto-removes with menu)
        Panel tooltip = new Panel("upgrade_tooltip") {
            @Override
            protected void paintSelf(PApplet applet, Theme theme) {
                float a = getEffectiveAlpha();
                int bg = 0xE01A2035;
                int r = (bg >> 16) & 0xFF;
                int g = (bg >> 8) & 0xFF;
                int b = bg & 0xFF;
                int alpha = (int)(((bg >> 24) & 0xFF) * a);
                applet.noStroke();
                applet.fill(r, g, b, alpha);
                applet.rect(getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight());
                applet.stroke(0xFF555555, (int)(255 * a));
                applet.strokeWeight(1);
                applet.noFill();
                applet.rect(getAbsoluteX() + 0.5f, getAbsoluteY() + 0.5f, getWidth() - 1, getHeight() - 1);
            }
        };
        tooltip.setBounds(0, 0, 160, 80);
        tooltip.setPaintBackground(true);
        tooltip.setVisible(false);
        tooltip.setZOrder(1000);
        app.sellMenuPanel.add(tooltip);

        TdUpgradeLabel lblTooltip = new TdUpgradeLabel("upgrade_tooltip_text");
        lblTooltip.setBounds(6, 4, 148, 72);
        lblTooltip.setTextColor(0xFFE0E6F0);
        lblTooltip.setWrapWidth(148);
        lblTooltip.setTextAlign(PApplet.LEFT);
        tooltip.add(lblTooltip);

        UpgradeButton btnUpgrade = new UpgradeButton("btn_upgrade", tower, app, tooltip);
        btnUpgrade.setBounds(4, 4, 92, 28);
        app.sellMenuPanel.add(btnUpgrade);

        Button btnSell = new Button("btn_sell");
        btnSell.setLabel(TdAssets.i18n("ui.sell"));
        btnSell.setBounds(4, 36, 92, 28);
        btnSell.setSfxPath(TdSound.SFX_CLICK);
        btnSell.setAction(() -> {
            TdGameWorld.sellTower(tower.gridX, tower.gridY);
            closeSellMenu(app);
        });
        app.sellMenuPanel.add(btnSell);

        Button btnCancel = new Button("btn_cancel_sell");
        btnCancel.setLabel(TdAssets.i18n("ui.cancel"));
        btnCancel.setBounds(4, 68, 92, 28);
        btnCancel.setSfxPath(TdSound.SFX_CLICK);
        btnCancel.setAction(() -> closeSellMenu(app));
        app.sellMenuPanel.add(btnCancel);

        root.add(app.sellMenuPanel);
    }

    static Vector2 getActualMousePos(TowerDefenseMin2 app, InputManager im) {
        return new Vector2((int)im.getMouseX(), (int)im.getMouseY());
    }

    /**
     * Upgrade button that dynamically enables/disables itself based on
     * money, upgrade permission, and tower upgrade state.
     * Only performs UI updates when its state actually changes.
     */
    static class UpgradeButton extends Button {
        Tower tower;
        int lastState = -1; // 0=maxLevel/upgrading, 1=notAllowed, 2=noMoney, 3=lv1Available, 4=lv2Available
        Panel tooltip;
        TowerDefenseMin2 appRef;

        UpgradeButton(String id, Tower tower, TowerDefenseMin2 app, Panel tooltip) {
            super(id);
            this.tower = tower;
            this.appRef = app;
            this.tooltip = tooltip;
            setSfxPath(TdSound.SFX_CLICK);
        }

        @Override
        public void update(PApplet applet, float dt) {
            super.update(applet, dt);
            if (tower == null || tower.def == null) return;

            int cost = (tower.upgradeLevel == 0) ? tower.def.upgradeCost : tower.def.upgrade2Cost;
            int state;
            if (tower.upgradeLevel >= 2 || tower.isUpgrading) state = 0;
            else if (!TdAppUtils.isUpgradeAllowed(tower)) state = 1;
            else if (TdGameWorld.money < cost) state = 2;
            else if (tower.upgradeLevel == 0) state = 3;
            else state = 4;

            if (state == lastState) {
                updateTooltip(state);
                return;
            }
            lastState = state;

            switch (state) {
                case 0:
                    setLabel(TdAssets.i18n("tower.upgraded"));
                    setEnabled(false);
                    setAction(null);
                    break;
                case 1:
                    setLabel(TdAssets.i18n("tower.upgrade.disabled"));
                    setEnabled(false);
                    setAction(null);
                    break;
                case 2:
                    setLabel(TdAssets.i18n("tower.upgrade") + " ($" + cost + ")");
                    setEnabled(false);
                    setAction(null);
                    break;
                case 3:
                    setLabel(TdAssets.i18n("tower.upgrade") + " ($" + cost + ")");
                    setEnabled(true);
                    setAction(() -> {
                        TdGameWorld.money -= cost;
                        tower.isUpgrading = true;
                        tower.upgradeProgress = 0;
                        TowerDefenseMin2 app = TowerDefenseMin2.inst;
                        if (app != null) TdAppUtils.closeSellMenu(app);
                    });
                    break;
                case 4:
                    setLabel(TdAssets.i18n("tower.upgrade") + " II ($" + cost + ")");
                    setEnabled(true);
                    setAction(() -> {
                        TdGameWorld.money -= cost;
                        tower.isUpgrading = true;
                        tower.upgradeProgress = 0;
                        TowerDefenseMin2 app = TowerDefenseMin2.inst;
                        if (app != null) TdAppUtils.closeSellMenu(app);
                    });
                    break;
            }

            updateTooltip(state);
        }

        void updateTooltip(int state) {
            if (tooltip == null) return;
            if (!hover || (state != 3 && state != 4)) {
                tooltip.setVisible(false);
                return;
            }

            TowerDef def = tower.def;
            StringBuilder sb = new StringBuilder();
            sb.append(TdAssets.i18n(def.nameKey)).append("\n");
            if (tower.upgradeLevel == 0) {
                sb.append(TdAssets.i18n("tower.upgrade")).append(" I\n");
                if (def.upgradeDamageMult > 1f)
                    sb.append("伤害 +").append(Math.round((def.upgradeDamageMult - 1f) * 100f)).append("%\n");
                if (def.upgradeRangeMult > 1f)
                    sb.append("射程 +").append(Math.round((def.upgradeRangeMult - 1f) * 100f)).append("%\n");
                if (def.upgradeSpeedMult < 1f)
                    sb.append("攻速 +").append(Math.round((1f / def.upgradeSpeedMult - 1f) * 100f)).append("%\n");
                if (def.upgradeAoeMult > 1f)
                    sb.append("范围 +").append(Math.round((def.upgradeAoeMult - 1f) * 100f)).append("%\n");
                if (def.upgradeBulletSizeMult > 1f)
                    sb.append("弹体 +").append(Math.round((def.upgradeBulletSizeMult - 1f) * 100f)).append("%\n");
                if (def.upgradeSlowMult < 1f)
                    sb.append("减速 +").append(Math.round((1f / def.upgradeSlowMult - 1f) * 100f)).append("%\n");
                if (def.upgradePoisonMult > 1f)
                    sb.append("毒素 +").append(Math.round((def.upgradePoisonMult - 1f) * 100f)).append("%\n");
                if (def.upgradeCommandMult > 1f)
                    sb.append("指挥 +").append(Math.round((def.upgradeCommandMult - 1f) * 100f)).append("%\n");
                if (def.type == TowerType.COMMAND) {
                    sb.append("攻击力 x").append(String.format("%.1f", def.upgradeCommandMult)).append("\n");
                    int bmin = def.commandKillBonusMin[1];
                    int bmax = def.commandKillBonusMax[1];
                    if (bmax > 0) sb.append("击杀奖金 ").append(bmin).append("~").append(bmax).append("金币");
                }
                if (def.type == TowerType.TESLA) {
                    sb.append("弹射次数 ").append(def.chainCount).append("→").append(def.upgradeChainCount).append("\n");
                    sb.append("衰减 ").append(Math.round(def.chainDecay * 100f)).append("%→").append(Math.round(def.upgradeChainDecay * 100f)).append("%");
                }
                if (def.type == TowerType.PIERCER) {
                    sb.append("伤害 ").append(def.damage).append("→").append(Math.round(def.damage * def.upgradeDamageMult)).append("\n");
                    sb.append("攻速 ").append(String.format("%.1f", def.firePeriod)).append("s");
                }
                if (def.type == TowerType.POISON) {
                    float effDps = def.poisonDamage * ((tower.upgradeLevel >= 1) ? def.upgradePoisonMult : 1f);
                    sb.append("毒素 ").append(Math.round(effDps)).append("/秒，").append(Math.round(def.poisonDuration)).append("秒");
                }
            } else if (tower.upgradeLevel == 1) {
                sb.append(TdAssets.i18n("tower.upgrade")).append(" II\n");
                switch (def.type) {
                    case MG:
                        sb.append("伤害 +100%\n");
                        sb.append("双发连射");
                        break;
                    case MISSILE:
                        sb.append("伤害再+20%\n");
                        sb.append("附加燃烧（").append(Math.round(def.burnDamage)).append("/秒，").append(Math.round(def.burnDuration)).append("秒）");
                        break;
                    case LASER:
                        sb.append("伤害 +60%");
                        break;
                    case SLOW:
                        sb.append("减速持续 +50%");
                        break;
                    case POISON:
                        float effDps2 = def.poisonDamage * def.upgradePoisonMult * 1.3f;
                        sb.append("毒素再+30%（").append(Math.round(effDps2)).append("/秒，").append(Math.round(def.poisonDuration)).append("秒）\n");
                        sb.append("角度 +50%");
                        break;
                    case COMMAND:
                        sb.append("攻击力 x").append(String.format("%.1f", def.upgrade2CommandMult)).append("\n");
                        int bmin2 = def.commandKillBonusMin[2];
                        int bmax2 = def.commandKillBonusMax[2];
                        if (bmax2 > 0) sb.append("击杀奖金 ").append(bmin2).append("~").append(bmax2).append("金币");
                        break;
                    case TESLA:
                        sb.append("弹射次数 ").append(def.upgradeChainCount).append("→").append(def.upgrade2ChainCount).append("\n");
                        sb.append("衰减 ").append(Math.round(def.upgradeChainDecay * 100f)).append("%→").append(Math.round(def.upgrade2ChainDecay * 100f)).append("%");
                        break;
                    case PIERCER:
                        sb.append("伤害 ").append(Math.round(def.damage * def.upgradeDamageMult)).append("\n");
                        sb.append("攻速 +30%");
                        break;
                }
            }

            Label lbl = (Label) tooltip.getChildren().get(0);
            lbl.setText(sb.toString());

            int lines = 1;
            for (int i = 0; i < sb.length(); i++) {
                if (sb.charAt(i) == '\n') lines++;
            }
            float lineH = 13f;
            float th = Math.max(40f, lines * lineH + 10f);
            tooltip.setBounds(tooltip.getX(), tooltip.getY(), 160f, th);
            lbl.setBounds(6, 4, 148, th - 8f);

            if (appRef != null) {
                DisplayManager dm = appRef.engine.getDisplayManager();
                float worldRight = dm.getActualWidth() / dm.getUniformScale() - TdConfig.RIGHT_W;
                float menuRight = getAbsoluteX() + getWidth();
                if (menuRight + 160f + 4f > worldRight) {
                    tooltip.setPosition(-164f, 0);
                } else {
                    tooltip.setPosition(getWidth() + 4f, 0);
                }
            }

            tooltip.setVisible(true);
        }
    }

    static boolean isMouseOverHud(TowerDefenseMin2 app) {
        if (app.ui == null) return false;
        Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        UIComponent hit = app.ui.getRoot().hitTest(designMouse.x, designMouse.y);
        if (hit == null) return false;
        String id = hit.getId();
        return !id.equals("ui_root");
    }

    static void syncCameraToWindow(TowerDefenseMin2 app) {
        if (app.camera == null) return;
        DisplayManager dm = app.engine.getDisplayManager();
        float scale = dm.getUniformScale();
        float gameX = 0;
        float gameY = TdConfig.TOP_HUD * scale;
        float gameW = dm.getActualWidth() - TdConfig.RIGHT_W * scale;
        float gameH = dm.getActualHeight() - gameY;
        app.camera.setViewportSize(gameW, gameH);
        app.camera.setViewportOffset(gameX, gameY);
    }
}
