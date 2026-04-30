/**
 * Camera controller: edge-scroll, clamp, mouse-in-viewport check.
 */
static final class TdCamera {

    static void updateEdgeScroll(float dt) {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam == null) return;
        TowerDefenseMin2 app = TowerDefenseMin2.inst;

        // Use actual window coordinates for consistent edge detection across all resolutions
        float mx = app.mouseX;
        float my = app.mouseY;
        int w = app.width;
        int h = app.height;

        float scrollSpeed = 400; // design pixels/sec
        float dx = 0, dy = 0;
        if (app.keyScrollLeft || mx <= 0)           dx = -scrollSpeed;
        if (app.keyScrollRight || mx >= w - 1)      dx =  scrollSpeed;
        if (app.keyScrollUp || my <= 0)             dy = -scrollSpeed;
        if (app.keyScrollDown || my >= h - 1)       dy =  scrollSpeed;

        if (dx != 0 || dy != 0) {
            cam.getTransform().translate(dx * dt / cam.getZoom(), dy * dt / cam.getZoom());
            cam.clampToBounds();
        }
    }

    static boolean isMouseInViewport() {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam == null) return false;
        // Use actual screen coordinates since camera viewport now matches full screen
        float mx = TowerDefenseMin2.inst.mouseX;
        float my = TowerDefenseMin2.inst.mouseY;
        float left   = cam.getViewportOffsetX();
        float top    = cam.getViewportOffsetY();
        float right  = left + cam.getViewportWidth();
        float bottom = top + cam.getViewportHeight();
        return mx >= left && mx <= right && my >= top && my <= bottom;
    }
}
