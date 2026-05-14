/**
 * Chapter tab button with enhanced selected visual feedback.
 * Extracted from TdFlow for standalone reuse.
 */
static class TdChapterButton extends shenyf.p5engine.ui.Button {
    boolean selected;

    TdChapterButton(String id) {
        super(id);
    }

    @Override
    public void paint(PApplet g, Theme theme) {
        float x = getAbsoluteX();
        float y = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        float alpha = getEffectiveAlpha();

        float scale = pressedVisual ? 0.96f : 1.0f;
        float cx = x + w * 0.5f;
        float cy = y + h * 0.5f;

        g.pushMatrix();
        g.translate(cx, cy);
        g.scale(scale);
        g.translate(-cx, -cy);

        // Background
        int bg = pressedVisual ? TdTheme.BTN_PRESS : (hover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG);
        if (selected && !pressedVisual) bg = TdTheme.BTN_HOVER;
        g.noStroke();
        g.fill(a(bg, alpha));
        g.rect(x, y, w, h, 6);

        // Border
        int borderCol = selected ? TdTheme.ACCENT : TdTheme.BORDER;
        g.stroke(a(borderCol, alpha));
        g.strokeWeight(selected ? 2 : 1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1, 6);

        // Text
        int textCol = selected ? TdTheme.ACCENT : TdTheme.TEXT;
        g.fill(a(textCol, alpha));
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        if (theme instanceof TdTheme) {
            PFont f = ((TdTheme) theme).getFont();
            if (f != null) g.textFont(f);
        }
        g.textSize(Math.min(18, h * 0.48f));
        g.text(getLabel(), x + w / 2f, y + h / 2f);

        // Selected bottom indicator
        if (selected) {
            g.noStroke();
            g.fill(a(TdTheme.ACCENT, alpha));
            g.rect(x + w * 0.25f, y + h - 3, w * 0.5f, 3, 1);
        }

        g.popMatrix();

        // Focus ring
        if (UIManager.isPaintingContext(this) && UIManager.isFocusRingVisible()) {
            theme.drawFocusRing(g, x, y, w, h);
        }
    }

    private int a(int col, float alphaMul) {
        int ca = (col >>> 24) & 0xFF;
        int rgb = col & 0xFFFFFF;
        int newA = Math.round(ca * alphaMul);
        return (newA << 24) | rgb;
    }
}
