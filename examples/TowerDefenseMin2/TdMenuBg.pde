/**
 * Animated sci-fi menu background with parallax stars and grid lines.
 * References WorldBgRenderer's multi-layer parallax system.
 */
static final class TdMenuBg {

    // ── Data model ──

    static class MenuStar {
        float baseX, baseY; // original position within screen
        float z;            // twinkle frequency
        float brightness;   // base brightness
        float size;         // draw size
        float parallax;     // parallax factor (Far=0.05, Mid=0.15, Near=0.30)

        MenuStar(float x, float y, float z, float b, float s, float p) {
            this.baseX = x; this.baseY = y; this.z = z;
            this.brightness = b; this.size = s; this.parallax = p;
        }
    }

    static class MenuCamera {
        float x, y;           // current offset
        float targetX, targetY; // target offset driven by mouse
        float maxOffset = 120f;
        float lerpSpeed = 4f;

        void update(float dt, float mouseX, float mouseY, int w, int h) {
            // Map mouse position to camera target (inverse direction for parallax feel)
            targetX = (mouseX / w - 0.5f) * maxOffset * 2f;
            targetY = (mouseY / h - 0.5f) * maxOffset * 2f;
            float t = Math.min(1f, lerpSpeed * dt);
            x += (targetX - x) * t;
            y += (targetY - y) * t;
        }
    }

    static final ArrayList<MenuStar> farStars = new ArrayList<>();
    static final ArrayList<MenuStar> midStars = new ArrayList<>();
    static final ArrayList<MenuStar> nearStars = new ArrayList<>();
    static final MenuCamera menuCamera = new MenuCamera();

    static float time = 0;
    static boolean initialized = false;
    static processing.core.PFont font;
    static processing.core.PFont titleFont;

    // Title animation state (0 = start, 1 = end)
    static float titleProgress = 0f;

    // Cached title text width in design coords (animScale=1), for ellipse activation
    static float cachedTitleWidth = -1f;
    static String cachedTitleText = null;

    // Background layered fade-in progress (0 = black, 1 = fully visible)
    static float bgFadeProgress = 0f;
    static final float BG_FADE_SPEED = 0.35f;
    static boolean titleAnimStarted = false;
    static boolean buttonAnimStarted = false;

    // Button references for delayed fade-in
    static Button btnStartRef;
    static Button btnSettingsRef;
    static Button btnQuitRef;

    // Offscreen buffer & shader for flashlight grid effect
    static processing.core.PGraphics gridLayer;
    static PShader flashlightShader;

    // Track window size so stars regenerate on resize
    static int lastStarW = -1;
    static int lastStarH = -1;

    static void setFont(processing.core.PFont f) {
        font = f;
    }

    static void setTitleFont(processing.core.PFont f) {
        titleFont = f;
    }

    static void resetCamera() {
        menuCamera.x = 0;
        menuCamera.y = 0;
        menuCamera.targetX = 0;
        menuCamera.targetY = 0;
    }

    static void init() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        int dw = app.width;
        int dh = app.height;
        if (initialized && dw == lastStarW && dh == lastStarH) return;

        lastStarW = dw;
        lastStarH = dh;
        farStars.clear();
        midStars.clear();
        nearStars.clear();

        // Scale star count by area so density stays consistent across resolutions
        int baseArea = 1280 * 720;
        int actualArea = dw * dh;
        int totalCount = Math.min(800, Math.max(200, 200 * actualArea / baseArea));

        java.util.Random rng = new java.util.Random(42);

        // Far layer: 50%, small, dim, slow parallax
        int farCount = (int)(totalCount * 0.50f);
        for (int i = 0; i < farCount; i++) {
            farStars.add(new MenuStar(
                rng.nextFloat() * dw,
                rng.nextFloat() * dh,
                rng.nextFloat() * 2 + 0.5f,
                rng.nextFloat() * 120 + 40,
                1 + rng.nextFloat(),
                0.05f
            ));
        }

