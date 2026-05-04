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
    float hoverTimer = 0;
    static final float FLASH_DURATION = 0.6f;

    // Shared tooltip state across all tower buttons in the build panel
    static float sharedTooltipTimer = 0;
    static boolean anyTowerButtonHoveredThisFrame = false;
    static float panelHoverWithoutButtonTimer = 0;
    static final float PANEL_GAP_TIMEOUT = 2.0f;

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

    /** Call once per frame after all TowerButtons have updated.
     *  Resets shared timer if mouse left the build panel,
     *  or if mouse stayed inside panel but not on any button for too long. */
    static void postUpdateTooltipTimer(float dt) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.hudBuildPanel != null) {
            float mx = UIManager.getDesignMouseX();
            float my = UIManager.getDesignMouseY();
            if (app.hudBuildPanel.containsPoint(mx, my)) {
                if (anyTowerButtonHoveredThisFrame) {
                    // Mouse is on a button — reset gap timer
                    panelHoverWithoutButtonTimer = 0;
                } else {
                    // Mouse is inside panel but on gap / non-button area
                    panelHoverWithoutButtonTimer += dt;
                    if (panelHoverWithoutButtonTimer >= PANEL_GAP_TIMEOUT) {
                        sharedTooltipTimer = 0;
                        panelHoverWithoutButtonTimer = 0;
                    }
                }
            } else {
                // Mouse left the panel entirely
                sharedTooltipTimer = 0;
                panelHoverWithoutButtonTimer = 0;
            }
        } else {
            sharedTooltipTimer = 0;
            panelHoverWithoutButtonTimer = 0;
        }
        anyTowerButtonHoveredThisFrame = false;
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
                    drawPolyCircle(applet.g, icx, icy, isize * 0.5f, 16);
                    applet.fill(0xFFFFFFFF, 120);
                    drawPolyCircle(applet.g, icx, icy, isize * 0.2f, 8);
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
                    drawPolyCircle(applet.g, icx, icy, lsize * 0.15f, 6);
                    break;
                }
                case SLOW:
                    drawTowerIconHexagon(applet, icx, icy, ihalf * 0.9f);
                    applet.fill(0xFFFFFFFF, 120);
                    drawPolyCircle(applet.g, icx, icy, isize * 0.175f, 8);
                    break;
                case POISON:
                    drawTowerIconPentagon(applet, icx, icy, ihalf * 0.98f);
                    applet.fill(0xFFFFFFFF, 120);
                    drawPolyCircle(applet.g, icx, icy, isize * 0.175f, 8);
                    break;
                case COMMAND:
                    float cmdIconOffset = ihalf * 0.25f;
                    drawTowerIconTriangle(applet, icx, icy + cmdIconOffset, ihalf);
                    applet.fill(0xFFFFFFFF, 120);
                    drawPolyCircle(applet.g, icx, icy + cmdIconOffset, ihalf * 0.3f, 6);
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

        // Tooltip on long hover
        if (hoverTimer >= TdAssets.getTooltipDelay() && def != null) {
            paintTooltip(applet, def);
        }
    }

    private void paintTooltip(PApplet g, TowerDef def) {
        float tipW = 230;
        float tipH = 120;
        float arrowW = 8;
        float pad = 10;
        float bx = getAbsoluteX();
        float by = getAbsoluteY();
        float bw = getWidth();
        float bh = getHeight();

        // Position to the left of the button
        float tipX = bx - tipW - arrowW - 4;
        float tipY = by + (bh - tipH) * 0.5f;

        // Clamp to screen bounds
        DisplayManager dm = TowerDefenseMin2.inst.engine.getDisplayManager();
        if (dm != null && dm.getScaleMode() != ScaleMode.NO_SCALE) {
            float scale = dm.getUniformScale();
            float maxY = dm.getActualHeight() / scale - tipH - 4;
            tipY = Math.max(4, Math.min(tipY, maxY));
        }

        int bg = 0xFF1A2035; // TdTheme.BG_PANEL opaque
        int border = TdTheme.BORDER;
        int accent = TdTheme.ACCENT;

        g.pushStyle();

        // Background panel
        g.noStroke();
        g.fill(bg);
        g.rect(tipX, tipY, tipW, tipH);

        // Border
        g.noFill();
        g.stroke(border);
        g.strokeWeight(1);
        g.rect(tipX + 0.5f, tipY + 0.5f, tipW - 1, tipH - 1);

        // Arrow (pointing right toward button)
        float arrowY = by + bh * 0.5f;
        g.noStroke();
        g.fill(bg);
        g.beginShape();
        g.vertex(tipX + tipW, arrowY - 6);
        g.vertex(tipX + tipW + arrowW, arrowY);
        g.vertex(tipX + tipW, arrowY + 6);
        g.endShape(PApplet.CLOSE);
        // Arrow border (top and bottom edges)
        g.noFill();
        g.stroke(border);
        g.strokeWeight(1);
        g.line(tipX + tipW, arrowY - 6, tipX + tipW + arrowW, arrowY);
        g.line(tipX + tipW + arrowW, arrowY, tipX + tipW, arrowY + 6);

        // Title: name + hotkey
        g.noStroke();
        g.fill(accent);
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        g.textSize(14);
        String name = TdAssets.i18n(def.nameKey);
        g.text(name, tipX + pad, tipY + pad);
        if (hotkey != null && !hotkey.isEmpty()) {
            float nameW = g.textWidth(name);
            g.textSize(11);
            g.fill(TdTheme.TEXT_DIM);
            g.text("[" + hotkey + "]", tipX + pad + nameW + 6, tipY + pad + 2);
        }

        // Separator line
        g.stroke(border);
        g.strokeWeight(1);
        g.line(tipX + pad, tipY + pad + 20, tipX + tipW - pad, tipY + pad + 20);

        // Description
        g.noStroke();
        g.fill(TdTheme.TEXT);
        g.textSize(12);
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        String desc = TdAssets.i18n(def.descKey);
        g.text(desc, tipX + pad, tipY + pad + 28, tipW - pad * 2, 40);

        // Stats grid (2x2)
        g.textSize(11);
        g.fill(TdTheme.TEXT_DIM);
        float statsY = tipY + tipH - pad - 28;
        float col2X = tipX + tipW * 0.55f;
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        g.text("造价: $" + def.cost, tipX + pad, statsY);
        g.text("射程: " + (int)def.range, col2X, statsY);
        g.text("伤害: " + (int)def.damage, tipX + pad, statsY + 14);
        String fireRateStr = def.firePeriod > 0 ? String.format("%.2fs", def.firePeriod) : "-";
        g.text("射速: " + fireRateStr, col2X, statsY + 14);

        g.popStyle();
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        if (flashTimer > 0) {
            flashTimer -= dt;
            if (flashTimer < 0) flashTimer = 0;
        }
        if (hover) {
            // If tooltip was already showing within the build panel, show immediately on this button
            if (sharedTooltipTimer >= TdAssets.getTooltipDelay()) {
                hoverTimer = TdAssets.getTooltipDelay();
            } else {
                hoverTimer += dt;
            }
            sharedTooltipTimer += dt;
            anyTowerButtonHoveredThisFrame = true;
        } else {
            hoverTimer = 0;
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

    private void drawTowerIconPentagon(PApplet g, float cx, float cy, float r) {
        g.beginShape();
        for (int i = 0; i < 5; i++) {
            float a = PApplet.TWO_PI / 5 * i - PApplet.PI / 2;
            g.vertex(cx + PApplet.cos(a) * r, cy + PApplet.sin(a) * r);
        }
        g.endShape(PApplet.CLOSE);
    }

    private void drawTowerIconTriangle(PApplet g, float cx, float cy, float r) {
        g.beginShape();
        g.vertex(cx, cy - r);
        g.vertex(cx + r * 0.866f, cy + r * 0.5f);
        g.vertex(cx - r * 0.866f, cy + r * 0.5f);
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
        // Adjust minimap height to match world aspect ratio
        if (TdGameWorld.level != null && TdGameWorld.level.worldW > 0) {
            MH = MW * TdGameWorld.level.worldH / TdGameWorld.level.worldW;
        }
        setSize(MW, MH);
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
            float worldW = TdGameWorld.level.worldW;
            float worldH = TdGameWorld.level.worldH;
            float scale = Math.min(MW / worldW, MH / worldH);
            float drawW = worldW * scale;
            float drawH = worldH * scale;
            float ox = mx + (MW - drawW) * 0.5f;
            float oy = my + (MH - drawH) * 0.5f;

            // Base
            applet.fill(0xFF4A9EFF);
            applet.ellipse(ox + TdGameWorld.level.basePos.x * scale, oy + TdGameWorld.level.basePos.y * scale, 6, 6);
            // Spawns
            applet.fill(0xFFFF8C42);
            if (TdGameWorld.level.spawnPos != null) {
                applet.ellipse(ox + TdGameWorld.level.spawnPos.x * scale, oy + TdGameWorld.level.spawnPos.y * scale, 5, 5);
            }
            // Exits
            applet.fill(0xFFFF4444);
            if (TdGameWorld.level.exitPos != null) {
                applet.ellipse(ox + TdGameWorld.level.exitPos.x * scale, oy + TdGameWorld.level.exitPos.y * scale, 6, 6);
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
                        applet.ellipse(ox + start.x * scale, oy + start.y * scale, 5, 5);
                    }
                    // Exit
                    boolean isBase = (TdGameWorld.level.basePos != null) && end.distance(TdGameWorld.level.basePos) <= 10f;
                    boolean isGlobalExit = (TdGameWorld.level.exitPos != null) && end.distance(TdGameWorld.level.exitPos) <= 10f;
                    if (!isBase && !isGlobalExit) {
                        applet.fill(0xFFFF4444);
                        applet.ellipse(ox + end.x * scale, oy + end.y * scale, 6, 6);
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
                        applet.line(ox + pts[i-1].x * scale, oy + pts[i-1].y * scale,
                                    ox + pts[i].x * scale, oy + pts[i].y * scale);
                    }
                }
            } else if (TdGameWorld.level.pathPoints != null) {
                Vector2[] pts = TdGameWorld.level.pathPoints;
                for (int i = 1; i < pts.length; i++) {
                    applet.line(ox + pts[i-1].x * scale, oy + pts[i-1].y * scale,
                                ox + pts[i].x * scale, oy + pts[i].y * scale);
                }
            }
            // Towers
            applet.noStroke();
            applet.fill(0xFF66FF66);
            for (Tower t : TdGameWorld.towers) {
                applet.rect(ox + t.worldX * scale - 1.5f, oy + t.worldY * scale - 1.5f, 3, 3);
            }
            // Orbs
            applet.noStroke();
            applet.fill(0xFFFFD700);
            for (Orb o : TdGameWorld.orbs) {
                applet.ellipse(ox + o.pos.x * scale, oy + o.pos.y * scale, 3, 3);
            }
            // Enemies
            applet.noStroke();
            applet.fill(0xFFFF4444);
            for (Enemy e : TdGameWorld.enemies) {
                applet.ellipse(ox + e.pos.x * scale, oy + e.pos.y * scale, 5, 5);
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
                float rx = ox + (cx - cw * 0.5f) * scale + 1;
                float ry = oy + (cy - ch * 0.5f) * scale + 1;
                float rw = Math.max(1, cw * scale - 2);
                float rh = Math.max(1, ch * scale - 2);
                applet.rect(rx, ry, rw, rh);
                // if (app.frameCount % 60 == 0) {
                //     println("[MINIMAP] mx=" + mx + " my=" + my + " MW=" + MW + " MH=" + MH +
                //             " | cam pos=" + cx + "," + cy + " vp=" + cam.getViewportWidth() + "x" + cam.getViewportHeight() +
                //             " zoom=" + cam.getZoom() + " cw=" + cw + " ch=" + ch +
                //             " | rx=" + rx + " ry=" + ry + " rw=" + rw + " rh=" + rh +
                //             " | worldW=" + TdGameWorld.level.worldW + " worldH=" + TdGameWorld.level.worldH);
                // }
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
        float worldW = TdGameWorld.level.worldW;
        float worldH = TdGameWorld.level.worldH;
        float scale = Math.min(MW / worldW, MH / worldH);
        float drawW = worldW * scale;
        float drawH = worldH * scale;
        float ox = mx + (MW - drawW) * 0.5f;
        float oy = my + (MH - drawH) * 0.5f;
        float wx = (absMouseX - ox) / scale;
        float wy = (absMouseY - oy) / scale;
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
            statusText = TdAssets.i18n("game.money") + " $" + TdGameWorld.money
                + "   " + TdAssets.i18n("game.escaped") + " " + TdGameWorld.escapedEnemies + "/" + TdGameWorld.level.maxEscapeCount
                + "   " + TdAssets.i18n("game.wave") + " " + TdGameWorld.currentWave + "/" + TdGameWorld.level.waves.length;
        } else {
            statusText = TdAssets.i18n("game.money") + " $" + TdGameWorld.money
                + "   " + TdAssets.i18n("game.orbits") + " " + TdGameWorld.orbits
                + "   " + TdAssets.i18n("game.wave") + " " + TdGameWorld.currentWave + "/" + (TdGameWorld.level != null ? TdGameWorld.level.waves.length : 0);
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
            nextWaveText = TdAssets.i18n("game.waveIncoming");
        } else if (TdGameWorld.currentWave >= (TdGameWorld.level != null ? TdGameWorld.level.waves.length : 0)) {
            nextWaveText = TdAssets.i18n("game.waveFinal");
        } else {
            nextWaveText = TdAssets.i18n("game.nextWaveIn", String.format("%.1f", TdGameWorld.waveTimer));
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
    TowerType[] allTypes = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW, TowerType.POISON, TowerType.COMMAND };
    String[] allInitials = { "M", "W", "L", "S", "P", "C" };

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
            String[] hotkeys = { "Q", "W", "E", "R", "T", "Y" };
            final TowerButton btn = new TowerButton("btn_" + tt.name().toLowerCase(), tt, allInitials[i], hotkeys[i]);
            btn.setPosition(8, by);
            btn.setSfxPath(TdSound.SFX_TOWER_SELECT);
            btn.setAction(() -> {
                TowerDefenseMin2 app = TowerDefenseMin2.inst;
                TdAppUtils.closeSellMenu(app);
                TowerDef def = TdAssets.loadTowerDef(tt);
                if (def != null && (app.devMode || TdGameWorld.money >= def.cost)) {
                    app.buildMode = mode;
                } else {
                    btn.flash();
                }
            });
            add(btn);
            by += 56 + 8;
        }


    }
}
