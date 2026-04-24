package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import shenyf.p5engine.math.Rect;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.rendering.Renderable;
import shenyf.p5engine.scene.Scene;
import shenyf.p5engine.util.Logger;

import java.util.ArrayList;
import java.util.List;

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
    private boolean showPath = true;
    private boolean showBaseExit = true;

    // Colors (default values; use setColors() to override)
    private int bgColor = 0xFF151A25;
    private int borderColor = 0xFF3A506B;
    private int viewportColor = 0xFF4ADE80;
    private int objectColor = 0xFF38BDF8;
    private int pathColor = 0xFF3C5A82;
    private int baseColor = 0xFF28C840;
    private int exitColor = 0xFFFF5050;

    // Tracked object entries (name prefix -> color & size)
    public static class TrackEntry {
        public final String namePrefix;
        public final int color;
        public final float size;

        public TrackEntry(String namePrefix, int color, float size) {
            this.namePrefix = namePrefix;
            this.color = color;
            this.size = size;
        }
    }

    private final List<TrackEntry> trackedEntries = new ArrayList<>();

    // Landmark data (path, base, exit)
    private Vector2[] pathPoints;
    private Vector2 basePos;
    private Vector2 exitPos;

    public void setColors(int bg, int border, int viewport, int object) {
        this.bgColor = bg;
        this.borderColor = border;
        this.viewportColor = viewport;
        this.objectColor = object;
    }

    public void setPathColor(int c) { this.pathColor = c; }
    public void setBaseColor(int c) { this.baseColor = c; }
    public void setExitColor(int c) { this.exitColor = c; }

    public Minimap() {}

    @Override
    public void start() {
        scene = getGameObject().getScene();
        if (scene != null) {
            camera = scene.getCamera();
        }
    }

    public void setScene(Scene scene) {
        this.scene = scene;
    }

    public void setCamera(Camera2D camera) {
        this.camera = camera;
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
    public void setShowPath(boolean v) { this.showPath = v; }
    public void setShowBaseExit(boolean v) { this.showBaseExit = v; }

    // ── Tracked objects ──

    public void clearTrackedNames() {
        trackedEntries.clear();
    }

    public void addTrackedName(String namePrefix, int color, float size) {
        trackedEntries.add(new TrackEntry(namePrefix, color, size));
    }

    public List<TrackEntry> getTrackedEntries() {
        return new ArrayList<>(trackedEntries);
    }

    public void setPathPoints(Vector2[] points) {
        this.pathPoints = points;
    }

    public void setBasePosition(Vector2 pos) {
        this.basePos = pos;
    }

    public void setExitPosition(Vector2 pos) {
        this.exitPos = pos;
    }

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

        g.rectMode(PGraphics.CORNER);
        g.noStroke();

        // Background
        setFillRGBA(g, bgColor);
        g.rect(x, y, w, h);

        // World area border (4 filled strips)
        setFillRGBA(g, borderColor);
        g.rect(ox, oy, drawW, 3);
        g.rect(ox, oy + drawH - 3, drawW, 3);
        g.rect(ox, oy, 3, drawH);
        g.rect(ox + drawW - 3, oy, 3, drawH);

        // Path (polyline)
        if (showPath && pathPoints != null && pathPoints.length > 1) {
            g.noFill();
            setStrokeRGBA(g, pathColor);
            g.strokeWeight(Math.max(1, 2 * minimapScale));
            g.beginShape();
            for (Vector2 p : pathPoints) {
                float px = ox + (p.x - worldBounds.x) * minimapScale;
                float py = oy + (p.y - worldBounds.y) * minimapScale;
                g.vertex(px, py);
            }
            g.endShape();
            g.strokeWeight(1);
        }

        // Base & Exit markers
        if (showBaseExit) {
            if (basePos != null) {
                float bx = ox + (basePos.x - worldBounds.x) * minimapScale;
                float by = oy + (basePos.y - worldBounds.y) * minimapScale;
                setFillRGBA(g, baseColor);
                g.noStroke();
                g.ellipse(bx, by, 8, 8);
            }
            if (exitPos != null) {
                float ex = ox + (exitPos.x - worldBounds.x) * minimapScale;
                float ey = oy + (exitPos.y - worldBounds.y) * minimapScale;
                setFillRGBA(g, exitColor);
                g.noStroke();
                g.ellipse(ex, ey, 6, 6);
            }
        }

        // Viewport rectangle (outline only, RTS-style)
        if (showViewportRect && camera != null) {
            Rect vp = camera.getViewport();
            float vx = ox + (vp.x - worldBounds.x) * minimapScale;
            float vy = oy + (vp.y - worldBounds.y) * minimapScale;
            float vw = Math.max(4, vp.width * minimapScale);
            float vh = Math.max(4, vp.height * minimapScale);
            // Clamp viewport rect inside the actual map drawing area
            vx = Math.max(ox, Math.min(ox + drawW - vw, vx));
            vy = Math.max(oy, Math.min(oy + drawH - vh, vy));
            g.noFill();
            setStrokeRGBA(g, viewportColor);
            g.rect(vx, vy, vw, vh);
            // Logger.debug("Minimap", String.format("viewport rect vp=(%.0f,%.0f %.0fx%.0f) mm=(%.1f,%.1f %.1fx%.1f) scale=%.4f",
            //     vp.x, vp.y, vp.width, vp.height, vx, vy, vw, vh, minimapScale));
        }

        // Objects (tracked by name prefix)
        if (showObjects && scene != null) {
            g.noStroke();
            for (TrackEntry entry : trackedEntries) {
                setFillRGBA(g, entry.color);
                for (GameObject go : scene.getGameObjects()) {
                    if (!go.isActive()) continue;
                    if (go.getName().startsWith(entry.namePrefix)) {
                        Vector2 pos = go.getTransform().getPosition();
                        float mx = ox + (pos.x - worldBounds.x) * minimapScale;
                        float my = oy + (pos.y - worldBounds.y) * minimapScale;
                        float hs = entry.size * 0.5f;
                        g.rect(mx - hs, my - hs, entry.size, entry.size);
                    }
                }
            }
        }
    }

    /** P2D compatible ARGB fill using 4-float overload. */
    private static void setFillRGBA(PGraphics g, int c) {
        float r = ((c >> 16) & 0xFF);
        float gr = ((c >> 8) & 0xFF);
        float b = (c & 0xFF);
        float a = ((c >> 24) & 0xFF);
        g.fill(r, gr, b, a);
    }

    /** P2D compatible ARGB stroke using 4-float overload. */
    private static void setStrokeRGBA(PGraphics g, int c) {
        float r = ((c >> 16) & 0xFF);
        float gr = ((c >> 8) & 0xFF);
        float b = (c & 0xFF);
        float a = ((c >> 24) & 0xFF);
        g.stroke(r, gr, b, a);
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

        Vector2 result = new Vector2(
            worldBounds.x + nx * worldBounds.width,
            worldBounds.y + ny * worldBounds.height
        );
        Logger.debug("Minimap", String.format("minimapToWorld design=(%.1f,%.1f) mm=(%.1f,%.1f) norm=(%.3f,%.3f) world=(%.1f,%.1f)",
            designX, designY, ox, oy, nx, ny, result.x, result.y));
        return result;
    }
}
