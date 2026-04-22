package shenyf.p5engine.rendering;

import processing.core.PGraphics;

import java.util.ArrayList;
import java.util.List;

/**
 * A chainable post-processing pipeline applied to the main canvas after scene rendering.
 *
 * <p>Effects are applied in registration order. Each effect receives the main
 * {@link PGraphics} context and can use {@code filter(PShader)} or direct drawing.</p>
 *
 * <p>Example:
 * <pre>
 *   engine.getPostProcessor().add(g -> g.filter(bloomShader));
 * </pre>
 */
public class PostProcessor {

    private final List<PostEffect> effects = new ArrayList<>();

    public PostProcessor add(PostEffect effect) {
        if (effect != null) {
            effects.add(effect);
        }
        return this;
    }

    public PostProcessor remove(PostEffect effect) {
        effects.remove(effect);
        return this;
    }

    public void clear() {
        effects.clear();
    }

    public int getEffectCount() {
        return effects.size();
    }

    /** Apply all effects to the given graphics context. */
    public void apply(PGraphics g) {
        for (PostEffect effect : effects) {
            effect.apply(g);
        }
    }
}
