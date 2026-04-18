package shenyf.p5engine.core;

import processing.core.PApplet;
import processing.core.PSurface;
import shenyf.p5engine.config.SketchConfig;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.time.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.util.Logger;
import shenyf.p5engine.util.SingleInstanceGuard;
import java.awt.Frame;
import javax.swing.JOptionPane;

public class P5Engine {
    private static P5Engine instance;

    private final PApplet applet;
    private final P5Config config;
    private final SceneManager sceneManager;
    private final P5GameTime gameTime;
    private final ProcessingRenderer renderer;
    private final SketchConfig sketchConfig;
    private final SingleInstanceGuard singleInstanceGuard;

    private boolean isRunning;
    private long lastFrameTime;
    private boolean windowPositionRestored;

    private boolean keyPressedState;
    private char keyChar;
    private int keyCode;

    private P5Engine(PApplet applet, P5Config config) {
        this.applet = applet;
        this.config = config;
        this.sketchConfig = new SketchConfig(applet);
        this.singleInstanceGuard = new SingleInstanceGuard(sketchConfig.get(SketchConfig.SECTION_P5ENGINE, SketchConfig.KEY_NAME, "p5engine"));
        this.sceneManager = new SceneManager();
        this.gameTime = new P5GameTime();
        this.renderer = new ProcessingRenderer(applet, config.getWidth(), config.getHeight());
        this.keyPressedState = false;
        this.keyChar = 0;
        this.keyCode = 0;
    }

    public static P5Engine create(PApplet applet) {
        return create(applet, P5Config.defaults());
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

        if (config.isDebugMode()) {
            Logger.setDebugEnabled(true);
            Logger.info("  Debug mode: enabled");
        }

        renderer.initialize();

        applet.registerMethod("keyEvent", this);
        applet.registerMethod("dispose", this);

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
        if (event.getAction() == processing.event.KeyEvent.PRESS) {
            keyChar = event.getKey();
            keyCode = event.getKeyCode();
            keyPressedState = true;
        } else if (event.getAction() == processing.event.KeyEvent.RELEASE) {
            keyPressedState = false;
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
        float deltaTime = (currentTime - lastFrameTime) / 1_000_000_000f;
        lastFrameTime = currentTime;

        if (deltaTime > 0.1f) {
            deltaTime = 1f / 60f;
        }

        gameTime.update(deltaTime);

        Scene activeScene = sceneManager.getActiveScene();
        if (activeScene != null) {
            activeScene.update(gameTime.getDeltaTime());
        }
    }

    public void render() {
        Scene activeScene = sceneManager.getActiveScene();
        if (activeScene != null) {
            renderer.clear(200);
            activeScene.render(renderer);
        }
    }

    public void destroy() {
        Logger.info("P5Engine shutting down...");
        sceneManager.destroy();
        singleInstanceGuard.releaseLock();
        isRunning = false;
        instance = null;
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

    public boolean isRunning() {
        return isRunning;
    }
}
