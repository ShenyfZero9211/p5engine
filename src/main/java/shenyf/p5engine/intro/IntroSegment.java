package shenyf.p5engine.intro;

import processing.core.PApplet;

/**
 * A single segment of an intro / cutscene sequence.
 * Each segment represents one piece of content shown to the player
 * (e.g. a title card, a video clip, or an interactive scene).
 */
public interface IntroSegment {

    /** Called once when this segment becomes the active segment. */
    void onStart();

    /**
     * Updates the segment.
     *
     * @param dt delta time in seconds
     * @return true if this segment has finished and the sequence should advance
     */
    boolean update(float dt);

    /** Renders the segment. */
    void render(PApplet g);

    /** Whether the player is allowed to skip this segment. */
    default boolean isSkippable() {
        return true;
    }

    /** Called when the player chooses to skip this segment. */
    default void onSkip() {
        // no-op by default
    }
}
