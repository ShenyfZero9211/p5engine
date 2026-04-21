package shenyf.p5engine.core;

public class P5Config {
    private int width;
    private int height;
    private String title;
    private float targetFrameRate;
    private boolean debugMode;
    private boolean debugOverlay;
    private shenyf.p5engine.util.Logger.Level logLevel = shenyf.p5engine.util.Logger.Level.INFO;
    private boolean logToFile = false;
    private String logDir = "logs";

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
}
