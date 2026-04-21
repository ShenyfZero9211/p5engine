package shenyf.p5engine.time;

import shenyf.p5engine.tween.Tween;

import java.util.ArrayList;
import java.util.List;

/**
 * A chainable timeline for sequencing timers, code execution, tweens, and pulses.
 *
 * <p>Example:
 * <pre>
 *   scheduler.sequence()
 *       .wait(0.5f)
 *       .run(() -> lbl.setText("Go!"))
 *       .tween(tm.toAlpha(panel, 1f, 0.3f))
 *       .wait(1.0f)
 *       .run(() -> goToNextLevel())
 *       .start();
 * </pre>
 *
 * <p>Managed by {@link Scheduler}.
 */
public class Sequence {

    private enum StepType { WAIT, RUN, TWEEN, PULSE }

    private static final class Step {
        final StepType type;
        final float waitDuration;
        final Runnable action;
        final Tween tween;
        final float pulseDuration;
        final float pulseInterval;
        final Runnable onPulse;

        Step(float waitDuration) {
            this.type = StepType.WAIT;
            this.waitDuration = waitDuration;
            this.action = null;
            this.tween = null;
            this.pulseDuration = 0;
            this.pulseInterval = 0;
            this.onPulse = null;
        }

        Step(Runnable action) {
            this.type = StepType.RUN;
            this.waitDuration = 0;
            this.action = action;
            this.tween = null;
            this.pulseDuration = 0;
            this.pulseInterval = 0;
            this.onPulse = null;
        }

        Step(Tween tween) {
            this.type = StepType.TWEEN;
            this.waitDuration = 0;
            this.action = null;
            this.tween = tween;
            this.pulseDuration = 0;
            this.pulseInterval = 0;
            this.onPulse = null;
        }

        Step(float duration, float interval, Runnable onPulse) {
            this.type = StepType.PULSE;
            this.waitDuration = 0;
            this.action = null;
            this.tween = null;
            this.pulseDuration = duration;
            this.pulseInterval = interval;
            this.onPulse = onPulse;
        }
    }

    private final List<Step> steps = new ArrayList<>();
    private int currentIndex = -1;
    private boolean completed = false;
    private boolean cancelled = false;
    private boolean started = false;

    // Runtime state for current step
    private float waitElapsed = 0;
    private PulseTimer activePulse = null;

    Sequence() {
    }

    // --- Builder ---

    public Sequence wait(float seconds) {
        steps.add(new Step(seconds));
        return this;
    }

    public Sequence run(Runnable action) {
        steps.add(new Step(action));
        return this;
    }

    /**
     * Adds a tween step. The tween will be started automatically when this step is reached.
     * The sequence waits until the tween completes or is killed.
     */
    public Sequence tween(Tween tween) {
        steps.add(new Step(tween));
        return this;
    }

    /**
     * Adds a pulse step: fires {@code onPulse} every {@code interval} seconds
     * for a total of {@code duration} seconds.
     */
    public Sequence pulse(float duration, float interval, Runnable onPulse) {
        steps.add(new Step(duration, interval, onPulse));
        return this;
    }

    // --- Lifecycle ---

    public void start() {
        if (started || completed || cancelled) return;
        started = true;
        currentIndex = 0;
        enterStep(0);
    }

    public void cancel() {
        cancelled = true;
        if (activePulse != null) {
            activePulse.cancel();
            activePulse = null;
        }
    }

    public boolean isCompleted() {
        return completed || cancelled;
    }

    /** Overall sequence progress in range [0, 1]. */
    public float getProgress() {
        if (completed || steps.isEmpty()) return 1f;
        if (!started || currentIndex < 0) return 0f;
        int total = steps.size();
        float base = (float) currentIndex / total;
        float weight = 1f / total;
        return Math.min(1f, base + weight * getCurrentStepLocalProgress());
    }

    private float getCurrentStepLocalProgress() {
        if (currentIndex >= steps.size()) return 1f;
        Step step = steps.get(currentIndex);
        switch (step.type) {
            case WAIT:
                return step.waitDuration <= 0 ? 1f : Math.min(1f, waitElapsed / step.waitDuration);
            case RUN:
                return 1f;
            case TWEEN:
                return step.tween != null ? step.tween.getProgress() : 1f;
            case PULSE:
                return activePulse != null ? activePulse.getProgress() : 1f;
            default:
                return 0f;
        }
    }

    // --- Update ---

    void update(float scaledDt, float unscaledDt) {
        if (!started || completed || cancelled) return;
        if (currentIndex >= steps.size()) {
            completed = true;
            return;
        }

        Step step = steps.get(currentIndex);
        boolean advance = false;

        switch (step.type) {
            case WAIT:
                waitElapsed += scaledDt;
                if (waitElapsed >= step.waitDuration) {
                    advance = true;
                }
                break;

            case RUN:
                if (step.action != null) {
                    step.action.run();
                }
                advance = true;
                break;

            case TWEEN:
                if (step.tween != null && (step.tween.isCompleted() || step.tween.isKilled())) {
                    advance = true;
                }
                break;

            case PULSE:
                if (activePulse != null) {
                    activePulse.update(scaledDt, unscaledDt);
                    if (activePulse.isCompleted()) {
                        activePulse = null;
                        advance = true;
                    }
                } else {
                    // Should not happen, but advance to avoid stuck
                    advance = true;
                }
                break;
        }

        if (advance) {
            currentIndex++;
            if (currentIndex >= steps.size()) {
                completed = true;
            } else {
                enterStep(currentIndex);
            }
        }
    }

    private void enterStep(int index) {
        waitElapsed = 0;
        Step step = steps.get(index);
        if (step.type == StepType.TWEEN && step.tween != null) {
            step.tween.start();
        } else if (step.type == StepType.PULSE) {
            activePulse = new PulseTimer(step.pulseDuration, step.pulseInterval, step.onPulse);
        }
    }
}
