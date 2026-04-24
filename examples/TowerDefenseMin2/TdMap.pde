/**
 * Map renderer: draws grid, path, base, spawn point in world space.
 */
static final class TdMap {

    static void render() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        LevelDef lv = TdGameWorld.level;
        if (lv == null) return;

        app.pushStyle();

        // Grid
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        for (int gx = 0; gx <= lv.worldW; gx += TdConfig.GRID) {
            app.line(gx, 0, gx, lv.worldH);
        }
        for (int gy = 0; gy <= lv.worldH; gy += TdConfig.GRID) {
            app.line(0, gy, lv.worldW, gy);
        }

        // Path
        if (lv.pathPoints.length > 1) {
            app.stroke(0xFF4A9EFF);
            app.strokeWeight(12);
            app.strokeCap(PApplet.ROUND);
            for (int i = 1; i < lv.pathPoints.length; i++) {
                app.line(lv.pathPoints[i-1].x, lv.pathPoints[i-1].y, lv.pathPoints[i].x, lv.pathPoints[i].y);
            }
        }

        // Base
        app.noStroke();
        app.fill(0xFF4A9EFF);
        app.ellipse(lv.basePos.x, lv.basePos.y, 24, 24);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(10);
        app.text("BASE", lv.basePos.x, lv.basePos.y);

        // Exit
        app.noStroke();
        app.fill(0xFFFF4444);
        app.ellipse(lv.exitPos.x, lv.exitPos.y, 16, 16);

        // Spawn
        app.noStroke();
        app.fill(0xFFFF8C42);
        app.ellipse(lv.spawnPos.x, lv.spawnPos.y, 12, 12);

        app.popStyle();
    }
}
