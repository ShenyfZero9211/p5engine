package shenyf.p5engine.time;

/**
 * Central game time manager. Provides both scaled (game) and unscaled (real) delta time,
 * smooth time-scale transitions, and pause/resume semantics.
 *
 * <p>Usage in {@link shenyf.p5engine.core.P5Engine#update()}:
 * <pre>
 *   gameTime.update(rawDelta);
 *   // world logic  -> gameTime.getDeltaTime()
 *   // UI / input   -> gameTime.getRealDeltaTime()
 * </pre>
 */
public class P5GameTime {

    // ── Configuration ──
    private static final float MAX_DELTA_TIME = 0.25f;

    // ── Core state ──
    private float deltaTime;
    private float realDeltaTime;
    private float totalTime;
    private float unscaledTime;
    private float timeScale = 1.0f;

    // ── Smooth transition ──
    private float targetTimeScale = 1.0f;
    private float transitionSpeed = 5.0f;

    // ── Pause semantics ──
    private boolean paused = false;
    private float prePauseTimeScale = 1.0f;

    // ── Frame stats ──
    private int frameCount;
    private float frameRate;
    private float frameRateSmooth = 60f;

    public P5GameTime() {
        reset();
    }

    /**
     * Call once per frame with the raw (real) delta time in seconds.
     * Handles anti-stutter clamping, smooth time-scale interpolation,
     * pause state, and accumulates both scaled and unscaled totals.
     */
    public void update(float rawDeltaTime) {
        // 1. Anti-stutter: cap huge time jumps (e.g. window minimized)
        if (rawDeltaTime > MAX_DELTA_TIME) {
            rawDeltaTime = MAX_DELTA_TIME;
        }

        // 2. Smooth time-scale transition
        if (Math.abs(timeScale - targetTimeScale) > 0.001f) {
            float t = 1.0f - (float) Math.exp(-transitionSpeed * rawDeltaTime);
            timeScale = lerp(timeScale, targetTimeScale, t);
        } else {
            timeScale = targetTimeScale;
        }

        // 3. Compute both deltas
        this.realDeltaTime = rawDeltaTime;
        this.deltaTime = paused ? 0f : rawDeltaTime * timeScale;

        // 4. Accumulate totals
        this.unscaledTime += rawDeltaTime;
        this.totalTime += this.deltaTime;

        // 5. Frame-rate stats (based on real delta)
        frameCount++;
        if (rawDeltaTime > 0) {
            frameRate = 1f / rawDeltaTime;
            frameRateSmooth = 0.9f * frameRateSmooth + 0.1f * frameRate;
        }
    }

    // ── Query: scaled (game) time ──

    /** Delta time affected by {@code timeScale}. Use for world logic, physics, AI. */
    public float getDeltaTime() {
        return deltaTime;
    }

    /** Total accumulated game time (scaled). */
    public float getTotalTime() {
        return totalTime;
    }

    // ── Query: unscaled (real) time ──

    /** Raw delta time unaffected by {@code timeScale}. Use for UI, input cooldowns, networking. */
    public float getRealDeltaTime() {
        return realDeltaTime;
    }

    /** Total accumulated real time (unscaled). */
    public float getUnscaledTime() {
        return unscaledTime;
    }

    /**
     * @deprecated Use {@link #getRealDeltaTime()} for the true raw delta.
     * This method returns {@code deltaTime / timeScale}, which is only an approximation.
     */
    @Deprecated
    public float getUnscaledDeltaTime() {
        return timeScale == 0 ? 0 : deltaTime / timeScale;
    }

    // ── Time scale control ──

    public float getTimeScale() {
        return timeScale;
    }

    /** Instantly sets the current time scale (bypasses smooth transition). */
    public void setTimeScale(float scale) {
        this.timeScale = Math.max(0f, scale);
        this.targetTimeScale = this.timeScale;
    }

    /** Sets the target time scale; actual value will smoothly interpolate toward it. */
    public void setTargetTimeScale(float scale) {
        this.targetTimeScale = Math.max(0f, scale);
    }

    public float getTargetTimeScale() {
        return targetTimeScale;
    }

    /** Speed of smooth transition (higher = faster). Default 5.0. */
    public void setTransitionSpeed(float speed) {
        this.transitionSpeed = Math.max(0f, speed);
    }

    public float getTransitionSpeed() {
        return transitionSpeed;
    }

    // ── Pause semantics ──

    public void pause() {
        if (!paused) {
            paused = true;
            prePauseTimeScale = targetTimeScale;
            setTargetTimeScale(0f);
        }
    }

    public void resume() {
        if (paused) {
            paused = false;
            setTargetTimeScale(prePauseTimeScale);
        }
    }

    public boolean isPaused() {
        return paused;
    }

    public void togglePause() {
        if (paused) resume();
        else pause();
    }

    // ── Frame stats ──

    public int getFrameCount() {
        return frameCount;
    }

    public float getFrameRate() {
        return frameRateSmooth;
    }

    // ── Lifecycle ──

    public void reset() {
        deltaTime = 0;
        realDeltaTime = 0;
        totalTime = 0;
        unscaledTime = 0;
        timeScale = 1.0f;
        targetTimeScale = 1.0f;
        paused = false;
        prePauseTimeScale = 1.0f;
        frameCount = 0;
        frameRate = 0;
        frameRateSmooth = 60f;
    }

    // ── Helpers ──

    private static float lerp(float a, float b, float t) {
        return a + (b - a) * t;
    }
}
