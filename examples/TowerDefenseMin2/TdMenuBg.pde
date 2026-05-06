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

    // Title animation state (0 = start, 1 = end)
    static float titleProgress = 0f;

    // Track window size so stars regenerate on resize
    static int lastStarW = -1;
    static int lastStarH = -1;

    static void setFont(processing.core.PFont f) {
        font = f;
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
        // Animated position: center (dsh*0.5) -> final (dsh*0.167)
        float startY = dsh * 0.5f;
        float endY = dsh * 0.12f;
        float curY = startY + (endY - startY) * titleProgress;

        // Animated alpha: 0 -> 255
        int alpha = (int)(Math.min(255, Math.max(0, 255 * titleProgress)));

        // Animated scale: 0.8 -> 1.0
        float scale = Math.max(0, 0.8f + 0.2f * titleProgress);

        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        if (font != null) g.textFont(font);
        g.textSize(48 * scale);

        float tw = g.textWidth(title);

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
        g.line(cx - tw * 0.5f, curY + 32, cx + tw * 0.5f, curY + 32);
    }

    static void draw(PApplet g) {
        init();
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        int dw = app.width;
        int dh = app.height;
        float brightness = TdAssets.getMenuStarBrightness();

        // Deep space background
        g.background(14, 18, 34);

        // Draw parallax star layers: Far -> Mid -> Near
        drawStarLayer(g, farStars, brightness, dw, dh);
        drawStarLayer(g, midStars, brightness, dw, dh);
        drawNearLayer(g, brightness, dw, dh);

        // Subtle perspective grid
        g.stroke(40, 60, 100, (int)(40 * brightness));
        g.strokeWeight(1);
        float horizonY = dh * 0.556f;  // 400/720 ≈ 0.556
        // Horizontal lines
        for (int i = 0; i < 12; i++) {
            float y = horizonY + i * 35;
            if (y > dh) break;
            float alpha = PApplet.map(y, horizonY, dh, 30, 80) * brightness;
            g.stroke(40, 60, 100, (int)alpha);
            g.line(0, y, dw, y);
        }
        // Vertical perspective lines
        float cx = dw * 0.5f;
        for (int i = -8; i <= 8; i++) {
            float x2 = cx + i * 120;
            g.stroke(40, 60, 100, (int)(25 * brightness));
            g.line(cx, horizonY - 100, x2, dh);
        }

        // Subtle vignette (darken edges)
        g.noStroke();
        for (int i = 0; i < 3; i++) {
            float t = i / 3f;
            int a = (int)(40 * (1 - t) * brightness);
            g.fill(0, 0, 0, a);
            float margin = t * 200;
            g.rect(0, 0, dw, margin);
            g.rect(0, dh - margin, dw, margin);
            g.rect(0, 0, margin, dh);
            g.rect(dw - margin, 0, margin, dh);
        }
    }
}
