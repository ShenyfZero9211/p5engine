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

    float sizeMult;

    MgTracerEffect(float x1, float y1, float x2, float y2) {
        this(x1, y1, x2, y2, 1f);
    }

    MgTracerEffect(float x1, float y1, float x2, float y2, float sizeMult) {
        super(0.08f);
        from.set(x1, y1);
        dest.set(x2, y2);
        this.sizeMult = sizeMult;
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
        float w1 = 2.5f * sizeMult;
        float w2 = 1f * sizeMult;
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
            g.strokeWeight(w1);
            g.line(sx, sy, ex, ey);
            g.stroke(0xFFFFFFFF, (int)(120 * t * rng.nextFloat()));
            g.strokeWeight(w2);
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

    float sizeMult;

    ExplosionEffect(float x, float y, float maxRadius) {
        this(x, y, maxRadius, 1f);
    }

    ExplosionEffect(float x, float y, float maxRadius, float sizeMult) {
        super(0.3f);
        pos.set(x, y);
        this.maxRadius = maxRadius;
        this.sizeMult = sizeMult;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float fade = PApplet.sin(progress * PApplet.PI);  // fade in then out
        float effRadius = maxRadius * sizeMult;

        // Main shockwave
        float r0 = effRadius * progress;
        g.noFill();
        g.stroke(0xFFFF6633, (int)(50 * fade));
        g.strokeWeight(2);
        drawPolyCircle(g, pos.x, pos.y, r0, 24);
        g.noStroke();
        g.fill(0xFFFF6633, (int)(60 * fade));
        drawPolyCircle(g, pos.x, pos.y, r0 * 0.75f, 20);

        // Echo 1: trailing at 0.7x radius
        float r1 = maxRadius * progress * 0.7f;
        g.noFill();
        g.stroke(0xFFFF8855, (int)(50 * fade));
        g.strokeWeight(1.5f);
        drawPolyCircle(g, pos.x, pos.y, r1, 20);

        // Echo 2: trailing further at 0.45x radius
        float r2 = maxRadius * progress * 0.45f;
        g.noFill();
        g.stroke(0xFFFFAA77, (int)(50 * fade));
        g.strokeWeight(1);
        drawPolyCircle(g, pos.x, pos.y, r2, 16);
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
        drawPolyCircle(g, pos.x, pos.y, radius * t, 8);
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
    final float rotation;

    DeathEffect(float x, float y, float radius, boolean carryingOrbs, float rotation) {
        super(0.7f);
        pos.set(x, y);
        baseRadius = radius;
        wasGold = carryingOrbs;
        this.rotation = rotation;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        int bodyColor = wasGold ? 0xFFFFDD00 : 0xFFFF6666;
        int glowColor = wasGold ? 0xFFFFDD00 : 0xFFFF4444;

        // Phase 1: arrow fading (0~0.25s), glow stays exactly as living enemy
        if (progress < 0.25f) {
            float t = progress / 0.25f;
            int arrowAlpha = (int)(255 * (1 - t));

            // Glow — identical to living enemy, NO fading in this phase
            g.noStroke();
            g.fill(glowColor, wasGold ? 80 : 60);
            drawPolyCircle(g, pos.x, pos.y, baseRadius * 1.4f, 16);

            // Arrow body — same orientation as the enemy
            g.pushMatrix();
            g.translate(pos.x, pos.y);
            g.rotate(rotation);
            g.noStroke();
            g.fill(bodyColor, arrowAlpha);
            g.beginShape();
            g.vertex(baseRadius * 1.2f, 0);
            g.vertex(-baseRadius * 0.6f, -baseRadius * 0.7f);
            g.vertex(-baseRadius * 0.3f, 0);
            g.vertex(-baseRadius * 0.6f, baseRadius * 0.7f);
            g.endShape(PApplet.CLOSE);
            g.popMatrix();
        }

        // Phase 2: glow shrinking + fading (0.25~0.5s)
        // Arrow is gone; the glow shrinks and fades until fully vanished.
        if (progress >= 0.25f && progress < 0.5f) {
            float t = (progress - 0.25f) / 0.25f;
            float r = baseRadius * 1.4f * (1 - t);
            int alpha = (int)((wasGold ? 80 : 60) * (1 - t));
            if (r > 0.5f && alpha > 0) {
                g.noStroke();
                g.fill(glowColor, alpha);
                drawPolyCircle(g, pos.x, pos.y, r, 16);
            }
        }

        // Phase 3: fragments burst (0.4~0.7s)
        if (progress >= 0.4f) {
            float burst = (progress - 0.4f) / 0.3f;
            if (burst > 1f) burst = 1f;
            int fragAlpha = (int)(255 * (1 - burst));
            g.noStroke();
            g.fill(bodyColor, fragAlpha);

            int fragments = 5;
            for (int i = 0; i < fragments; i++) {
                float angle = i * PApplet.TWO_PI / fragments + burst * 2;
                float dist = burst * baseRadius * 2.5f;
                float fx = pos.x + PApplet.cos(angle) * dist;
                float fy = pos.y + PApplet.sin(angle) * dist;
                float fr = baseRadius * 0.4f * (1 - burst);
                drawPolyCircle(g, fx, fy, fr, 12);
            }
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
 * Command tower buff wave: expanding ant-line rings with rotation.
 * Pure visual — no gameplay logic attached.
 */
static class CommandWaveEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float maxRadius;
    final long spawnTime;

    CommandWaveEffect(float x, float y, float maxRadius) {
        super(2.0f); // slow overall duration
        pos.set(x, y);
        this.maxRadius = maxRadius;
        this.spawnTime = System.currentTimeMillis();
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float radius = maxRadius * progress;
        float fade = life / maxLife;
        if (radius <= 3f || fade <= 0.01f) return;

        float elapsed = (System.currentTimeMillis() - spawnTime) / 1000f;
        int segments = 20;

        // 3 ant-line rings, counter-rotating
        for (int ring = 0; ring < 3; ring++) {
            float r = radius * (0.4f + ring * 0.3f);
            if (r <= 3f) continue;

            float dir = (ring % 2 == 0) ? 1f : -1f;
            float rot = elapsed * 0.7f * dir + ring * 0.4f;
            int alpha = (int)(65 * fade * (1f - ring * 0.2f));
            float sw = 2f - ring * 0.4f;

            g.noFill();
            g.stroke(0xFFFFD700, alpha);
            g.strokeWeight(sw);

            for (int i = 0; i < segments; i++) {
                float a0 = rot + i * PApplet.TWO_PI / segments;
                float dash = PApplet.TWO_PI / segments * 0.55f;
                float x0 = pos.x + PApplet.cos(a0) * r;
                float y0 = pos.y + PApplet.sin(a0) * r;
                float x1 = pos.x + PApplet.cos(a0 + dash) * r;
                float y1 = pos.y + PApplet.sin(a0 + dash) * r;
                g.line(x0, y0, x1, y1);
            }
        }
    }
}

/**
 * Poison tower fan cloud: expanding fan-shaped green cloud.
 */
static class PoisonCloudEffect extends Effect {
    final Vector2 pos = new Vector2();
    final float maxRadius;
    final float facingAngle;
    final float fanAngle;

    PoisonCloudEffect(float x, float y, float maxRadius, float facingAngle, float fanAngle) {
        super(0.6f);
        pos.set(x, y);
        this.maxRadius = maxRadius;
        this.facingAngle = facingAngle;
        this.fanAngle = fanAngle;
    }

    void render(PGraphics g) {
        float progress = 1f - (life / maxLife);
        float radius = maxRadius * progress;
        float t = life / maxLife;
        if (radius <= 0.5f) return;

        float startA = facingAngle - fanAngle * 0.5f;
        float endA = facingAngle + fanAngle * 0.5f;

        // Helper: draw filled fan using triangle fan (much faster than arc())
        g.noStroke();
        int layers = 8;
        for (int i = layers; i >= 0; i--) {
            float r = radius * (i / (float)layers);
            if (r <= 0.5f) continue;
            int alpha = (int)(70 * t * (1f - i / (float)layers));
            g.fill(0xFF44CC44, alpha);
            drawFan(g, pos.x, pos.y, r, startA, endA, 16);
        }

        // Dense inner core
        g.fill(0xFF66FF66, (int)(100 * t * (1f - progress * 0.5f)));
        drawFan(g, pos.x, pos.y, radius * 0.6f,
                facingAngle - fanAngle * 0.4f,
                facingAngle + fanAngle * 0.4f, 12);

        // Scattered poison particles inside the fan (reduced count for performance)
        java.util.Random rng = new java.util.Random((long)(pos.x * 1000 + pos.y));
        g.fill(0xFFAAFFAA, (int)(200 * t));
        for (int i = 0; i < 8; i++) {
            float dist = rng.nextFloat() * radius * progress;
            float angleOffset = (rng.nextFloat() - 0.5f) * fanAngle * 0.8f;
            float a = facingAngle + angleOffset;
            float px = pos.x + PApplet.cos(a) * dist;
            float py = pos.y + PApplet.sin(a) * dist;
            g.rect(px - 1.5f, py - 1.5f, 3, 3);
        }

        // Leading edge bright arc (drawn as short line segments)
        float midFade = PApplet.pow(PApplet.sin(progress * PApplet.PI), 3);
        g.noFill();
        g.stroke(0xFFAAFFAA, (int)(180 * midFade * t));
        g.strokeWeight(2 + midFade * 3f);
        drawArcLine(g, pos.x, pos.y, radius, startA, endA, 24);

        // Inner bright arc
        g.stroke(0xFFFFFFFF, (int)(100 * midFade * t));
        g.strokeWeight(1);
        drawArcLine(g, pos.x, pos.y, radius * 0.7f,
                    facingAngle - fanAngle * 0.35f,
                    facingAngle + fanAngle * 0.35f, 16);
    }

    // Fast triangle-fan fill (avoids slow arc())
    private void drawFan(PGraphics g, float cx, float cy, float r,
                          float startA, float endA, int segments) {
        float step = (endA - startA) / segments;
        g.beginShape();
        g.vertex(cx, cy);
        for (int i = 0; i <= segments; i++) {
            float a = startA + step * i;
            g.vertex(cx + PApplet.cos(a) * r, cy + PApplet.sin(a) * r);
        }
        g.endShape(PApplet.CLOSE);
    }

    // Fast arc outline using short line segments (avoids slow arc())
    private void drawArcLine(PGraphics g, float cx, float cy, float r,
                              float startA, float endA, int segments) {
        float step = (endA - startA) / segments;
        g.beginShape();
        for (int i = 0; i <= segments; i++) {
            float a = startA + step * i;
            g.vertex(cx + PApplet.cos(a) * r, cy + PApplet.sin(a) * r);
        }
        g.endShape();
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
        drawPolyCircle(g, pos.x, pos.y, r, 16);
        g.stroke(ringColor, (int)(160 * fade));
        g.strokeWeight(2);
        drawPolyCircle(g, pos.x, pos.y, r * 0.8f, 16);
        g.stroke(0xFFFFFFFF, (int)(80 * fade));
        g.strokeWeight(1);
        drawPolyCircle(g, pos.x, pos.y, r * 0.6f, 16);
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
        drawPolyCircle(g, pos.x, pos.y, r, 16);
        g.stroke(0xFFFF6633, (int)(80 * fade));
        g.strokeWeight(1);
        drawPolyCircle(g, pos.x, pos.y, r * 0.7f, 16);
    }
}
