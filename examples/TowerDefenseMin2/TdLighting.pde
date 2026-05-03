/**
 * 2D Lighting System for TowerDefenseMin2.
 * Mask-based lighting: dark ambient + additive light sources, multiplied onto the world viewport.
 *
 * Optimized with static/dynamic buffer separation:
 * - staticBuffer: cached persistent lights (tower ambient + base), rebuilt only when
 *   static light set changes, camera moves, or zoom changes.
 * - dynBuffer: per-frame composite of staticBuffer + dynamic lights (flashes, bullet glows).
 */

static class TdLight {
    Vector2 worldPos;
    float radius;
    int lightColor;
    float intensity;
    float duration;
    float maxDuration;
    boolean dead;

    TdLight(Vector2 worldPos, float radius, int lightColor, float intensity, float duration) {
        this.worldPos = worldPos;
        this.radius = radius;
        this.lightColor = lightColor;
        this.intensity = intensity;
        this.duration = duration;
        this.maxDuration = duration;
        this.dead = false;
    }

    void update(float dt) {
        if (duration > 0) {
            duration -= dt;
            if (duration <= 0) dead = true;
        }
    }

    /** Returns intensity faded over time (full for first 50%, then linear fade) */
    float getEffectiveIntensity() {
        if (duration <= 0) return intensity;
        if (maxDuration <= 0) return intensity;
        float fadeStart = maxDuration * 0.5f;
        if (duration >= fadeStart) return intensity;
        return intensity * (duration / fadeStart);
    }
}

static class TdLightingSystem {
    PGraphics staticBuffer;   // cached persistent lights
    PGraphics dynBuffer;      // per-frame: static + dynamic composite
    PApplet appRef;
    ArrayList<TdLight> lights = new ArrayList<>();
    int ambientColor = 0xFFFFFFFF; // white — no dimming for now; change to darker for night levels later
    static final int GRADIENT_STEPS = 20;

    // Cache invalidation state
    boolean staticBufferDirty = true;
    float lastZoom = -1f;
    float lastCamX = Float.MAX_VALUE;
    float lastCamY = Float.MAX_VALUE;

    TdLightingSystem(PApplet app) {
        this.appRef = app;
    }

    void init(PApplet app, int w, int h) {
        this.appRef = app;
        ensureBuffers(w, h);
    }

    void addLight(TdLight light) {
        lights.add(light);
        if (light.duration <= 0) {
            staticBufferDirty = true;
        }
    }

    void update(float dt) {
        for (int i = lights.size() - 1; i >= 0; i--) {
            TdLight light = lights.get(i);
            light.update(dt);
            if (light.dead) {
                lights.remove(i);
            }
        }
    }

