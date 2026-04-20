package shenyf.p5engine.math;

/**
 * Color constants and ARGB building utilities.
 * Provides Processing-style color constants without requiring a PApplet instance,
 * making them usable in static configuration classes and PDE inner classes.
 */
public final class Colors {

    // ===== Common color constants =====

    public static final int WHITE       = 0xFFFFFFFF;
    public static final int BLACK       = 0xFF000000;
    public static final int RED         = 0xFFFF0000;
    public static final int GREEN       = 0xFF00FF00;
    public static final int BLUE        = 0xFF0000FF;
    public static final int YELLOW      = 0xFFFFFF00;
    public static final int CYAN        = 0xFF00FFFF;
    public static final int MAGENTA     = 0xFFFF00FF;
    public static final int ORANGE      = 0xFFFFA500;
    public static final int PURPLE      = 0xFF800080;
    public static final int PINK        = 0xFFFFC0CB;
    public static final int GRAY        = 0xFF808080;
    public static final int DARK_GRAY   = 0xFF404040;
    public static final int LIGHT_GRAY  = 0xFFC0C0C0;
    public static final int TRANSPARENT = 0x00000000;

    private Colors() {
        // utility class
    }

    // ===== Building colors from components =====

    /**
     * Builds an opaque color from RGB components (0-255).
     */
    public static int rgb(int r, int g, int b) {
        return argb(255, r, g, b);
    }

    /**
     * Builds a color from ARGB components (0-255).
     */
    public static int argb(int a, int r, int g, int b) {
        return ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
    }

    /**
     * Builds a grayscale color (0-255).
     */
    public static int gray(int value) {
        return rgb(value, value, value);
    }

    // ===== Extracting components =====

    public static int alpha(int c) {
        return (c >> 24) & 0xFF;
    }

    public static int red(int c) {
        return (c >> 16) & 0xFF;
    }

    public static int green(int c) {
        return (c >> 8) & 0xFF;
    }

    public static int blue(int c) {
        return c & 0xFF;
    }
}
