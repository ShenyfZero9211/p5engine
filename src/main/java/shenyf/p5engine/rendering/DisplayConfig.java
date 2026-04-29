package shenyf.p5engine.rendering;

/**
 * Configuration for display scaling, design resolution, window behavior, and resolution presets.
 *
 * <p>The <b>design resolution</b> is the reference canvas size that all game logic
 * and UI coordinates are based on. The engine automatically scales the output to
 * match the actual window size using the chosen {@link ScaleMode}.
 *
 * <p>The <b>render resolution</b> is the actual window/framebuffer pixel size,
 * controlled by {@link #resolutionPreset} (or {@link #windowedWidth}/{@link #windowedHeight}
 * when preset is {@link ResolutionPreset#CUSTOM}).
 */
public class DisplayConfig {
    // ── Design resolution (logical coordinate system) ──
    private int designWidth = 1280;
    private int designHeight = 720;

    // ── Scaling ──
    private ScaleMode scaleMode = ScaleMode.FIT;

    // ── Window / Resolution ──
    private ResolutionPreset resolutionPreset = ResolutionPreset.R1080;
    private DisplayMode displayMode = DisplayMode.WINDOWED;
    private boolean resizable = true;

    // ── Custom resolution (only used when preset == CUSTOM) ──
    private int windowedWidth = 1280;
    private int windowedHeight = 720;

    // ── Dynamic resolution (runtime selected from enumerated list) ──
    private ResolutionInfo currentResolution;

    // ── Deprecated / compatibility ──
    /** @deprecated Use {@link #displayMode} instead. */
    @Deprecated
    private boolean fullscreen = false;

    public static DisplayConfig defaults() {
        return new DisplayConfig();
    }

    // ── Design resolution fluent setters ──

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

    // ── Resolution preset ──

    public DisplayConfig resolutionPreset(ResolutionPreset preset) {
        this.resolutionPreset = preset != null ? preset : ResolutionPreset.R1080;
        return this;
    }

    // ── Display mode ──

    public DisplayConfig displayMode(DisplayMode mode) {
        this.displayMode = mode != null ? mode : DisplayMode.WINDOWED;
        return this;
    }

    // ── Custom window size (for CUSTOM preset) ──

    public DisplayConfig windowedSize(int w, int h) {
        this.windowedWidth = w;
        this.windowedHeight = h;
        return this;
    }

    /**
     * Sets a dynamically enumerated resolution.
     * This takes precedence over the fixed {@link #resolutionPreset}.
     */
    public DisplayConfig resolution(ResolutionInfo info) {
        this.currentResolution = info;
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

    public ResolutionPreset getResolutionPreset() {
        return resolutionPreset;
    }

    public DisplayMode getDisplayMode() {
        return displayMode;
    }

    /**
     * Returns the actual render width in pixels.
     * Priority: {@link #currentResolution} > {@link ResolutionPreset#CUSTOM} > preset.
     */
    public int getRenderWidth() {
        if (currentResolution != null) {
            return currentResolution.width;
        }
        return (resolutionPreset == ResolutionPreset.CUSTOM)
            ? windowedWidth
            : resolutionPreset.width;
    }

    /**
     * Returns the actual render height in pixels.
     * Priority: {@link #currentResolution} > {@link ResolutionPreset#CUSTOM} > preset.
     */
    public int getRenderHeight() {
        if (currentResolution != null) {
            return currentResolution.height;
        }
        return (resolutionPreset == ResolutionPreset.CUSTOM)
            ? windowedHeight
            : resolutionPreset.height;
    }

    public ResolutionInfo getCurrentResolution() {
        return currentResolution;
    }

    public int getWindowedWidth() {
        return windowedWidth;
    }

    public int getWindowedHeight() {
        return windowedHeight;
    }

    /** @deprecated Use {@link #getDisplayMode()} == {@link DisplayMode#EXCLUSIVE_FULLSCREEN}. */
    @Deprecated
    public boolean isFullscreen() {
        return fullscreen || displayMode == DisplayMode.EXCLUSIVE_FULLSCREEN;
    }
}
