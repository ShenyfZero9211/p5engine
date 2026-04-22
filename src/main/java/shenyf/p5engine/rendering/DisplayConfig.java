package shenyf.p5engine.rendering;

/**
 * Configuration for display scaling, design resolution, and window behavior.
 *
 * <p>The <b>design resolution</b> is the reference canvas size that all game logic
 * and UI coordinates are based on. The engine automatically scales the output to
 * match the actual window size using the chosen {@link ScaleMode}.
 */
public class DisplayConfig {
    private int designWidth = 1920;
    private int designHeight = 1080;
    private ScaleMode scaleMode = ScaleMode.FIT;
    private boolean resizable = true;
    private boolean fullscreen = false;
    private int windowedWidth = 1280;
    private int windowedHeight = 720;

    public static DisplayConfig defaults() {
        return new DisplayConfig();
    }

    public DisplayConfig designWidth(int w) {
        this.designWidth = w;
        return this;
    }

    public DisplayConfig designHeight(int h) {
        this.designHeight = h;
        return this;
    }

    public DisplayConfig scaleMode(ScaleMode mode) {
        this.scaleMode = mode;
        return this;
    }

    public DisplayConfig resizable(boolean v) {
        this.resizable = v;
        return this;
    }

    public DisplayConfig fullscreen(boolean v) {
        this.fullscreen = v;
        return this;
    }

    public DisplayConfig windowedSize(int w, int h) {
        this.windowedWidth = w;
        this.windowedHeight = h;
        return this;
    }

    // ── Getters ──

    public int getDesignWidth() {
        return designWidth;
    }

    public int getDesignHeight() {
        return designHeight;
    }

    public ScaleMode getScaleMode() {
        return scaleMode;
    }

    public boolean isResizable() {
        return resizable;
    }

    public boolean isFullscreen() {
        return fullscreen;
    }

    public int getWindowedWidth() {
        return windowedWidth;
    }

    public int getWindowedHeight() {
        return windowedHeight;
    }
}
