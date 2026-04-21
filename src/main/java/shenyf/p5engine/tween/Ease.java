package shenyf.p5engine.tween;

/**
 * Easing function library. All functions take a normalized time t in [0, 1]
 * and return an eased value also in [0, 1].
 *
 * <p>Reference implementations follow the standard Robert Penner easing equations
 * adapted for float precision and game-loop performance.</p>
 */
public final class Ease {

    private Ease() { }

    // ─── Back easing constants ───
    private static final float BACK_C1 = 1.70158f;
    private static final float BACK_C2 = BACK_C1 * 1.525f;
    private static final float BACK_C3 = BACK_C1 + 1f;

    // ─── Elastic constants ───
    private static final float ELASTIC_C4 = (float) (2 * Math.PI) / 3f;
    private static final float ELASTIC_C5 = (float) (2 * Math.PI) / 4.5f;

    // ═══════════════════════════════════════════════════════════════
    // Linear
    // ═══════════════════════════════════════════════════════════════

    public static float linear(float t) {
        return t;
    }

    // ═══════════════════════════════════════════════════════════════
    // Quadratic
    // ═══════════════════════════════════════════════════════════════

    public static float inQuad(float t) {
        return t * t;
    }

    public static float outQuad(float t) {
        float u = 1f - t;
        return 1f - u * u;
    }

    public static float inOutQuad(float t) {
        if (t < 0.5f) {
            return 2f * t * t;
        }
        float u = -2f * t + 2f;
        return 1f - u * u / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Cubic
    // ═══════════════════════════════════════════════════════════════

    public static float inCubic(float t) {
        return t * t * t;
    }

    public static float outCubic(float t) {
        float u = 1f - t;
        return 1f - u * u * u;
    }

    public static float inOutCubic(float t) {
        if (t < 0.5f) {
            return 4f * t * t * t;
        }
        float u = -2f * t + 2f;
        return 1f - u * u * u / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Quartic
    // ═══════════════════════════════════════════════════════════════

    public static float inQuart(float t) {
        return t * t * t * t;
    }

    public static float outQuart(float t) {
        float u = 1f - t;
        return 1f - u * u * u * u;
    }

    public static float inOutQuart(float t) {
        if (t < 0.5f) {
            return 8f * t * t * t * t;
        }
        float u = -2f * t + 2f;
        return 1f - u * u * u * u / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Quintic
    // ═══════════════════════════════════════════════════════════════

    public static float inQuint(float t) {
        return t * t * t * t * t;
    }

    public static float outQuint(float t) {
        float u = 1f - t;
        return 1f - u * u * u * u * u;
    }

    public static float inOutQuint(float t) {
        if (t < 0.5f) {
            return 16f * t * t * t * t * t;
        }
        float u = -2f * t + 2f;
        return 1f - u * u * u * u * u / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Sine
    // ═══════════════════════════════════════════════════════════════

    public static float inSine(float t) {
        return 1f - (float) Math.cos(t * Math.PI / 2f);
    }

    public static float outSine(float t) {
        return (float) Math.sin(t * Math.PI / 2f);
    }

    public static float inOutSine(float t) {
        return -((float) Math.cos(Math.PI * t) - 1f) / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Exponential
    // ═══════════════════════════════════════════════════════════════

    public static float inExpo(float t) {
        return t == 0f ? 0f : (float) Math.pow(2f, 10f * (t - 1f));
    }

    public static float outExpo(float t) {
        return t == 1f ? 1f : 1f - (float) Math.pow(2f, -10f * t);
    }

    public static float inOutExpo(float t) {
        if (t == 0f) return 0f;
        if (t == 1f) return 1f;
        if (t < 0.5f) {
            return (float) Math.pow(2f, 20f * t - 10f) / 2f;
        }
        return (2f - (float) Math.pow(2f, -20f * t + 10f)) / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Circular
    // ═══════════════════════════════════════════════════════════════

    public static float inCirc(float t) {
        return 1f - (float) Math.sqrt(1f - t * t);
    }

    public static float outCirc(float t) {
        float u = t - 1f;
        return (float) Math.sqrt(1f - u * u);
    }

    public static float inOutCirc(float t) {
        if (t < 0.5f) {
            return (1f - (float) Math.sqrt(1f - 4f * t * t)) / 2f;
        }
        float u = -2f * t + 2f;
        return ((float) Math.sqrt(1f - u * u) + 1f) / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Back
    // ═══════════════════════════════════════════════════════════════

    public static float inBack(float t) {
        return BACK_C3 * t * t * t - BACK_C1 * t * t;
    }

    public static float outBack(float t) {
        float u = t - 1f;
        return BACK_C3 * u * u * u + BACK_C1 * u * u + 1f;
    }

    public static float inOutBack(float t) {
        if (t < 0.5f) {
            float v = 2f * t;
            return (v * v * ((BACK_C2 + 1f) * v - BACK_C2)) / 2f;
        }
        float v = 2f * t - 2f;
        return (v * v * ((BACK_C2 + 1f) * v + BACK_C2) + 2f) / 2f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Elastic
    // ═══════════════════════════════════════════════════════════════

    public static float inElastic(float t) {
        if (t == 0f) return 0f;
        if (t == 1f) return 1f;
        return -(float) Math.pow(2f, 10f * (t - 1f)) * (float) Math.sin((t - 1.1f) * ELASTIC_C5);
    }

    public static float outElastic(float t) {
        if (t == 0f) return 0f;
        if (t == 1f) return 1f;
        return (float) Math.pow(2f, -10f * t) * (float) Math.sin((t - 0.1f) * ELASTIC_C5) + 1f;
    }

    public static float inOutElastic(float t) {
        if (t == 0f) return 0f;
        if (t == 1f) return 1f;
        if (t < 0.5f) {
            return -((float) Math.pow(2f, 20f * t - 10f) * (float) Math.sin((20f * t - 11.125f) * ELASTIC_C5)) / 2f;
        }
        return ((float) Math.pow(2f, -20f * t + 10f) * (float) Math.sin((20f * t - 11.125f) * ELASTIC_C5)) / 2f + 1f;
    }

    // ═══════════════════════════════════════════════════════════════
    // Bounce
    // ═══════════════════════════════════════════════════════════════

    public static float inBounce(float t) {
        return 1f - outBounce(1f - t);
    }

    public static float outBounce(float t) {
        float n1 = 7.5625f;
        float d1 = 2.75f;
        if (t < 1f / d1) {
            return n1 * t * t;
        } else if (t < 2f / d1) {
            float u = t - 1.5f / d1;
            return n1 * u * u + 0.75f;
        } else if (t < 2.5f / d1) {
            float u = t - 2.25f / d1;
            return n1 * u * u + 0.9375f;
        } else {
            float u = t - 2.625f / d1;
            return n1 * u * u + 0.984375f;
        }
    }

    public static float inOutBounce(float t) {
        if (t < 0.5f) {
            return (1f - outBounce(1f - 2f * t)) / 2f;
        }
        return (1f + outBounce(2f * t - 1f)) / 2f;
    }
}
