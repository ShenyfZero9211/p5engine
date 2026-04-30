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
        sketchUi = new SketchUiCoordinator(TowerDefenseMin2.this, ui);
        TdTheme theme = new TdTheme();
        PFont cnFont = createFont("Microsoft YaHei", 48);
        theme.setFont(cnFont);
        TdMenuBg.setFont(cnFont);
        ui.setTheme(theme);

        gameScene = engine.getSceneManager().getActiveScene();
        setupCamera();

        // Connect UI to DisplayManager for design-resolution scaling
        ui.setDisplayManager(engine.getDisplayManager());

        // World background renderer (grid, path, base, exit) — lives in Scene
        GameObject bgGo = GameObject.create("world_bg");
        WorldBgRenderer bgR = new WorldBgRenderer();
        bgGo.addComponent(bgR);
        bgGo.setRenderLayer(0);
        bgGo.setCullEnabled(false);
        gameScene.addGameObject(bgGo);

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

        TdAssets.loadAll(TowerDefenseMin2.this);
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

        TdFlow.buildMainMenu(TowerDefenseMin2.this);
    }

    void setupCamera() {
        GameObject camGo = GameObject.create("camera");
        camera = camGo.addComponent(Camera2D.class);
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

        // === Layer 1: Background & World (actual screen pixels, no scaling) ===
        if (app.state == TdState.PLAYING || app.state == TdState.PAUSED) {
            app.background(14, 18, 34);
        }

        InputManager im = app.engine.getInput();
        TdAppInput.handleKeyboardInput(app, im);

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

        TdAppInput.handleMouseInput(app, im);

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
        if (app.state == TdState.MENU || app.state == TdState.LEVEL_SELECT || app.state == TdState.SETTINGS) {
            TdMenuBg.update(dtReal);
            TdMenuBg.draw(app);
        }

        // === Layer 2: UI & Overlays (FIT scaled design coordinates) ===
        app.pushMatrix();
        app.translate(dm.getOffsetX(), dm.getOffsetY());
        app.scale(dm.getUniformScale(), dm.getUniformScale());

        app.sketchUi.updateFrame(dtReal);
        app.sketchUi.renderFrame();

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

    static void keyPressed(TowerDefenseMin2 app) {
        if (app.key == PApplet.ESC) {
            app.key = 0; // Block Processing default quit behavior
            if (app.state == TdState.PLAYING) {
                TdFlow.showPauseMenu(app);
            } else if (app.state == TdState.PAUSED) {
                TdFlow.hidePauseMenu(app);
            }
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

        // Tower range toggle (T)
        boolean isT = im.isKeyDown(java.awt.event.KeyEvent.VK_T);
        if (isT && !app.wasKeyT) {
            app.showTowerRanges = !app.showTowerRanges;
        }
        app.wasKeyT = isT;

        // Space: jump camera to most dangerous enemy
        boolean isSpace = im.isKeyDown(java.awt.event.KeyEvent.VK_SPACE);
        if (isSpace && !app.wasKeySpace) {
            TdAppUtils.jumpToMostDangerousEnemy(app);
        }
        app.wasKeySpace = isSpace;

        // Build hotkeys (Q/W/E/R) — check money before entering build mode
        boolean isQ = im.isKeyDown(java.awt.event.KeyEvent.VK_Q);
        if (isQ && !app.wasKeyQ && TdAppUtils.isTowerAllowed(app, TdBuildMode.MG)) {
            TowerDef defQ = TdAssets.loadTowerDef(TowerType.MG);
            if (defQ != null && TdGameWorld.money >= defQ.cost) {
                app.buildMode = TdBuildMode.MG;
            } else if (defQ != null) {
                app.hudBuildPanel.flashButton(TowerType.MG);
            }
        }
        app.wasKeyQ = isQ;

        boolean isW = im.isKeyDown(java.awt.event.KeyEvent.VK_W);
        if (isW && !app.wasKeyW && TdAppUtils.isTowerAllowed(app, TdBuildMode.MISSILE)) {
            TowerDef defW = TdAssets.loadTowerDef(TowerType.MISSILE);
            if (defW != null && TdGameWorld.money >= defW.cost) {
                app.buildMode = TdBuildMode.MISSILE;
            } else if (defW != null) {
                app.hudBuildPanel.flashButton(TowerType.MISSILE);
            }
        }
        app.wasKeyW = isW;

        boolean isE = im.isKeyDown(java.awt.event.KeyEvent.VK_E);
        if (isE && !app.wasKeyE && TdAppUtils.isTowerAllowed(app, TdBuildMode.LASER)) {
            TowerDef defE = TdAssets.loadTowerDef(TowerType.LASER);
            if (defE != null && TdGameWorld.money >= defE.cost) {
                app.buildMode = TdBuildMode.LASER;
            } else if (defE != null) {
                app.hudBuildPanel.flashButton(TowerType.LASER);
            }
        }
        app.wasKeyE = isE;

        boolean isR2 = im.isKeyDown(java.awt.event.KeyEvent.VK_R);
        if (isR2 && !app.wasKeyR && TdAppUtils.isTowerAllowed(app, TdBuildMode.SLOW)) {
            TowerDef defR = TdAssets.loadTowerDef(TowerType.SLOW);
            if (defR != null && TdGameWorld.money >= defR.cost) {
                app.buildMode = TdBuildMode.SLOW;
            } else if (defR != null) {
                app.hudBuildPanel.flashButton(TowerType.SLOW);
            }
        }
        app.wasKeyR = isR2;
    }

    static void handleMouseInput(TowerDefenseMin2 app, InputManager im) {
        if (app.state != TdState.PLAYING || app.camera == null) return;
        handleMouseWheelZoom(app, im);
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
        if (!im.isMousePressed() || im.getMouseButton() != PApplet.LEFT) return;
        if (!TdCamera.isMouseInViewport()) return;
        float ddx = im.getMouseDragDX();
        float ddy = im.getMouseDragDY();
        if (ddx != 0 || ddy != 0) {
            app.camera.getTransform().translate(-ddx / app.camera.getZoom(), -ddy / app.camera.getZoom());
            app.camera.clampToBounds();
        }
    }

    static void handleMouseClick(TowerDefenseMin2 app, InputManager im) {
        Vector2 dm = TdAppUtils.getActualMousePos(app, im);

        // Place tower on world viewport click
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
                app.buildMode = TdBuildMode.NONE;
                TdGhost.cleanup(app);
            }
        }

        // Right-click: cancel build or show sell menu
        if (im.isMouseJustPressed() && im.getMouseButton() == PApplet.RIGHT) {
            if (app.buildMode != TdBuildMode.NONE) {
                app.buildMode = TdBuildMode.NONE;
                TdGhost.cleanup(app);
            } else if (!TdAppUtils.isMouseOverHud(app)) {
                Tower clicked = TdAppUtils.getTowerAtMouse(app, im);
                if (clicked != null) {
                    TdAppUtils.showSellMenu(app, clicked);
                } else {
                    TdAppUtils.closeSellMenu(app);
                }
            }
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
            Panel root = app.ui.getRoot();
            root.remove(app.sellMenuPanel);
            app.sellMenuPanel = null;
        }
    }

    static void showSellMenu(TowerDefenseMin2 app, Tower tower) {
        closeSellMenu(app);
        Panel root = app.ui.getRoot();
        app.sellMenuPanel = new Panel("sell_menu");
        // Convert screen mouse to design coordinates for UI placement
        Vector2 designMouse = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        app.sellMenuPanel.setBounds((int)designMouse.x, (int)designMouse.y, 100, 80);
        app.sellMenuPanel.setZOrder(999);
        app.sellMenuPanel.setPaintBackground(true);

        Button btnSell = new Button("btn_sell");
        btnSell.setLabel("出售");
        btnSell.setBounds(4, 4, 92, 32);
        btnSell.setAction(() -> {
            TdGameWorld.sellTower(tower.gridX, tower.gridY);
            closeSellMenu(app);
        });
        app.sellMenuPanel.add(btnSell);

        Button btnCancel = new Button("btn_cancel_sell");
        btnCancel.setLabel("取消");
        btnCancel.setBounds(4, 42, 92, 32);
        btnCancel.setAction(() -> closeSellMenu(app));
        app.sellMenuPanel.add(btnCancel);

        root.add(app.sellMenuPanel);
    }

    static Vector2 getActualMousePos(TowerDefenseMin2 app, InputManager im) {
        return new Vector2((int)im.getMouseX(), (int)im.getMouseY());
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
