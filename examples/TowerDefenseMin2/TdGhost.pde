/**
 * Ghost tower preview: draws on screen layer using worldToScreen transform.
 */
static final class TdGhost {

    static int gridX, gridY;
    static boolean isValid;
    static float worldX, worldY;

    static void update() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.buildMode == TdBuildMode.NONE || app.camera == null) {
            isValid = false;
            return;
        }
        // Coordinate chain: actual mouse → design coords → world coords → snap to grid
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        Vector2 world = app.camera.screenToWorld(dm);
        gridX = Math.round(world.x / TdConfig.GRID - 0.5f);
        gridY = Math.round(world.y / TdConfig.GRID - 0.5f);
        worldX = (gridX + 0.5f) * TdConfig.GRID;
        worldY = (gridY + 0.5f) * TdConfig.GRID;
        isValid = TdGameWorld.canPlaceTower(gridX, gridY);
    }

    static void draw() {
        if (!isValid) return;
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        // Coordinate chain for drawing: world → design (screen) → actual pixels
        Vector2 design = app.camera.worldToScreen(new Vector2(worldX, worldY));
        Vector2 screen = app.engine.getDisplayManager().designToActual(design);
        float r = app.camera.getZoom() * TdConfig.GRID * 0.5f;

        app.pushStyle();
        app.noFill();
        app.stroke(app.buildMode == TdBuildMode.MG ? 0xFF4A9EFF :
                   app.buildMode == TdBuildMode.MISSILE ? 0xFFFF643C :
                   app.buildMode == TdBuildMode.LASER ? 0xFF3CDC78 :
                   0xFFC878DC);
        app.strokeWeight(2);
        app.ellipse(screen.x, screen.y, r * 2, r * 2);

        // Range indicator
        TowerDef def = TdAssets.loadTowerDef(TowerType.fromBuildMode(app.buildMode));
        if (def != null) {
            float rangeR = app.camera.getZoom() * def.range;
            app.strokeWeight(1);
            app.stroke(0x55FFFFFF);
            app.noFill();
            app.ellipse(screen.x, screen.y, rangeR * 2, rangeR * 2);
        }

        app.popStyle();
    }
}
