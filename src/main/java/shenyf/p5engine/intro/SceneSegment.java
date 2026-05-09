package shenyf.p5engine.intro;

import processing.core.PApplet;
import shenyf.p5engine.rendering.ProcessingRenderer;
import shenyf.p5engine.scene.Scene;

/**
 * An intro segment that wraps an entire {@link Scene}.
 * <p>
 * Useful for interactive intro sequences built with the engine's
 * GameObject / Component system (e.g. a fly-through camera, animated logo).
 * <p>
 * Rendering requires a {@link ProcessingRenderer}, which must be supplied
 * during construction (typically obtained from {@code P5Engine.getRenderer()}).
 */
public class SceneSegment implements IntroSegment {

    private final Scene scene;
    private final ProcessingRenderer renderer;
    private final float maxDuration;
    private float elapsed = 0;
    private boolean active = false;
    private boolean skipped = false;

    /**
     * @param scene       the scene to play
     * @param renderer    the renderer used to draw the scene
     * @param maxDuration maximum time in seconds before auto-advancing; &le;0 means indefinite
     */
    public SceneSegment(Scene scene, ProcessingRenderer renderer, float maxDuration) {
        this.scene = scene;
        this.renderer = renderer;
        this.maxDuration = maxDuration;
    }

    @Override
    public void onStart() {
        elapsed = 0;
        active = true;
        skipped = false;
    }

    @Override
    public boolean update(float dt) {
        if (!active || skipped) return true;
        elapsed += dt;
        if (scene != null) {
            scene.update(dt);
        }
        if (maxDuration > 0 && elapsed >= maxDuration) {
            return true;
        }
        return false;
    }

    @Override
    public void render(PApplet g) {
        if (!active || scene == null || renderer == null) return;
        scene.render(renderer);
    }

    @Override
    public boolean isSkippable() {
        return true;
    }

    @Override
    public void onSkip() {
        skipped = true;
    }

    public Scene getScene() {
        return scene;
    }

    public float getElapsed() {
        return elapsed;
    }
}
