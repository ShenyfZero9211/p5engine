/**
 * HUD UI components using p5engine UI library.
 * Replaces hand-drawn TdHUD and TdMinimap.
 */

// ─── Tower Button ───

static class TowerButton extends Button {
    TowerType towerType;
    String initial;
    String hotkey;
    float flashTimer = 0;
    static final float FLASH_DURATION = 0.6f;

    TowerButton(String id, TowerType type, String initial, String hotkey) {
        super(id);
        this.towerType = type;
        this.initial = initial;
        this.hotkey = hotkey;
        setSize(TdConfig.RIGHT_W - 16, 56);
    }

    void flash() {
        flashTimer = FLASH_DURATION;
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        TowerDef def = TdAssets.loadTowerDef(towerType);
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        boolean selected = (app.buildMode == TowerType.toBuildMode(towerType));

        float scale = (pressedVisual || selected) ? 0.94f : 1.0f;
        float cx = getAbsoluteX() + getWidth() * 0.5f;
        float cy = getAbsoluteY() + getHeight() * 0.5f;

        applet.pushMatrix();
        applet.translate(cx, cy);
        applet.scale(scale);
        applet.translate(-cx, -cy);

        int fill = selected ? TdTheme.BTN_PRESS : (hover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG);
        applet.noStroke();
        applet.fill(fill);
        applet.rect(getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight());

        applet.stroke(selected ? TdTheme.ACCENT : TdTheme.BORDER);
        applet.strokeWeight(selected ? 2 : 1);
        applet.noFill();
        applet.rect(getAbsoluteX() + 0.5f, getAbsoluteY() + 0.5f, getWidth() - 1, getHeight() - 1);

        // Icon — tower shape preview
        float iconSize = 32;
        float iconX = getAbsoluteX() + 8;
        float iconY = getAbsoluteY() + (getHeight() - iconSize) * 0.5f;
        applet.noStroke();
        if (def != null) {
            float icx = iconX + iconSize * 0.5f;
            float icy = iconY + iconSize * 0.5f;
            float isize = iconSize * 0.85f;
            float ihalf = isize * 0.5f;
            applet.fill(def.iconColor);
            switch (towerType) {
                case MG:
                    applet.rect(icx - ihalf, icy - ihalf, isize, isize, 3);
                    applet.fill(0xFFFFFFFF, 120);
                    applet.rect(icx - ihalf + 4, icy - ihalf + 4, isize - 8, 4, 1);
                    break;
                case MISSILE:
                    applet.ellipse(icx, icy, isize, isize);
                    applet.fill(0xFFFFFFFF, 120);
                    applet.ellipse(icx, icy, isize * 0.4f, isize * 0.4f);
                    break;
                case LASER: {
                    float lsize = isize * 0.75f;
                    float lhalf = lsize * 0.5f;
                    applet.pushMatrix();
                    applet.translate(icx, icy);
                    applet.rotate(PApplet.PI / 4);
                    applet.rect(-lhalf, -lhalf, lsize, lsize, 3);
                    applet.popMatrix();
                    applet.fill(0xFFFFFFFF, 120);
                    applet.ellipse(icx, icy, lsize * 0.3f, lsize * 0.3f);
                    break;
                }
                case SLOW:
                    drawTowerIconHexagon(applet, icx, icy, ihalf * 0.9f);
                    applet.fill(0xFFFFFFFF, 120);
                    applet.ellipse(icx, icy, isize * 0.35f, isize * 0.35f);
                    break;
            }
        } else {
            applet.fill(TdConfig.C_ACCENT);
            applet.rect(iconX, iconY, iconSize, iconSize);
            applet.fill(TdTheme.BG_DARK);
            applet.textAlign(PApplet.CENTER, PApplet.CENTER);
            applet.textSize(14);
            applet.text(initial, iconX + iconSize * 0.5f, iconY + iconSize * 0.5f);
        }

        // Name and cost
        if (def != null) {
            applet.fill(TdTheme.TEXT);
            applet.textAlign(PApplet.LEFT, PApplet.CENTER);
            applet.textSize(13);
            String name = TdAssets.i18n(def.nameKey);
            float nameX = iconX + iconSize + 10;
            float nameY = getAbsoluteY() + getHeight() * 0.35f;
            applet.text(name, nameX, nameY);
            // Hotkey hint next to name
            if (hotkey != null && !hotkey.isEmpty()) {
                float nameW = applet.textWidth(name);
                applet.textSize(10);
                applet.fill(TdTheme.TEXT_DIM);
                applet.text("[" + hotkey + "]", nameX + nameW + 6, nameY);
            }
            applet.fill(TdTheme.TEXT_DIM);
            applet.textSize(11);
            applet.text("$" + def.cost, iconX + iconSize + 10, getAbsoluteY() + getHeight() * 0.7f);
        }

        // Affordability overlay: dim when money is insufficient
        boolean canAfford = (def != null && TdGameWorld.money >= def.cost);
        if (!canAfford) {
            float dimAlpha = 100;
            if (flashTimer > 0) {
                float t = flashTimer / FLASH_DURATION;
                float pulse = (PApplet.sin(flashTimer * 20) + 1) * 0.5f;
                dimAlpha = 80 + pulse * 120 * t;
            }
            applet.noStroke();
            applet.fill(40, 42, 50, dimAlpha);
            applet.rect(getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight());
        }

        applet.popMatrix();
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        if (flashTimer > 0) {
            flashTimer -= dt;
            if (flashTimer < 0) flashTimer = 0;
        }
    }

