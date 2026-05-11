/**
 * Button with a polished completion badge on the right side.
 */
static class BadgeButton extends Button {

    boolean showBadge;

    BadgeButton(String id) {
        super(id);
    }

    void setShowBadge(boolean show) {
        this.showBadge = show;
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        super.paint(applet, theme);
        if (showBadge) {
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

            float bx = ax + w - 18;
            float by = ay + h * 0.5f;

            applet.pushStyle();

            // Outer soft glow
            applet.noStroke();
            applet.fill(0xFFFFD700, Math.round(a * 0.22f));
            applet.ellipse(bx, by, 20, 20);
            applet.fill(0xFFFFD700, Math.round(a * 0.40f));
            applet.ellipse(bx, by, 14, 14);

            // Main gold disc
            applet.fill(0xFFFFD700, a);
            applet.ellipse(bx, by, 12, 12);

            // Subtle inner shadow ring
            applet.noFill();
            applet.stroke(0xFFD4AF37, Math.round(a * 0.50f));
            applet.strokeWeight(1.0f);
            applet.ellipse(bx, by, 12, 12);

            // Top-left specular highlight
            applet.noStroke();
            applet.fill(0xFFFFFFFF, Math.round(a * 0.70f));
            applet.ellipse(bx - 2.5f, by - 2.5f, 3.5f, 3.5f);

            // White checkmark
            applet.stroke(0xFFFFFFFF, a);
            applet.strokeWeight(2.0f);
            applet.strokeCap(PApplet.ROUND);
            applet.strokeJoin(PApplet.ROUND);
            applet.line(bx - 3.0f, by, bx - 0.5f, by + 3.0f);
            applet.line(bx - 0.5f, by + 3.0f, bx + 4.5f, by - 3.0f);

            applet.popStyle();
            applet.popMatrix();
        }
    }
}
