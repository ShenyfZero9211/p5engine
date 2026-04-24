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

    static void setFont(processing.core.PFont f) {
        font = f;
    }

    static void init() {
        if (initialized) return;
        java.util.Random rng = new java.util.Random(42);
        for (int i = 0; i < STAR_COUNT; i++) {
            stars.add(new Star(
                rng.nextFloat() * 1280,
                rng.nextFloat() * 720,
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
        // Large glowing title
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        if (font != null) g.textFont(font);
        g.textSize(48);
        // Glow shadow
        g.fill(74, 158, 255, 60);
        g.text(title, 642, 122);
        g.text(title, 638, 118);
        // Main text
        g.fill(224, 230, 240);
        g.text(title, 640, 120);
        // Accent underline
        g.stroke(74, 158, 255, 180);
        g.strokeWeight(2);
        float tw = g.textWidth(title);
        g.line(640 - tw * 0.5f, 152, 640 + tw * 0.5f, 152);
    }

    static void draw(PApplet g) {
        init();

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
        float horizonY = 400;
        // Horizontal lines
        for (int i = 0; i < 12; i++) {
            float y = horizonY + i * 35;
            if (y > 720) break;
            float alpha = PApplet.map(y, horizonY, 720, 30, 80);
            g.stroke(40, 60, 100, (int)alpha);
            g.line(0, y, 1280, y);
        }
        // Vertical perspective lines
        float cx = 640;
        for (int i = -8; i <= 8; i++) {
            float x2 = cx + i * 120;
            g.stroke(40, 60, 100, 25);
            g.line(cx, horizonY - 100, x2, 720);
        }

        // Subtle vignette (darken edges)
        g.noStroke();
        for (int i = 0; i < 3; i++) {
            float t = i / 3f;
            int a = (int)(40 * (1 - t));
            g.fill(0, 0, 0, a);
            float margin = t * 200;
            g.rect(0, 0, 1280, margin);
            g.rect(0, 720 - margin, 1280, margin);
            g.rect(0, 0, margin, 720);
            g.rect(1280 - margin, 0, margin, 720);
        }
    }
}
