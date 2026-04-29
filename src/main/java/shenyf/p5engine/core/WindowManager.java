package shenyf.p5engine.core;

import processing.core.PApplet;
import shenyf.p5engine.rendering.DisplayMode;
import shenyf.p5engine.rendering.ResolutionInfo;
import shenyf.p5engine.rendering.ResolutionPreset;
import shenyf.p5engine.util.Logger;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Runtime window mode and resolution management for p5engine.
 *
 * <p>Provides fullscreen toggling, resolution switching, and window positioning
 * via JOGL/NEWT reflection. Works with P2D/P3D (JOGL GLWindow) renderers.
 * JAVA2D renderer support is limited to resolution changes via AWT Frame.</p>
 */
public class WindowManager {

    private final PApplet applet;
    private final P5Config config;
    private Object nativeSurface;
    private boolean isJOGL;

    // Saved windowed state for restore after fullscreen
    private int savedX = -1;
    private int savedY = -1;
    private int savedW = -1;
    private int savedH = -1;
    private boolean savedDecorated = true;

    private DisplayMode currentMode = DisplayMode.WINDOWED;

    public WindowManager(PApplet applet, P5Config config) {
        this.applet = applet;
        this.config = config;
        this.currentMode = config.getDisplayConfig().getDisplayMode();
        cacheNativeSurface();
    }

    private void cacheNativeSurface() {
        try {
            this.nativeSurface = applet.getSurface().getNative();
            if (nativeSurface != null) {
                String clsName = nativeSurface.getClass().getName();
                this.isJOGL = clsName.contains("newt") || clsName.contains("jogamp");
            }
        } catch (Exception e) {
            Logger.debug("WindowManager: could not cache native surface: " + e.getMessage());
        }
    }

    // ========================================================================
    //  Public API
    // ========================================================================

    /**
     * Switches between windowed and fullscreen (borderless preferred).
     * If current mode is windowed, switches to borderless fullscreen.
     * If current mode is any fullscreen, switches back to windowed.
     */
    public void toggleFullscreen() {
        if (isFullscreen()) {
            setDisplayMode(DisplayMode.WINDOWED);
        } else {
            setDisplayMode(DisplayMode.BORDERLESS_FULLSCREEN);
        }
    }

    /**
     * Sets the display mode and applies it immediately.
     *
     * @param mode the desired display mode
     */
    public void setDisplayMode(DisplayMode mode) {
        if (mode == null) mode = DisplayMode.WINDOWED;
        if (mode == currentMode) return;

        Logger.info("WindowManager: switching display mode " + currentMode + " -> " + mode);

        switch (mode) {
            case WINDOWED:
                restoreWindowed();
                break;
            case BORDERLESS_FULLSCREEN:
                if (!applyBorderlessFullscreen()) {
                    Logger.warn("WindowManager: borderless fullscreen failed, keeping windowed mode");
                    // Do NOT fall back to exclusive fullscreen on Windows/JOGL
                    // as it causes the window to disappear. Stay in current mode.
                    return;
                }
                break;
            case EXCLUSIVE_FULLSCREEN:
                applyExclusiveFullscreen();
                break;
        }
        this.currentMode = mode;
    }

    public DisplayMode getDisplayMode() {
        return currentMode;
    }

    public boolean isFullscreen() {
        return currentMode == DisplayMode.BORDERLESS_FULLSCREEN
            || currentMode == DisplayMode.EXCLUSIVE_FULLSCREEN;
    }

    /**
     * Returns the windowed size saved before entering fullscreen.
     * Returns {-1, -1} if no state was saved.
     */
    public int[] getSavedWindowSize() {
        return new int[]{savedW, savedH};
    }

    /**
     * Returns the windowed position saved before entering fullscreen.
     * Returns {-1, -1} if no state was saved.
     */
    public int[] getSavedWindowPosition() {
        return new int[]{savedX, savedY};
    }

