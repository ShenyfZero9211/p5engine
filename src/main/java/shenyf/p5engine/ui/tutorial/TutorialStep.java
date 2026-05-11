package shenyf.p5engine.ui.tutorial;

/**
 * Describes a single step in a tutorial sequence.
 */
public class TutorialStep {

    public enum TargetType {
        /** Focus on a UI component by its ID. */
        UI_COMPONENT,
        /** Focus on a screen rectangle (design-resolution coordinates). */
        SCREEN_RECT,
        /** Focus on a world-coordinate rectangle, auto-converted to screen space. */
        WORLD_RECT,
        /** Full-screen step with no dark mask; borders and bubble still render. */
        FULL_SCREEN_NO_MASK,
        /** No primary target; bubble is shown at a fixed screen position (e.g. top-right). */
        GLOBAL
    }

    public enum AdvanceMode {
        /** Advance when user clicks inside the target area. */
        CLICK,
        /** Advance when the game code calls {@link TutorialSequence#nextStep()}. */
        ACTION,
        /** Advance automatically after {@link #autoDuration} seconds. */
        AUTO,
        /** Advance when user presses any key or clicks. */
        KEY
    }

    public enum BorderEffect {
        /** Default: pulsing border (scale + alpha oscillation). */
        PULSE,
        /** Fixed-size border with alpha flash only. */
        FLASH,
        /** No border effect. */
        NONE
    }

    public int stepIndex;
    public TargetType targetType = TargetType.SCREEN_RECT;
    public String targetId;                       // for UI_COMPONENT
    public float targetX, targetY, targetW, targetH; // for SCREEN_RECT / WORLD_RECT (primary)
    /** Optional list of additional target rectangles for multi-spotlight steps.
     *  Each float[] = {x, y, w, h} in the same coordinate space as targetX/Y/W/H. */
    public java.util.List<float[]> targetRects;
    public String textKey;                        // i18n key for the description text
    public AdvanceMode advanceMode = AdvanceMode.CLICK;
    public float delay = 0f;                      // seconds to wait before showing this step
    public float autoDuration = 3.0f;             // seconds, for AUTO mode
    public String triggerEvent;                   // for AUTO steps: external event name that forces stepReady (e.g. "orb_stolen")
    public boolean allowSkip = true;              // allow ESC/right-click to skip
    public BorderEffect borderEffect = BorderEffect.PULSE; // border animation style
    /** For GLOBAL target type: where to pin the bubble.
     *  Supported: "top_right", "top_left", "bottom_right", "bottom_left", "center". */
    public String bubbleAnchor = "center";

    public TutorialStep() {}

    public TutorialStep(int index, String textKey, AdvanceMode advanceMode) {
        this.stepIndex = index;
        this.textKey = textKey;
        this.advanceMode = advanceMode;
    }
}
