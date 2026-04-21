package shenyf.p5engine.time;

import java.util.ArrayList;
import java.util.List;

/**
 * Global scheduler for managing timers.
 * Update is called automatically by P5Engine each frame.
 *
 * <p>Uses scaled game time by default. Timers can opt into unscaled real time
 * via {@link Timer#setTimeScaleAffected(boolean)}.
 */
public class Scheduler {

    private final List<Timer> timers = new ArrayList<>();
    private final List<PulseTimer> pulseTimers = new ArrayList<>();
    private final List<Sequence> sequences = new ArrayList<>();

    public Timer delay(float seconds, Runnable action) {
        Timer timer = Timer.delay(seconds, action);
        timers.add(timer);
        return timer;
    }

    /** Creates a timer that uses unscaled (real) time regardless of game timeScale. */
    public Timer delayUnscaled(float seconds, Runnable action) {
        Timer timer = Timer.delay(seconds, action);
        timer.setTimeScaleAffected(false);
        timers.add(timer);
        return timer;
    }

    public Timer interval(float seconds, Runnable action) {
        Timer timer = Timer.interval(seconds, action);
        timers.add(timer);
        return timer;
    }

    public Timer interval(float seconds, int repeatCount, Runnable action) {
        Timer timer = Timer.interval(seconds, repeatCount, action);
        timers.add(timer);
        return timer;
    }

    /**
     * Creates a pulse timer: fires {@code onPulse} every {@code interval} seconds
     * for a total of {@code duration} seconds.
     */
    public PulseTimer pulse(float duration, float interval, Runnable onPulse) {
        PulseTimer pt = new PulseTimer(duration, interval, onPulse);
        pulseTimers.add(pt);
        return pt;
    }

    /** Creates a new sequence builder. Call {@link Sequence#start()} to begin execution. */
    public Sequence sequence() {
        Sequence seq = new Sequence();
        sequences.add(seq);
        return seq;
    }

    /**
     * Update all active timers.
     *
     * @param scaledDt    delta time affected by timeScale (game logic time)
     * @param unscaledDt  raw delta time (real time)
     */
    public void update(float scaledDt, float unscaledDt) {
        for (int i = timers.size() - 1; i >= 0; i--) {
            Timer timer = timers.get(i);
            timer.update(scaledDt, unscaledDt);
            if (timer.isCompleted()) {
                timers.remove(i);
            }
        }
        for (int i = pulseTimers.size() - 1; i >= 0; i--) {
            PulseTimer pt = pulseTimers.get(i);
            pt.update(scaledDt, unscaledDt);
            if (pt.isCompleted()) {
                pulseTimers.remove(i);
            }
        }
        for (int i = sequences.size() - 1; i >= 0; i--) {
            Sequence seq = sequences.get(i);
            seq.update(scaledDt, unscaledDt);
            if (seq.isCompleted()) {
                sequences.remove(i);
            }
        }
    }

    /** Backward-compatible update when both scaled and unscaled time are identical. */
    public void update(float dt) {
        update(dt, dt);
    }

    public void clear() {
        timers.clear();
        pulseTimers.clear();
        sequences.clear();
    }

    public int getTimerCount() {
        return timers.size();
    }

    public int getPulseTimerCount() {
        return pulseTimers.size();
    }

    public int getSequenceCount() {
        return sequences.size();
    }
}
