/**
 * Minimap widget — encapsulates bounds, drawing, and click-to-jump logic.
 */
static final class TdMinimap {
    static final float MW = 180, MH = 120;

    static float getX() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, app.height));
        return d.x - TdConfig.RIGHT_W + 16;
    }

    static float getY() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, app.height));
        return d.y - MH - 16;
    }

    static boolean isMouseOver() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        float mx = getX();
        float my = getY();
        return dm.x >= mx && dm.x <= mx + MW && dm.y >= my && dm.y <= my + MH;
    }

    static void handleClick() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (TdGameWorld.level == null || app.camera == null) return;
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        float mx = getX();
        float my = getY();
        float wx = (dm.x - mx) / MW * TdGameWorld.level.worldW;
        float wy = (dm.y - my) / MH * TdGameWorld.level.worldH;
        app.camera.jumpCenterTo(wx, wy);
    }

    static void draw() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        float mx = getX();
        float my = getY();

        app.pushStyle();
        app.noStroke();
        app.fill(TdTheme.BG_DARK);
        app.rect(mx, my, MW, MH);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(mx + 0.5f, my + 0.5f, MW - 1, MH - 1);

        if (TdGameWorld.level != null) {
            float sx = MW / TdGameWorld.level.worldW;
            float sy = MH / TdGameWorld.level.worldH;
            // Base
            app.fill(0xFF4A9EFF);
            app.ellipse(mx + TdGameWorld.level.basePos.x * sx, my + TdGameWorld.level.basePos.y * sy, 6, 6);
            // Exit
            app.fill(0xFFFF4444);
            app.ellipse(mx + TdGameWorld.level.exitPos.x * sx, my + TdGameWorld.level.exitPos.y * sy, 6, 6);
            // Path
            app.stroke(0xFF4A9EFF);
            app.strokeWeight(1);
            Vector2[] pts = TdGameWorld.level.pathPoints;
            for (int i = 1; i < pts.length; i++) {
                app.line(mx + pts[i-1].x * sx, my + pts[i-1].y * sy,
                         mx + pts[i].x * sx, my + pts[i].y * sy);
            }
            // Towers (fixed screen-pixel size so they remain visible)
            app.noStroke();
            app.fill(0xFF66FF66);
            for (Tower t : TdGameWorld.towers) {
              app.rect(mx + t.worldX * sx - 4, my + t.worldY * sy - 4, 6, 6);
            }
            // Enemies
            app.noStroke();
            app.fill(0xFFFF4444);
            for (Enemy e : TdGameWorld.enemies) {
              app.ellipse(mx + e.pos.x * sx, my + e.pos.y * sy, 5, 5);
            }

            // Camera rect
            Camera2D cam = app.camera;
            float cx = cam.getTransform().getPosition().x;
            float cy = cam.getTransform().getPosition().y;
            float cw = cam.getViewportWidth() / cam.getZoom();
            float ch = cam.getViewportHeight() / cam.getZoom();
            app.noFill();
            app.stroke(0xFFFF8C42);
            app.strokeWeight(1);
            app.rect(mx + (cx - cw * 0.5f) * sx, my + (cy - ch * 0.5f) * sy, cw * sx, ch * sy);
        }

        app.popStyle();
    }
}
