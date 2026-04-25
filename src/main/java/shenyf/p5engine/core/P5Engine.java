package shenyf.p5engine.core;

import processing.core.PApplet;
import processing.core.PSurface;
import shenyf.p5engine.config.SketchConfig;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.time.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.input.InputManager;
import shenyf.p5engine.event.EventSystem;
import shenyf.p5engine.pool.ObjectPool;
import shenyf.p5engine.pool.GenericObjectPool;
import shenyf.p5engine.tween.TweenManager;
import shenyf.p5engine.Constants;
import shenyf.p5engine.util.Logger;
import shenyf.p5engine.util.SingleInstanceGuard;
import shenyf.p5engine.util.ScreenshotTool;
import shenyf.p5engine.audio.AudioManager;
import shenyf.p5engine.debug.DebugOverlay;
import shenyf.p5engine.i18n.I18n;
import java.awt.Frame;
import java.util.ArrayList;
import java.util.List;
import javax.swing.JOptionPane;

import shenyf.p5engine.GameState;

public class P5Engine {
    private static P5Engine instance;

    private final PApplet applet;
    private final P5Config config;
    private final SceneManager sceneManager;
    private final P5GameTime gameTime;
    private final ProcessingRenderer renderer;
    private final InputManager inputManager;
    private final shenyf.p5engine.time.Scheduler scheduler;
    private final EventSystem eventSystem;
    private final ObjectPool objectPool;
    private final TweenManager tweenManager;
    private final SketchConfig sketchConfig;
    private final SingleInstanceGuard singleInstanceGuard;
    private final DebugOverlay debugOverlay;
    private final AudioManager audioManager;
    private final I18n i18n;
    private shenyf.p5engine.rendering.PostProcessor postProcessor;
    private shenyf.p5engine.rendering.DisplayManager displayManager;

    private final List<Runnable> onDisposeListeners = new ArrayList<>();
    private float lastMouseX;
    private float lastMouseY;

    /** Cached native surface (JOGL GLWindow or AWT Frame) for mouse confinement. */
    private Object nativeSurface;

    private boolean isRunning;
    private long lastFrameTime;


    private boolean keyPressedState;
    private char keyChar;
    private int keyCode;
    private boolean mouseConfinedEnabled;
    private boolean wasFocused = true;
    private boolean windowPositionApplied;

    private int defaultBackgroundColor = 0xFF000000;
    private GameState gameState = GameState.READY;

    /** Human-readable window title prefix (no FPS / version suffix). */
    private String applicationTitleBase;
    /** Sketch release string shown as {@code | v …}; null omits that segment. */
    private String sketchVersion;
    private String lastComposedWindowTitle;

    private P5Engine(PApplet applet, P5Config config) {
        this.applet = applet;
        this.config = config;
        this.sketchConfig = new SketchConfig(applet);
        this.singleInstanceGuard = new SingleInstanceGuard(sketchConfig.get(SketchConfig.SECTION_P5ENGINE, SketchConfig.KEY_NAME, "p5engine"));
        this.sceneManager = new SceneManager();
        this.gameTime = new P5GameTime();
        this.renderer = new ProcessingRenderer(applet, config.getWidth(), config.getHeight());
        this.inputManager = new InputManager();
        this.scheduler = new shenyf.p5engine.time.Scheduler();
        this.eventSystem = new EventSystem();
        this.objectPool = new ObjectPool();
        this.tweenManager = new TweenManager();
        this.debugOverlay = new DebugOverlay();
        this.audioManager = new AudioManager(applet);
        this.i18n = new I18n(applet);
        this.displayManager = new shenyf.p5engine.rendering.DisplayManager(
            config.getDisplayConfig(), config.getWidth(), config.getHeight());
        this.keyPressedState = false;
        this.keyChar = 0;
        this.keyCode = 0;
    }

    public static P5Engine create(PApplet applet) {
        P5Config config = P5Config.defaults();
        if (applet.width > 0 && applet.height > 0) {
            config.width(applet.width).height(applet.height);
        }
        return create(applet, config);
    }

