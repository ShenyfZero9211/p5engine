/**
 * HUD legacy helpers — only pause overlay remains.
 * Top bar, build panel, and minimap are now handled by UI components in TdUiHud.pde.
 */
static final class TdHUD {

    static void drawPauseOverlay() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        DisplayManager dm = app.engine.getDisplayManager();
        float ox = dm.getOffsetX() / dm.getUniformScale();
        float oy = dm.getOffsetY() / dm.getUniformScale();
        float w = dm.getActualWidth() / dm.getUniformScale();
        float h = dm.getActualHeight() / dm.getUniformScale();
        app.pushStyle();
        app.fill(0x66000000);
        app.noStroke();
        app.rect(-ox, -oy, w, h);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(32);
        app.text("PAUSED", dm.getDesignWidth() * 0.5f, dm.getDesignHeight() * 0.5f);
        app.popStyle();
    }
}
