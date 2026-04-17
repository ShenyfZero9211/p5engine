package shenyf.p5engine.core;

public class P5Config {
    private int width;
    private int height;
    private String title;
    private float targetFrameRate;
    private boolean debugMode;

    private P5Config() {
        this.width = 800;
        this.height = 600;
        this.title = "p5engine";
        this.targetFrameRate = 60f;
        this.debugMode = false;
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
}
