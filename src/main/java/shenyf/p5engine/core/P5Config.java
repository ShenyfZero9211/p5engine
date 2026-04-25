package shenyf.p5engine.core;

public class P5Config {
    public enum RenderMode { JAVA2D, P2D, FX2D }

    private int width;
    private int height;
    private String title;
    private float targetFrameRate;
    private boolean debugMode;
    private boolean debugOverlay;
    private shenyf.p5engine.util.Logger.Level logLevel = shenyf.p5engine.util.Logger.Level.INFO;
    private boolean logToFile = false;
    private String logDir = "logs";
    private RenderMode renderMode = RenderMode.P2D;
    private int pixelDensity = 0; // 0 = auto
    private shenyf.p5engine.rendering.DisplayConfig displayConfig;
    private boolean mouseConfined = false;
    private boolean centerWindow = true;
    private int windowX = -1;
    private int windowY = -1;

    private P5Config() {
        this.width = 800;
        this.height = 600;
        this.title = "p5engine";
        this.targetFrameRate = 60f;
        this.debugMode = false;
        this.debugOverlay = false;
    }

    public static P5Config defaults() {
        return new P5Config();
    }

    public P5Config width(int width) {
        this.width = width;
        return this;
    }

    public P5Config height(int height) {
        this.height = height;
        return this;
    }

    public P5Config title(String title) {
        this.title = title;
        return this;
    }

    public P5Config targetFrameRate(float frameRate) {
        this.targetFrameRate = frameRate;
        return this;
    }

    public P5Config debugMode(boolean debugMode) {
        this.debugMode = debugMode;
        return this;
    }

    public P5Config debugOverlay(boolean debugOverlay) {
        this.debugOverlay = debugOverlay;
        return this;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public String getTitle() {
        return title;
    }

    public float getTargetFrameRate() {
        return targetFrameRate;
    }

    public boolean isDebugMode() {
        return debugMode;
    }

    public boolean isDebugOverlay() {
        return debugOverlay;
    }

    public P5Config logLevel(shenyf.p5engine.util.Logger.Level logLevel) {
        this.logLevel = logLevel;
        return this;
    }

    public shenyf.p5engine.util.Logger.Level getLogLevel() {
        return logLevel;
    }

    public P5Config logToFile(boolean logToFile) {
        this.logToFile = logToFile;
        return this;
    }

    public boolean isLogToFile() {
        return logToFile;
    }

    public P5Config logDir(String logDir) {
        this.logDir = logDir;
        return this;
    }

    public String getLogDir() {
        return logDir;
    }

    public P5Config renderer(RenderMode renderMode) {
        this.renderMode = renderMode;
        return this;
    }

    public RenderMode getRenderMode() {
        return renderMode;
    }

    public P5Config pixelDensity(int pixelDensity) {
        this.pixelDensity = pixelDensity;
        return this;
    }

    public int getPixelDensity() {
        return pixelDensity;
    }

    public P5Config displayConfig(shenyf.p5engine.rendering.DisplayConfig displayConfig) {
        this.displayConfig = displayConfig;
        return this;
    }

    public shenyf.p5engine.rendering.DisplayConfig getDisplayConfig() {
        if (displayConfig == null) {
            displayConfig = shenyf.p5engine.rendering.DisplayConfig.defaults()
                .designWidth(width)
                .designHeight(height);
        }
        return displayConfig;
    }

    public P5Config mouseConfined(boolean mouseConfined) {
        this.mouseConfined = mouseConfined;
        return this;
    }

    public boolean isMouseConfined() {
        return mouseConfined;
    }

    public P5Config centerWindow(boolean centerWindow) {
        this.centerWindow = centerWindow;
        return this;
    }

    public boolean isCenterWindow() {
        return centerWindow;
    }

    public P5Config windowPosition(int x, int y) {
        this.windowX = x;
        this.windowY = y;
        this.centerWindow = false;
        return this;
    }

    public int getWindowX() {
        return windowX;
    }

    public int getWindowY() {
        return windowY;
    }
}