    private void drawTowerIconHexagon(PApplet g, float cx, float cy, float r) {
        g.beginShape();
        for (int i = 0; i < 6; i++) {
            float a = PApplet.TWO_PI / 6 * i - PApplet.PI / 2;
            g.vertex(cx + PApplet.cos(a) * r, cy + PApplet.sin(a) * r);
        }
        g.endShape(PApplet.CLOSE);
    }
}

// ─── Minimap Component ───

static class TdMinimapComponent extends UIComponent {
    static float MW = 180, MH = 120;

    TdMinimapComponent(String id) {
        super(id);
        setSize(MW, MH);
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        // Position minimap at the bottom of the build panel with a margin
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.hudBuildPanel != null) {
            float panelBottom = app.hudBuildPanel.getY() + app.hudBuildPanel.getHeight();
            setPosition(app.hudBuildPanel.getX() + 8, panelBottom - MH - 8);
        }
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        float mx = getAbsoluteX();
        float my = getAbsoluteY();

        applet.pushStyle();
        applet.noStroke();
        applet.fill(TdTheme.BG_DARK);
        applet.rect(mx, my, MW, MH);
        applet.stroke(TdTheme.BORDER);
        applet.strokeWeight(1);
        applet.noFill();
        applet.rect(mx + 0.5f, my + 0.5f, MW - 1, MH - 1);

