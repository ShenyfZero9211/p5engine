/**
 * Lightweight visual effects system (no physics, render-only).
 * Decouples damage结算 from visual presentation for tower attacks.
 */

static abstract class Effect {
    float life;
    float maxLife;

    Effect(float maxLife) {
        this.maxLife = maxLife;
        this.life = maxLife;
    }

    void update(float dt) {
        life -= dt;
    }

    abstract void render(PGraphics g);

    boolean isDead() {
        return life <= 0;
    }
}

/**
 * Machine-gun tracer line: instant damage visual feedback.
 */
static class MgTracerEffect extends Effect {
    final Vector2 from = new Vector2();
    final Vector2 dest = new Vector2();

    MgTracerEffect(float x1, float y1, float x2, float y2) {
        super(0.08f);
        from.set(x1, y1);
        dest.set(x2, y2);
    }

    void render(PGraphics g) {
        float t = life / maxLife;
        float dx = dest.x - from.x;
        float dy = dest.y - from.y;
        float len = PApplet.sqrt(dx*dx + dy*dy);
        if (len <= 0) return;

        long seed = System.nanoTime();
        java.util.Random rng = new java.util.Random(seed);

        int segments = 3 + rng.nextInt(3);
        g.noFill();
        for (int i = 0; i < segments; i++) {
            float startRatio = rng.nextFloat();
            float segLen = 10 + rng.nextFloat() * 25;
            float segRatio = PApplet.min(1f, segLen / len);
            float sx = from.x + dx * startRatio;
            float sy = from.y + dy * startRatio;
            float ex = from.x + dx * PApplet.min(1f, startRatio + segRatio);
            float ey = from.y + dy * PApplet.min(1f, startRatio + segRatio);
            g.stroke(0xFFFFFF00, (int)(180 * t));
            g.strokeWeight(2.5f);
            g.line(sx, sy, ex, ey);
            g.stroke(0xFFFFFFFF, (int)(120 * t * rng.nextFloat()));
            g.strokeWeight(1);
            g.line(sx, sy, ex, ey);
        }
    }
}

/**
 * Missile explosion: expanding circle that fades out.
 */
static class ExplosionEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float maxRadius;

    ExplosionEffect(float x, float y, float maxRadius) {
        super(0.3f);
        pos.set(x, y);
        this.maxRadius = maxRadius;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float fade = PApplet.sin(progress * PApplet.PI);  // fade in then out

        // Main shockwave
        float r0 = maxRadius * progress;
        g.noFill();
        g.stroke(0xFFFF6633, (int)(50 * fade));
        g.strokeWeight(2);
        g.ellipse(pos.x, pos.y, r0 * 2, r0 * 2);
        g.noStroke();
        g.fill(0xFFFF6633, (int)(60 * fade));
        g.ellipse(pos.x, pos.y, r0 * 1.5f, r0 * 1.5f);

        // Echo 1: trailing at 0.7x radius
        float r1 = maxRadius * progress * 0.7f;
        g.noFill();
        g.stroke(0xFFFF8855, (int)(50 * fade));
        g.strokeWeight(1.5f);
        g.ellipse(pos.x, pos.y, r1 * 2, r1 * 2);

        // Echo 2: trailing further at 0.45x radius
        float r2 = maxRadius * progress * 0.45f;
        g.noFill();
        g.stroke(0xFFFFAA77, (int)(50 * fade));
        g.strokeWeight(1);
        g.ellipse(pos.x, pos.y, r2 * 2, r2 * 2);
    }
}

/**
 * Missile smoke trail: drifts backward along the ballistic path and expands.
 */
static class MissileSmokeEffect extends Effect {
    final Vector2 pos = new Vector2();
    final Vector2 drift = new Vector2();
    float radius;

    MissileSmokeEffect(float x, float y, float vx, float vy) {
        super(0.6f);
        pos.set(x, y);
        drift.set(-vx * 0.15f + (float)(Math.random() - 0.5) * 30,
                  -vy * 0.15f + (float)(Math.random() - 0.5) * 30);
        radius = 4 + (float)Math.random() * 4;
    }

    void update(float dt) {
        super.update(dt);
        pos.x += drift.x * dt;
        pos.y += drift.y * dt;
        radius += 15 * dt;
    }

    void render(PGraphics g) {
        float t = life / maxLife;
        g.noStroke();
        g.fill(0xFFAAAAAA, (int)(100 * t));
        g.ellipse(pos.x, pos.y, radius * 2 * t, radius * 2 * t);
    }
}

/**
 * Laser beam: thickness pulses thin -> thick -> thin.
 */
static class LaserBeamEffect extends Effect {
    final Vector2 from = new Vector2();
    final Vector2 dest = new Vector2();

    LaserBeamEffect(float x1, float y1, float x2, float y2) {
        super(0.35f);
        from.set(x1, y1);
        dest.set(x2, y2);
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float pulse = PApplet.sin(progress * PApplet.PI);
        float weight = 1.5f + pulse * 5f;
        float alpha = (int)(200 * pulse);
        g.noFill();
        g.stroke(0xFFC878DC, alpha);
        g.strokeWeight(weight);
        g.line(from.x, from.y, dest.x, dest.y);
        // Core bright line
        g.stroke(0xFFFFFFFF, (int)(160 * pulse));
        g.strokeWeight(weight * 0.4f);
        g.line(from.x, from.y, dest.x, dest.y);
    }
}

