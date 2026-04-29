/**
 * HUD elements rendered on screen layer (top bar, right panel, minimap).
 */
static final class TdHUD {

    static void drawTopBar() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        DisplayManager dm = app.engine.getDisplayManager();
        float x = 0, y = 0;
        float w = dm.getDesignWidth();
        float h = TdConfig.TOP_HUD;

        app.pushStyle();
        app.noStroke();
        app.fill(TdTheme.BG_TITLE);
        app.rect(x, y, w, h);
        app.stroke(TdTheme.ACCENT);
        app.strokeWeight(1);
        app.noFill();
        app.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);

        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.LEFT, PApplet.CENTER);
        app.textSize(14);
        String statusText;
        if (TdGameWorld.level != null && TdGameWorld.level.levelType == LevelType.SURVIVAL) {
            statusText = "$ " + TdGameWorld.money + "  逃 " + TdGameWorld.escapedEnemies + "/" + TdGameWorld.level.maxEscapeCount
                + "  波 " + TdGameWorld.currentWave + "/" + TdGameWorld.level.waves.length;
        } else {
            statusText = "$ " + TdGameWorld.money + "  ♦ " + TdGameWorld.orbits
                + "  波 " + TdGameWorld.currentWave + "/" + (TdGameWorld.level != null ? TdGameWorld.level.waves.length : 0);
        }
        app.text(statusText, x + 16, y + h * 0.5f);

        // Pause button
        float btnW = 72;
        float btnH = 28;
        float btnX = x + w - btnW - 12;
        float btnY = y + (h - btnH) * 0.5f;
        Vector2 dMouse = dm.actualToDesign(new Vector2(app.mouseX, app.mouseY));
        boolean pauseHover = dMouse.x >= btnX && dMouse.x <= btnX + btnW && dMouse.y >= btnY && dMouse.y <= btnY + btnH;
        int pauseFill = pauseHover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG;
        app.noStroke();
        app.fill(pauseFill);
        app.rect(btnX, btnY, btnW, btnH);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(btnX + 0.5f, btnY + 0.5f, btnW - 1, btnH - 1);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(12);
        app.text(TdAssets.i18n("game.pause"), btnX + btnW * 0.5f, btnY + btnH * 0.5f);

        app.popStyle();
    }

    static void drawBuildPanel() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        DisplayManager dm = app.engine.getDisplayManager();
        float x = dm.getDesignWidth() - TdConfig.RIGHT_W;
        float y = TdConfig.TOP_HUD;
        float w = TdConfig.RIGHT_W;
        float h = dm.getDesignHeight() - y;

        app.pushStyle();
        app.noStroke();
        app.fill(TdTheme.BG_PANEL);
        app.rect(x, y, w, h);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);

        // Tower buttons
        float btnH = 56;
        float gap = 8;
        float by = y + 16;
        TowerType[] types = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW };
        String[] initials = { "M", "R", "L", "S" };
        Vector2 dMouse = dm.actualToDesign(new Vector2(app.mouseX, app.mouseY));
        for (int i = 0; i < types.length; i++) {
            TowerType tt = types[i];
            TowerDef def = TdAssets.loadTowerDef(tt);
            if (def == null) continue;
            boolean selected = app.buildMode == TowerType.toBuildMode(tt);
            boolean hover = dMouse.x >= x + 8 && dMouse.x <= x + w - 8 && dMouse.y >= by && dMouse.y <= by + btnH;
            int fill = selected ? TdTheme.BTN_PRESS : (hover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG);
            app.noStroke();
            app.fill(fill);
            app.rect(x + 8, by, w - 16, btnH);
            app.stroke(selected ? TdTheme.ACCENT : TdTheme.BORDER);
            app.strokeWeight(selected ? 2 : 1);
            app.noFill();
            app.rect(x + 8.5f, by + 0.5f, w - 17, btnH - 1);

            // Icon
            float iconSize = 32;
            float iconX = x + 16;
            float iconY = by + (btnH - iconSize) * 0.5f;
            app.noStroke();
            app.fill(TdConfig.C_ACCENT);
            app.rect(iconX, iconY, iconSize, iconSize);
            app.fill(TdTheme.BG_DARK);
            app.textAlign(PApplet.CENTER, PApplet.CENTER);
            app.textSize(14);
            app.text(initials[i], iconX + iconSize * 0.5f, iconY + iconSize * 0.5f);

            // Name and cost
            app.fill(TdTheme.TEXT);
            app.textAlign(PApplet.LEFT, PApplet.CENTER);
            app.textSize(13);
            app.text(TdAssets.i18n(def.nameKey), iconX + iconSize + 10, by + btnH * 0.35f);
            app.fill(TdTheme.TEXT_DIM);
            app.textSize(11);
            app.text("$" + def.cost, iconX + iconSize + 10, by + btnH * 0.7f);

            by += btnH + gap;
        }

        // Cancel button
        by += 8;
        float cancelH = 32;
        boolean cancelHover = dMouse.x >= x + 8 && dMouse.x <= x + w - 8 && dMouse.y >= by && dMouse.y <= by + cancelH;
        int cancelFill = cancelHover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG;
        app.noStroke();
        app.fill(cancelFill);
        app.rect(x + 8, by, w - 16, cancelH);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(x + 8.5f, by + 0.5f, w - 17, cancelH - 1);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(12);
        app.text(TdAssets.i18n("game.build.cancel"), x + w * 0.5f, by + cancelH * 0.5f);

        app.popStyle();
    }

    static void drawMinimap() {
        TdMinimap.draw();
    }

    static void handleMinimapClick() {
        TdMinimap.handleClick();
    }

    static void drawPauseOverlay() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        DisplayManager dm = app.engine.getDisplayManager();
        app.pushStyle();
        app.fill(0x66000000);
        app.noStroke();
        app.rect(0, 0, dm.getDesignWidth(), dm.getDesignHeight());
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(32);
        app.text("PAUSED", dm.getDesignWidth() * 0.5f, dm.getDesignHeight() * 0.5f);
        app.popStyle();
    }

    static boolean isPauseButtonHit(float mx, float my) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        DisplayManager dm = app.engine.getDisplayManager();
        float x = 0, y = 0;
        float w = dm.getDesignWidth();
        float h = TdConfig.TOP_HUD;
        float btnW = 72;
        float btnH = 28;
        float btnX = x + w - btnW - 12;
        float btnY = y + (h - btnH) * 0.5f;
        return mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH;
    }

    static TdBuildMode getBuildModeAt(float mx, float my) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        DisplayManager dm = app.engine.getDisplayManager();
        float x = dm.getDesignWidth() - TdConfig.RIGHT_W;
        float y = TdConfig.TOP_HUD;
        float w = TdConfig.RIGHT_W;
        float btnH = 56;
        float gap = 8;
        float by = y + 16;
        TowerType[] allTypes = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW };
        TowerType[] allowed = (TdGameWorld.level != null && TdGameWorld.level.allowedTowers != null)
            ? TdGameWorld.level.allowedTowers : allTypes;
        for (int i = 0; i < allTypes.length; i++) {
            TowerType tt = allTypes[i];
            boolean isAllowed = false;
            for (TowerType a : allowed) {
                if (a == tt) { isAllowed = true; break; }
            }
            if (!isAllowed) continue;
            TowerDef def = TdAssets.loadTowerDef(tt);
            if (def == null) continue;
            if (mx >= x + 8 && mx <= x + w - 8 && my >= by && my <= by + btnH) {
                return TowerType.toBuildMode(tt);
            }
            by += btnH + gap;
        }
        // Cancel button
        by += 8;
        float cancelH = 32;
        if (mx >= x + 8 && mx <= x + w - 8 && my >= by && my <= by + cancelH) {
            return TdBuildMode.NONE;
        }
        return null;
    }
}