        if (TdGameWorld.level != null) {
            float sx = MW / TdGameWorld.level.worldW;
            float sy = MH / TdGameWorld.level.worldH;

            // Base
            applet.fill(0xFF4A9EFF);
            applet.ellipse(mx + TdGameWorld.level.basePos.x * sx, my + TdGameWorld.level.basePos.y * sy, 6, 6);
            // Spawns
            applet.fill(0xFFFF8C42);
            if (TdGameWorld.level.spawnPos != null) {
                applet.ellipse(mx + TdGameWorld.level.spawnPos.x * sx, my + TdGameWorld.level.spawnPos.y * sy, 5, 5);
            }
            // Exits
            applet.fill(0xFFFF4444);
            if (TdGameWorld.level.exitPos != null) {
                applet.ellipse(mx + TdGameWorld.level.exitPos.x * sx, my + TdGameWorld.level.exitPos.y * sy, 6, 6);
            }
            // Multi-path spawns and exits
            if (TdGameWorld.level.paths != null) {
                for (PathRoute pr : TdGameWorld.level.paths) {
                    if (pr.path == null || pr.path.points == null || pr.path.points.length < 2) continue;
                    Vector2 start = pr.path.points[0];
                    Vector2 end = pr.path.points[pr.path.points.length - 1];
                    // Spawn
                    boolean spawnDistinct = (TdGameWorld.level.spawnPos == null) || start.distance(TdGameWorld.level.spawnPos) > 10f;
                    if (spawnDistinct) {
                        applet.fill(0xFFFF8C42);
                        applet.ellipse(mx + start.x * sx, my + start.y * sy, 5, 5);
                    }
                    // Exit
                    boolean isBase = (TdGameWorld.level.basePos != null) && end.distance(TdGameWorld.level.basePos) <= 10f;
                    boolean isGlobalExit = (TdGameWorld.level.exitPos != null) && end.distance(TdGameWorld.level.exitPos) <= 10f;
                    if (!isBase && !isGlobalExit) {
                        applet.fill(0xFFFF4444);
                        applet.ellipse(mx + end.x * sx, my + end.y * sy, 6, 6);
                    }
                }
            }
            // Path — draw all routes (multi-path) or legacy pathPoints
            applet.stroke(0xFF4A9EFF);
            applet.strokeWeight(1);
            if (TdGameWorld.level.paths != null && TdGameWorld.level.paths.length > 0) {
                for (PathRoute pr : TdGameWorld.level.paths) {
                    if (pr.path == null || pr.path.points == null || pr.path.points.length < 2) continue;
                    Vector2[] pts = pr.path.points;
                    for (int i = 1; i < pts.length; i++) {
                        applet.line(mx + pts[i-1].x * sx, my + pts[i-1].y * sy,
                                    mx + pts[i].x * sx, my + pts[i].y * sy);
                    }
                }
            } else if (TdGameWorld.level.pathPoints != null) {
                Vector2[] pts = TdGameWorld.level.pathPoints;
                for (int i = 1; i < pts.length; i++) {
                    applet.line(mx + pts[i-1].x * sx, my + pts[i-1].y * sy,
                                mx + pts[i].x * sx, my + pts[i].y * sy);
                }
            }
            // Towers
            applet.noStroke();
            applet.fill(0xFF66FF66);
            for (Tower t : TdGameWorld.towers) {
                applet.rect(mx + t.worldX * sx - 1.5f, my + t.worldY * sy - 1.5f, 3, 3);
            }
            // Orbs
            applet.noStroke();
            applet.fill(0xFFFFD700);
            for (Orb o : TdGameWorld.orbs) {
                applet.ellipse(mx + o.pos.x * sx, my + o.pos.y * sy, 3, 3);
            }
            // Enemies
            applet.noStroke();
            applet.fill(0xFFFF4444);
            for (Enemy e : TdGameWorld.enemies) {
                applet.ellipse(mx + e.pos.x * sx, my + e.pos.y * sy, 5, 5);
            }
            // Camera rect
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            Camera2D cam = app.camera;
            if (cam != null) {
                float cx = cam.getTransform().getPosition().x;
                float cy = cam.getTransform().getPosition().y;
                float cw = cam.getViewportWidth() / cam.getZoom();
                float ch = cam.getViewportHeight() / cam.getZoom();
                applet.noFill();
                applet.stroke(0xFFFF8C42);
                applet.strokeWeight(1);
                float rx = mx + (cx - cw * 0.5f) * sx + 1;
                float ry = my + (cy - ch * 0.5f) * sy + 1;
                float rw = Math.max(1, cw * sx - 2);
                float rh = Math.max(1, ch * sy - 2);
                applet.rect(rx, ry, rw, rh);
                if (app.frameCount % 60 == 0) {
                    println("[MINIMAP] mx=" + mx + " my=" + my + " MW=" + MW + " MH=" + MH +
                            " | cam pos=" + cx + "," + cy + " vp=" + cam.getViewportWidth() + "x" + cam.getViewportHeight() +
                            " zoom=" + cam.getZoom() + " cw=" + cw + " ch=" + ch +
                            " | rx=" + rx + " ry=" + ry + " rw=" + rw + " rh=" + rh +
                            " | worldW=" + TdGameWorld.level.worldW + " worldH=" + TdGameWorld.level.worldH);
                }
            }
        }
        applet.popStyle();
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (TowerDefenseMin2.inst.sellMenuPanel != null) return false;
        if (event.getMouseButton() != PApplet.LEFT) return false;
        switch (event.getType()) {
            case MOUSE_PRESSED:
            case MOUSE_DRAGGED:
                jumpCameraTo(absMouseX, absMouseY);
                return true;
            case MOUSE_RELEASED:
                return true;
            default:
                return false;
        }
    }

    void jumpCameraTo(float absMouseX, float absMouseY) {
        if (TdGameWorld.level == null) return;
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.camera == null) return;
        float mx = getAbsoluteX();
        float my = getAbsoluteY();
        float wx = (absMouseX - mx) / MW * TdGameWorld.level.worldW;
        float wy = (absMouseY - my) / MH * TdGameWorld.level.worldH;
        app.camera.jumpCenterTo(wx, wy);
    }
}

