package shenyf.p5engine.intro;

import processing.core.PApplet;

import java.util.ArrayList;
import java.util.List;

/**
 * Manages a queue of {@link IntroSegment}s played in order.
 * <p>
 * The sequence drives one segment at a time via {@link #update(float)}.
 * When a segment reports itself complete, the sequence automatically
 * advances to the next. When all segments finish, the optional
 * {@code onComplete} callback is fired.
 */
public class IntroSequence {

    private final List<IntroSegment> segments = new ArrayList<>();
    private int currentIndex = -1;
    private boolean complete = false;
    private boolean started = false;
    private Runnable onComplete;

    public void add(IntroSegment segment) {
        if (segment == null) return;
        segments.add(segment);
    }

    public void onComplete(Runnable callback) {
        this.onComplete = callback;
    }

    /** Starts the sequence (must be called before the first update). */
    public void start() {
        if (started) return;
        started = true;
        currentIndex = -1;
        complete = false;
        advance();
    }

    /** Updates the active segment; auto-advances when it finishes. */
    public void update(float dt) {
        if (!started || complete) return;

        if (currentIndex >= 0 && currentIndex < segments.size()) {
            IntroSegment seg = segments.get(currentIndex);
            boolean finished = seg.update(dt);
            if (finished) {
                advance();
            }
        } else {
            // No segments or past end
            finish();
        }
    }

    /** Renders the currently active segment. */
    public void render(PApplet g) {
        if (!started || complete) return;
        if (currentIndex >= 0 && currentIndex < segments.size()) {
            segments.get(currentIndex).render(g);
        }
    }

    /** Skips the current segment if it is skippable, otherwise does nothing. */
    public void skip() {
        if (!started || complete) return;
        if (currentIndex >= 0 && currentIndex < segments.size()) {
            IntroSegment seg = segments.get(currentIndex);
            if (seg.isSkippable()) {
                seg.onSkip();
                advance();
            }
        }
    }

    /** Skips all remaining segments and immediately finishes the sequence. */
    public void skipAll() {
        if (!started || complete) return;
        finish();
    }

    public boolean isComplete() {
        return complete;
    }

    public boolean isStarted() {
        return started;
    }

    public int getCurrentIndex() {
        return currentIndex;
    }

    public int getSegmentCount() {
        return segments.size();
    }

    private void advance() {
        currentIndex++;
        if (currentIndex >= segments.size()) {
            finish();
        } else {
            segments.get(currentIndex).onStart();
        }
    }

    private void finish() {
        if (complete) return;
        complete = true;
        currentIndex = segments.size();
        if (onComplete != null) {
            onComplete.run();
        }
    }
}
