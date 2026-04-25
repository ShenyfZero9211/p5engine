/**
 * Ghost tower preview: managed as a Scene GameObject with RendererComponent.
 * Renders through SceneViewport's off-screen buffer, naturally clipped to world bounds.
 */
static final class TdGhost {

    static int gridX, gridY;
    static boolean isValid;
    static float worldX, worldY;
    static GameObject ghostGo;

    static void ensureGameObject(TowerDefenseMin2 app) {
        if (ghostGo == null) {
            ghostGo = GameObject.create("ghost_tower");
            ghostGo.setRenderLayer(50);  // above towers(5) and enemies(10)
            ghostGo.addComponent(new GhostRenderer());
            app.gameScene.addGameObject(ghostGo);
        }
    }

    static void update() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.buildMode == TdBuildMode.NONE || app.camera == null) {
            isValid = false;
            if (ghostGo != null) ghostGo.setActive(false);
            return;
        }
        // Don't show ghost when mouse is over HUD
        if (app.isMouseOverHud()) {
            isValid = false;
            if (ghostGo != null) ghostGo.setActive(false);
            return;
        }
        ensureGameObject(app);
        ghostGo.setActive(true);

        // Coordinate chain: actual mouse → design coords → world coords → snap to grid
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        Vector2 world = app.camera.screenToWorld(dm);
        gridX = Math.round(world.x / TdConfig.GRID - 0.5f);
        gridY = Math.round(world.y / TdConfig.GRID - 0.5f);
        worldX = (gridX + 0.5f) * TdConfig.GRID;
        worldY = (gridY + 0.5f) * TdConfig.GRID;
        isValid = TdGameWorld.canPlaceTower(gridX, gridY);

        // Sync position to GameObject transform
        ghostGo.getTransform().setPosition(worldX, worldY);
    }

    static void draw() {
        // Rendering is handled by Scene system via GhostRenderer
    }

    static void cleanup(TowerDefenseMin2 app) {
        if (ghostGo != null) {
            ghostGo.markForDestroy();
            ghostGo = null;
        }
    }
}

static class GhostRenderer extends RendererComponent {
    @Override
    protected void renderShape(PGraphics g) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (!TdGhost.isValid || app.buildMode == TdBuildMode.NONE) return;

        float x = getTransform().getPosition().x;
        float y = getTransform().getPosition().y;

        // Tower visual size in world units (matches TowerRenderer)
        float size = TdConfig.GRID * 0.75f;

        // Color by tower type
        int ghostColor;
        switch (app.buildMode) {
            case MG:      ghostColor = 0xFF4A9EFF; break;
            case MISSILE: ghostColor = 0xFFFF643C; break;
            case LASER:   ghostColor = 0xFF3CDC78; break;
            case SLOW:    ghostColor = 0xFFC878DC; break;
            default:      ghostColor = 0xFFFFFFFF;
        }

        // Camera already applies zoom in Scene.renderWorld(), so draw in world units
        float zoom = app.camera.getZoom();
        g.noFill();
        g.stroke(ghostColor);
        g.strokeWeight(2 / zoom);  // counter-scale stroke for consistent screen width
        g.ellipse(x, y, size, size);

        // Range indicator in world units (def.range is world distance)
        TowerDef def = TdAssets.loadTowerDef(TowerType.fromBuildMode(app.buildMode));
        if (def != null) {
            g.strokeWeight(1 / zoom);
            g.stroke(0x55FFFFFF);
            g.noFill();
            g.ellipse(x, y, def.range * 2, def.range * 2);
        }
    }
}
