package shenyf.p5engine.rendering;

import processing.core.PGraphics;

/**
 * A single post-processing effect applied to the main canvas.
 */
public interface PostEffect {

    /**
     * Apply this effect to the graphics context.
     * The effect can use {@link PGraphics#filter} (PShader) or direct drawing.
     *
     * @param g the main graphics context (typically {@code applet.g})
     */
    void apply(PGraphics g);
}
