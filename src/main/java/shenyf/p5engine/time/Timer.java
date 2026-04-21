package shenyf.p5engine.time;

/**
 * A lightweight timer for delayed and repeated execution.
 * Not a Component — managed by Scheduler.
 *
 * <p>Supports lifecycle callbacks ({@code onStart}, {@code onUpdate}, {@code onComplete}),
 * progress inspection, pause/resume, and timeScale control.
 */
public class Timer {

    float elapsed = 0;
    float duration;
    Runnable action;
    boolean repeating;
    int repeatCount = -1;   // -1 = infinite
    int currentRepeat = 0;
    boolean completed = false;
    boolean cancelled = false;

    // --- Phase 1 extensions ---
    private Runnable onStart;
    private Runnable onUpdate;
    private Runnable onComplete;
    private boolean started = false;
    private boolean paused = false;
    private boolean timeScaleAffected = true;

    Timer(float duration, Runnable action) {
        this.duration = duration;
        this.action = action;
        this.repeating = false;
    }

    Timer(float duration, boolean repeating, Runnable action) {
        this.duration = duration;
        this.action = action;
        this.repeating = repeating;
    }

    Timer(float duration, int repeatCount, Runnable action) {
        this.duration = duration;
        this.action = action;
        this.repeating = true;
        this.repeatCount = repeatCount;
    }

    public static Timer delay(float seconds, Runnable action) {
        return new Timer(seconds, action);
    }

    public static Timer interval(float seconds, Runnable action) {
        Timer t = new Timer(seconds, true, action);
        t.repeatCount = -1;
        return t;
    }

    public static Timer interval(float seconds, int repeatCount, Runnable action) {
        return new Timer(seconds, repeatCount, action);
    }

    // --- Lifecycle configuration ---

    public Timer onStart(Runnable callback) {
        this.onStart = callback;
        return this;
    }

    public Timer onUpdate(Runnable callback) {
        this.onUpdate = callback;
        return this;
    }

    public Timer onComplete(Runnable callback) {
        this.onComplete = callback;
        return this;
    }

    // --- TimeScale & Pause ---

    /**
     * When true (default), this timer uses scaled game time.
     * When false, it uses unscaled real time.
     */
    public Timer setTimeScaleAffected(boolean affected) {
        this.timeScaleAffected = affected;
        return this;
    }

    public boolean isTimeScaleAffected() {
        return timeScaleAffected;
    }

    public void pause() {
        this.paused = true;
    }

    public void resume() {
        this.paused = false;
    }

    public boolean isPaused() {
        return paused;
    }

    // --- Progress inspection ---

    /** Returns progress in range [0, 1] for the current cycle. */
    public float getProgress() {
        if (completed || duration <= 0) return 1f;
        return Math.min(1f, elapsed / duration);
    }

    public float getElapsed() {
        return elapsed;
    }

    public float getRemainingTime() {
        if (completed) return 0f;
        return Math.max(0f, duration - elapsed);
    }

    public int getCurrentRepeat() {
        return currentRepeat;
    }

    public int getRepeatCount() {
        return repeatCount;
    }

    // --- Update ---

    void update(float scaledDt, float unscaledDt) {
        if (completed || cancelled) return;
        if (paused) {
            // Still call onUpdate while paused? No — timer is frozen.
            return;
        }
        float dt = timeScaleAffected ? scaledDt : unscaledDt;

        if (!started) {
            started = true;
            if (onStart != null) {
                onStart.run();
            }
        }

        elapsed += dt;
        if (elapsed >= duration) {
            elapsed -= duration;
            if (action != null) {
                action.run();
            }
            currentRepeat++;
            if (!repeating || (repeatCount > 0 && currentRepeat >= repeatCount)) {
                completed = true;
                if (onComplete != null) {
                    onComplete.run();
                }
            }
        }

        if (onUpdate != null) {
            onUpdate.run();
        }
    }

    /** Backward-compatible single-dt update (treats both args as same). */
    void update(float dt) {
        update(dt, dt);
    }

    public void cancel() {
        cancelled = true;
    }

    public boolean isCompleted() {
        return completed || cancelled;
    }

    public void reset() {
        elapsed = 0;
        currentRepeat = 0;
        completed = false;
        cancelled = false;
        started = false;
        paused = false;
    }

    public float getDuration() {
        return duration;
    }

    public void setDuration(float duration) {
        this.duration = duration;
    }
}
