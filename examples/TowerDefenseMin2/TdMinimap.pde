/**
 * Minimap widget — encapsulates bounds, drawing, and click-to-jump logic.
 */
static final class TdMinimap {
    static float MW = 180, MH = 120;

    static float getX() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.hudMinimap != null) return app.hudMinimap.getAbsoluteX();
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, app.height));
        return d.x - TdConfig.RIGHT_W + 16;
    }

    static float getY() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.hudMinimap != null) return app.hudMinimap.getAbsoluteY();
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
        float worldW = TdGameWorld.level.worldW;
        float worldH = TdGameWorld.level.worldH;
        float scale = Math.min(MW / worldW, MH / worldH);
        float drawW = worldW * scale;
        float drawH = worldH * scale;
        float ox = mx + (MW - drawW) * 0.5f;
        float oy = my + (MH - drawH) * 0.5f;
        float wx = (dm.x - ox) / scale;
        float wy = (dm.y - oy) / scale;
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
            float worldW = TdGameWorld.level.worldW;
            float worldH = TdGameWorld.level.worldH;
            float scale = Math.min(MW / worldW, MH / worldH);
            float drawW = worldW * scale;
            float drawH = worldH * scale;
            float ox = mx + (MW - drawW) * 0.5f;
            float oy = my + (MH - drawH) * 0.5f;

            // Base
            app.fill(0xFF4A9EFF);
            app.ellipse(ox + TdGameWorld.level.basePos.x * scale, oy + TdGameWorld.level.basePos.y * scale, 6, 6);
            // Spawns (global + per-path)
            app.fill(0xFFFF8C42);
            if (TdGameWorld.level.spawnPos != null) {
                app.ellipse(ox + TdGameWorld.level.spawnPos.x * scale, oy + TdGameWorld.level.spawnPos.y * scale, 6, 6);
            }
            if (TdGameWorld.level.paths != null) {
                for (PathRoute pr : TdGameWorld.level.paths) {
                    if (pr.path == null || pr.path.points == null || pr.path.points.length < 1) continue;
                    Vector2 start = pr.path.points[0];
                    boolean distinct = (TdGameWorld.level.spawnPos == null) || start.distance(TdGameWorld.level.spawnPos) > 10f;
                    if (distinct) {
                        app.ellipse(ox + start.x * scale, oy + start.y * scale, 5, 5);
                    }
                }
            } else if (TdGameWorld.level.pathPoints != null && TdGameWorld.level.pathPoints.length > 0) {
                // legacy single-path: first point as spawn
                Vector2 start = TdGameWorld.level.pathPoints[0];
                app.ellipse(ox + start.x * scale, oy + start.y * scale, 5, 5);
            }

            // Exits (global + per-path endpoints)
            app.fill(0xFFFF4444);
            if (TdGameWorld.level.exitPos != null) {
                app.ellipse(ox + TdGameWorld.level.exitPos.x * scale, oy + TdGameWorld.level.exitPos.y * scale, 6, 6);
            }
            if (TdGameWorld.level.paths != null) {
                for (PathRoute pr : TdGameWorld.level.paths) {
                    if (pr.path == null || pr.path.points == null || pr.path.points.length < 2) continue;
                    Vector2 end = pr.path.points[pr.path.points.length - 1];
                    boolean isBase = (TdGameWorld.level.basePos != null) && end.distance(TdGameWorld.level.basePos) <= 10f;
                    boolean isGlobalExit = (TdGameWorld.level.exitPos != null) && end.distance(TdGameWorld.level.exitPos) <= 10f;
                    if (!isBase && !isGlobalExit) {
                        app.ellipse(ox + end.x * scale, oy + end.y * scale, 5, 5);
                    }
                }
            } else if (TdGameWorld.level.pathPoints != null && TdGameWorld.level.pathPoints.length > 1) {
                // legacy single-path: last point as exit (if not base)
                Vector2 end = TdGameWorld.level.pathPoints[TdGameWorld.level.pathPoints.length - 1];
                boolean isBase = (TdGameWorld.level.basePos != null) && end.distance(TdGameWorld.level.basePos) <= 10f;
                if (!isBase) {
                    app.ellipse(ox + end.x * scale, oy + end.y * scale, 5, 5);
                }
            }
            // Path
            app.stroke(0xFF4A9EFF);
            app.strokeWeight(1);
            Vector2[] pts = TdGameWorld.level.pathPoints;
            for (int i = 1; i < pts.length; i++) {
                app.line(ox + pts[i-1].x * scale, oy + pts[i-1].y * scale,
                         ox + pts[i].x * scale, oy + pts[i].y * scale);
            }
            // Towers (fixed screen-pixel size so they remain visible)
            app.noStroke();
            app.fill(0xFF66FF66);
            for (Tower t : TdGameWorld.towers) {
              app.rect(ox + t.worldX * scale - 4, oy + t.worldY * scale - 4, 6, 6);
            }
            // Orbs
            app.noStroke();
            app.fill(0xFFFFD700);
            for (Orb o : TdGameWorld.orbs) {
              app.ellipse(ox + o.pos.x * scale, oy + o.pos.y * scale, 4, 4);
            }

            // Enemies
            app.noStroke();
            app.fill(0xFFFF4444);
            for (Enemy e : TdGameWorld.enemies) {
              app.ellipse(ox + e.pos.x * scale, oy + e.pos.y * scale, 5, 5);
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
            app.rect(ox + (cx - cw * 0.5f) * scale, oy + (cy - ch * 0.5f) * scale, cw * scale, ch * scale);
        }

        app.popStyle();
    }
}