    public static P5Engine create(PApplet applet, P5Config config) {
        if (instance != null) {
            throw new IllegalStateException("P5Engine already created. Use P5Engine.getInstance() instead.");
        }
        instance = new P5Engine(applet, config);
        instance.init();
        return instance;
    }

    public static P5Engine getInstance() {
        if (instance == null) {
            throw new IllegalStateException("P5Engine not initialized. Call P5Engine.create() first.");
        }
        return instance;
    }

    public static boolean isInitialized() {
        return instance != null;
    }

    /**
     * Sets the sketch framebuffer pixel density to match the primary display (HiDPI / Retina).
     * Call from {@code settings()} immediately after {@code size(...)} or {@code fullScreen(...)}.
     * Calling from {@code setup()} or after {@link #create(PApplet)} is too late and may have no effect.
     *
     * @param applet the sketch (typically {@code this} from the sketch class)
     */
    public static void applyRecommendedPixelDensity(PApplet applet) {
        applyRecommendedPixelDensity(applet, 1);
    }

    /**
     * Same as {@link #applyRecommendedPixelDensity(PApplet)}, with a requested minimum density.
     * The value actually applied is never greater than {@link PApplet#displayDensity()}: many
     * displays reject {@code pixelDensity(2)} when the OS reports {@code 1}, which shrinks the
     * window and prints {@code pixelDensity(N) is not available for this display}.
     *
     * @param minDensity ignored when greater than {@code displayDensity()}; otherwise same as single-arg
     */
    public static void applyRecommendedPixelDensity(PApplet applet, int minDensity) {
        if (applet == null) {
            return;
        }
        int d = applet.displayDensity();
        if (d < 1) {
            d = 1;
        }
        int floor = Math.max(1, minDensity);
        if (floor > d) {
            Logger.warn("applyRecommendedPixelDensity: minDensity=" + floor + " > displayDensity()="
                + d + "; using pixelDensity(" + d + "). Forcing a higher density is not supported on this display.");
        }
        applet.pixelDensity(d);
    }

    /**
     * Configure sketch display (size, renderer, pixel density) from a {@link P5Config}.
     * Must be called inside the sketch's {@code settings()} method.
     *
     * <pre>
     *   void settings() {
     *       P5Engine.configureDisplay(this, P5Config.defaults()
     *           .width(1280).height(720)
     *           .renderer(P5Config.RenderMode.P2D));
     *   }
     * </pre>
     */
    public static void configureDisplay(PApplet applet, P5Config config) {
        if (applet == null || config == null) return;
        int pd = config.getPixelDensity();
        if (pd > 0) {
            applet.pixelDensity(pd);
        } else {
            applyRecommendedPixelDensity(applet);
        }
        switch (config.getRenderMode()) {
            case P2D:
                applet.size(config.getWidth(), config.getHeight(), processing.core.PConstants.P2D);
                break;
            case FX2D:
                applet.size(config.getWidth(), config.getHeight(), processing.core.PConstants.FX2D);
                break;
            default:
                applet.size(config.getWidth(), config.getHeight());
                break;
        }
    }

    private void init() {
        isRunning = false;

        Logger.info("P5Engine initializing...");
        Logger.info("  Version: " + shenyf.p5engine.Constants.ENGINE_VERSION);
        Logger.info("  Window: " + config.getWidth() + "x" + config.getHeight());

        syncConfigToFile();

        if (checkSingleInstance()) {
            return;
        }

        if (config.isDebugMode()) {
            Logger.setDebugEnabled(true);
            Logger.info("  Debug mode: enabled");
        }
        if (config.isDebugOverlay()) {
            debugOverlay.toggle();
            Logger.info("  Debug overlay: enabled");
        }

        // Initialize logging
        Logger.setLevel(config.getLogLevel());
        if (config.isLogToFile()) {
            Logger.setFileLogging(true);
            Logger.setLogDirectory(applet.sketchPath(config.getLogDir()));
            Logger.info("  File logging: enabled -> " + config.getLogDir());
        }

        renderer.initialize();

        applet.registerMethod("keyEvent", this);
        applet.registerMethod("mouseEvent", this);
        applet.registerMethod("dispose", this);

        lastMouseX = applet.mouseX;
        lastMouseY = applet.mouseY;

        // Initialize audio
        audioManager.init();

        // Cache native surface for mouse confinement and other native operations
        try {
            nativeSurface = applet.getSurface().getNative();
        } catch (Exception e) {
            Logger.debug("Could not cache native surface: " + e.getMessage());
        }

        // Apply window position (center or custom) before window is fully visible
        applyWindowPosition();

        // Register JOGL focus listener for proper focus restoration (P2D/P3D)
        registerFocusListener();

        // Auto-enable mouse confinement if configured
        if (config.isMouseConfined()) {
            setMouseConfined(true);
        }

        Logger.info("P5Engine initialized successfully");
    }