/**
 * Enemy death animation: collapse then burst into fragments.
 */
static class DeathEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float baseRadius;
    final boolean wasGold;

    DeathEffect(float x, float y, float radius, boolean carryingOrbs) {
        super(0.7f);
        pos.set(x, y);
        baseRadius = radius;
        wasGold = carryingOrbs;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);

        if (progress < 0.6f) {  // phase 1: collapse (0~0.42s)
            float collapse = progress / 0.6f;
            float r = baseRadius;
            int alpha = (int)(255 * (1 - collapse));
            int bodyColor = wasGold ? 0xFFFFDD00 : 0xFFFF6666;
            g.noStroke();
            g.fill(bodyColor, alpha);
            g.ellipse(pos.x, pos.y, r * 2, r * 2);
            // white highlight hidden
        } else {  // phase 2: fragments burst (0.42~0.7s)
            float burst = (progress - 0.6f) / 0.4f;
            int fragAlpha = (int)(255 * (1 - burst));
            int fragColor = wasGold ? 0xFFFFDD00 : 0xFFFF6666;
            g.noStroke();
            g.fill(fragColor, fragAlpha);

            int fragments = 5;
            for (int i = 0; i < fragments; i++) {
                float angle = i * PApplet.TWO_PI / fragments + burst * 2;
                float dist = burst * baseRadius * 2.5f;
                float fx = pos.x + PApplet.cos(angle) * dist;
                float fy = pos.y + PApplet.sin(angle) * dist;
                float fr = baseRadius * 0.4f * (1 - burst);
                g.ellipse(fx, fy, fr * 2, fr * 2);
            }
            g.fill(0xFFFFFFFF, (int)(180 * (1 - burst)));
            g.ellipse(pos.x, pos.y, baseRadius * 0.35f * (1 - burst), baseRadius * 0.35f * (1 - burst));
        }
    }
}

/**
 * Slow tower wave: expanding ring that slows enemies on creation.
 */
static class SlowWaveEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float maxRadius;

    SlowWaveEffect(float x, float y, float maxRadius) {
        super(0.5f);
        pos.set(x, y);
        this.maxRadius = maxRadius;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float radius = maxRadius * progress;
        float t = life / maxLife;
        if (radius <= 0.5f) return;

        // Radial gradient fill: 6 concentric circles, alpha fades from center to edge
        int layers = 6;
        for (int i = layers; i >= 0; i--) {
            float r = radius * (i / (float)layers);
            if (r <= 0.5f) continue;
            int alpha = (int)(40 * t * (1f - i / (float)layers));
            g.noStroke();
            g.fill(0xFF44FF66, alpha);
            g.ellipse(pos.x, pos.y, r * 2, r * 2);
        }

        // Leading edge ring: only visible near the middle of the duration
        float midFade = PApplet.pow(PApplet.sin(progress * PApplet.PI), 3);
        g.noFill();
        g.stroke(0xFF44FF66, (int)(120 * midFade));
        g.strokeWeight(1 + midFade * 2.5f);
        g.ellipse(pos.x, pos.y, radius * 2, radius * 2);
    }
}

/**
 * Enemy spawn effect: expanding ring at spawn point.
 */
static class EnemySpawnEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float maxRadius;
    final int ringColor;

    EnemySpawnEffect(float x, float y, float radius, boolean isGold) {
        super(0.4f);
        pos.set(x, y);
        maxRadius = radius * 5f;
        ringColor = isGold ? 0xFFFFDD00 : 0xFFFF4444;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float fade = 1f - progress;
        float r = maxRadius * progress;
        g.noFill();
        g.stroke(ringColor, (int)(255 * fade));
        g.strokeWeight(3);
        g.ellipse(pos.x, pos.y, r * 2, r * 2);
        g.stroke(ringColor, (int)(160 * fade));
        g.strokeWeight(2);
        g.ellipse(pos.x, pos.y, r * 1.6f, r * 1.6f);
        g.stroke(0xFFFFFFFF, (int)(80 * fade));
        g.strokeWeight(1);
        g.ellipse(pos.x, pos.y, r * 1.2f, r * 1.2f);
    }
}

/**
 * Enemy escape effect: shrinking ring at exit point.
 */
static class EnemyEscapeEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float startRadius;

    EnemyEscapeEffect(float x, float y, float radius) {
        super(0.3f);
        pos.set(x, y);
        startRadius = radius * 3f;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float fade = 1f - progress;
        float r = startRadius * (1f - progress);
        if (r < 1) return;
        g.noFill();
        g.stroke(0xFFFF8C42, (int)(150 * fade));
        g.strokeWeight(2);
        g.ellipse(pos.x, pos.y, r * 2, r * 2);
        g.stroke(0xFFFF6633, (int)(80 * fade));
        g.strokeWeight(1);
        g.ellipse(pos.x, pos.y, r * 1.4f, r * 1.4f);
    }
}
