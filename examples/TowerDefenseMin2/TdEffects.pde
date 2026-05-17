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
        super(1.0f);
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
        int segments = 24;

        // Subtle golden disc underneath
        g.noStroke();
        g.fill(0xFFFFD700, (int)(18 * fade));
        drawPolyCircle(g, pos.x, pos.y, radius * 0.95f, 48);

        // 3 ant-line rings, counter-rotating
        for (int ring = 0; ring < 3; ring++) {
            float r = radius * (0.35f + ring * 0.32f);
            if (r <= 3f) continue;

            float dir = (ring % 2 == 0) ? 1f : -1f;
            float rot = elapsed * 0.9f * dir + ring * 0.4f;
            int alpha = (int)(120 * fade * (1f - ring * 0.2f));
            float sw = 3f - ring * 0.5f;

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

/**
 * Tesla chain lightning arc: jagged electric lines that grow segment-by-segment.
 * Each branch follows a unique random-walk path: every anchor is spawned within
 * a random range from the previous one, gradually approaching the target.
 * Damage is applied exactly when the arc reaches its target.
 *
 * Anchor points are pre-calculated at creation time and never change.
 * Each anchor vibrates independently (not branch-wide) for a realistic
 * electric crackle effect.
 */
static class TeslaArcEffect extends Effect {
    static final float SEGMENT_GROW_TIME = 0.08f;
    static final float CHAIN_DELAY = 0.15f;
    static final float HOLD_TIME = 1.0f;
    static final int BRANCH_COUNT = 3;
    static final int ANCHORS_PER_BRANCH = 7;

    final Vector2 towerPos;
    final java.util.ArrayList<Enemy> chain = new java.util.ArrayList<>();
    final float[] segmentDamages;
    final boolean[] damageApplied;

    // Pre-calculated anchor params: [segIndex][branch][anchorIndex] -> {t, offset}
    // t = ratio along path (0~1), offset = perpendicular displacement in pixels
    final float[][][] anchorT;
    final float[][][] anchorOffset;

    TeslaArcEffect(float towerX, float towerY, java.util.ArrayList<Enemy> chainEnemies, float baseDamage, float chainDecay, float cmdMult) {
        super(Math.max(0.45f, chainEnemies.size() * CHAIN_DELAY + SEGMENT_GROW_TIME + HOLD_TIME));
        this.towerPos = new Vector2(towerX, towerY);
        this.chain.addAll(chainEnemies);
        int segCount = chainEnemies.size();
        segmentDamages = new float[segCount];
        damageApplied = new boolean[segCount];
        float dmg = baseDamage * cmdMult;
        for (int i = 0; i < segCount; i++) {
            segmentDamages[i] = dmg;
            if (i > 0) dmg *= (1f - chainDecay);
        }

        // Pre-calculate anchor points with random step spacing so paths look completely different
        anchorT = new float[segCount][BRANCH_COUNT][ANCHORS_PER_BRANCH];
        anchorOffset = new float[segCount][BRANCH_COUNT][ANCHORS_PER_BRANCH];
        for (int s = 0; s < segCount; s++) {
            for (int b = 0; b < BRANCH_COUNT; b++) {
                java.util.Random rng = new java.util.Random(s * 7919L + b * 13331L + System.nanoTime());
                // Build random step sizes; uneven spacing makes each path unique
                float[] steps = new float[ANCHORS_PER_BRANCH + 1];
                float totalStep = 0f;
                for (int i = 0; i < steps.length; i++) {
                    steps[i] = 0.05f + rng.nextFloat() * 0.20f;
                    totalStep += steps[i];
                }
                float accum = 0f;
                float prevOffset = 0f;
                float maxOffset = 18f;
                for (int a = 0; a < ANCHORS_PER_BRANCH; a++) {
                    accum += steps[a];
                    float t = Math.min(0.97f, accum / totalStep);
                    anchorT[s][b][a] = t;
                    // Midpoint-displacement smoothing: new offset drifts from previous one
                    // so adjacent anchors are correlated, avoiding sharp zig-zag corners
                    float targetOffset = (rng.nextFloat() - 0.5f) * 2f * maxOffset;
                    float offset = prevOffset + (targetOffset - prevOffset) * 0.55f;
                    // Envelope: offset converges near endpoints (start 0~10%, end 85~100%)
                    float envelope = (t < 0.1f) ? (t / 0.1f) : (t > 0.85f) ? ((1f - t) / 0.15f) : 1f;
                    envelope = envelope < 0.35f ? 0.35f : (envelope > 1f ? 1f : envelope);
                    anchorOffset[s][b][a] = offset * envelope;
                    prevOffset = offset;
                }
            }
        }
    }

    void update(float dt) {
        super.update(dt);
        float elapsed = maxLife - life;
        int segCount = damageApplied.length;
        for (int i = 0; i < segCount; i++) {
            if (damageApplied[i]) continue;
            float segFinish = i * CHAIN_DELAY + SEGMENT_GROW_TIME;
            if (elapsed >= segFinish) {
                Enemy e = chain.get(i);
                if (e != null && e.hp > 0) {
                    e.takeDamage(segmentDamages[i], TowerType.TESLA);
                    e.statusEffects.add(new TeslaHitMark());
                }
                damageApplied[i] = true;
            }
        }
    }

    void render(PGraphics g) {
        if (chain.isEmpty()) return;
        float elapsed = maxLife - life;
        int segmentCount = chain.size();
        float holdStart = segmentCount * CHAIN_DELAY + SEGMENT_GROW_TIME;
        float fade = 1f;
        if (elapsed > holdStart) {
            fade = 1f - (elapsed - holdStart) / HOLD_TIME;
            if (fade < 0f) fade = 0f;
            if (fade > 1f) fade = 1f;
        }
        if (fade <= 0f) return;

        for (int i = 0; i < segmentCount; i++) {
            float segStart = i * CHAIN_DELAY;
            if (elapsed < segStart) continue;
            float growth = Math.min(1f, (elapsed - segStart) / SEGMENT_GROW_TIME);
            Vector2 a = (i == 0) ? towerPos : chain.get(i - 1).pos;
            Vector2 b = chain.get(i).pos;
            if (a == null || b == null) continue;
            renderGrowingArc(g, a, b, i, growth, fade, elapsed);
        }
    }

    // Per-bounce base alpha and stroke weight lookup tables
    static final int[] SEG_BASE_ALPHAS = { 225, 190, 170, 150, 130, 130, 130 };
    static final float[] SEG_BASE_WEIGHTS = { 1.8f, 1.5f, 1.2f, 1.0f, 0.8f, 0.8f, 0.8f };

    private void renderGrowingArc(PGraphics g, Vector2 a, Vector2 b, int segIndex, float growth, float fade, float elapsed) {
        float dx = b.x - a.x;
        float dy = b.y - a.y;
        float fullLen = PApplet.sqrt(dx * dx + dy * dy);
        if (fullLen <= 0 || growth <= 0) return;

        float ex = a.x + dx * growth;
        float ey = a.y + dy * growth;

        float nx = dx / fullLen;
        float ny = dy / fullLen;
        float perpX = -ny;
        float perpY = nx;

        // Look up base alpha and weight for this bounce segment
        int baseAlpha = (segIndex < SEG_BASE_ALPHAS.length) ? SEG_BASE_ALPHAS[segIndex] : 45;
        float baseWeight = (segIndex < SEG_BASE_WEIGHTS.length) ? SEG_BASE_WEIGHTS[segIndex] : 0.4f;

        float[] branchWeights = { baseWeight, baseWeight * 0.72f, baseWeight * 0.42f };
        int[] branchAlphas = { baseAlpha, (int)(baseAlpha * 0.75f), (int)(baseAlpha * 0.45f) };

        for (int branchIdx = 0; branchIdx < BRANCH_COUNT; branchIdx++) {
            g.noFill();
            g.stroke(0xFF00E5FF, (int)(branchAlphas[branchIdx] * fade));
            g.strokeWeight(branchWeights[branchIdx] * fade);
            g.beginShape();
            g.vertex(a.x, a.y);

            for (int idx = 0; idx < ANCHORS_PER_BRANCH; idx++) {
                float t = anchorT[segIndex][branchIdx][idx];
                if (t > growth) break;

                float pathX = a.x + dx * t;
                float pathY = a.y + dy * t;
                float px = pathX + perpX * anchorOffset[segIndex][branchIdx][idx];
                float py = pathY + perpY * anchorOffset[segIndex][branchIdx][idx];

                // Three-layer Perlin Noise vibration:
                // slow drift + fast jitter + sporadic crackle
                PApplet applet = P5Engine.getInstance().getApplet();
                float drift  = (applet.noise(elapsed * 7f + idx * 0.8f + branchIdx * 0.4f) - 0.5f) * 5f;
                float jitter = (applet.noise(elapsed * 20f + idx * 1.5f + branchIdx * 0.9f + 100) - 0.5f) * 3f;
                float crackle = (applet.noise(elapsed * 30f + idx * 2.3f + 200) > 0.70f)
                                ? (applet.noise(elapsed * 50f + idx * 3.7f + 300) - 0.5f) * 12f
                                : 0f;
                float hum = drift + jitter + crackle;
                px += perpX * hum;
                py += perpY * hum;

                g.vertex(px, py);
            }

            g.vertex(ex, ey);
            g.endShape();
        }

        // // White hot core (hidden for now)
        // g.stroke(0xFFFFFFFF, (int)(160 * fade));
        // g.strokeWeight(0.8f * fade);
        // g.line(a.x, a.y, ex, ey);

        // Endpoint spark at growing tip
        if (growth < 1f) {
            g.noStroke();
            g.fill(0xFFFFFFFF, (int)(200 * fade));
            drawPolyCircle(g, ex, ey, 2f * fade, 6);
            g.fill(0xFF00E5FF, (int)(100 * fade));
            drawPolyCircle(g, ex, ey, 3.5f * fade, 8);
        }
    }
}


/**
 * Piercer fireball: calculates intercept at launch moment, flies straight to locked position.
 */
static class PiercerFireball {
    static final float CHARGE_TIME = 1.50f;
    enum State { CHARGING, FLYING, IMPACTED, EXPIRED }

    Vector2 pos = new Vector2();
    Vector2 vel = new Vector2();
    float towerX, towerY;
    float lockX, lockY;
    float flightTime;
    State state = State.CHARGING;
    float chargeTimer = 0f;
    float flightTimer = 0f;
    Enemy target;
    boolean lockCalculated = false;
    float speed = 600f;

    void reset(float sx, float sy, Enemy target, float speed) {
        pos.set(sx, sy);
        towerX = sx;
        towerY = sy;
        this.target = target;
        this.speed = speed;
        lockX = sx;
        lockY = sy;
        vel.set(0, 0);
        flightTime = 0f;
        state = State.CHARGING;
        chargeTimer = 0f;
        flightTimer = 0f;
        lockCalculated = false;
    }

    void calculateLock() {
        if (target == null || target.pos == null) {
            lockCalculated = true;
            return;
        }

        float tx = target.pos.x;
        float ty = target.pos.y;
        float dx = tx - towerX;
        float dy = ty - towerY;
        float vm = speed;

        // Get enemy velocity
        Vector2 ve = new Vector2(0, 0);
        if (target.activeRoute != null && target.activeRoute.path != null) {
            Vector2 edir = target.activeRoute.path.direction(target.routeProgress);
            if (edir != null) {
                ve.set(edir.x, edir.y);
                float speed = target.speed * target.slowFactor;
                if (target.backtracking) speed *= -1;
                ve.mult(speed);
            }
        }

        // If not moving, aim directly
        if (ve.magnitudeSq() <= 0.001f) {
            lockX = tx;
            lockY = ty;
            float len = PApplet.sqrt(dx*dx + dy*dy);
            if (len > 0) vel.set((dx/len)*speed, (dy/len)*speed);
            flightTime = len / speed;
            lockCalculated = true;
            return;
        }

        // Solve quadratic: (|Ve|² - Vm²) * t² + 2(D·Ve) * t + |D|² = 0
        float a = ve.magnitudeSq() - vm * vm;
        float b = 2 * (dx * ve.x + dy * ve.y);
        float c = dx * dx + dy * dy;

        float disc = b * b - 4 * a * c;
        if (disc < 0 || a == 0) {
            lockX = tx;
            lockY = ty;
            float len = PApplet.sqrt(dx*dx + dy*dy);
            if (len > 0) vel.set((dx/len)*speed, (dy/len)*speed);
            flightTime = len / speed;
            lockCalculated = true;
            return;
        }

        float sqrtDisc = PApplet.sqrt(disc);
        float t1 = (-b - sqrtDisc) / (2 * a);
        float t2 = (-b + sqrtDisc) / (2 * a);
        float t = (t1 > 0) ? t1 : (t2 > 0 ? t2 : 0);

        if (t <= 0) {
            lockX = tx;
            lockY = ty;
            float len = PApplet.sqrt(dx*dx + dy*dy);
            if (len > 0) vel.set((dx/len)*speed, (dy/len)*speed);
            flightTime = len / speed;
            lockCalculated = true;
            return;
        }

        // Intercept position
        lockX = towerX + dx + ve.x * t;
        lockY = towerY + dy + ve.y * t;

        float fdx = lockX - towerX;
        float fdy = lockY - towerY;
        float len = PApplet.sqrt(fdx*fdx + fdy*fdy);
        if (len > 0) {
            vel.set((fdx/len)*speed, (fdy/len)*speed);
        }
        flightTime = len / speed;
        lockCalculated = true;
    }

    void update(float dt) {
        switch (state) {
            case CHARGING:
                chargeTimer += dt;
                if (chargeTimer >= CHARGE_TIME) {
                    calculateLock();
                    state = State.FLYING;
                }
                break;
            case FLYING:
                float remainDx = lockX - pos.x;
                float remainDy = lockY - pos.y;
                float moveDx = vel.x * dt;
                float moveDy = vel.y * dt;

                if (remainDx * remainDx + remainDy * remainDy <= moveDx * moveDx + moveDy * moveDy) {
                    pos.set(lockX, lockY);
                    state = State.IMPACTED;
                } else {
                    pos.x += moveDx;
                    pos.y += moveDy;
                }
                flightTimer += dt;
                break;
            case IMPACTED:
            case EXPIRED:
                break;
        }
    }

    boolean isCharging() { return state == State.CHARGING; }
    boolean isFlying() { return state == State.FLYING; }
    boolean hasImpacted() { return state == State.IMPACTED; }
    boolean hasExpired() { return state == State.EXPIRED; }

    float getRadius() {
        if (state == State.CHARGING) {
            return 3f + (chargeTimer / CHARGE_TIME) * 11f;
        }
        return 14f;
    }

    void getRenderPosition(PApplet applet, float[] out) {
        if (state == State.CHARGING) {
            float p = chargeTimer / CHARGE_TIME;
            float amp = (1.5f + p * 2.5f) * 2f;
            out[0] = pos.x + (applet.noise(chargeTimer * 12f) - 0.5f) * amp;
            out[1] = pos.y + (applet.noise(chargeTimer * 12f + 77.7f) - 0.5f) * amp;
        } else {
            float p = (flightTime > 0) ? Math.min(1f, flightTimer / flightTime) : 1f;
            float amp = PApplet.lerp(4.0f, 1.0f, p) * 2f;
            float elapsed = chargeTimer + flightTimer;
            out[0] = pos.x + (applet.noise(elapsed * 12f) - 0.5f) * amp;
            out[1] = pos.y + (applet.noise(elapsed * 12f + 77.7f) - 0.5f) * amp;
        }
    }
}

/**
 * Piercer beam effect: manages fireball visuals, trail, explosion and recoil.
 */
static class PiercerBeamEffect extends Effect {
    static final float EXPLODE_TIME = 0.24f;
    static final float AFTER_TIME = 0.50f;
    static final float EXPLODE_RADIUS = 40f;

    final float sx, sy;
    final float dmg;
    String fireSfx;
    Enemy target;
    Tower tower;
    PiercerFireball fireball;
    float impactElapsed = -1f;
    boolean impactRecorded = false;
    boolean damageApplied = false;
    boolean wasFlying = false;
    final float[] shardAngle = new float[8];
    final float[] shardSpeed = new float[8];

    PiercerBeamEffect(float sx, float sy, Enemy target, float dmg, String fireSfx, Tower tower) {
        super(PiercerFireball.CHARGE_TIME + 2.0f + EXPLODE_TIME + AFTER_TIME);
        this.sx = sx;
        this.sy = sy;
        this.target = target;
        this.dmg = dmg;
        this.fireSfx = fireSfx;
        this.tower = tower;
        this.fireball = new PiercerFireball();
        float fbSpeed = (tower != null && tower.def != null) ? tower.def.missileSpeed : 600f;
        fireball.reset(sx, sy, target, fbSpeed);
        java.util.Random rng = new java.util.Random(System.nanoTime());
        for (int i = 0; i < 8; i++) {
            shardAngle[i] = rng.nextFloat() * PApplet.TWO_PI;
            shardSpeed[i] = 40f + rng.nextFloat() * 80f;
        }
    }

    void update(float dt) {
        super.update(dt);
        boolean flyingBefore = wasFlying;
        fireball.update(dt);
        wasFlying = fireball.isFlying();
        if (!flyingBefore && wasFlying) {
            if (fireSfx != null) TdAssets.playSfx(fireSfx);
            if (tower != null) TdLightingSystem.addFireFlash(tower);
        }
        if (!impactRecorded && fireball.hasImpacted()) {
            impactElapsed = maxLife - life;
            impactRecorded = true;
        }
        if (!damageApplied && fireball.hasImpacted()) {
            applyExplosionDamage();
            damageApplied = true;
        }
    }

    void applyExplosionDamage() {
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp <= 0 || e.pos == null) continue;
            float dx = fireball.lockX - e.pos.x;
            float dy = fireball.lockY - e.pos.y;
            if (dx * dx + dy * dy <= EXPLODE_RADIUS * EXPLODE_RADIUS) {
                e.takeDamage(dmg, TowerType.PIERCER);
            }
        }
    }

    void render(PGraphics g) {
        float elapsed = maxLife - life;
        float globalFade = life / maxLife;
        if (globalFade <= 0f) return;

        PApplet applet = P5Engine.getInstance().getApplet();
        float[] ballPos = new float[2];
        fireball.getRenderPosition(applet, ballPos);
        float ballRadius = fireball.getRadius();

        // Determine trail endpoints
        float trailEx = fireball.lockCalculated ? fireball.lockX : sx;
        float trailEy = fireball.lockCalculated ? fireball.lockY : sy;
        if (fireball.isFlying()) {
            trailEx = ballPos[0];
            trailEy = ballPos[1];
        }

        // === Scorch trail ===
        if (elapsed >= PiercerFireball.CHARGE_TIME) {
            float trailStart, trailEnd;
            if (fireball.isFlying()) {
                trailStart = 0f;
                trailEnd = 1f;
            } else {
                float afterProgress = (elapsed - impactElapsed) / (EXPLODE_TIME + AFTER_TIME);
                trailStart = PApplet.min(1f, afterProgress);
                trailEnd = 1f;
            }
            if (trailEnd > trailStart) {
                drawScorchTrail(g, sx, sy, trailEx, trailEy, trailStart, trailEnd, elapsed);
            }
        }

        // === Fireball glow (charging or flying) ===
        if (!fireball.hasImpacted() && !fireball.hasExpired()) {
            g.noStroke();
            drawRadialGlow(g, ballPos[0], ballPos[1], ballRadius * 2.5f,
                0xFFFF7744, 110, 0xFFDD4422, 0, 24);
            drawRadialGlow(g, ballPos[0], ballPos[1], ballRadius * 1.5f,
                0xFFFFAA66, 200, 0xFFFF7744, 80, 20);
            drawRadialGlow(g, ballPos[0], ballPos[1], ballRadius * 0.8f,
                0xFFFFFFFF, 255, 0xFFFFAA66, 150, 16);

            // Flight tail dots
            if (fireball.isFlying()) {
                float dx = trailEx - sx;
                float dy = trailEy - sy;
                float flightProgress = (fireball.flightTime > 0) ? fireball.flightTimer / fireball.flightTime : 1f;
                for (int trail = 0; trail < 4; trail++) {
                    float trailT = flightProgress - trail * 0.04f;
                    if (trailT < 0) continue;
                    float tx = sx + dx * trailT;
                    float ty = sy + dy * trailT;
                    float trailFade = 1f - trail * 0.25f;
                    g.fill(0xFFFF2200, (int)(60 * trailFade));
                    drawPolyCircle(g, tx, ty, ballRadius * trailFade * 0.9f, 10);
                    g.fill(0xFFFF6600, (int)(100 * trailFade));
                    drawPolyCircle(g, tx, ty, ballRadius * trailFade * 0.6f, 8);
                }
            }
        }

        // === Explosion on impact ===
        if (fireball.hasImpacted() && impactElapsed >= 0) {
            float explodeElapsed = elapsed - impactElapsed;
            if (explodeElapsed < EXPLODE_TIME) {
                float explodeProgress = explodeElapsed / EXPLODE_TIME;
                float explodeFade = 1f - explodeProgress;
                float explodeBase = 14f * (1f + explodeProgress * 2f);
                g.noStroke();
                drawRadialGlow(g, fireball.lockX, fireball.lockY, explodeBase * 2.5f,
                    0xFFFF7744, (int)(110 * explodeFade),
                    0xFFDD4422, 0, 24);
                drawRadialGlow(g, fireball.lockX, fireball.lockY, explodeBase * 1.5f,
                    0xFFFFAA66, (int)(200 * explodeFade),
                    0xFFFF7744, (int)(80 * explodeFade), 20);
                drawRadialGlow(g, fireball.lockX, fireball.lockY, explodeBase * 0.8f,
                    0xFFFFFFFF, (int)(255 * explodeFade),
                    0xFFFFAA66, (int)(150 * explodeFade), 16);
            }
        }

        // === Tower recoil glow (triggered at launch moment) ===
        float recoilElapsed = elapsed - PiercerFireball.CHARGE_TIME;
        if (recoilElapsed >= 0 && recoilElapsed < 0.50f) {
            float recoilFade = 1f - recoilElapsed / 0.50f;
            g.noStroke();
            g.fill(0xFFFF2200, (int)(160 * recoilFade));
            drawPolyCircle(g, sx, sy, 12f * recoilFade, 10);
            g.fill(0xFFFF6600, (int)(180 * recoilFade));
            drawPolyCircle(g, sx, sy, 8f * recoilFade, 8);
            g.fill(0xFFFFFFFF, (int)(160 * recoilFade));
            drawPolyCircle(g, sx, sy, 4f * recoilFade, 6);
        }
    }

    void drawScorchTrail(PGraphics g, float ax, float ay, float bx, float by,
                         float t0, float t1, float elapsed) {
        if (t1 <= t0) return;
        float dx = bx - ax;
        float dy = by - ay;
        float len = PApplet.sqrt(dx * dx + dy * dy);
        if (len <= 0) return;

        PApplet applet = P5Engine.getInstance().getApplet();
        float perpX = -dy / len;
        float perpY = dx / len;
        int segments = 40;
        float baseWidth = 28f;

        int[] layerColors = { 0xFF331111, 0xFF552211, 0xFF883311 };
        float[] layerWidthMult = { 1.0f, 0.6f, 0.25f };
        int[] layerBaseAlpha = { 130, 100, 70 };

        for (int layer = 0; layer < 3; layer++) {
            g.noStroke();
            g.beginShape(PApplet.QUAD_STRIP);
            for (int i = 0; i <= segments; i++) {
                float t = t0 + (t1 - t0) * (i / (float)segments);

                float edgeFade = 1f;
                float edgeRange = 0.20f;
                if (t > t1 - edgeRange) edgeFade = (t1 - t) / edgeRange;
                if (t < t0 + edgeRange) edgeFade *= (t - t0) / edgeRange;

                float spotAge = elapsed - (PiercerFireball.CHARGE_TIME + t * fireball.flightTime);
                float alphaDecay = PApplet.max(0f, 1f - spotAge * 0.5f);
                float widthDecay = PApplet.max(0.3f, 1f - spotAge * 0.35f);

                float noiseX = (applet.noise(t * 5f + ax * 0.1f) - 0.5f) * 4f;
                float noiseY = (applet.noise(t * 5f + ay * 0.1f + 33.3f) - 0.5f) * 4f;
                float cx = ax + dx * t + noiseX;
                float cy = ay + dy * t + noiseY;
                float w = baseWidth * layerWidthMult[layer] * widthDecay * 0.5f;

                int alpha = (int)(layerBaseAlpha[layer] * alphaDecay * edgeFade);
                g.fill(layerColors[layer], alpha);
                g.vertex(cx + perpX * w, cy + perpY * w);
                g.vertex(cx - perpX * w, cy - perpY * w);
            }
            g.endShape();
        }

        // Ember glow strip at center
        g.beginShape(PApplet.QUAD_STRIP);
        for (int i = 0; i <= segments; i++) {
            float t = t0 + (t1 - t0) * (i / (float)segments);
            float edgeFade = 1f;
            float edgeRange = 0.20f;
            if (t > t1 - edgeRange) edgeFade = (t1 - t) / edgeRange;
            if (t < t0 + edgeRange) edgeFade *= (t - t0) / edgeRange;

            float spotAge = elapsed - (PiercerFireball.CHARGE_TIME + t * fireball.flightTime);
            float alphaDecay = PApplet.max(0f, 1f - spotAge * 0.5f);
            float widthDecay = PApplet.max(0.3f, 1f - spotAge * 0.35f);
            float flicker = 0.5f + 0.5f * PApplet.sin(spotAge * 10f + t * 15f);

            float noiseX = (applet.noise(t * 5f + ax * 0.1f) - 0.5f) * 4f;
            float noiseY = (applet.noise(t * 5f + ay * 0.1f + 33.3f) - 0.5f) * 4f;
            float cx = ax + dx * t + noiseX;
            float cy = ay + dy * t + noiseY;
            float w = baseWidth * 0.12f * widthDecay * 0.5f;

            int alpha = (int)(180 * alphaDecay * edgeFade * flicker);
            g.fill(0xFFCC4400, alpha);
            g.vertex(cx + perpX * w, cy + perpY * w);
            g.vertex(cx - perpX * w, cy - perpY * w);
        }
        g.endShape();
    }

    void drawRadialGlow(PGraphics g, float cx, float cy, float radius,
                        int centerColor, int centerAlpha,
                        int edgeColor, int edgeAlpha, int segments) {
        g.noStroke();
        g.beginShape(PApplet.TRIANGLE_FAN);
        g.fill(centerColor, centerAlpha);
        g.vertex(cx, cy);
        for (int i = 0; i <= segments; i++) {
            float angle = i * PApplet.TWO_PI / segments;
            float rx = cx + PApplet.cos(angle) * radius;
            float ry = cy + PApplet.sin(angle) * radius;
            g.fill(edgeColor, edgeAlpha);
            g.vertex(rx, ry);
        }
        g.endShape();
    }
}