    /**
     * Centers the sketch window on the primary screen.
     * Works with P2D/P3D (JOGL) and JAVA2D renderers.
     * Call from {@code setup()} before any {@code surface.setResizable()} calls
     * to avoid JOGL EDT conflicts.
     */
    public void centerWindow() {
        if (nativeSurface == null) {
            Logger.debug("centerWindow: nativeSurface not available");
            return;
        }
        if (windowPositionApplied) {
            return;
        }
        try {
            String clsName = nativeSurface.getClass().getName();
            boolean isJOGL = clsName.contains("newt") || clsName.contains("jogamp");
            int winW = applet.width > 0 ? applet.width : config.getWidth();
            int winH = applet.height > 0 ? applet.height : config.getHeight();

            if (isJOGL) {
                java.lang.reflect.Method getScreen = nativeSurface.getClass().getMethod("getScreen");
                Object screen = getScreen.invoke(nativeSurface);
                if (screen != null) {
                    int screenW = (Integer) screen.getClass().getMethod("getWidth").invoke(screen);
                    int screenH = (Integer) screen.getClass().getMethod("getHeight").invoke(screen);
                    int x = (screenW - winW) / 2;
                    int y = (screenH - winH) / 2;
                    java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                    setPosition.invoke(nativeSurface, x, y);
                    windowPositionApplied = true;
                    Logger.info("Window centered: " + x + ", " + y);
                }
            } else {
                Frame frame = getFrameFromSurface();
                if (frame != null) {
                    java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
                    java.awt.Rectangle screenBounds = ge.getDefaultScreenDevice().getDefaultConfiguration().getBounds();
                    java.awt.Rectangle usableBounds = ge.getMaximumWindowBounds();
                    int x = (screenBounds.width - winW) / 2 + screenBounds.x;
                    int y = (usableBounds.height - winH) / 2 + usableBounds.y;
                    frame.setLocation(x, y);
                    windowPositionApplied = true;
                    Logger.info("Window centered (AWT): " + x + ", " + y);
                }
            }
        } catch (Exception e) {
            Logger.debug("centerWindow failed: " + e.getMessage());
        }
    }

    /**
     * Sets the sketch window to a specific position.
     * Works with P2D/P3D (JOGL) and JAVA2D renderers.
     */
    public void setWindowPosition(int x, int y) {
        if (nativeSurface == null) {
            Logger.debug("setWindowPosition: nativeSurface not available");
            return;
        }
        if (windowPositionApplied) {
            return;
        }
        try {
            String clsName = nativeSurface.getClass().getName();
            boolean isJOGL = clsName.contains("newt") || clsName.contains("jogamp");

            if (isJOGL) {
                java.lang.reflect.Method setPosition = nativeSurface.getClass().getMethod("setPosition", int.class, int.class);
                setPosition.invoke(nativeSurface, x, y);
                windowPositionApplied = true;
                Logger.info("Window positioned: " + x + ", " + y);
            } else {
                Frame frame = getFrameFromSurface();
                if (frame != null) {
                    frame.setLocation(x, y);
                    windowPositionApplied = true;
                    Logger.info("Window positioned (AWT): " + x + ", " + y);
                }
            }
        } catch (Exception e) {
            Logger.debug("setWindowPosition failed: " + e.getMessage());
        }
    }

