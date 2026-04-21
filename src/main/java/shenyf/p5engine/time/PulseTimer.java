package shenyf.p5engine.time;

/**
 * A timer that fires a pulse callback at regular intervals within a fixed duration.
 * Useful for effects like "spawn a spark every 0.2s for 3 seconds".
 *
 * <p>Managed by {@link Scheduler}.
 */
public class PulseTimer {

    private final float duration;
    private final float interval;
    private final Runnable onPulse;

    private Runnable onComplete;
    private Runnable onStart;
    private Runnable onUpdate;

    private float elapsedTotal = 0;
    private float elapsedSincePulse = 0;
    private int pulseCount = 0;
    private boolean completed = false;
    private boolean cancelled = false;
    private boolean paused = false;
    private boolean started = false;
    private boolean timeScaleAffected = true;

    PulseTimer(float duration, float interval, Runnable onPulse) {
        this.duration = duration;
        this.interval = interval;
        this.onPulse = onPulse;
    }

    // --- Configuration ---

    public PulseTimer onStart(Runnable callback) {
        this.onStart = callback;
        return this;
    }

    public PulseTimer onUpdate(Runnable callback) {
        this.onUpdate = callback;
        return this;
    }

    public PulseTimer onComplete(Runnable callback) {
        this.onComplete = callback;
        return this;
    }

    public PulseTimer setTimeScaleAffected(boolean affected) {
        this.timeScaleAffected = affected;
        return this;
    }

    // --- Control ---

    public void pause() {
        this.paused = true;
    }

    public void resume() {
        this.paused = false;
    }

    public boolean isPaused() {
        return paused;
    }

    public void cancel() {
        this.cancelled = true;
    }

    public boolean isCompleted() {
        return completed || cancelled;
    }

    public void reset() {
        elapsedTotal = 0;
        elapsedSincePulse = 0;
        pulseCount = 0;
        completed = false;
        cancelled = false;
        paused = false;
        started = false;
    }

    // --- Inspection ---

    public float getDuration() {
        return duration;
    }

    public float getInterval() {
        return interval;
    }

    public float getProgress() {
        if (duration <= 0) return 1f;
        return Math.min(1f, elapsedTotal / duration);
    }

    public float getElapsed() {
        return elapsedTotal;
    }

    public float getRemainingTime() {
        return Math.max(0f, duration - elapsedTotal);
    }

    public int getPulseCount() {
        return pulseCount;
    }

    // --- Update ---

    void update(float scaledDt, float unscaledDt) {
        if (completed || cancelled || paused) return;
        float dt = timeScaleAffected ? scaledDt : unscaledDt;

        if (!started) {
            started = true;
            if (onStart != null) onStart.run();
        }

        elapsedTotal += dt;
        elapsedSincePulse += dt;

        while (elapsedSincePulse >= interval && !completed) {
            elapsedSincePulse -= interval;
            pulseCount++;
            if (onPulse != null) onPulse.run();
        }

        if (elapsedTotal >= duration) {
            completed = true;
            if (onComplete != null) onComplete.run();
        }

        if (onUpdate != null) onUpdate.run();
    }
}
