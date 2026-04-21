package shenyf.p5engine.tween;

import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.ui.UIComponent;

/**
 * A single tween animation that interpolates one property on a target object
 * from a start value to an end value over a given duration.
 *
 * <p>Use the chainable configuration methods ({@link #ease}, {@link #delay},
 * {@link #yoyo}, {@link #repeat}, {@link #onComplete}) to customize behaviour,
 * then call {@link #start()} to register it with the global {@link TweenManager}.</p>
 */
public class Tween {

    public enum Type {
        GO_POSITION, GO_ROTATION, GO_SCALE,
        UI_X, UI_Y, UI_WIDTH, UI_HEIGHT, UI_ALPHA
    }

    private final TweenManager manager;
    private final Object target;
    private final Type type;

    private final float fromF, toF;
    private final float fromX, fromY, toX, toY;
    private final boolean isVector2;

    private float duration;
    private float delay;
    private float elapsed;
    private EaseFunction ease = Ease::linear;
    private boolean yoyo;
    private boolean repeating;
    private int repeatCount = 0;
    private int currentRepeat;

    private Runnable onStart;
    private Runnable onUpdate;
    private Runnable onComplete;

    private boolean started;
    private boolean completed;
    private boolean killed;
    private boolean forward = true;

    /**
     * Package-private constructor. Use {@link TweenManager} factory methods
     * such as {@code toPosition()}, {@code toAlpha()}, etc.
     */
    Tween(TweenManager manager, Object target, Type type,
          float fromF, float toF,
          float fromX, float fromY, float toX, float toY,
          boolean isVector2, float duration) {
        this.manager = manager;
        this.target = target;
        this.type = type;
        this.fromF = fromF;
        this.toF = toF;
        this.fromX = fromX;
        this.fromY = fromY;
        this.toX = toX;
        this.toY = toY;
        this.isVector2 = isVector2;
        this.duration = Math.max(0.0001f, duration);
    }

    // ═══════════════════════════════════════════════════════════════
    // Chainable configuration
    // ═══════════════════════════════════════════════════════════════

    public Tween ease(EaseFunction ease) {
        this.ease = ease != null ? ease : Ease::linear;
        return this;
    }

    public Tween delay(float delay) {
        this.delay = Math.max(0f, delay);
        return this;
    }

    /** When true, the tween plays forward then backward to form one cycle. */
    public Tween yoyo(boolean yoyo) {
        this.yoyo = yoyo;
        return this;
    }

    /**
     * Number of additional cycles after the first play.
     * {@code 0} = play once, {@code 1} = play twice, {@code -1} = loop forever.
     */
    public Tween repeat(int count) {
        this.repeatCount = count;
        this.repeating = count != 0;
        return this;
    }

    public Tween onStart(Runnable callback) {
        this.onStart = callback;
        return this;
    }

    public Tween onUpdate(Runnable callback) {
        this.onUpdate = callback;
        return this;
    }

    public Tween onComplete(Runnable callback) {
        this.onComplete = callback;
        return this;
    }

    // ═══════════════════════════════════════════════════════════════
    // Lifecycle
    // ═══════════════════════════════════════════════════════════════

    /** Register this tween with the manager so it begins updating next frame. */
    public void start() {
        if (started) return;
        started = true;
        shenyf.p5engine.util.Logger.debug("Tween", "START target=" + target.getClass().getSimpleName()
            + " type=" + type + " from=" + fromF + "," + fromX + "/" + fromY
            + " to=" + toF + "," + toX + "/" + toY + " duration=" + String.format("%.2f", duration));
        if (onStart != null) {
            onStart.run();
        }
        manager.add(this);
    }

    /** Mark this tween for removal on the next manager update. */
    public void kill() {
        this.killed = true;
    }

    // ═══════════════════════════════════════════════════════════════
    // Queries
    // ═══════════════════════════════════════════════════════════════

    public boolean isCompleted() {
        return completed;
    }

    public boolean isKilled() {
        return killed;
    }

    public Object getTarget() {
        return target;
    }

    public Type getType() {
        return type;
    }

    public float getDuration() {
        return duration;
    }

    /** Normalized progress [0, 1] of the current direction (ignores yoyo). */
    public float getProgress() {
        if (duration <= 0f) return 1f;
        return Math.min(1f, elapsed / duration);
    }

    // ═══════════════════════════════════════════════════════════════
    // Internal update
    // ═══════════════════════════════════════════════════════════════

    /**
     * Advance the tween by dt seconds.
     *
     * @param dt delta time in seconds
     * @return true if the tween has finished and should be removed from the manager
     */
    boolean update(float dt) {
        if (killed || completed) {
            return true;
        }

        if (delay > 0f) {
            delay -= dt;
            return false;
        }

        elapsed += dt;
        float progress = Math.min(1f, elapsed / duration);
        float t = forward ? progress : (1f - progress);
        float eased = ease.apply(t);

        applyValue(eased);

        if (onUpdate != null) {
            onUpdate.run();
        }

        if (progress >= 1f) {
            // Yoyo backward phase
            if (yoyo && forward) {
                forward = false;
                elapsed = 0f;
                return false;
            }

            // Cycle complete — check repeat
            if (repeating && (repeatCount < 0 || currentRepeat < repeatCount)) {
                currentRepeat++;
                forward = true;
                elapsed = 0f;
                return false;
            }

            completed = true;
            if (onComplete != null) {
                onComplete.run();
            }
            return true;
        }

        return false;
    }

    private void applyValue(float t) {
        shenyf.p5engine.util.Logger.debug("Tween", "  applyValue t=" + String.format("%.3f", t) + " type=" + type);
        if (isVector2) {
            float cx = fromX + (toX - fromX) * t;
            float cy = fromY + (toY - fromY) * t;
            switch (type) {
                case GO_POSITION:
                    ((GameObject) target).getTransform().setPosition(cx, cy);
                    break;
                case GO_SCALE:
                    ((GameObject) target).getTransform().setScale(cx, cy);
                    break;
                default:
                    break;
            }
        } else {
            float v = fromF + (toF - fromF) * t;
            switch (type) {
                case GO_ROTATION:
                    ((GameObject) target).getTransform().setRotation(v);
                    break;
                case UI_X: {
                    UIComponent ui = (UIComponent) target;
                    ui.setPosition(v, ui.getY());
                    break;
                }
                case UI_Y: {
                    UIComponent ui = (UIComponent) target;
                    ui.setPosition(ui.getX(), v);
                    break;
                }
                case UI_WIDTH: {
                    UIComponent ui = (UIComponent) target;
                    ui.setSize(v, ui.getHeight());
                    break;
                }
                case UI_HEIGHT: {
                    UIComponent ui = (UIComponent) target;
                    ui.setSize(ui.getWidth(), v);
                    break;
                }
                case UI_ALPHA:
                    ((UIComponent) target).setAlpha(v);
                    break;
                default:
                    break;
            }
        }
    }
}
