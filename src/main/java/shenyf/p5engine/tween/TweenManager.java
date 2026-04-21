package shenyf.p5engine.tween;

import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.ui.UIComponent;

import java.util.ArrayList;
import java.util.List;

/**
 * Global manager for all active tween animations.
 *
 * <p>One instance is owned by {@link shenyf.p5engine.core.P5Engine} and updated
 * automatically each frame with scaled delta time (respects {@code timeScale}).</p>
 *
 * <p>Factory methods return a {@link Tween} instance that can be configured
 * with chainable calls before {@code start()} registers it.</p>
 */
public class TweenManager {

    private final List<Tween> activeTweens = new ArrayList<>();

    // ═══════════════════════════════════════════════════════════════
    // Update loop
    // ═══════════════════════════════════════════════════════════════

    public void update(float dt) {
        if (activeTweens.isEmpty()) return;
        shenyf.p5engine.util.Logger.debug("Tween", "update start, active=" + activeTweens.size() + ", dt=" + String.format("%.4f", dt));
        for (int i = activeTweens.size() - 1; i >= 0; i--) {
            Tween tween = activeTweens.get(i);
            shenyf.p5engine.util.Logger.debug("Tween", "  tween target=" + tween.getTarget().getClass().getSimpleName()
                + " type=" + tween.getType() + " progress=" + String.format("%.3f", tween.getProgress()));
            if (tween.update(dt)) {
                shenyf.p5engine.util.Logger.debug("Tween", "  tween COMPLETED, target=" + tween.getTarget());
                activeTweens.remove(i);
            }
        }
        shenyf.p5engine.util.Logger.debug("Tween", "update end, active=" + activeTweens.size());
    }

    // ═══════════════════════════════════════════════════════════════
    // GameObject factories
    // ═══════════════════════════════════════════════════════════════

    public Tween toPosition(GameObject go, Vector2 target, float duration) {
        Vector2 from = go.getTransform().getPosition();
        Tween tween = new Tween(this, go, Tween.Type.GO_POSITION,
            0f, 0f, from.x, from.y, target.x, target.y, true, duration);
        return tween;
    }

    public Tween toRotation(GameObject go, float targetRadians, float duration) {
        float from = go.getTransform().getRotation();
        Tween tween = new Tween(this, go, Tween.Type.GO_ROTATION,
            from, targetRadians, 0f, 0f, 0f, 0f, false, duration);
        return tween;
    }

    public Tween toRotationDegrees(GameObject go, float targetDegrees, float duration) {
        return toRotation(go, (float) Math.toRadians(targetDegrees), duration);
    }

    public Tween toScale(GameObject go, Vector2 target, float duration) {
        Vector2 from = go.getTransform().getScale();
        Tween tween = new Tween(this, go, Tween.Type.GO_SCALE,
            0f, 0f, from.x, from.y, target.x, target.y, true, duration);
        return tween;
    }

    public Tween toScale(GameObject go, float uniformScale, float duration) {
        return toScale(go, new Vector2(uniformScale, uniformScale), duration);
    }

    // ═══════════════════════════════════════════════════════════════
    // UIComponent factories
    // ═══════════════════════════════════════════════════════════════

    public Tween toX(UIComponent ui, float target, float duration) {
        Tween tween = new Tween(this, ui, Tween.Type.UI_X,
            ui.getX(), target, 0f, 0f, 0f, 0f, false, duration);
        return tween;
    }

    public Tween toY(UIComponent ui, float target, float duration) {
        Tween tween = new Tween(this, ui, Tween.Type.UI_Y,
            ui.getY(), target, 0f, 0f, 0f, 0f, false, duration);
        return tween;
    }

    public Tween toWidth(UIComponent ui, float target, float duration) {
        Tween tween = new Tween(this, ui, Tween.Type.UI_WIDTH,
            ui.getWidth(), target, 0f, 0f, 0f, 0f, false, duration);
        return tween;
    }

    public Tween toHeight(UIComponent ui, float target, float duration) {
        Tween tween = new Tween(this, ui, Tween.Type.UI_HEIGHT,
            ui.getHeight(), target, 0f, 0f, 0f, 0f, false, duration);
        return tween;
    }

    public Tween toAlpha(UIComponent ui, float target, float duration) {
        Tween tween = new Tween(this, ui, Tween.Type.UI_ALPHA,
            ui.getAlpha(), target, 0f, 0f, 0f, 0f, false, duration);
        return tween;
    }

    // ═══════════════════════════════════════════════════════════════
    // Batch helpers
    // ═══════════════════════════════════════════════════════════════

    /**
     * Animate both X and Y of a UI component with the same duration and easing.
     * Returns the Y tween so you can still chain; call {@code start()} on both.
     */
    public Tween[] toXY(UIComponent ui, float x, float y, float duration) {
        return new Tween[]{ toX(ui, x, duration), toY(ui, y, duration) };
    }

    /** Animate both width and height of a UI component. */
    public Tween[] toSize(UIComponent ui, float w, float h, float duration) {
        return new Tween[]{ toWidth(ui, w, duration), toHeight(ui, h, duration) };
    }

    // ═══════════════════════════════════════════════════════════════
    // Lifecycle management
    // ═══════════════════════════════════════════════════════════════

    /** Stop every tween whose target equals the given object. */
    public void killTarget(Object target) {
        for (Tween tween : activeTweens) {
            if (tween.getTarget() == target) {
                tween.kill();
            }
        }
    }

    /** Stop every active tween immediately. */
    public void killAll() {
        for (Tween tween : activeTweens) {
            tween.kill();
        }
    }

    /** Return how many tweens are currently running. */
    public int getActiveCount() {
        return activeTweens.size();
    }

    // ═══════════════════════════════════════════════════════════════
    // Internal
    // ═══════════════════════════════════════════════════════════════

    void add(Tween tween) {
        activeTweens.add(tween);
        shenyf.p5engine.util.Logger.debug("Tween", "ADD tween target=" + tween.getTarget().getClass().getSimpleName()
            + " type=" + tween.getType() + " duration=" + String.format("%.2f", tween.getDuration()));
    }
}
