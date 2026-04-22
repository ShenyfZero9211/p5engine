package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import shenyf.p5engine.math.Rect;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.rendering.Renderable;
import shenyf.p5engine.scene.Scene;

/**
 * A screen-space minimap that shows a simplified overview of the world,
 * the current camera viewport, and key objects.
 *
 * <p>Place the host GameObject on {@code renderLayer >= 100} so it renders
 * in screen space (unaffected by {@link Camera2D}).
 *
 * <p>All coordinates ({@code x, y, w, h}) are in <b>design-resolution</b> space
 * and are automatically scaled by {@link DisplayManager}.
 */
public class Minimap extends Component implements Renderable {

    private Rect worldBounds;
    private float x, y, w, h;

    // Cached references (resolved in start())
    private Scene scene;
    private Camera2D camera;

    // Visual toggles
    private boolean showViewportRect = true;
    private boolean showObjects = true;

    // Colors (default values; use setColors() to override)
    private int bgColor = 0xC80A0A0A;
    private int borderColor = 0xFF373737;
    private int viewportColor = 0xFF78FF78;
    private int objectColor = 0xFF50C8FF;

    public void setColors(int bg, int border, int viewport, int object) {
        this.bgColor = bg;
        this.borderColor = border;
        this.viewportColor = viewport;
        this.objectColor = object;
    }

    public Minimap() {}

    @Override
    public void start() {
        scene = getGameObject().getScene();
        if (scene != null) {
            camera = scene.getCamera();
        }
    }

    // ── Configuration ──

    public void setWorldBounds(Rect bounds) {
        this.worldBounds = bounds;
    }

    public Rect getWorldBounds() {
        return worldBounds;
    }

    public void setRect(float x, float y, float w, float h) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }

    public float getX() { return x; }
    public float getY() { return y; }
    public float getW() { return w; }
    public float getH() { return h; }

    public void setShowViewportRect(boolean v) { this.showViewportRect = v; }
    public void setShowObjects(boolean v) { this.showObjects = v; }

    // ── Render ──

    @Override
    public void render(IRenderer renderer) {
        if (worldBounds == null) return;

        PGraphics g = renderer.getGraphics();

        float scaleX = w / worldBounds.width;
        float scaleY = h / worldBounds.height;
        float minimapScale = Math.min(scaleX, scaleY);

        float drawW = worldBounds.width * minimapScale;
        float drawH = worldBounds.height * minimapScale;
        float ox = x + (w - drawW) * 0.5f;
        float oy = y + (h - drawH) * 0.5f;

        // Use 3-arg fill() to avoid P2D fill(int) issues.
        // NOTE: g.pushStyle()/popStyle() disabled for P2D compatibility test.
        g.rectMode(PGraphics.CORNER);
        g.noStroke();

        // Background
        setFillRGB(g, bgColor);
        g.rect(x, y, w, h);

        // World area border (4 filled strips)
        setFillRGB(g, borderColor);
        g.rect(ox, oy, drawW, 3);
        g.rect(ox, oy + drawH - 3, drawW, 3);
        g.rect(ox, oy, 3, drawH);
        g.rect(ox + drawW - 3, oy, 3, drawH);

        // Viewport rectangle
        if (showViewportRect && camera != null) {
            Rect vp = camera.getViewport();
            float vx = ox + (vp.x - worldBounds.x) * minimapScale;
            float vy = oy + (vp.y - worldBounds.y) * minimapScale;
            float vw = Math.max(4, vp.width * minimapScale);
            float vh = Math.max(4, vp.height * minimapScale);
            setFillRGB(g, viewportColor);
            g.rect(vx, vy, vw, vh);
        }

        // Objects
        if (showObjects && scene != null) {
            setFillRGB(g, objectColor);
            for (GameObject go : scene.getGameObjects()) {
                if (!go.isActive()) continue;
                if (go.getName().equals("ship")) {
                    Vector2 pos = go.getTransform().getPosition();
                    float mx = ox + (pos.x - worldBounds.x) * minimapScale;
                    float my = oy + (pos.y - worldBounds.y) * minimapScale;
                    g.rect(mx - 4, my - 4, 9, 9);
                }
            }
        }
    }

    /** P2D's fill(int) is unreliable with negative ARGB values; use 3-float fill instead. */
    private static void setFillRGB(PGraphics g, int c) {
        float r = ((c >> 16) & 0xFF);
        float gr = ((c >> 8) & 0xFF);
        float b = (c & 0xFF);
        g.fill(r, gr, b);
    }

    // ── Interaction ──

    /**
     * Check whether a design-resolution point lies inside the minimap widget.
     */
    public boolean contains(float designX, float designY) {
        return designX >= x && designX <= x + w && designY >= y && designY <= y + h;
    }

    /**
     * Convert a design-resolution point inside the minimap to world coordinates.
     *
     * @param designX design-resolution X (e.g. from {@link DisplayManager#actualToDesign})
     * @param designY design-resolution Y
     * @return world position; clamped to the world bounds
     */
    public Vector2 minimapToWorld(float designX, float designY) {
        if (worldBounds == null) return new Vector2(0, 0);

        float scaleX = w / worldBounds.width;
        float scaleY = h / worldBounds.height;
        float minimapScale = Math.min(scaleX, scaleY);

        float drawW = worldBounds.width * minimapScale;
        float drawH = worldBounds.height * minimapScale;
        float ox = x + (w - drawW) * 0.5f;
        float oy = y + (h - drawH) * 0.5f;

        float nx = (designX - ox) / Math.max(1f, drawW);
        float ny = (designY - oy) / Math.max(1f, drawH);
        nx = Math.max(0f, Math.min(1f, nx));
        ny = Math.max(0f, Math.min(1f, ny));

        return new Vector2(
            worldBounds.x + nx * worldBounds.width,
            worldBounds.y + ny * worldBounds.height
        );
    }
}