// ─── Top Bar ───

static class TdTopBar extends Panel {
    Label lblStatus;
    Label lblTime;
    Label lblSpeed;
    Label lblNextWave;
    Button btnRange;

    TdTopBar(String id) {
        super(id);
        setPaintBackground(true);
        setBounds(0, 0, 1280, TdConfig.TOP_HUD);
        setAnchor(ANCHOR_TOP | ANCHOR_LEFT | ANCHOR_RIGHT);
        setLayoutManager(null);

        lblStatus = new Label("lbl_status");
        lblStatus.setBounds(16, 0, 420, TdConfig.TOP_HUD);
        lblStatus.setTextAlign(PApplet.LEFT);
        add(lblStatus);

        lblTime = new Label("lbl_time");
        lblTime.setBounds(460, 0, 120, TdConfig.TOP_HUD);
        lblTime.setTextAlign(PApplet.CENTER);
        add(lblTime);

        lblSpeed = new Label("lbl_speed");
        lblSpeed.setBounds(600, 0, 70, TdConfig.TOP_HUD);
        lblSpeed.setTextAlign(PApplet.CENTER);
        add(lblSpeed);

        lblNextWave = new Label("lbl_nextwave");
        lblNextWave.setBounds(690, 0, 180, TdConfig.TOP_HUD);
        lblNextWave.setTextAlign(PApplet.CENTER);
        add(lblNextWave);

        btnRange = new Button("btn_range");
        btnRange.setBounds(getWidth() - 72 - 12 - 72 - 8 - 80 - 8, (TdConfig.TOP_HUD - 28) * 0.5f, 80, 28);
        btnRange.setAction(() -> {
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            app.showTowerRanges = !app.showTowerRanges;
        });
        add(btnRange);

        Button btnPause = new Button("btn_pause");
        btnPause.setLabel(TdAssets.i18n("game.pause"));
        btnPause.setBounds(getWidth() - 72 - 12 - 72 - 8, (TdConfig.TOP_HUD - 28) * 0.5f, 72, 28);
        btnPause.setAction(() -> {
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            if (app.state == TdState.PLAYING) {
                app.state = TdState.PAUSED;
            } else if (app.state == TdState.PAUSED) {
                app.state = TdState.PLAYING;
            }
        });
        add(btnPause);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.menu"));
        btnMenu.setBounds(getWidth() - 72 - 12, (TdConfig.TOP_HUD - 28) * 0.5f, 72, 28);
        btnMenu.setAction(() -> {
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            if (app.state == TdState.PLAYING) {
                TdFlow.showPauseMenu(app);
            } else if (app.state == TdState.PAUSED) {
                TdFlow.hidePauseMenu(app);
            }
        });
        add(btnMenu);
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        String statusText;
        if (TdGameWorld.level != null && TdGameWorld.level.levelType == LevelType.SURVIVAL) {
            statusText = "资金 $" + TdGameWorld.money
                + "   逃脱 " + TdGameWorld.escapedEnemies + "/" + TdGameWorld.level.maxEscapeCount
                + "   波次 " + TdGameWorld.currentWave + "/" + TdGameWorld.level.waves.length;
        } else {
            statusText = "资金 $" + TdGameWorld.money
                + "   基地能量球 " + TdGameWorld.orbits
                + "   波次 " + TdGameWorld.currentWave + "/" + (TdGameWorld.level != null ? TdGameWorld.level.waves.length : 0);
        }
        lblStatus.setText(statusText);

        // Game time
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        float total = app.engine.getGameTime().getTotalTime() - TdGameWorld.levelStartTotalTime;
        int minutes = (int)(total / 60);
        int seconds = (int)(total % 60);
        lblTime.setText(String.format("%02d:%02d", minutes, seconds));

        // Game speed
        float ts = app.engine.getGameTime().getTimeScale();
        lblSpeed.setText(String.format("%.1fx", ts));

        // Next wave countdown
        String nextWaveText;
        if (TdGameWorld.waveInProgress) {
            nextWaveText = "来袭中";
        } else if (TdGameWorld.currentWave >= (TdGameWorld.level != null ? TdGameWorld.level.waves.length : 0)) {
            nextWaveText = "最后一波";
        } else {
            nextWaveText = String.format("下一波 %.1fs", TdGameWorld.waveTimer);
        }
        lblNextWave.setText(nextWaveText);

        boolean active = app.showTowerRanges || app.buildMode != TdBuildMode.NONE;
        String rangeLabel = TdAssets.i18n(active ? "game.rangeOn" : "game.rangeOff");
        btnRange.setLabel("[T] " + rangeLabel);

        // Re-position right-aligned buttons when width changes (anchor stretch)
        float w = getWidth();
        btnRange.setPosition(w - 72 - 12 - 72 - 8 - 80 - 8, btnRange.getY());
        for (UIComponent c : getChildren()) {
            if ("btn_pause".equals(c.getId())) {
                c.setPosition(w - 72 - 12 - 72 - 8, c.getY());
            } else if ("btn_menu".equals(c.getId())) {
                c.setPosition(w - 72 - 12, c.getY());
            }
        }
    }
}

