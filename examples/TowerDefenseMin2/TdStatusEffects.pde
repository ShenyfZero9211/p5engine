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

/**
 * Poison status: green dripping dots, deals damage over time.
 */
static class PoisonStatusEffect extends EnemyStatusEffect {
    float dps;
    float tickTimer = 0.5f;   // 每 0.5 秒跳一次毒伤
    int stackIndex;           // 0 = 第一层, 1 = 第二层

    PoisonStatusEffect(float dps, float duration, int stackIndex) {
        super(duration);
        this.dps = dps;
        this.stackIndex = stackIndex;
    }

    boolean update(float dt) {
        timer -= dt;
        tickTimer -= dt;
        return timer > 0;
    }

    void render(PGraphics g, float x, float y, float r) {
        float t = timer / maxTimer;
        float pulse = PApplet.sin(t * PApplet.PI * 8);
        pulse = pulse * pulse;
        int alpha = (int)(240 * t * (0.6f + 0.4f * pulse));
        g.noStroke();

        // Two stacks offset horizontally so they don't fully overlap
        float offsetX = (stackIndex == 0) ? -r * 0.22f : r * 0.22f;
        float cx = x + offsetX;

        // Outer toxic aura — large green halo (polygon circle)
        g.fill(0xFF44CC44, (int)(80 * t));
        drawPolyCircle(g, cx, y, r * 1.4f, 12);

        // Rotating/skull ring — shows debuff intensity (small rects)
        g.fill(0xFF22AA22, (int)(160 * t));
        float ringR = r * 0.85f;
        float time = System.currentTimeMillis() / 1000f;
        float dotSize = r * 0.22f;
        for (int i = 0; i < 8; i++) {
            float a = PApplet.TWO_PI / 8 * i + time * 2;
            float px = cx + PApplet.cos(a) * ringR;
            float py = y + PApplet.sin(a) * ringR;
            g.rect(px - dotSize * 0.5f, py - dotSize * 0.5f, dotSize, dotSize);
        }

        // Green droplets — falling down (triangles)
        // NOTE: temporarily disabled for performance; uncomment to restore
        // g.fill(0xFF44CC44, alpha);
        // float dropY = y + r * 0.7f * (1 - t);
        // drawDroplet(g, cx - r * 0.35f, dropY, r * 0.28f, r * 0.38f);
        // drawDroplet(g, cx + r * 0.25f, dropY + r * 0.15f, r * 0.24f, r * 0.34f);
        // drawDroplet(g, cx, dropY + r * 0.35f, r * 0.2f, r * 0.3f);

        // Core bright glow (polygon circle)
        g.fill(0xFF66FF66, (int)(200 * t));
        drawPolyCircle(g, cx, y - r * 0.05f, r * 0.325f, 10);

        // Hot center (polygon circle)
        g.fill(0xFFAAFFAA, (int)(180 * t * (0.5f + 0.5f * pulse)));
        drawPolyCircle(g, cx, y - r * 0.05f, r * 0.15f, 8);
    }
}

/**
 * Burn debuff from level-2 missile tower: red/orange DoT aura.
 * Does not stack — reapplying refreshes duration.
 */
static class BurnStatusEffect extends EnemyStatusEffect {
    float dps;
    float tickTimer = 0.5f;

    BurnStatusEffect(float dps, float duration) {
        super(duration);
        this.dps = dps;
    }

    boolean update(float dt) {
        timer -= dt;
        tickTimer -= dt;
        if (tickTimer <= 0) {
            // Find the enemy this effect is attached to and apply damage
            for (Enemy e : TdGameWorld.enemies) {
                if (e.statusEffects.contains(this)) {
                    e.hp -= dps * 0.5f;
                    e.hitFlashTimer = 0.05f;
                    break;
                }
            }
            tickTimer = 0.5f;
        }
        return timer > 0;
    }

    void render(PGraphics g, float x, float y, float r) {
        float t = timer / maxTimer;
        float pulse = PApplet.sin(t * PApplet.PI * 6);
        pulse = pulse * pulse;
        int alpha = (int)(220 * t * (0.5f + 0.5f * pulse));
        g.noStroke();

        // Outer orange aura
        g.fill(0xFFFF6600, (int)(60 * t));
        drawPolyCircle(g, x, y, r * 1.3f, 12);

        // Rotating ember ring
        g.fill(0xFFFF4400, (int)(140 * t));
        float ringR = r * 0.8f;
        float time = System.currentTimeMillis() / 1000f;
        float dotSize = r * 0.18f;
        for (int i = 0; i < 6; i++) {
            float a = PApplet.TWO_PI / 6 * i + time * 3;
            float px = x + PApplet.cos(a) * ringR;
            float py = y + PApplet.sin(a) * ringR;
            g.rect(px - dotSize * 0.5f, py - dotSize * 0.5f, dotSize, dotSize);
        }

        // Core bright glow
        g.fill(0xFFFFAA00, (int)(180 * t));
        drawPolyCircle(g, x, y - r * 0.05f, r * 0.3f, 8);

        // Hot center
        g.fill(0xFFFFDD00, (int)(160 * t * (0.5f + 0.5f * pulse)));
        drawPolyCircle(g, x, y - r * 0.05f, r * 0.12f, 6);
    }
}

/** Lightweight polygon-circle (avoids ellipse overhead). */
public static void drawPolyCircle(PGraphics g, float cx, float cy, float radius, int segments) {
    g.beginShape();
    for (int i = 0; i < segments; i++) {
        float a = PApplet.TWO_PI / segments * i;
        g.vertex(cx + PApplet.cos(a) * radius, cy + PApplet.sin(a) * radius);
    }
    g.endShape(PApplet.CLOSE);
}

/** Lightweight triangle droplet (avoids ellipse overhead). */
private static void drawDroplet(PGraphics g, float cx, float cy, float w, float h) {
    g.beginShape();
    g.vertex(cx, cy - h * 0.5f);
    g.vertex(cx - w * 0.5f, cy + h * 0.5f);
    g.vertex(cx + w * 0.5f, cy + h * 0.5f);
    g.endShape(PApplet.CLOSE);
}