        // Mid layer: 35%, medium, medium brightness
        int midCount = (int)(totalCount * 0.35f);
        for (int i = 0; i < midCount; i++) {
            midStars.add(new MenuStar(
                rng.nextFloat() * dw,
                rng.nextFloat() * dh,
                rng.nextFloat() * 2 + 0.5f,
                rng.nextFloat() * 160 + 80,
                1.5f + rng.nextFloat(),
                0.15f
            ));
        }

        // Near layer: 15%, larger, bright, fast parallax
        int nearCount = totalCount - farCount - midCount;
        for (int i = 0; i < nearCount; i++) {
            nearStars.add(new MenuStar(
                rng.nextFloat() * dw,
                rng.nextFloat() * dh,
                rng.nextFloat() * 2 + 0.5f,
                rng.nextFloat() * 200 + 100,
                2.5f + rng.nextFloat() * 1.5f,
                0.30f
            ));
        }
        initialized = true;
    }

    static void update(float dt) {
        time += dt;
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        menuCamera.update(dt, app.mouseX, app.mouseY, app.width, app.height);

        if (bgFadeProgress < 1f) {
            bgFadeProgress += dt * BG_FADE_SPEED;
        }
        if (!titleAnimStarted && bgFadeProgress >= 0.55f) {
            titleAnimStarted = true;
            startTitleTween();
        }
        if (!buttonAnimStarted && bgFadeProgress >= 0.70f) {
            buttonAnimStarted = true;
            startButtonTweens();
        }
    }

    static void startTitleTween() {
        TweenManager tm = TowerDefenseMin2.inst.engine.getTweenManager();
        tm.toFloat(0f, 1f, 0.8f, v -> {
            TdMenuBg.titleProgress = v;
        }).ease(Ease::outBack).start();
    }

    static void startButtonTweens() {
        TweenManager tm = TowerDefenseMin2.inst.engine.getTweenManager();
        if (btnStartRef != null) tm.toAlpha(btnStartRef, 1f, 0.5f).start();
        if (btnSettingsRef != null) tm.toAlpha(btnSettingsRef, 1f, 0.5f).delay(0.08f).start();
        if (btnQuitRef != null) tm.toAlpha(btnQuitRef, 1f, 0.5f).delay(0.16f).start();
    }

    static void resetMenuFade() {
        // Don't reset if the menu animation has already fully played once.
        // This prevents the fade-in animation from replaying when returning
        // from sub-menus (settings, level select) back to the main menu.
        if (bgFadeProgress >= 1f && titleProgress >= 1f) {
            return;
        }
        bgFadeProgress = 0f;
        titleAnimStarted = false;
        buttonAnimStarted = false;
        titleProgress = 0f;
        btnStartRef = null;
        btnSettingsRef = null;
        btnQuitRef = null;
    }

    static float wrapCoord(float v, float size) {
        return ((v % size) + size) % size;
    }

    static void drawStarLayer(PApplet g, ArrayList<MenuStar> stars, float brightness, int dw, int dh) {
        g.noStroke();
        for (MenuStar s : stars) {
            float drawX = wrapCoord(s.baseX - menuCamera.x * s.parallax, dw);
            float drawY = wrapCoord(s.baseY - menuCamera.y * s.parallax, dh);
            float twinkle = 0.7f + 0.3f * PApplet.sin(time * s.z + s.baseX * 0.01f);
            int alpha = (int)(s.brightness * twinkle * brightness);
            g.fill(200, 220, 255, alpha);
            g.ellipse(drawX, drawY, s.size, s.size);
        }
    }

    static void drawNearLayer(PApplet g, float brightness, int dw, int dh) {
        g.noStroke();
        for (MenuStar s : nearStars) {
            float drawX = wrapCoord(s.baseX - menuCamera.x * s.parallax, dw);
            float drawY = wrapCoord(s.baseY - menuCamera.y * s.parallax, dh);
            float twinkle = 0.7f + 0.3f * PApplet.sin(time * s.z + s.baseX * 0.01f);
            int alpha = (int)(s.brightness * twinkle * brightness);
            // Simplified glow (ellipse instead of drawPolyCircle)
            g.fill(200, 210, 255, (int)(alpha * 0.25f));
            g.ellipse(drawX, drawY, s.size + 3, s.size + 3);
            // Core
            g.fill(255, 255, 255, alpha);
            g.ellipse(drawX, drawY, s.size, s.size);
        }
    }

    static void drawTitle(PApplet g, String title) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        int dsw = app.engine.getDisplayManager().getDesignWidth();
        int dsh = app.engine.getDisplayManager().getDesignHeight();
        float cx = dsw * 0.5f;
        // Animated position: center -> red-box area center (~35% of design height)
        float startY = dsh * 0.5f;
        float endY = dsh * 0.25f;
        float curY = startY + (endY - startY) * titleProgress;

        // Animated alpha: 0 -> 255
        int alpha = (int)(Math.min(255, Math.max(0, 255 * titleProgress)));

        // Animated scale: 0.8 -> 1.0
        float scale = Math.max(0, 0.8f + 0.2f * titleProgress);

        float baseTextSize = 84f;
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        if (titleFont != null) g.textFont(titleFont);
        else if (font != null) g.textFont(font);
        g.textSize(baseTextSize * scale);

        float tw = g.textWidth(title);
        // Cache normalized width (animScale=1) for flashlight grid ellipse
        // Re-calculate when title text changes (language switch) or first time
        if (!title.equals(cachedTitleText) || (titleProgress >= 0.99f && cachedTitleWidth < 0)) {
            cachedTitleWidth = tw / scale;
            cachedTitleText = title;
        }

        // Glow shadow
        g.fill(74, 158, 255, (int)(60 * titleProgress));
        g.text(title, cx + 2, curY + 2);
        g.text(title, cx - 2, curY - 2);
        // Main text
        g.fill(224, 230, 240, alpha);
        g.text(title, cx, curY);
        // Accent underline
        g.stroke(74, 158, 255, (int)(180 * titleProgress));
        g.strokeWeight(2);
        float underlineOffset = baseTextSize * 0.65f;
        g.line(cx - tw * 0.5f, curY + underlineOffset, cx + tw * 0.5f, curY + underlineOffset);
    }

    static void draw(PApplet g) {
        init();
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        int dw = app.width;
        int dh = app.height;
        float brightness = TdAssets.getMenuStarBrightness();
        float p = bgFadeProgress;

        // Background transitions from black to configured menu bg color (0 ~ 0.75)
        float bgT = Math.min(1f, p / 0.75f);
        int baseR = TdAssets.getMenuBgR();
        int baseG = TdAssets.getMenuBgG();
        int baseB = TdAssets.getMenuBgB();
        int bgR = (int)(baseR * bgT);
        int bgG = (int)(baseG * bgT);
        int bgB = (int)(baseB * bgT);
        g.background(bgR, bgG, bgB);

        // Stage 1: Stars fade in (0 ~ 0.35)
        float starAlpha = Math.min(1f, p / 0.35f);
        if (starAlpha > 0) {
            drawStarLayer(g, farStars, brightness * starAlpha, dw, dh);
            drawStarLayer(g, midStars, brightness * starAlpha, dw, dh);
            drawNearLayer(g, brightness * starAlpha, dw, dh);
        }

        // Stage 2: Perspective grid lines (subtle background grid)
        float gridAlpha = (p > 0.25f) ? Math.min(1f, (p - 0.25f) / 0.25f) : 0f;
        if (gridAlpha > 0) {
            g.stroke(40, 60, 100, (int)(40 * brightness * gridAlpha));
            g.strokeWeight(1);
            float horizonY = dh * 0.556f;
            // Horizontal lines
            for (int i = 0; i < 12; i++) {
                float y = horizonY + i * 35;
                if (y > dh) break;
                float alpha = PApplet.map(y, horizonY, dh, 30, 80) * brightness * gridAlpha;
                g.stroke(40, 60, 100, (int)alpha);
                g.line(0, y, dw, y);
            }
            // Vertical perspective lines
            float cx = dw * 0.5f;
            for (int i = -8; i <= 8; i++) {
                float x2 = cx + i * 120;
                g.stroke(40, 60, 100, (int)(25 * brightness * gridAlpha));
                g.line(cx, horizonY - 100, x2, dh);
            }
        }

        // Stage 3: Flashlight grid overlay (only on main menu, hidden in settings/level select)
        if (app.state == TdState.MENU) {
            drawFlashlightGrid(g, dw, dh);
        }

        // Stage 3: Vignette fades in (0.55 ~ 0.85)
        float vignetteAlpha = (p > 0.55f) ? Math.min(1f, (p - 0.55f) / 0.30f) : 0f;
        if (vignetteAlpha > 0) {
            g.noStroke();
            for (int i = 0; i < 3; i++) {
                float t = i / 3f;
                int a = (int)(40 * (1 - t) * brightness * vignetteAlpha);
                g.fill(0, 0, 0, a);
                float margin = t * 200;
                g.rect(0, 0, dw, margin);
                g.rect(0, dh - margin, dw, margin);
                g.rect(0, 0, margin, dh);
                g.rect(dw - margin, 0, margin, dh);
            }
        }

        // Bottom-center credit text (只在主菜单显示)
        if (app.state == TdState.MENU) {
            shenyf.p5engine.rendering.DisplayManager dm = app.engine.getDisplayManager();
            float uiScale = dm.getUniformScale();
            g.textAlign(PApplet.CENTER, PApplet.BOTTOM);
            if (font != null) g.textFont(font);
            g.textSize(14 * uiScale);
            g.fill(200, 210, 230, (int)(100 * p));
            g.text("- Achieved with P5engine -", dw * 0.5f, dh - 12 * uiScale);
        }
    }

    static void drawFlashlightGrid(PApplet g, int dw, int dh) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        shenyf.p5engine.rendering.DisplayManager dm = app.engine.getDisplayManager();

        // Title final position in physical screen pixels
        float scale = dm.getUniformScale();
        float offsetX = dm.getOffsetX();
        float offsetY = dm.getOffsetY();
        float titleCx = offsetX + dm.getDesignWidth() * 0.5f * scale;
        float titleCy = offsetY + dm.getDesignHeight() * 0.25f * scale;

        float mx = app.mouseX;
        float my = app.mouseY;

        // Activation: elliptical zone around the title text (adapts to CN/EN width)
        float titleTextW = (cachedTitleWidth > 0 ? cachedTitleWidth : 300f) * scale;
        float titleTextH = 84f * scale;
        float margin = 40f * scale;
        float halfW = (titleTextW * 0.5f + margin) * 0.5f;  // shrink 50%
        float halfH = (titleTextH * 0.5f + margin) * 0.5f;

        float dx = mx - titleCx;
        float dy = my - titleCy;
        // Normalized ellipse distance: <=1 means inside the ellipse
        float ellipseDist = PApplet.sqrt((dx * dx) / (halfW * halfW) + (dy * dy) / (halfH * halfH));

        float fadeRange = 0.8f;  // tighten the overall activation zone
        if (ellipseDist > 1f + fadeRange) return;

        float activation;
        if (ellipseDist <= 1f) {
            activation = 1.0f;
        } else {
            float t = (ellipseDist - 1f) / fadeRange;
            // smoothstep: zero derivative at both ends for imperceptible fade-in/out
            t = t * t * (3f - 2f * t);
            activation = 1f - t;
        }

        float lightRadius = Math.min(dw, dh) * 0.132f;

        // ---- Debug: visualize the elliptical activation zone ----
        // g.noFill();
        // g.strokeWeight(2);
        // g.stroke(255, 60, 60, 120);
        // g.ellipse(titleCx, titleCy, halfW * 2f, halfH * 2f);

        // ---- Shader: grid lines generated in fragment shader ----
        if (flashlightShader == null) {
            flashlightShader = g.loadShader("shaders/flashlight_grid.glsl");
        }
        flashlightShader.set("resolution", (float)dw, (float)dh);
        flashlightShader.set("mouse", mx, dh - my);
        flashlightShader.set("gridSize", 40f);
        flashlightShader.set("lightRadius", lightRadius);
        flashlightShader.set("activation", activation);
        flashlightShader.set("rectSize", 0f, 0f);

        g.blendMode(PApplet.ADD);
        g.shader(flashlightShader);
        g.noStroke();
        g.fill(255);
        g.rect(0, 0, dw, dh);
        g.resetShader();
        g.blendMode(PApplet.BLEND);
    }
}