    private void applyWindowPosition() {
        if (config.isCenterWindow()) {
            centerWindow();
        } else if (config.getWindowX() >= 0 && config.getWindowY() >= 0) {
            setWindowPosition(config.getWindowX(), config.getWindowY());
        }
    }

    /**
     * Registers a JOGL WindowListener to detect focus gain/loss.
     * On focus gain, re-applies mouse confinement using the required
     * "disable then re-enable" sequence (Windows security restriction).
     */
    private void registerFocusListener() {
        if (nativeSurface == null) {
            return;
        }
        String clsName = nativeSurface.getClass().getName();
        if (!clsName.contains("newt") && !clsName.contains("jogamp")) {
            return; // Not JOGL, skip
        }
        try {
            Class<?> windowListenerClass = Class.forName("com.jogamp.newt.event.WindowListener");
            Object listener = java.lang.reflect.Proxy.newProxyInstance(
                windowListenerClass.getClassLoader(),
                new Class<?>[]{windowListenerClass},
                (proxy, method, args) -> {
                    if ("windowGainedFocus".equals(method.getName())) {
                        onWindowGainedFocus();
                    }
                    return null;
                }
            );
            java.lang.reflect.Method addListener = nativeSurface.getClass().getMethod("addWindowListener", windowListenerClass);
            addListener.invoke(nativeSurface, listener);
            Logger.debug("JOGL focus listener registered");
        } catch (Exception e) {
            Logger.debug("Could not register JOGL focus listener: " + e.getMessage());
        }
    }

    /**
     * Called when JOGL window gains focus.
     * Re-applies mouse confinement with the required disable-then-enable sequence.
     */
    private void onWindowGainedFocus() {
        if (!mouseConfinedEnabled || nativeSurface == null) {
            return;
        }
        try {
            java.lang.reflect.Method m = nativeSurface.getClass().getMethod("confinePointer", boolean.class);
            // Windows security: must disable then re-enable to regain capture
            m.invoke(nativeSurface, false);
            m.invoke(nativeSurface, true);
            recenterPointer();
            Logger.info("Mouse confinement restored on focus gain");
        } catch (Exception e) {
            Logger.debug("Focus restore confinement failed: " + e.getMessage());
        }
    }

    private void syncConfigToFile() {
        sketchConfig.setWindowSize(config.getWidth(), config.getHeight());
        sketchConfig.setDebugMode(config.isDebugMode());
        sketchConfig.save();
    }

    private boolean checkSingleInstance() {
        if (!sketchConfig.isSingleInstance()) {
            return false;
        }

        if (singleInstanceGuard.isAnotherInstanceRunning()) {
            JOptionPane.showMessageDialog(
                null,
                "Another instance of this application is already running.",
                "Single Instance Mode",
                JOptionPane.WARNING_MESSAGE
            );
            System.exit(0);
            return true;
        }

        return false;
    }

    private Frame getFrameFromSurface() {
        try {
            PSurface surface = applet.getSurface();
            Object nativeObj = surface.getNative();
            if (nativeObj == null) return null;

            // JAVA2D renderer: native is SmoothCanvas which wraps a Frame
            if (nativeObj.getClass().getSimpleName().contains("SmoothCanvas")) {
                java.lang.reflect.Method method = nativeObj.getClass().getMethod("getFrame");
                Object frame = method.invoke(nativeObj);
                if (frame instanceof Frame) {
                    return (Frame) frame;
                }
            }

            // P2D/P3D renderer (JOGL): native is GLWindow, need to traverse to find the Frame
            String clsName = nativeObj.getClass().getName();
            if (clsName.contains("newt") || clsName.contains("jogamp")) {
                // Try to get the parent Window/Frame through NEWT
                try {
                    java.lang.reflect.Method getParentMethod = nativeObj.getClass().getMethod("getParent");
                    Object parent = getParentMethod.invoke(nativeObj);
                    while (parent != null) {
                        if (parent instanceof Frame) {
                            return (Frame) parent;
                        }
                        java.lang.reflect.Method gp = parent.getClass().getMethod("getParent");
                        parent = gp.invoke(parent);
                    }
                } catch (Exception ignored) {}

                // Alternative: use the window handle via JNA to get window rect
                // For now, fall through to null and handle in caller
            }

            if (nativeObj instanceof Frame) {
                return (Frame) nativeObj;
            }
        } catch (Exception e) {
            Logger.debug("getFrame failed: " + e.getMessage());
        }
        return null;
    }

