package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import shenyf.p5engine.scene.Component;

/**
 * Convenience base class for Components that need to render.
 * Automatically unwraps {@link IRenderer} to {@link PGraphics},
 * so subclasses only need to implement {@code renderShape(PGraphics g)}.
 *
 * <p>Usage in PDE:</p>
 * <pre>
 * class MyShape extends RendererComponent {
 *     protected void renderShape(PGraphics g) {
 *         g.fill(255, 0, 0);
 *         g.rect(0, 0, 50, 50);
 *     }
 * }
 * </pre>
 */
public abstract class RendererComponent extends Component implements Renderable {

    @Override
    public final void render(IRenderer renderer) {
        renderShape(renderer.getGraphics());
    }

    /**
     * Override this to draw using the raw Processing graphics context.
     */
    protected abstract void renderShape(PGraphics g);
}
