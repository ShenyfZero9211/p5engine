/**
 * Status effects attached to enemies (hit marks, debuffs, etc.).
 * Rendered by EnemyRenderer alongside the enemy body.
 */

static abstract class EnemyStatusEffect {
    float timer;
    float maxTimer;

    EnemyStatusEffect(float duration) {
        this.maxTimer = duration;
        this.timer = duration;
    }

    boolean update(float dt) {
        timer -= dt;
        return timer > 0;
    }

    abstract void render(PGraphics g, float x, float y, float r);
}

/**
 * Machine-gun hit mark: yellow cross flash.
 */
static class MgHitMark extends EnemyStatusEffect {
    MgHitMark() { super(0.15f); }

    void render(PGraphics g, float x, float y, float r) {
        float t = timer / maxTimer;
        float flicker = PApplet.sin(t * PApplet.PI * 8);
        int alpha = (int)(255 * t * Math.abs(flicker));
        g.noFill();
        g.stroke(0xFFFFFF00, alpha);
        g.strokeWeight(2);
        float arm = r * 0.4f;
        g.line(x - arm, y, x + arm, y);
        g.line(x, y - arm, x, y + arm);
    }
}

/**
 * Missile hit mark: small orange burst star.
 */
static class MissileHitMark extends EnemyStatusEffect {
    MissileHitMark() { super(0.3f); }

    void render(PGraphics g, float x, float y, float r) {
        float t = timer / maxTimer;
        float expand = 1f - t;
        int alpha = (int)(255 * t);
        g.noFill();
        g.stroke(0xFFFFBB66, alpha);
        g.strokeWeight(2);
        float arm = r * (0.4f + expand * 0.8f);
        for (int i = 0; i < 4; i++) {
            float a = PApplet.PI / 4 + i * PApplet.PI / 2;
            g.line(x, y, x + PApplet.cos(a) * arm, y + PApplet.sin(a) * arm);
        }
    }
}

/**
 * Laser hit mark: purple burn spot with slow pulse.
 */
static class LaserHitMark extends EnemyStatusEffect {
    LaserHitMark() { super(0.35f); }

    void render(PGraphics g, float x, float y, float r) {
        float t = timer / maxTimer;
        float pulse = PApplet.sin(t * PApplet.PI * 5);
        pulse = pulse * pulse; // sharpen pulse
        float bright = 0.7f + 0.3f * pulse;

        g.noStroke();
        // Outer glow — larger, high alpha
        g.fill(0xFFE8A0F0, (int)(200 * t * bright));
        float glowR = r * 0.8f;
        g.ellipse(x, y, glowR * 2, glowR * 2);

        // Main spot — full purple
        g.fill(0xFFC878DC, (int)(255 * t * bright));
        float spotR = r * 0.55f;
        g.ellipse(x, y, spotR * 2, spotR * 2);

        // Core white — piercing bright
        g.fill(0xFFFFFFFF, (int)(255 * t * (0.5f + 0.5f * pulse)));
        g.ellipse(x, y, spotR * 0.6f, spotR * 0.6f);

        // Pinpoint hot center
        g.fill(0xFFFFFFFF, (int)(255 * t));
        g.ellipse(x, y, spotR * 0.25f, spotR * 0.25f);
    }
}