    /**
     * Confines or releases the mouse cursor to the sketch window.
     * Works with P2D/P3D (JOGL GLWindow) and JAVA2D renderers.
     * Automatically re-applies confinement when window regains focus.
     *
     * @param confined true to keep the cursor inside the window, false to allow free movement
     */
    /**
     * Confines or releases the mouse cursor to the sketch window.
     * Works with P2D/P3D (JOGL GLWindow) and JAVA2D renderers.
     * Automatically re-applies confinement when window regains focus,
     * and warps the cursor to the window center when enabling.
     *
     * @param confined true to keep the cursor inside the window, false to allow free movement
     */
    public void setMouseConfined(boolean confined) {
        mouseConfinedEnabled = confined;
        applyMouseConfinement();
        if (confined) {
            recenterPointer();
        }
    }

    private void applyMouseConfinement() {
        if (nativeSurface == null) {
            Logger.debug("setMouseConfined: nativeSurface not available");
            return;
        }
        try {
            java.lang.reflect.Method m = nativeSurface.getClass().getMethod("confinePointer", boolean.class);
            m.invoke(nativeSurface, mouseConfinedEnabled);
            Logger.info("Mouse confined: " + mouseConfinedEnabled);
        } catch (NoSuchMethodException e) {
            Logger.warn("setMouseConfined not supported by current renderer (confinePointer method not found)");
        } catch (Exception e) {
            Logger.warn("setMouseConfined failed: " + e.getMessage());
        }
    }

    /**
     * Moves the mouse cursor to the specified position relative to the sketch window.
     * Only supported by JOGL (P2D/P3D) renderers.
     *
     * @param x horizontal position in sketch pixels
     * @param y vertical position in sketch pixels
     */
    public void warpPointer(int x, int y) {
        if (nativeSurface == null) {
            Logger.debug("warpPointer: nativeSurface not available");
            return;
        }
        try {
            java.lang.reflect.Method m = nativeSurface.getClass().getMethod("warpPointer", int.class, int.class);
            m.invoke(nativeSurface, x, y);
        } catch (NoSuchMethodException e) {
            Logger.debug("warpPointer not supported by current renderer");
        } catch (Exception e) {
            Logger.debug("warpPointer failed: " + e.getMessage());
        }
    }

    /**
     * Moves the mouse cursor to the center of the sketch window.
     * Useful after enabling mouse confinement or regaining window focus.
     */
    public void recenterPointer() {
        int cx = applet.width > 0 ? applet.width / 2 : config.getWidth() / 2;
        int cy = applet.height > 0 ? applet.height / 2 : config.getHeight() / 2;
        warpPointer(cx, cy);
    }

    public void keyEvent(processing.event.KeyEvent event) {
        inputManager.onKeyEvent(event);
        int action = event.getAction();
        int code = event.getKeyCode();

        if (action == processing.event.KeyEvent.PRESS) {
            keyChar = event.getKey();
            keyCode = code;
            keyPressedState = true;

            // Debug overlay shortcuts
            char k = event.getKey();
            if (k == '`' || k == '~' || code == java.awt.event.KeyEvent.VK_BACK_QUOTE) {
                debugOverlay.toggle();
            } else if (code == java.awt.event.KeyEvent.VK_F2) {
                debugOverlay.toggleGizmos();
            } else if (code == java.awt.event.KeyEvent.VK_F3) {
                debugOverlay.toggleTree();
            } else if (code == java.awt.event.KeyEvent.VK_F4) {
                debugOverlay.toggleHud();
            } else if (code == java.awt.event.KeyEvent.VK_F5) {
                Logger.cycleLevel();
            } else if (k == '.') {
                boolean saveToFile = sketchConfig.isScreenshotToFile();
                String outputDir = sketchConfig.getScreenshotDir();
                ScreenshotTool.capture(applet, saveToFile, outputDir);
            }

            dispatchKeyEventToComponents(code, true);
        } else if (action == processing.event.KeyEvent.RELEASE) {
            keyPressedState = false;
            dispatchKeyEventToComponents(code, false);
        }
    }

