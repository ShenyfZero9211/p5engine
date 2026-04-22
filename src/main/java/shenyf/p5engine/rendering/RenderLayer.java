package shenyf.p5engine.rendering;

import processing.core.PApplet;
import processing.core.PGraphics;

import java.util.function.Consumer;

/**
 * A cached render layer that draws static content to an off-screen buffer.
 * Only rebuilds when explicitly marked dirty, saving redraw cost per frame.
 *
 * <p>Ideal for backgrounds, tilemaps, or other rarely-changing visuals.</p>
 */
public class RenderLayer {

    private PGraphics cache;
    private boolean dirty = true;
    private final int width;
    private final int height;

    public RenderLayer(int width, int height) {
        this.width = width;
        this.height = height;
    }

    /** Mark this layer as needing a rebuild before next use. */
    public void invalidate() {
        dirty = true;
    }

    public boolean isDirty() {
        return dirty;
    }

    /** Initialize or resize the internal PGraphics buffer. Call once in setup. */
    public void init(PApplet applet) {
        if (cache == null || cache.width != width || cache.height != height) {
            cache = applet.createGraphics(width, height);
        }
    }

    /**
     * Rebuild the cache by drawing through the provided callback.
     * The callback receives the layer's PGraphics for drawing.
     */
    public void rebuild(Consumer<PGraphics> drawFn) {
        if (cache == null) return;
        cache.beginDraw();
        cache.clear();
        drawFn.accept(cache);
        cache.endDraw();
        dirty = false;
    }

    /** Draw the cached layer to the target graphics. */
    public void render(PGraphics target, float x, float y) {
        if (cache != null) {
            target.image(cache, x, y);
        }
    }

    public PGraphics getCache() {
        return cache;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }
}
