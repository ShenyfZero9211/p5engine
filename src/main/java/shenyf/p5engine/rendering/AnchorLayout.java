package shenyf.p5engine.rendering;

/**
 * Layout utility that converts design-resolution coordinates (based on an {@link Anchor})
 * to actual screen pixel positions.
 *
 * <p>Used by screen-layer UI components ({@code renderLayer >= 100}) to stay correctly
 * positioned regardless of window size or {@link ScaleMode}.
 */
public final class AnchorLayout {

    private AnchorLayout() {}

    /**
     * Compute the actual X screen coordinate for a UI element.
     *
     * @param anchor     the anchor point
     * @param offsetX    design-resolution offset from the anchor point
     * @param width      design-resolution width of the element
     * @param designW    design-resolution screen width
     */
    public static float calcX(Anchor anchor, float offsetX, float width, float designW) {
        switch (anchor) {
            case TOP_LEFT:
            case MIDDLE_LEFT:
            case BOTTOM_LEFT:
            case STRETCH_LEFT:
                return offsetX;
            case TOP_CENTER:
            case CENTER:
            case BOTTOM_CENTER:
                return (designW - width) / 2f + offsetX;
            case TOP_RIGHT:
            case MIDDLE_RIGHT:
            case BOTTOM_RIGHT:
            case STRETCH_RIGHT:
                return designW - width - offsetX;
            case STRETCH_TOP:
            case STRETCH_BOTTOM:
            case STRETCH_ALL:
                return offsetX;
            default:
                return offsetX;
        }
    }

    /**
     * Compute the actual Y screen coordinate for a UI element.
     *
     * @param anchor     the anchor point
     * @param offsetY    design-resolution offset from the anchor point
     * @param height     design-resolution height of the element
     * @param designH    design-resolution screen height
     */
    public static float calcY(Anchor anchor, float offsetY, float height, float designH) {
        switch (anchor) {
            case TOP_LEFT:
            case TOP_CENTER:
            case TOP_RIGHT:
            case STRETCH_TOP:
                return offsetY;
            case MIDDLE_LEFT:
            case CENTER:
            case MIDDLE_RIGHT:
                return (designH - height) / 2f + offsetY;
            case BOTTOM_LEFT:
            case BOTTOM_CENTER:
            case BOTTOM_RIGHT:
            case STRETCH_BOTTOM:
                return designH - height - offsetY;
            case STRETCH_LEFT:
            case STRETCH_RIGHT:
            case STRETCH_ALL:
                return offsetY;
            default:
                return offsetY;
        }
    }

    /**
     * Compute the actual width. For stretch anchors, this expands to fill the design width
     * minus the offsets.
     */
    public static float calcW(Anchor anchor, float width, float offsetX, float designW) {
        switch (anchor) {
            case STRETCH_LEFT:
            case STRETCH_RIGHT:
            case STRETCH_TOP:
            case STRETCH_BOTTOM:
                return width; // user-defined width
            case STRETCH_ALL:
                return designW - offsetX * 2;
            default:
                return width;
        }
    }

    /**
     * Compute the actual height. For stretch anchors, this expands to fill the design height
     * minus the offsets.
     */
    public static float calcH(Anchor anchor, float height, float offsetY, float designH) {
        switch (anchor) {
            case STRETCH_LEFT:
            case STRETCH_RIGHT:
            case STRETCH_TOP:
            case STRETCH_BOTTOM:
                return height; // user-defined height
            case STRETCH_ALL:
                return designH - offsetY * 2;
            default:
                return height;
        }
    }

    /**
     * Convenience: compute all four values at once.
     *
     * @return float[4] = {x, y, w, h} in design-resolution space
     */
    public static float[] calcRect(Anchor anchor, float offsetX, float offsetY,
                                    float width, float height, float designW, float designH) {
        return new float[] {
            calcX(anchor, offsetX, width, designW),
            calcY(anchor, offsetY, height, designH),
            calcW(anchor, width, offsetX, designW),
            calcH(anchor, height, offsetY, designH)
        };
    }
}