    void render(PGraphics target, Camera2D camera, float vpX, float vpY, float vpW, float vpH) {
        if (appRef == null) return;

        int iw = Math.max(1, (int) vpW);
        int ih = Math.max(1, (int) vpH);
        ensureBuffers(iw, ih);

        // Detect camera movement / zoom change
        Vector2 camPos = camera.getTransform().getPosition();
        float camX = camPos.x;
        float camY = camPos.y;
        float camZoom = camera.getZoom();
        if (Math.abs(camX - lastCamX) > 0.5f || Math.abs(camY - lastCamY) > 0.5f
            || Math.abs(camZoom - lastZoom) > 0.001f) {
            staticBufferDirty = true;
            lastCamX = camX;
            lastCamY = camY;
            lastZoom = camZoom;
        }

        // Rebuild static buffer if needed
        if (staticBufferDirty) {
            rebuildStaticBuffer(camera, vpX, vpY, vpW, vpH);
        }

        // Draw dynamic buffer: copy static + overlay dynamic lights
        dynBuffer.beginDraw();
        dynBuffer.background(0);
        if (staticBuffer != null) {
            dynBuffer.image(staticBuffer, 0, 0);
        }
        dynBuffer.blendMode(PApplet.ADD);
        dynBuffer.noStroke();

        for (TdLight light : lights) {
            if (light.duration <= 0) continue; // already in staticBuffer
            if (light.dead) continue;
            Vector2 screenPos = camera.worldToScreen(light.worldPos);
            float sx = screenPos.x - vpX;
            float sy = screenPos.y - vpY;
            float r = light.radius * camera.getZoom();

            // Cull if completely outside viewport
            if (sx + r < 0 || sx - r > vpW || sy + r < 0 || sy - r > vpH) continue;

            drawRadialGradient(dynBuffer, sx, sy, r, light.lightColor, light.getEffectiveIntensity());
        }

        // Laser beam capsule glows (always dynamic)
        for (Effect e : TdGameWorld.effects) {
            if (e instanceof LaserBeamEffect) {
                LaserBeamEffect lb = (LaserBeamEffect) e;
                Vector2 s1 = camera.worldToScreen(lb.from);
                Vector2 s2 = camera.worldToScreen(lb.dest);
                float lifeRatio = lb.life / lb.maxLife;
                drawLaserGlow(dynBuffer, s1.x - vpX, s1.y - vpY, s2.x - vpX, s2.y - vpY, 0xFFC878DC, 1.0f, lifeRatio);
            }
        }

        dynBuffer.endDraw();

        target.pushStyle();
        // Step 1: ambient dimming (MULTIPLY)
        target.blendMode(PApplet.MULTIPLY);
        target.noStroke();
        target.fill(ambientColor);
        target.rect(vpX, vpY, vpW, vpH);
        // Step 2: light source flares (SCREEN — softer than ADD, less overexposure)
        target.blendMode(PApplet.SCREEN);
        target.image(dynBuffer, vpX, vpY);
        target.blendMode(PApplet.BLEND);
        target.popStyle();
    }

    void rebuildStaticBuffer(Camera2D camera, float vpX, float vpY, float vpW, float vpH) {
        if (staticBuffer == null) return;
        staticBuffer.beginDraw();
        staticBuffer.background(0);
        staticBuffer.blendMode(PApplet.ADD);
        staticBuffer.noStroke();

        for (TdLight light : lights) {
            if (light.duration > 0) continue; // only persistent lights
            if (light.dead) continue;
            Vector2 screenPos = camera.worldToScreen(light.worldPos);
            float sx = screenPos.x - vpX;
            float sy = screenPos.y - vpY;
            float r = light.radius * camera.getZoom();

            // Cull if completely outside viewport
            if (sx + r < 0 || sx - r > vpW || sy + r < 0 || sy - r > vpH) continue;

            drawRadialGradient(staticBuffer, sx, sy, r, light.lightColor, light.getEffectiveIntensity());
        }

        staticBuffer.endDraw();
        staticBufferDirty = false;
    }

    void drawRadialGradient(PGraphics pg, float cx, float cy, float radius, int lightColor, float intensity) {
        int r = (lightColor >> 16) & 0xFF;
        int g = (lightColor >> 8) & 0xFF;
        int b = lightColor & 0xFF;

        for (int i = GRADIENT_STEPS; i >= 0; i--) {
            float t = i / (float) GRADIENT_STEPS;
            float cr = radius * t;
            int a = (int) (255 * (1 - t) * intensity);
            if (a <= 0) continue;
            pg.fill(r, g, b, a);
            int segs = (cr < 5) ? 8 : ((cr < 15) ? 12 : 16);
            drawPolyCircle(pg, cx, cy, cr, segs);
        }
    }

    void drawLaserGlow(PGraphics pg, float x1, float y1, float x2, float y2, int lightColor, float intensity, float lifeRatio) {
        float dx = x2 - x1, dy = y2 - y1;
        float len = PApplet.sqrt(dx * dx + dy * dy);
        if (len <= 0) return;

        float cx = (x1 + x2) * 0.5f;
        float cy = (y1 + y2) * 0.5f;
        float angle = PApplet.atan2(dy, dx);
        int r = (lightColor >> 16) & 0xFF;
        int g = (lightColor >> 8) & 0xFF;
        int b = lightColor & 0xFF;

        pg.pushMatrix();
        pg.translate(cx, cy);
        pg.rotate(angle);

        int steps = 8;
        float maxW = 25 * lifeRatio;
        float hLen = len * 0.5f;
        pg.noFill();
        pg.strokeCap(PApplet.ROUND);
        for (int i = steps; i >= 0; i--) {
            float t = i / (float) steps;
            float w = maxW * t;
            int a = (int) (255 * (1 - t) * intensity * lifeRatio);
            if (a <= 0 || w <= 1) continue;
            pg.stroke(r, g, b, a);
            pg.strokeWeight(w);
            pg.line(-hLen, 0, hLen, 0);
        }
        pg.popMatrix();
    }

