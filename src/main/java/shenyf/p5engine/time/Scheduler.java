package shenyf.p5engine.time;

import java.util.ArrayList;
import java.util.List;

/**
 * Global scheduler for managing timers.
 * Update is called automatically by P5Engine each frame.
 */
public class Scheduler {

    private final List<Timer> timers = new ArrayList<>();

    public Timer delay(float seconds, Runnable action) {
        Timer timer = Timer.delay(seconds, action);
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

    public void update(float dt) {
        for (int i = timers.size() - 1; i >= 0; i--) {
            Timer timer = timers.get(i);
            timer.update(dt);
            if (timer.isCompleted()) {
                timers.remove(i);
            }
        }
    }

    public void clear() {
        timers.clear();
    }

    public int getTimerCount() {
        return timers.size();
    }
}
