package shenyf.p5engine.rendering;

/**
 * Display scaling modes for adapting the design resolution to the actual window size.
 */
public enum ScaleMode {
    /** 1:1 pixel mapping. No scaling; black bars or clipping occur if aspect ratios differ. */
    NO_SCALE,

    /** Stretch to fill the entire window. Aspect ratio may be distorted. */
    STRETCH,

    /** Uniform scale to fit entirely within the window. Preserves aspect ratio; may show black bars. */
    FIT,

    /** Uniform scale to fill the entire window. Preserves aspect ratio; may clip content. */
    FILL
}