    /**
     * Sets the window size at runtime via NEWT reflection.
     * Processing will automatically trigger {@code windowResize()}.
     *
     * @param w new width in pixels
     * @param h new height in pixels
     */
    public void setWindowSize(int w, int h) {
        if (w < 1 || h < 1) return;
        if (isJOGL && nativeSurface != null) {
            try {
                java.lang.reflect.Method setSize = nativeSurface.getClass().getMethod("setSize", int.class, int.class);
                setSize.invoke(nativeSurface, w, h);
                Logger.info("WindowManager: set window size " + w + "x" + h);
            } catch (Exception e) {
                Logger.warn("WindowManager: setWindowSize failed: " + e.getMessage());
            }
        } else {
            // JAVA2D fallback: try AWT Frame
            java.awt.Frame frame = getAwtFrame();
            if (frame != null) {
                frame.setSize(w, h);
                Logger.info("WindowManager: set AWT frame size " + w + "x" + h);
            }
        }
    }

    /**
     * Changes the render resolution preset and resizes the window to match.
     *
     * @param preset the resolution preset
     */
    public void setResolution(ResolutionPreset preset) {
        if (preset == null) return;
        int w = preset.width;
        int h = preset.height;
        if (w > 0 && h > 0) {
            setWindowSize(w, h);
        }
    }

    /**
     * Returns the primary screen size as {@code int[]{width, height}}.
     */
    public static int[] getScreenSize() {
        try {
            java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
            java.awt.GraphicsDevice device = ge.getDefaultScreenDevice();
            java.awt.DisplayMode dm = device.getDisplayMode();
            return new int[] { dm.getWidth(), dm.getHeight() };
        } catch (Exception e) {
            Logger.warn("WindowManager: failed to get screen size: " + e.getMessage());
            return new int[] { 1920, 1080 };
        }
    }

    /**
     * Enumerates all available display resolutions from the primary graphics device.
     * Returns a deduplicated, sorted list from lowest to highest resolution.
     */
    public static List<ResolutionInfo> listAvailableResolutions() {
        List<ResolutionInfo> result = new ArrayList<>();
        try {
            java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
            java.awt.GraphicsDevice device = ge.getDefaultScreenDevice();
            java.awt.DisplayMode[] modes = device.getDisplayModes();
            for (java.awt.DisplayMode dm : modes) {
                int w = dm.getWidth();
                int h = dm.getHeight();
                if (w < 640 || h < 480) continue; // Filter out unusable tiny modes
                ResolutionInfo info = new ResolutionInfo(w, h, dm.getRefreshRate(), dm.getBitDepth());
                if (!result.contains(info)) {
                    result.add(info);
                }
            }
            result.sort(Comparator.<ResolutionInfo>comparingInt(r -> r.width)
                .thenComparingInt(r -> r.height)
                .thenComparingInt(r -> r.refreshRate));
        } catch (Exception e) {
            Logger.warn("WindowManager: failed to enumerate resolutions: " + e.getMessage());
        }
        return result;
    }

    /**
     * Applies a specific resolution at runtime.
     * Works in both windowed and fullscreen modes.
     *
     * @param info the resolution to apply
     */
    public void applyResolution(ResolutionInfo info) {
        if (info == null) return;
        Logger.info("WindowManager: applying resolution " + info.width + "x" + info.height);
        setWindowSize(info.width, info.height);
    }

    /**
     * Returns the current window position as {x, y}.
     * Returns {-1, -1} if the position cannot be determined.
     */
    public int[] getWindowPosition() {
        if (isJOGL && nativeSurface != null) {
            try {
                java.lang.reflect.Method getX = nativeSurface.getClass().getMethod("getX");
                java.lang.reflect.Method getY = nativeSurface.getClass().getMethod("getY");
                int x = (Integer) getX.invoke(nativeSurface);
                int y = (Integer) getY.invoke(nativeSurface);
                return new int[]{x, y};
            } catch (Exception e) {
                Logger.debug("WindowManager: getWindowPosition failed: " + e.getMessage());
            }
        }
        java.awt.Frame frame = getAwtFrame();
        if (frame != null) {
            java.awt.Rectangle b = frame.getBounds();
            return new int[]{b.x, b.y};
        }
        return new int[]{-1, -1};
    }

