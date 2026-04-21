package shenyf.p5engine.tween;

/**
 * Functional interface for easing functions.
 * Maps a normalized time t in [0, 1] to an eased value in [0, 1].
 */
@FunctionalInterface
public interface EaseFunction {
    float apply(float t);
}
