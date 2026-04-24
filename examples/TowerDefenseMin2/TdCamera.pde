/**
 * Camera controller: edge-scroll, clamp, mouse-in-viewport check.
 */
static final class TdCamera {

    static void updateEdgeScroll(float dt) {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam == null) return;
        Vector2 dm = TowerDefenseMin2.inst.engine.getDisplayManager().actualToDesign(
            new Vector2(TowerDefenseMin2.inst.mouseX, TowerDefenseMin2.inst.mouseY));

        float scrollSpeed = 400; // design pixels/sec
        float margin = 24;
        // Use full design window edges, not just the world viewport
        float left   = 0;
        float top    = 0;
        float right  = TdConfig.DESIGN_W;
        float bottom = TdConfig.DESIGN_H;

        float dx = 0, dy = 0;
        if (TowerDefenseMin2.inst.keyScrollLeft || dm.x < left + margin)  dx = -scrollSpeed;
        if (TowerDefenseMin2.inst.keyScrollRight || dm.x > right - margin) dx = scrollSpeed;
        if (TowerDefenseMin2.inst.keyScrollUp || dm.y < top + margin)    dy = -scrollSpeed;
        if (TowerDefenseMin2.inst.keyScrollDown || dm.y > bottom - margin) dy = scrollSpeed;

        if (dx != 0 || dy != 0) {
            cam.getTransform().translate(dx * dt / cam.getZoom(), dy * dt / cam.getZoom());
            cam.clampToBounds();
        }
    }

    static boolean isMouseInViewport() {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam == null) return false;
        Vector2 dm = TowerDefenseMin2.inst.engine.getDisplayManager().actualToDesign(
            new Vector2(TowerDefenseMin2.inst.mouseX, TowerDefenseMin2.inst.mouseY));
        float left   = cam.getViewportOffsetX();
        float top    = cam.getViewportOffsetY();
        float right  = left + cam.getViewportWidth();
        float bottom = top + cam.getViewportHeight();
        return dm.x >= left && dm.x <= right && dm.y >= top && dm.y <= bottom;
    }
}
