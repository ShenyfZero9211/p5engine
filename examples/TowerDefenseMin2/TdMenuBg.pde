/**
 * Animated sci-fi menu background with stars and grid lines.
 */
static final class TdMenuBg {

    static class Star {
        float x, y, z, brightness;
        Star(float x, float y, float z, float b) { this.x = x; this.y = y; this.z = z; this.brightness = b; }
    }

    static final int STAR_COUNT = 200;
    static final ArrayList<Star> stars = new ArrayList<>();
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

    static void init() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        int dw = app.width;
        int dh = app.height;
        if (initialized && dw == lastStarW && dh == lastStarH) return;

        lastStarW = dw;
        lastStarH = dh;
        stars.clear();

        // Scale star count by area so density stays consistent across resolutions
        int baseArea = 1280 * 720;
        int actualArea = dw * dh;
        int count = Math.min(800, Math.max(STAR_COUNT, STAR_COUNT * actualArea / baseArea));

        java.util.Random rng = new java.util.Random(42);
        for (int i = 0; i < count; i++) {
            stars.add(new Star(
                rng.nextFloat() * dw,
                rng.nextFloat() * dh,
                rng.nextFloat() * 2 + 0.5f,
                rng.nextFloat() * 200 + 55
            ));
        }
        initialized = true;
    }

    static void update(float dt) {
        time += dt;
    }

    static void drawTitle(PApplet g, String title) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        int dw = app.engine.getDisplayManager().getDesignWidth();
        int dh = app.engine.getDisplayManager().getDesignHeight();
        float cx = dw * 0.5f;
        // Animated position: center (dh*0.5) -> final (dh*0.167)
        float startY = dh * 0.5f;
        float endY = dh * 0.167f;
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

        // Deep space background
        g.background(14, 18, 34);

        // Draw stars with twinkle
        g.noStroke();
        for (Star s : stars) {
            float twinkle = 0.7f + 0.3f * PApplet.sin(time * s.z + s.x * 0.01f);
            int alpha = (int)(s.brightness * twinkle);
            g.fill(200, 220, 255, alpha);
            float sz = 1 + s.z * 0.8f;
            g.ellipse(s.x, s.y, sz, sz);
        }

        // Subtle perspective grid
        g.stroke(40, 60, 100, 40);
        g.strokeWeight(1);
        float horizonY = dh * 0.556f;  // 400/720 ≈ 0.556
        // Horizontal lines
        for (int i = 0; i < 12; i++) {
            float y = horizonY + i * 35;
            if (y > dh) break;
            float alpha = PApplet.map(y, horizonY, dh, 30, 80);
            g.stroke(40, 60, 100, (int)alpha);
            g.line(0, y, dw, y);
        }
        // Vertical perspective lines
        float cx = dw * 0.5f;
        for (int i = -8; i <= 8; i++) {
            float x2 = cx + i * 120;
            g.stroke(40, 60, 100, 25);
            g.line(cx, horizonY - 100, x2, dh);
        }

        // Subtle vignette (darken edges)
        g.noStroke();
        for (int i = 0; i < 3; i++) {
            float t = i / 3f;
            int a = (int)(40 * (1 - t));
            g.fill(0, 0, 0, a);
            float margin = t * 200;
            g.rect(0, 0, dw, margin);
            g.rect(0, dh - margin, dw, margin);
            g.rect(0, 0, margin, dh);
            g.rect(dw - margin, 0, margin, dh);
        }
    }
}
