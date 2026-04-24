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

    private boolean isRunning;
    private long lastFrameTime;
    private boolean windowPositionRestored;

    private boolean keyPressedState;
    private char keyChar;
    private int keyCode;

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
        windowPositionRestored = false;
        Logger.info("P5Engine initializing...");
        Logger.info("  Version: " + shenyf.p5engine.Constants.ENGINE_VERSION);
        Logger.info("  Window: " + config.getWidth() + "x" + config.getHeight());

        syncConfigToFile();

        if (checkSingleInstance()) {
            return;
        }

        String detectedTitle = detectWindowTitle();
        if (detectedTitle != null && !detectedTitle.isEmpty()) {
            applicationTitleBase = normalizeTitleBase(detectedTitle);
            if (applicationTitleBase != null) {
                sketchConfig.saveWindowTitle(applicationTitleBase);
                Logger.info("  Window title: " + applicationTitleBase);
            }
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

        Logger.info("P5Engine initialized successfully");
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

    private String detectWindowTitle() {
        try {
            PSurface surface = applet.getSurface();
            Object nativeObj = surface.getNative();
            if (nativeObj == null) return null;

            if (nativeObj.getClass().getSimpleName().contains("SmoothCanvas")) {
                java.lang.reflect.Method method = nativeObj.getClass().getMethod("getFrame");
                Object frame = method.invoke(nativeObj);
                if (frame instanceof javax.swing.JFrame) {
                    return ((javax.swing.JFrame) frame).getTitle();
                }
            }
        } catch (Exception e) {
            Logger.debug("detectWindowTitle failed: " + e.getMessage());
        }
        return null;
    }

    private Frame getFrameFromSurface() {
        try {
            PSurface surface = applet.getSurface();
            Object nativeObj = surface.getNative();
            if (nativeObj == null) return null;

            if (nativeObj.getClass().getSimpleName().contains("SmoothCanvas")) {
                java.lang.reflect.Method method = nativeObj.getClass().getMethod("getFrame");
                Object frame = method.invoke(nativeObj);
                if (frame instanceof Frame) {
                    return (Frame) frame;
                }
            }

            if (nativeObj instanceof Frame) {
                return (Frame) nativeObj;
            }
        } catch (Exception e) {
            Logger.debug("getFrame failed: " + e.getMessage());
        }
        return null;
    }

    private void restoreWindowPosition() {
        try {
            Frame frame = getFrameFromSurface();
            if (frame != null) {
                int[] pos = sketchConfig.getWindowPosition();
                if (pos != null) {
                    frame.setLocation(pos[0], pos[1]);
                    Logger.info("  Window position restored: " + pos[0] + ", " + pos[1]);
                } else {
                    int[] center = SketchConfig.getCenterPosition(config.getWidth(), config.getHeight());
                    frame.setLocation(center[0], center[1]);
                    Logger.info("  Window centered on screen");
                }
            }
        } catch (Exception e) {
            Logger.warn("Could not restore window position: " + e.getMessage());
        }
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
            } else if (code == java.awt.event.KeyEvent.VK_F2 || k == '1') {
                debugOverlay.toggleGizmos();
            } else if (code == java.awt.event.KeyEvent.VK_F3 || k == '2') {
                debugOverlay.toggleTree();
            } else if (code == java.awt.event.KeyEvent.VK_F4 || k == '3') {
                debugOverlay.toggleHud();
            } else if (code == java.awt.event.KeyEvent.VK_F5 || k == '4') {
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
        saveWindowPosition();
        destroy();
    }

    private void saveWindowPosition() {
        try {
            Frame frame = getFrameFromSurface();
            if (frame != null) {
                java.awt.Point location = frame.getLocationOnScreen();
                int x = location.x;
                int y = location.y;
                sketchConfig.saveWindowPosition(x, y);
            }
        } catch (Exception e) {
            Logger.warn("Could not save window position: " + e.getMessage());
        }
    }

    public void update() {
        if (!isRunning) {
            isRunning = true;
            lastFrameTime = System.nanoTime();
        }

        if (!windowPositionRestored) {
            restoreWindowPosition();
            windowPositionRestored = true;
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
        if (applicationTitleBase != null && !applicationTitleBase.isEmpty()) {
            sketchConfig.saveWindowTitle(applicationTitleBase);
        }
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
        String fromConfig = sketchConfig.getWindowTitle();
        if (fromConfig != null && !fromConfig.trim().isEmpty()) {
            String n = normalizeTitleBase(fromConfig);
            if (n != null) {
                return n;
            }
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
            Frame frame = getFrameFromSurface();
            if (frame != null) {
                frame.setTitle(composed);
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
