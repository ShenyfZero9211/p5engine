/**
 * Level select button with lock overlay (unavailable) or cleared badge.
 */
static class LevelButton extends Button {

    boolean locked;
    boolean cleared;

    LevelButton(String id) {
        super(id);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        super.paint(applet, theme);
        float alpha = getEffectiveAlpha();
        int a = Math.round(255 * alpha);

        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        float scale = pressedVisual ? 0.96f : 1.0f;
        float cx = ax + w * 0.5f;
        float cy = ay + h * 0.5f;

        // Apply same press-scale transform as TdTheme.drawButton
        applet.pushMatrix();
        applet.translate(cx, cy);
        applet.scale(scale);
        applet.translate(-cx, -cy);

        if (locked) {
            float lx = ax + w * 0.5f;
            float ly = ay + h * 0.5f;
            drawLock(applet, lx, ly, a);
        } else if (cleared) {
            float bx = ax + w - 12;
            float by = ay + 10;
            drawClearedBadge(applet, bx, by, a);
        }

        applet.popMatrix();
    }

    private void drawLock(PApplet g, float cx, float cy, int a) {
        g.pushStyle();
        // Shackle
        g.noFill();
        g.stroke(0xFF999999, a);
        g.strokeWeight(2.0f);
        g.strokeCap(PApplet.ROUND);
        g.arc(cx, cy - 1, 10, 10, PApplet.PI, PApplet.TWO_PI);
        // Body
        g.noStroke();
        g.fill(0xFF999999, a);
        g.rect(cx - 5, cy - 1, 10, 7, 1.5f);
        // Keyhole dot
        g.fill(0xFF444444, a);
        g.ellipse(cx, cy + 2, 2, 2);
        g.popStyle();
    }

    private void drawClearedBadge(PApplet g, float cx, float cy, int a) {
        g.pushStyle();
        // Outer soft glow
        g.noStroke();
        g.fill(0xFF4ADE80, Math.round(a * 0.25f));
        g.ellipse(cx, cy, 12, 12);
        // Green disc
        g.fill(0xFF4ADE80, a);
        g.ellipse(cx, cy, 8, 8);
        // White checkmark
        g.stroke(0xFFFFFFFF, a);
        g.strokeWeight(1.5f);
        g.strokeCap(PApplet.ROUND);
        g.line(cx - 2, cy, cx, cy + 2);
        g.line(cx, cy + 2, cx + 3, cy - 2);
        g.popStyle();
    }
}