    void clear() {
        lights.clear();
        staticBufferDirty = true;
    }

    void ensureBuffers(int w, int h) {
        if (dynBuffer == null || dynBuffer.width != w || dynBuffer.height != h) {
            dynBuffer = appRef.createGraphics(w, h, PApplet.P2D);
            staticBuffer = appRef.createGraphics(w, h, PApplet.P2D);
            staticBufferDirty = true;
        }
    }

    // ── Convenience factory methods ──

    static void addFlash(float worldX, float worldY, float radius, int lightColor, float intensity, float duration) {
        TowerDefenseMin2.inst.lighting.addLight(new TdLight(
            new Vector2(worldX, worldY), radius, lightColor, intensity, duration));
    }

    static void addTowerLight(Tower tower) {
        if (tower.ambientLight != null) return;
        TdLight light = new TdLight(
            new Vector2(tower.worldX, tower.worldY),
            35, tower.def.iconColor, 0.15f, -1);
        tower.ambientLight = light;
        TowerDefenseMin2.inst.lighting.addLight(light);
    }

    static void removeTowerLight(Tower tower) {
        if (tower.ambientLight != null) {
            tower.ambientLight.dead = true;
            tower.ambientLight = null;
            TowerDefenseMin2.inst.lighting.staticBufferDirty = true;
        }
    }

    static void addBaseLight(Vector2 basePos) {
        TowerDefenseMin2.inst.lighting.addLight(new TdLight(
            basePos.copy(), 70, 0xFF4A9EFF, 0.2f, -1));
    }

    static void addSpawnFlash(float x, float y) {
        addFlash(x, y, 40, 0xFFFF4444, 0.2f, 0.20f);
    }

    static void addEscapeFlash(float x, float y) {
        addFlash(x, y, 40, 0xFFFF4444, 0.2f, 0.20f);
    }

    static void addBulletGlow(float x, float y) {
        // Default bullet glow: yellow, small radius, very short duration
        addFlash(x, y, 20, 0xFFFFFF00, 0.6f, 0.03f);
    }

    static void addMissileBulletGlow(float x, float y) {
        // Missile bullet glow: yellow, smaller radius (70% of default), shorter duration
        addFlash(x, y, 14, 0xFFFFFF00, 0.6f, 0.02f);
    }

    static void addOrbGlow(float x, float y) {
        // Orb glow: gold, small radius, very short duration
        addFlash(x, y, 25, 0xFFFFD700, 0.3f, 0.02f);
    }

    static void addLaserGlow(float x1, float y1, float x2, float y2) {
        // Laser beam glow: centered on beam midpoint, pink
        float mx = (x1 + x2) * 0.5f;
        float my = (y1 + y2) * 0.5f;
        addFlash(mx, my, 35, 0xFFC878DC, 0.15f, 0.03f);
    }

    // Fire flash by tower type
    static void addFireFlash(Tower tower) {
        float baseSize = TdConfig.GRID * 0.75f;
        switch (tower.def.type) {
            case MG:
                addFlash(tower.worldX, tower.worldY, baseSize * 2.0f, tower.def.iconColor, 0.1f, 0.30f);
                break;
            case MISSILE:
                addFlash(tower.worldX, tower.worldY, baseSize * 2.0f, tower.def.iconColor, 0.1f, 0.40f);
                break;
            case LASER:
                addFlash(tower.worldX, tower.worldY, baseSize * 0.75f * 2.5f, tower.def.iconColor, 0.1f, 0.25f);
                break;
            case SLOW:
                addFlash(tower.worldX, tower.worldY, baseSize * 2.0f, tower.def.iconColor, 0.1f, 0.30f);
                break;
            case COMMAND:
                addFlash(tower.worldX, tower.worldY, baseSize * 1.5f, tower.def.iconColor, 0.1f, 0.25f);
                break;
        }
    }
}
