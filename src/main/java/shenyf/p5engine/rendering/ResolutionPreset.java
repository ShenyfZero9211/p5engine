package shenyf.p5engine.rendering;

/**
 * Predefined render resolutions for the engine window.
 *
 * <p>The preset determines the initial window/framebuffer size.
 * When the window is resized or the user selects a different preset at runtime,
 * the engine adjusts the actual pixel dimensions via {@link DisplayConfig#getRenderWidth()}
 * and {@link DisplayConfig#getRenderHeight()}.
 */
public enum ResolutionPreset {
    R720  (1280, 720,  "720p"),
    R1080 (1920, 1080, "1080p"),
    R1440 (2560, 1440, "1440p"),
    R4K   (3840, 2160, "4K"),
    CUSTOM(-1,   -1,   "Custom");

    public final int width;
    public final int height;
    public final String label;

    ResolutionPreset(int width, int height, String label) {
        this.width = width;
        this.height = height;
        this.label = label;
    }

    /**
     * Returns a preset that matches the given dimensions, or {@link #CUSTOM} if no match.
     */
    public static ResolutionPreset fromSize(int w, int h) {
        for (ResolutionPreset p : values()) {
            if (p.width == w && p.height == h) {
                return p;
            }
        }
        return CUSTOM;
    }
}
