/**
 * HUD UI components using p5engine UI library.
 * Replaces hand-drawn TdHUD and TdMinimap.
 */

// ─── Tower Button ───

static class TowerButton extends Button {
    TowerType towerType;
    String initial;

    TowerButton(String id, TowerType type, String initial) {
        super(id);
        this.towerType = type;
        this.initial = initial;
        setSize(TdConfig.RIGHT_W - 16, 56);
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

        // Icon
        float iconSize = 32;
        float iconX = getAbsoluteX() + 8;
        float iconY = getAbsoluteY() + (getHeight() - iconSize) * 0.5f;
        applet.noStroke();
        applet.fill(TdConfig.C_ACCENT);
        applet.rect(iconX, iconY, iconSize, iconSize);
        applet.fill(TdTheme.BG_DARK);
        applet.textAlign(PApplet.CENTER, PApplet.CENTER);
        applet.textSize(14);
        applet.text(initial, iconX + iconSize * 0.5f, iconY + iconSize * 0.5f);

        // Name and cost
        if (def != null) {
            applet.fill(TdTheme.TEXT);
            applet.textAlign(PApplet.LEFT, PApplet.CENTER);
            applet.textSize(13);
            applet.text(TdAssets.i18n(def.nameKey), iconX + iconSize + 10, getAbsoluteY() + getHeight() * 0.35f);
            applet.fill(TdTheme.TEXT_DIM);
            applet.textSize(11);
            applet.text("$" + def.cost, iconX + iconSize + 10, getAbsoluteY() + getHeight() * 0.7f);
        }

        applet.popMatrix();
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        TowerDef def = TdAssets.loadTowerDef(towerType);
        if (def != null) {
            setEnabled(TdGameWorld.money >= def.cost);
        }
    }
}

// ─── Minimap Component ───

static class TdMinimapComponent extends UIComponent {
    static final float MW = 180, MH = 120;

    TdMinimapComponent(String id) {
        super(id);
        setSize(MW, MH);
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
            // Exit
            applet.fill(0xFFFF4444);
            applet.ellipse(mx + TdGameWorld.level.exitPos.x * sx, my + TdGameWorld.level.exitPos.y * sy, 6, 6);
            // Path
            applet.stroke(0xFF4A9EFF);
            applet.strokeWeight(1);
            Vector2[] pts = TdGameWorld.level.pathPoints;
            for (int i = 1; i < pts.length; i++) {
                applet.line(mx + pts[i-1].x * sx, my + pts[i-1].y * sy,
                            mx + pts[i].x * sx, my + pts[i].y * sy);
            }
            // Towers
            applet.noStroke();
            applet.fill(0xFF66FF66);
            for (Tower t : TdGameWorld.towers) {
                applet.rect(mx + t.worldX * sx - 4, my + t.worldY * sy - 4, 6, 6);
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
                applet.rect(mx + (cx - cw * 0.5f) * sx, my + (cy - ch * 0.5f) * sy, cw * sx, ch * sy);
            }
        }
        applet.popStyle();
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
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
    Button btnRange;

    TdTopBar(String id) {
        super(id);
        setPaintBackground(true);
        setBounds(0, 0, 1280, TdConfig.TOP_HUD);
        setLayoutManager(null);

        lblStatus = new Label("lbl_status");
        lblStatus.setBounds(16, 0, 400, TdConfig.TOP_HUD);
        lblStatus.setTextAlign(PApplet.LEFT);
        add(lblStatus);

        btnRange = new Button("btn_range");
        btnRange.setBounds(1280 - 72 - 12 - 80 - 8, (TdConfig.TOP_HUD - 28) * 0.5f, 80, 28);
        btnRange.setAction(() -> {
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            app.showTowerRanges = !app.showTowerRanges;
        });
        add(btnRange);

        Button btnPause = new Button("btn_pause");
        btnPause.setLabel(TdAssets.i18n("game.pause"));
        btnPause.setBounds(1280 - 72 - 12, (TdConfig.TOP_HUD - 28) * 0.5f, 72, 28);
        btnPause.setAction(() -> {
            TowerDefenseMin2 app = TowerDefenseMin2.inst;
            if (app.state == TdState.PLAYING) {
                app.state = TdState.PAUSED;
            } else if (app.state == TdState.PAUSED) {
                app.state = TdState.PLAYING;
            }
        });
        add(btnPause);
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        lblStatus.setText("$ " + TdGameWorld.money + "  ♦ " + TdGameWorld.orbits + "  波 " + TdGameWorld.currentWave + "/" + (TdGameWorld.level != null ? TdGameWorld.level.totalWaves : 0));

        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        boolean active = app.showTowerRanges || app.buildMode != TdBuildMode.NONE;
        btnRange.setLabel(TdAssets.i18n(active ? "game.rangeOn" : "game.rangeOff"));
    }
}

// ─── Build Panel ───

static class TdBuildPanel extends Panel {
    TowerType[] types = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW };
    String[] initials = { "M", "R", "L", "S" };

    TdBuildPanel(String id) {
        super(id);
        setPaintBackground(true);
        setBounds(1280 - TdConfig.RIGHT_W, TdConfig.TOP_HUD, TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
        setLayoutManager(null);

        float by = 16;
        for (int i = 0; i < types.length; i++) {
            TowerType tt = types[i];
            final TdBuildMode mode = TowerType.toBuildMode(tt);
            TowerButton btn = new TowerButton("btn_" + tt.name().toLowerCase(), tt, initials[i]);
            btn.setPosition(8, by);
            btn.setAction(() -> {
                TowerDefenseMin2 app = TowerDefenseMin2.inst;
                app.buildMode = mode;
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
            app.buildMode = TdBuildMode.NONE;
        });
        add(btnCancel);
    }
}
