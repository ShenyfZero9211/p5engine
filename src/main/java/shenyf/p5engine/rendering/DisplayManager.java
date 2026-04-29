package shenyf.p5engine.rendering;

import shenyf.p5engine.math.Rect;
import shenyf.p5engine.math.Vector2;

/**
 * Manages the mapping between design resolution and actual window size.
 *
 * <p>Call {@link #onWindowResize(int, int)} when the Processing window changes size
 * (e.g. from {@code windowResize()} in the sketch). The manager then recalculates
 * scale factors and letterbox offsets so that rendering can be applied automatically.
 */
public class DisplayManager {
    private final DisplayConfig config;
    private ScaleMode scaleMode;
    private int actualWidth;
    private int actualHeight;

    private float scaleX = 1f;
    private float scaleY = 1f;
    private float uniformScale = 1f;
    private float offsetX = 0f;
    private float offsetY = 0f;

    public DisplayManager(DisplayConfig config, int initialWidth, int initialHeight) {
        this.config = config;
        this.scaleMode = config.getScaleMode();
        this.actualWidth = initialWidth;
        this.actualHeight = initialHeight;
        recalculate();
    }

    /**
     * Notify the manager that the window has been resized.
     * This is typically called from the sketch's {@code windowResize()} callback.
     */
    public void onWindowResize(int w, int h) {
        this.actualWidth = w;
        this.actualHeight = h;
        recalculate();
    }

    private void recalculate() {
        int dw = config.getDesignWidth();
        int dh = config.getDesignHeight();

        switch (scaleMode) {
            case NO_SCALE:
                scaleX = scaleY = uniformScale = 1f;
                offsetX = offsetY = 0f;
                break;

            case STRETCH:
                scaleX = (float) actualWidth / dw;
                scaleY = (float) actualHeight / dh;
                uniformScale = 1f;
                offsetX = offsetY = 0f;
                break;

            case FIT:
                uniformScale = Math.min((float) actualWidth / dw, (float) actualHeight / dh);
                scaleX = scaleY = uniformScale;
                offsetX = (actualWidth - dw * uniformScale) / 2f;
                offsetY = (actualHeight - dh * uniformScale) / 2f;
                break;

            case FILL:
                uniformScale = Math.max((float) actualWidth / dw, (float) actualHeight / dh);
                scaleX = scaleY = uniformScale;
                offsetX = (actualWidth - dw * uniformScale) / 2f;
                offsetY = (actualHeight - dh * uniformScale) / 2f;
                break;
        }
    }

    // ── Render-space helpers ──

    /**
     * Apply the display scaling transform to the renderer.
     * Must be paired with {@link #end(IRenderer)}.
     */
    public void begin(IRenderer renderer) {
        if (config.getScaleMode() == ScaleMode.NO_SCALE) return;

        renderer.pushTransform();
        renderer.translate(offsetX, offsetY);
        renderer.scale(scaleX, scaleY);
    }

    /**
     * Restore the renderer transform after display scaling.
     */
    public void end(IRenderer renderer) {
        if (config.getScaleMode() == ScaleMode.NO_SCALE) return;
        renderer.popTransform();
    }

    // ── Coordinate conversion ──

    /** Convert a design-resolution point to actual screen pixels. */
    public Vector2 designToActual(Vector2 designPos) {
        return new Vector2(
            designPos.x * scaleX + offsetX,
            designPos.y * scaleY + offsetY
        );
    }

    /** Convert actual screen pixels to a design-resolution point. */
    public Vector2 actualToDesign(Vector2 actualPos) {
        return new Vector2(
            (actualPos.x - offsetX) / scaleX,
            (actualPos.y - offsetY) / scaleY
        );
    }

    // ── Getters ──

    public float getScaleX() {
        return scaleX;
    }

    public float getScaleY() {
        return scaleY;
    }

    public float getUniformScale() {
        return uniformScale;
    }

    public float getOffsetX() {
        return offsetX;
    }

    public float getOffsetY() {
        return offsetY;
    }

    public int getActualWidth() {
        return actualWidth;
    }

    public int getActualHeight() {
        return actualHeight;
    }

    public int getDesignWidth() {
        return config.getDesignWidth();
    }

    public int getDesignHeight() {
        return config.getDesignHeight();
    }

    public ScaleMode getScaleMode() {
        return scaleMode;
    }

    /**
     * Change the scale mode at runtime and recalculate immediately.
     */
    public void setScaleMode(ScaleMode mode) {
        this.scaleMode = mode;
        recalculate();
    }

    /**
     * Returns the current uniform scale factor (minimum of scaleX and scaleY).
     * This is the factor that maps design-resolution units to actual screen pixels.
     */
    public float getRenderScale() {
        return uniformScale;
    }

    // ── SafeArea & WorldArea ──

    /**
     * Returns the safe area rectangle in screen pixels.
     * This is the region where UI rendered with FIT scaling is visible.
     * For NO_SCALE/STRETCH modes, this equals the full window.
     */
    public Rect getSafeAreaRect() {
        switch (scaleMode) {
            case FIT:
                return new Rect(offsetX, offsetY,
                    config.getDesignWidth() * uniformScale,
                    config.getDesignHeight() * uniformScale);
            case FILL:
                return new Rect(offsetX, offsetY,
                    config.getDesignWidth() * uniformScale,
                    config.getDesignHeight() * uniformScale);
            case NO_SCALE:
            case STRETCH:
            default:
                return new Rect(0, 0, actualWidth, actualHeight);
        }
    }

    /**
     * Returns the full window area in screen pixels.
     * This is where the world layer renders (no black bars).
     */
    public Rect getWorldAreaRect() {
        return new Rect(0, 0, actualWidth, actualHeight);
    }

    /** Convert a screen pixel point to design-resolution coordinates. */
    public Vector2 screenToDesign(Vector2 screenPos) {
        return actualToDesign(screenPos);
    }

    /** Convert a design-resolution point to screen pixel coordinates. */
    public Vector2 designToScreen(Vector2 designPos) {
        return designToActual(designPos);
    }

    /**
     * Returns true if scaling is active (i.e. scale mode is not NO_SCALE and
     * the actual window size differs from the design resolution).
     */
    public boolean isScaleActive() {
        return scaleMode != ScaleMode.NO_SCALE
            && (actualWidth != getDesignWidth() || actualHeight != getDesignHeight());
    }
}