static class PiercerScorchEffect extends Effect {
    final float sx, sy, ex, ey;
    static final int SCORCH_COUNT = 20;

    PiercerScorchEffect(float sx, float sy, float ex, float ey) {
        super(0.5f);
        this.sx = sx;
        this.sy = sy;
        this.ex = ex;
        this.ey = ey;
    }

    void render(PGraphics g) {
        float fade = life / maxLife;
        if (fade <= 0f) return;

        float dx = ex - sx;
        float dy = ey - sy;
        float len = PApplet.sqrt(dx * dx + dy * dy);
        if (len <= 0) return;

        PApplet applet = P5Engine.getInstance().getApplet();

        // Core burn line - bright glowing center
        g.noFill();
        g.stroke(0xFFAA3311, (int)(50 * fade));
        g.strokeWeight(2.5f * fade);
        g.line(sx, sy, ex, ey);

        g.stroke(0xFF661111, (int)(80 * fade));
        g.strokeWeight(4.0f * fade);
        int segCount = (int)(len / 4f);
        for (int i = 0; i < segCount; i += 2) {
            float t0 = i / (float)segCount;
            float t1 = PApplet.min(1f, (i + 1) / (float)segCount);
            g.line(sx + dx * t0, sy + dy * t0, sx + dx * t1, sy + dy * t1);
        }

        // Scorch spots along path
        g.noStroke();
        for (int i = 0; i < SCORCH_COUNT; i++) {
            float t = i / (float)(SCORCH_COUNT - 1);
            float noiseX = (applet.noise(t * 5f + sx * 0.1f) - 0.5f) * 5f;
            float noiseY = (applet.noise(t * 5f + sy * 0.1f + 33.3f) - 0.5f) * 5f;
            float px = sx + dx * t + noiseX;
            float py = sy + dy * t + noiseY;
            float spotFade = fade * (0.7f + 0.3f * PApplet.sin(t * PApplet.PI * 3f + life * 8f));
            float spotSize = 2.5f + PApplet.sin(t * PApplet.PI) * 2f;
            // Outer scorch - brighter red-brown
            g.fill(0xFF993311, (int)(100 * spotFade));
            drawPolyCircle(g, px, py, spotSize * 1.8f, 8);
            // Inner scorch - dark core
            g.fill(0xFF551111, (int)(70 * spotFade));
            drawPolyCircle(g, px, py, spotSize, 6);

            // Ember flicker - every 3rd spot gets a hot glowing center
            if (i % 3 == 0) {
                float emberFade = spotFade * (0.5f + 0.5f * PApplet.sin(life * 12f + i * 1.7f));
                g.fill(0xFFFF5500, (int)(140 * emberFade));
                drawPolyCircle(g, px, py, spotSize * 0.5f, 5);
                g.fill(0xFFFFAA00, (int)(90 * emberFade));
                drawPolyCircle(g, px, py, spotSize * 0.25f, 4);
            }
        }

        // Endpoint char mark - larger and more pronounced
        g.fill(0xFF771111, (int)(120 * fade));
        drawPolyCircle(g, ex, ey, 5f, 8);
        g.fill(0xFF441111, (int)(80 * fade));
        drawPolyCircle(g, ex, ey, 3f, 6);
    }
}