    /**
     * Recenters the window on the primary display.
     * Delegates to {@link P5Engine#centerWindow()} if available.
     */
    public void centerWindow() {
        if (isJOGL && nativeSurface != null) {
            try {
                java.lang.reflect.Method getScreen = nativeSurface.getClass().getMethod("getScreen");
                Object screen = getScreen.invoke(nativeSurface);
                if (screen != null) {
                    int screenW = (Integer) screen.getClass().getMethod("getWidth").invoke(screen);
                    int screenH = (Integer) screen.getClass().getMethod("getHeight").invoke(screen);
                    int winW = applet.width > 0 ? applet.width : config.getWidth();
                    int winH = applet.height > 0 ? applet.height : config.getHeight();
                    int x = (screenW - winW) / 2;
                    int y = (screenH - winH) / 2;
                    java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                    setPosition.invoke(nativeSurface, x, y);
                    Logger.info("WindowManager: centered window at " + x + "," + y);
                }
            } catch (Exception e) {
                Logger.debug("WindowManager: centerWindow failed: " + e.getMessage());
            }
        }
    }

    // ========================================================================
    //  Internal implementation
    // ========================================================================

    private boolean applyBorderlessFullscreen() {
        if (!isJOGL || nativeSurface == null) {
            applyExclusiveFullscreen();
            return true;
        }
        try {
            // Save current windowed state
            saveWindowedState();

            // Get screen dimensions
            java.lang.reflect.Method getScreen = nativeSurface.getClass().getMethod("getScreen");
            Object screen = getScreen.invoke(nativeSurface);
            if (screen == null) return false;
            int screenW = (Integer) screen.getClass().getMethod("getWidth").invoke(screen);
            int screenH = (Integer) screen.getClass().getMethod("getHeight").invoke(screen);

            // Undecorate (may fail on some platforms at runtime)
            try {
                java.lang.reflect.Method setUndecorated = nativeSurface.getClass().getMethod("setUndecorated", boolean.class);
                setUndecorated.invoke(nativeSurface, true);
                savedDecorated = false;
            } catch (Exception e) {
                Logger.debug("WindowManager: setUndecorated not available or failed: " + e.getMessage());
                savedDecorated = true;
            }

            // Size to full screen — this is the critical step
            try {
                java.lang.reflect.Method setSize = nativeSurface.getClass().getMethod("setSize", int.class, int.class);
                setSize.invoke(nativeSurface, screenW, screenH);
            } catch (Exception e) {
                Logger.warn("WindowManager: setSize failed: " + e.getMessage());
                return false;
            }

            // Move to top-left corner to ensure window covers entire screen
            try {
                java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                setPosition.invoke(nativeSurface, 0, 0);
            } catch (Exception e) {
                Logger.debug("WindowManager: setPosition failed: " + e.getMessage());
            }

            Logger.info("WindowManager: borderless fullscreen " + screenW + "x" + screenH + " @ 0,0");
            return true;
        } catch (Exception e) {
            Logger.warn("WindowManager: applyBorderlessFullscreen failed: " + e.getMessage());
            return false;
        }
    }

    private boolean applyExclusiveFullscreen() {
        if (!isJOGL || nativeSurface == null) {
            Logger.warn("WindowManager: exclusive fullscreen not supported without JOGL");
            return false;
        }
        try {
            saveWindowedState();
            java.lang.reflect.Method setFullscreen = nativeSurface.getClass().getMethod("setFullscreen", boolean.class);
            setFullscreen.invoke(nativeSurface, true);
            Logger.info("WindowManager: exclusive fullscreen enabled");
            return true;
        } catch (Exception e) {
            Logger.warn("WindowManager: applyExclusiveFullscreen failed: " + e.getMessage());
            return false;
        }
    }

