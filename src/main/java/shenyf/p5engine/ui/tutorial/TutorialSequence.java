package shenyf.p5engine.ui.tutorial;

import java.util.ArrayList;
import java.util.List;

/**
 * Manages a sequence of tutorial steps and drives the {@link TutorialOverlay}.
 */
public class TutorialSequence {

    private final List<TutorialStep> steps = new ArrayList<>();
    private int currentIndex = -1;
    private Runnable onComplete;
    private Runnable onStepChanged;
    private float autoTimer = 0;
    private float delayTimer = 0;
    private boolean stepReady = false;
    private boolean active = false;

    public void start(List<TutorialStep> steps) {
        this.steps.clear();
        if (steps != null) {
            this.steps.addAll(steps);
        }
        this.currentIndex = -1;
        this.autoTimer = 0;
        this.delayTimer = 0;
        this.stepReady = false;
        this.active = !this.steps.isEmpty();
        if (active) {
            nextStep();
        } else if (onComplete != null) {
            onComplete.run();
        }
    }

    public void nextStep() {
        if (!active) return;
        currentIndex++;
        autoTimer = 0;
        delayTimer = 0;
        stepReady = false;
        if (currentIndex >= steps.size()) {
            active = false;
            currentIndex = -1;
            if (onComplete != null) {
                onComplete.run();
            }
        }
        // onStepChanged will be fired when delay expires
    }

    public void skip() {
        if (!active) return;
        active = false;
        currentIndex = -1;
        if (onComplete != null) {
            onComplete.run();
        }
    }

    /**
     * Stops the sequence without firing the onComplete callback.
     * Use this when the tutorial is interrupted (e.g., game over)
     * so that completion state is not persisted.
     */
    public void stop() {
        active = false;
        currentIndex = -1;
        autoTimer = 0;
        delayTimer = 0;
        stepReady = false;
    }

    public void update(float dt) {
        if (!active || currentIndex < 0 || currentIndex >= steps.size()) return;
        TutorialStep step = steps.get(currentIndex);

        // Step delay: wait before making the step visible
        if (!stepReady) {
            delayTimer += dt;
            if (delayTimer >= step.delay) {
                stepReady = true;
                delayTimer = 0;
                if (onStepChanged != null) {
                    onStepChanged.run();
                }
            }
            return;
        }

        if (step.advanceMode == TutorialStep.AdvanceMode.AUTO) {
            autoTimer += dt;
            if (autoTimer >= step.autoDuration) {
                nextStep();
            }
        }
        // BUTTON mode: do not auto-advance; wait for user to click the next button
    }

    public boolean isActive() {
        return active;
    }

    public boolean isStepReady() {
        return active && stepReady;
    }

    public void triggerEvent(String event) {
        if (!active || currentIndex < 0 || currentIndex >= steps.size()) return;
        TutorialStep step = steps.get(currentIndex);
        if (!stepReady && event != null && step.triggerEvent != null) {
            String[] events = step.triggerEvent.split(",");
            for (String ev : events) {
                if (event.equals(ev.trim())) {
                    stepReady = true;
                    delayTimer = 0;
                    if (onStepChanged != null) {
                        onStepChanged.run();
                    }
                    return;
                }
            }
        }
    }

    public TutorialStep getCurrentStep() {
        if (!active || currentIndex < 0 || currentIndex >= steps.size()) return null;
        return steps.get(currentIndex);
    }

    public int getCurrentIndex() {
        return active ? currentIndex : -1;
    }

    public int getTotalSteps() {
        return steps.size();
    }

    public void setOnComplete(Runnable onComplete) {
        this.onComplete = onComplete;
    }

    public void setOnStepChanged(Runnable onStepChanged) {
        this.onStepChanged = onStepChanged;
    }
}