    public void mouseEvent(processing.event.MouseEvent event) {
        int action = event.getAction();

        if (action == processing.event.MouseEvent.WHEEL) {
            inputManager.onMouseWheel(event.getCount());
        } else if (action == processing.event.MouseEvent.DRAG) {
            float dx = event.getX() - lastMouseX;
            float dy = event.getY() - lastMouseY;
            inputManager.onMouseDragged(dx, dy);
        }
        if (action == processing.event.MouseEvent.MOVE || action == processing.event.MouseEvent.DRAG) {
            lastMouseX = event.getX();
            lastMouseY = event.getY();
        }

        int button = event.getButton();
        if (action == processing.event.MouseEvent.PRESS) {
            dispatchMouseEventToComponents(button, true);
        } else if (action == processing.event.MouseEvent.RELEASE) {
            dispatchMouseEventToComponents(button, false);
        }
    }

    private void dispatchKeyEventToComponents(int keyCode, boolean pressed) {
        Scene scene = sceneManager.getActiveScene();
        if (scene == null) return;
        for (shenyf.p5engine.scene.GameObject go : scene.getGameObjects()) {
            if (!go.isActive()) continue;
            for (shenyf.p5engine.scene.Component c : go.getComponents()) {
                if (!c.isEnabled()) continue;
                if (pressed) {
                    c.onKeyPressed(keyCode);
                } else {
                    c.onKeyReleased(keyCode);
                }
            }
        }
    }

    private void dispatchMouseEventToComponents(int button, boolean pressed) {
        Scene scene = sceneManager.getActiveScene();
        if (scene == null) return;
        for (shenyf.p5engine.scene.GameObject go : scene.getGameObjects()) {
            if (!go.isActive()) continue;
            for (shenyf.p5engine.scene.Component c : go.getComponents()) {
                if (!c.isEnabled()) continue;
                if (pressed) {
                    c.onMousePressed(button);
                } else {
                    c.onMouseReleased(button);
                }
            }
        }
    }

    public void dispose() {
        destroy();
    }

    public void update() {
        if (!isRunning) {
            isRunning = true;
            lastFrameTime = System.nanoTime();
        }

        long currentTime = System.nanoTime();
        float rawDelta = (currentTime - lastFrameTime) / 1_000_000_000f;
        lastFrameTime = currentTime;

        // P5GameTime handles anti-stutter clamping, smooth time-scale transition, and pause
        gameTime.update(rawDelta);

        renderer.syncSizeFromApplet();

        Scene activeScene = sceneManager.getActiveScene();
        if (activeScene != null) {
            activeScene.update(gameTime.getDeltaTime());
        }

        // Fallback: re-apply mouse confinement via Processing focus state.
        // Primary focus restoration is handled by JOGL WindowListener (onWindowGainedFocus).
        if (mouseConfinedEnabled) {
            boolean nowFocused = applet.focused;
            if (nowFocused && !wasFocused) {
                // Use the same disable-then-enable sequence as the JOGL listener
                try {
                    java.lang.reflect.Method m = nativeSurface.getClass().getMethod("confinePointer", boolean.class);
                    m.invoke(nativeSurface, false);
                    m.invoke(nativeSurface, true);
                    recenterPointer();
                } catch (Exception e) {
                    Logger.debug("Focus restore fallback failed: " + e.getMessage());
                }
            }
            wasFocused = nowFocused;
        }

        inputManager.updateMouse(applet.mouseX, applet.mouseY, applet.mousePressed, applet.mouseButton);
        inputManager.postUpdate();
        scheduler.update(gameTime.getDeltaTime(), gameTime.getRealDeltaTime());
        tweenManager.update(gameTime);
        audioManager.update();

        refreshNativeWindowTitle();
    }