// ─── Build Panel ───

static class TdBuildPanel extends Panel {
    TowerType[] allTypes = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW };
    String[] allInitials = { "M", "W", "L", "S" };

    TdBuildPanel(String id) {
        super(id);
        setPaintBackground(true);
        setBounds(1280 - TdConfig.RIGHT_W, TdConfig.TOP_HUD, TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
        setAnchor(ANCHOR_TOP | ANCHOR_RIGHT | ANCHOR_BOTTOM);
        setLayoutManager(null);
        rebuildButtons();
    }

    void flashButton(TowerType type) {
        for (UIComponent c : getChildren()) {
            if (c instanceof TowerButton) {
                TowerButton b = (TowerButton) c;
                if (b.towerType == type) {
                    b.flash();
                    return;
                }
            }
        }
    }

    void rebuildButtons() {
        removeAllChildren();

        TowerType[] allowed = (TdGameWorld.level != null && TdGameWorld.level.allowedTowers != null)
            ? TdGameWorld.level.allowedTowers : allTypes;

        float by = 16;
        for (int i = 0; i < allTypes.length; i++) {
            TowerType tt = allTypes[i];
            boolean isAllowed = false;
            for (TowerType a : allowed) {
                if (a == tt) { isAllowed = true; break; }
            }
            if (!isAllowed) continue;

            final TdBuildMode mode = TowerType.toBuildMode(tt);
            String[] hotkeys = { "Q", "W", "E", "R" };
            final TowerButton btn = new TowerButton("btn_" + tt.name().toLowerCase(), tt, allInitials[i], hotkeys[i]);
            btn.setPosition(8, by);
            btn.setSfxPath(TdSound.SFX_TOWER_SELECT);
            btn.setAction(() -> {
                TowerDefenseMin2 app = TowerDefenseMin2.inst;
                TdAppUtils.closeSellMenu(app);
                TowerDef def = TdAssets.loadTowerDef(tt);
                if (def != null && TdGameWorld.money >= def.cost) {
                    app.buildMode = mode;
                } else {
                    btn.flash();
                }
            });
            add(btn);
            by += 56 + 8;
        }

        by += 8;
        Button btnCancel = new Button("btn_cancel");
        btnCancel.setLabel(TdAssets.i18n("game.build.cancel"));
        btnCancel.setBounds(8, by, TdConfig.RIGHT_W - 16, 32);
        btnCancel.setAction(() -> {
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            TdAppUtils.closeSellMenu(app);
            app.buildMode = TdBuildMode.NONE;
        });
        add(btnCancel);
    }
}
