package shenyf.p5engine.time;

public class P5GameTime {
    private float deltaTime;
    private float totalTime;
    private float unscaledTime;
    private float timeScale;
    private int frameCount;
    private float frameRate;
    private float frameRateSmooth;
    private long lastFrameTime;
    private float framesPerSecond;
    private float frameTimeAccum;

    public P5GameTime() {
        this.timeScale = 1.0f;
        this.frameRateSmooth = 60f;
        reset();
    }

    public void update(float deltaTime) {
        this.deltaTime = deltaTime * timeScale;
        this.unscaledTime += deltaTime;
        this.totalTime += this.deltaTime;
        this.frameCount++;

        if (deltaTime > 0) {
            frameRate = 1f / deltaTime;
            frameRateSmooth = 0.9f * frameRateSmooth + 0.1f * frameRate;
        }
    }

    public float getDeltaTime() {
        return deltaTime;
    }

    public float getUnscaledDeltaTime() {
        return deltaTime / timeScale;
    }

    public float getTotalTime() {
        return totalTime;
    }

    public float getUnscaledTime() {
        return unscaledTime;
    }

    public int getFrameCount() {
        return frameCount;
    }

    public float getFrameRate() {
        return frameRateSmooth;
    }

    public float getTimeScale() {
        return timeScale;
    }

    public void setTimeScale(float scale) {
        this.timeScale = scale;
    }

    public void reset() {
        deltaTime = 0;
        totalTime = 0;
        unscaledTime = 0;
        frameCount = 0;
        frameRate = 0;
        frameRateSmooth = 60f;
        lastFrameTime = System.nanoTime();
    }
}