    private void restoreWindowed() {
        if (!isJOGL || nativeSurface == null) {
            restoreAwtWindowed();
            return;
        }
        try {
            // If we were in exclusive fullscreen, disable it first
            if (currentMode == DisplayMode.EXCLUSIVE_FULLSCREEN) {
                try {
                    java.lang.reflect.Method setFullscreen = nativeSurface.getClass().getMethod("setFullscreen", boolean.class);
                    setFullscreen.invoke(nativeSurface, false);
                } catch (Exception e) {
                    Logger.debug("WindowManager: disabling exclusive fullscreen failed: " + e.getMessage());
                }
            }

            // Restore decoration if we removed it
            if (!savedDecorated) {
                try {
                    java.lang.reflect.Method setUndecorated = nativeSurface.getClass().getMethod("setUndecorated", boolean.class);
                    setUndecorated.invoke(nativeSurface, true); // must re-apply true before false on some platforms
                    setUndecorated.invoke(nativeSurface, false);
                } catch (Exception e) {
                    Logger.debug("WindowManager: setUndecorated restore failed: " + e.getMessage());
                }
            }

            // Restore size
            if (savedW > 0 && savedH > 0) {
                try {
                    java.lang.reflect.Method setSize = nativeSurface.getClass().getMethod("setSize", int.class, int.class);
                    setSize.invoke(nativeSurface, savedW, savedH);
                } catch (Exception e) {
                    Logger.warn("WindowManager: restore size failed: " + e.getMessage());
                }
            }

            // Restore position
            if (savedX >= 0 && savedY >= 0) {
                try {
                    java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                    setPosition.invoke(nativeSurface, savedX, savedY);
                } catch (Exception e) {
                    Logger.debug("WindowManager: restore position failed: " + e.getMessage());
                    centerWindow();
                }
            } else {
                centerWindow();
            }

            Logger.info("WindowManager: restored windowed mode " + savedW + "x" + savedH + " @ " + savedX + "," + savedY);
        } catch (Exception e) {
            Logger.warn("WindowManager: restoreWindowed failed: " + e.getMessage());
        }
    }

    private void saveWindowedState() {
        if (!isJOGL || nativeSurface == null) {
            saveAwtState();
            return;
        }
        try {
            java.lang.reflect.Method getX = nativeSurface.getClass().getMethod("getX");
            java.lang.reflect.Method getY = nativeSurface.getClass().getMethod("getY");
            savedX = (Integer) getX.invoke(nativeSurface);
            savedY = (Integer) getY.invoke(nativeSurface);
            savedW = applet.width;
            savedH = applet.height;
            Logger.debug("WindowManager: saved windowed state " + savedW + "x" + savedH + " @ " + savedX + "," + savedY);
        } catch (Exception e) {
            Logger.debug("WindowManager: saveWindowedState failed: " + e.getMessage());
            savedW = config.getWidth();
            savedH = config.getHeight();
            savedX = -1;
            savedY = -1;
        }
    }

    // ========================================================================
    //  JAVA2D AWT fallback
    // ========================================================================

    private java.awt.Frame getAwtFrame() {
        try {
            Object nativeObj = applet.getSurface().getNative();
            if (nativeObj == null) return null;
            if (nativeObj instanceof java.awt.Frame) {
                return (java.awt.Frame) nativeObj;
            }
            // SmoothCanvas wrapper
            if (nativeObj.getClass().getSimpleName().contains("SmoothCanvas")) {
                java.lang.reflect.Method m = nativeObj.getClass().getMethod("getFrame");
                Object frame = m.invoke(nativeObj);
                if (frame instanceof java.awt.Frame) {
                    return (java.awt.Frame) frame;
                }
            }
        } catch (Exception e) {
            Logger.debug("WindowManager: getAwtFrame failed: " + e.getMessage());
        }
        return null;
    }

    private void saveAwtState() {
        java.awt.Frame frame = getAwtFrame();
        if (frame != null) {
            java.awt.Rectangle b = frame.getBounds();
            savedX = b.x;
            savedY = b.y;
            savedW = b.width;
            savedH = b.height;
        } else {
            savedW = config.getWidth();
            savedH = config.getHeight();
            savedX = -1;
            savedY = -1;
        }
    }

    private void restoreAwtWindowed() {
        java.awt.Frame frame = getAwtFrame();
        if (frame == null) return;
        frame.dispose();
        frame.setUndecorated(false);
        if (savedW > 0 && savedH > 0) {
            frame.setSize(savedW, savedH);
        }
        if (savedX >= 0 && savedY >= 0) {
            frame.setLocation(savedX, savedY);
        }
        frame.setVisible(true);
    }
}
