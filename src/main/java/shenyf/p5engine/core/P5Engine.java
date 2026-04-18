package shenyf.p5engine.core;

import processing.core.PApplet;
import shenyf.p5engine.config.WindowConfigSource;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.time.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.util.Logger;
import java.awt.Frame;
import java.awt.Component;

public class P5Engine {
    private static P5Engine instance;

    private final PApplet applet;
    private final P5Config config;
    private final SceneManager sceneManager;
    private final P5GameTime gameTime;
    private final ProcessingRenderer renderer;
    private final WindowConfigSource windowConfig;

    private boolean isRunning;
    private long lastFrameTime;

    private boolean keyPressedState;
    private char keyChar;
    private int keyCode;

    private P5Engine(PApplet applet, P5Config config) {
        this.applet = applet;
        this.config = config;
        this.sceneManager = new SceneManager();
        this.gameTime = new P5GameTime();
        this.renderer = new ProcessingRenderer(applet, config.getWidth(), config.getHeight());
        this.windowConfig = new WindowConfigSource("window", 10);
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
        Logger.info("P5Engine initializing...");
        Logger.info("  Version: " + shenyf.p5engine.Constants.ENGINE_VERSION);
        Logger.info("  Window: " + config.getWidth() + "x" + config.getHeight());

        if (config.isDebugMode()) {
            Logger.setDebugEnabled(true);
            Logger.info("  Debug mode: enabled");
        }

        renderer.initialize();

        applet.registerMethod("keyEvent", this);
        applet.registerMethod("dispose", this);

        restoreWindowPosition();

        Logger.info("P5Engine initialized successfully");
    }

    private Frame getFrame() {
        try {
            java.lang.reflect.Field frameField = PApplet.class.getDeclaredField("frame");
            frameField.setAccessible(true);
            Object frame = frameField.get(applet);
            if (frame instanceof Frame) {
                return (Frame) frame;
            }
        } catch (Exception e) {
            // frame not available
        }
        return null;
    }

    private void restoreWindowPosition() {
        Frame frame = getFrame();
        if (frame != null) {
            int[] pos = windowConfig.getSavedPosition();
            if (pos != null) {
                frame.setLocation(pos[0], pos[1]);
                Logger.info("  Window position restored: " + pos[0] + ", " + pos[1]);
            } else {
                int[] center = WindowConfigSource.getCenterPosition(config.getWidth(), config.getHeight());
                frame.setLocation(center[0], center[1]);
                Logger.info("  Window centered on screen");
            }
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
        Frame frame = getFrame();
        if (frame != null) {
            java.awt.Point location = frame.getLocationOnScreen();
            int x = location.x;
            int y = location.y;
            windowConfig.savePosition(x, y);
        }
    }

    public void update() {
        if (!isRunning) {
            isRunning = true;
            lastFrameTime = System.nanoTime();
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