    /**
     * Sets the static part of the native window title (before {@code | v … | fps … | p5engine v …}).
     * Persists to sketch config as the window title (without dynamic suffix).
     */
    public void setApplicationTitle(String base) {
        applicationTitleBase = normalizeTitleBase(base);
    }

    /**
     * Sketch version shown in the title as {@code | v {version}}; pass {@code null} or blank to omit.
     */
    public void setSketchVersion(String version) {
        if (version == null) {
            this.sketchVersion = null;
            return;
        }
        String t = version.trim();
        this.sketchVersion = t.isEmpty() ? null : t;
    }

    private static String normalizeTitleBase(String title) {
        if (title == null) {
            return null;
        }
        String s = title.trim();
        if (s.isEmpty()) {
            return null;
        }
        String lower = s.toLowerCase();
        String suffix = " (p5engine)";
        if (lower.endsWith(suffix)) {
            s = s.substring(0, s.length() - suffix.length()).trim();
        }
        return s.isEmpty() ? null : s;
    }

    private String resolveApplicationTitleBase() {
        if (applicationTitleBase != null && !applicationTitleBase.isEmpty()) {
            return applicationTitleBase;
        }
        return applet.getClass().getSimpleName();
    }

    private String composeWindowTitle() {
        String base = resolveApplicationTitleBase();
        StringBuilder sb = new StringBuilder(base);
        if (sketchVersion != null && !sketchVersion.isEmpty()) {
            sb.append(" | v ").append(sketchVersion);
        }
        int fps = Math.round(gameTime.getFrameRate());
        sb.append(" | fps - ").append(fps);
        sb.append(" | p5engine v ").append(Constants.ENGINE_VERSION);
        return sb.toString();
    }

    private void refreshNativeWindowTitle() {
        try {
            String composed = composeWindowTitle();
            if (composed.equals(lastComposedWindowTitle)) {
                return;
            }
            lastComposedWindowTitle = composed;
            PSurface surface = applet.getSurface();
            if (surface != null) {
                surface.setTitle(composed);
                return;
            }

        } catch (Exception e) {
            Logger.debug("refreshNativeWindowTitle failed: " + e.getMessage());
        }
    }

    /**
     * Renders the active scene with the default background color.
     * Automatically clears the background before rendering.
     */
    public void render() {
        render(defaultBackgroundColor);
    }

    /**
     * Renders the active scene with a custom background color.
     * Automatically clears the background before rendering.
     */
    public void render(int backgroundColor) {
        Scene activeScene = sceneManager.getActiveScene();
        if (activeScene != null) {
            renderer.clear(backgroundColor);
            displayManager.begin(renderer);
            activeScene.render(renderer);
            displayManager.end(renderer);
        }
        if (postProcessor != null && postProcessor.getEffectCount() > 0) {
            postProcessor.apply(applet.g);
        }
        if (debugOverlay != null) {
            debugOverlay.render(applet, this);
        }
    }

    /**
     * Renders the active scene without clearing the background.
     * Use this when you want to handle background clearing yourself
     * (e.g. for trail effects, multi-layer rendering, etc.)
     */
    public void renderSkipBackground() {
        Scene activeScene = sceneManager.getActiveScene();
        if (activeScene != null) {
            displayManager.begin(renderer);
            activeScene.render(renderer);
            displayManager.end(renderer);
        }
    }

    public void addOnDisposeListener(Runnable listener) {
        onDisposeListeners.add(listener);
    }

    public void destroy() {
        Logger.info("P5Engine shutting down...");
        setMouseConfined(false);
        audioManager.shutdown();
        sceneManager.destroy();
        singleInstanceGuard.releaseLock();
        isRunning = false;
        instance = null;
        for (Runnable listener : onDisposeListeners) {
            try {
                listener.run();
            } catch (Exception e) {
                Logger.warn("OnDisposeListener error: " + e.getMessage());
            }
        }
        Logger.info("P5Engine destroyed");
    }

