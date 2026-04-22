package shenyf.p5engine.rendering;

/**
 * Anchor points for positioning UI elements relative to the screen edges.
 *
 * <p>All coordinates are based on the <b>design resolution</b> (see {@link DisplayConfig}).
 * The engine automatically scales them to the actual window size.
 *
 * <p>Standard anchors (9-point grid):
 * <pre>
 *  TOP_LEFT      TOP_CENTER      TOP_RIGHT
 *  MIDDLE_LEFT   CENTER          MIDDLE_RIGHT
 *  BOTTOM_LEFT   BOTTOM_CENTER   BOTTOM_RIGHT
 * </pre>
 *
 * <p>Stretch anchors expand to fill one or both axes:
 * <pre>
 *  STRETCH_LEFT   STRETCH_RIGHT   STRETCH_TOP   STRETCH_BOTTOM   STRETCH_ALL
 * </pre>
 */
public enum Anchor {
    TOP_LEFT,
    TOP_CENTER,
    TOP_RIGHT,
    MIDDLE_LEFT,
    CENTER,
    MIDDLE_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_CENTER,
    BOTTOM_RIGHT,

    STRETCH_LEFT,
    STRETCH_RIGHT,
    STRETCH_TOP,
    STRETCH_BOTTOM,
    STRETCH_ALL
}
