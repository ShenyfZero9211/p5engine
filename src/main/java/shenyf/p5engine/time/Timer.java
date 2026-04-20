package shenyf.p5engine.time;

/**
 * A lightweight timer for delayed and repeated execution.
 * Not a Component — managed by Scheduler.
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

    void update(float dt) {
        if (completed || cancelled) return;
        elapsed += dt;
        if (elapsed >= duration) {
            elapsed -= duration;
            if (action != null) {
                action.run();
            }
            currentRepeat++;
            if (!repeating || (repeatCount > 0 && currentRepeat >= repeatCount)) {
                completed = true;
            }
        }
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
    }

    public float getDuration() {
        return duration;
    }

    public void setDuration(float duration) {
        this.duration = duration;
    }
}