    public SceneManager getSceneManager() {
        return sceneManager;
    }

    public P5GameTime getGameTime() {
        return gameTime;
    }

    public ProcessingRenderer getRenderer() {
        return renderer;
    }

    public P5Config getConfig() {
        return config;
    }

    public SketchConfig getSketchConfig() {
        return sketchConfig;
    }

    public PApplet getApplet() {
        return applet;
    }

    public boolean isKeyPressed() {
        return keyPressedState;
    }

    public char getKey() {
        return keyChar;
    }

    public int getKeyCode() {
        return keyCode;
    }

    public void notifyKeyPressed(char key, int keyCode) {
        this.keyChar = key;
        this.keyCode = keyCode;
        this.keyPressedState = true;
    }

    public void notifyKeyReleased() {
        this.keyPressedState = false;
    }

    public boolean isMousePressed() {
        return applet.mousePressed;
    }

    public int getMouseX() {
        return applet.mouseX;
    }

    public int getMouseY() {
        return applet.mouseY;
    }

    public InputManager getInput() {
        return inputManager;
    }

    public shenyf.p5engine.time.Scheduler getScheduler() {
        return scheduler;
    }

    public EventSystem getEventSystem() {
        return eventSystem;
    }

    public ObjectPool getObjectPool() {
        return objectPool;
    }

    /** Create a generic object pool for arbitrary types. */
    public <T> GenericObjectPool<T> createPool(java.util.function.Supplier<T> factory) {
        return new GenericObjectPool<>(factory);
    }

    /** Create a generic object pool with reset callback. */
    public <T> GenericObjectPool<T> createPool(java.util.function.Supplier<T> factory, java.util.function.Consumer<T> resetter) {
        return new GenericObjectPool<>(factory, resetter);
    }

    public TweenManager getTweenManager() {
        return tweenManager;
    }

    public DebugOverlay getDebugOverlay() {
        return debugOverlay;
    }

    public AudioManager getAudio() {
        return audioManager;
    }

    public I18n getI18n() {
        return i18n;
    }

    public shenyf.p5engine.rendering.DisplayManager getDisplayManager() {
        return displayManager;
    }

    public shenyf.p5engine.rendering.PostProcessor getPostProcessor() {
        if (postProcessor == null) {
            postProcessor = new shenyf.p5engine.rendering.PostProcessor();
        }
        return postProcessor;
    }

    /**
     * Renders the debug overlay on top of the current frame.
     * Call this at the end of your sketch's {@code draw()} if you are not using {@link #render()}.
     */
    public void renderDebugOverlay() {
        System.out.println("[P5ENGINE] renderDebugOverlay called, debugOverlay=" + (debugOverlay != null));
        if (debugOverlay != null) {
            debugOverlay.render(applet, this);
        }
    }

    public boolean isRunning() {
        return isRunning;
    }

    // ===== Background Color =====

    public int getBackgroundColor() {
        return defaultBackgroundColor;
    }

    public void setBackgroundColor(int color) {
        this.defaultBackgroundColor = color;
    }

    // ===== Scene Manager shortcuts =====

    public Scene createScene(String name) {
        return sceneManager.createScene(name);
    }

    public void loadScene(String name) {
        sceneManager.loadScene(name);
    }

    public Scene getActiveScene() {
        return sceneManager.getActiveScene();
    }

    public Scene getScene(String name) {
        return sceneManager.getScene(name);
    }

    // ===== GameState =====

    public GameState getGameState() {
        return gameState;
    }

    public void setGameState(GameState state) {
        this.gameState = state;
    }

    // ===== Static config loading utilities =====

    public static String[] loadStrings(String filename) {
        return getInstance().getApplet().loadStrings(filename);
    }

    public static String loadConfig(String filename) {
        String[] lines = loadStrings(filename);
        return lines != null ? String.join("\n", lines) : null;
    }
}
