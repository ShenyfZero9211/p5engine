/**
 * Level card component: a Button with preview image, level name,
 * lock/cleared states, and selected highlight.
 */
static public class TdLevelCard extends shenyf.p5engine.ui.Button {

    private PImage previewImage;
    private String levelName = "";
    private String levelId = null;
    private boolean unlocked = true;
    private boolean cleared = false;
    private boolean selected = false;

    // Colors (match TdTheme / LevelCarousel)
    static final int BG_NORMAL   = 0xFF1A2035;
    static final int BG_HOVER    = 0xFF2F3D5A;
    static final int BG_PRESS    = 0xFF151B2E;
    static final int BORDER      = 0xFF2A3A55;
    static final int ACCENT      = 0xFF4A9EFF;
    static final int TEXT        = 0xFFE0E6F0;
    static final int TEXT_DIM    = 0xFF8899AA;
    static final int LOCK_COLOR  = 0xFF999999;

    static PFont cardFont;
    static void setCardFont(PFont f) { cardFont = f; }

    public TdLevelCard(String id) {
        super(id);
        setSize(220, 240);
        setFocusable(true);
    }

    public void setPreviewImage(PImage img) { this.previewImage = img; }
    public PImage getPreviewImage() { return previewImage; }
    public void setLevelName(String name) { this.levelName = name != null ? name : ""; }
    public String getLevelName() { return levelName; }
    public void setLevelId(String id) { this.levelId = id; }
    public String getLevelId() { return levelId; }

    /**
     * Automatically derive the chapter-local display index from the level ID.
     * Naming rule: level_&lt;chapter_prefix&gt;&lt;num&gt;  (e.g. "11" = ch1-#1, "110" = ch1-#10)
     * Non-numeric IDs (custom levels) return -1.
     */
    public int getDisplayIndex() {
        if (levelId == null) return -1;
        try {
            // Strip the leading chapter digit and parse the remainder
            return Integer.parseInt(levelId.substring(1));
        } catch (NumberFormatException | IndexOutOfBoundsException e) {
            return -1;
        }
    }
    public void setUnlocked(boolean v) { this.unlocked = v; }
    public boolean isUnlocked() { return unlocked; }
    public void setCleared(boolean v) { this.cleared = v; }
    public boolean isCleared() { return cleared; }
    public void setSelected(boolean v) { this.selected = v; }
    public boolean isSelected() { return selected; }

    /** Allow parent container to manually control hover state. */
    public void setHover(boolean v) { this.hover = v; }

    /** Allow parent container to manually control pressed visual state. */
    public void setPressedVisual(boolean v) { this.pressedVisual = v; }

    @Override
    public void paint(PApplet g, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        float x = getAbsoluteX();
        float y = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        float alpha = getEffectiveAlpha();

        float cardScale = w / 220f;

        float pressScale = pressedVisual ? 0.96f : 1.0f;
        float cx = x + w * 0.5f;
        float cy = y + h * 0.5f;

        g.pushMatrix();
        g.translate(cx, cy);
        g.scale(pressScale);
        g.translate(-cx, -cy);

        // Background
        int bg = !unlocked ? BG_NORMAL : (pressedVisual ? BG_PRESS : (hover ? BG_HOVER : BG_NORMAL));
        g.noStroke();
        g.fill(applyAlpha(bg, alpha));
        g.rect(x, y, w, h, 4 * cardScale);

        // Preview image area (top 55%, 6px margin)
        float margin = 6f * cardScale;
        float previewH = h * 0.55f;
        float px = x + margin;
        float py = y + margin;
        float pw = w - margin * 2;
        float ph = previewH;

        if (previewImage != null) {
            g.imageMode(PApplet.CORNER);
            if (alpha < 1f) {
                g.tint(255, Math.round(255 * alpha));
                g.image(previewImage, px, py, pw, ph);
                g.noTint();
            } else {
                g.image(previewImage, px, py, pw, ph);
            }
        } else {
            g.noStroke();
            g.fill(applyAlpha(0xFF111827, alpha));
            g.rect(px, py, pw, ph, 2 * cardScale);
            g.stroke(applyAlpha(BORDER, alpha));
            g.strokeWeight(1 * cardScale);
            float cx2 = px + pw / 2;
            float cy2 = py + ph / 2;
            g.line(cx2 - 10 * cardScale, cy2, cx2 + 10 * cardScale, cy2);
            g.line(cx2, cy2 - 10 * cardScale, cx2, cy2 + 10 * cardScale);
        }

        // Level name (two lines: chinese number + name)
        g.fill(applyAlpha(unlocked ? TEXT : TEXT_DIM, alpha));
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        if (cardFont != null) {
            g.textFont(cardFont);
        } else if (theme instanceof TdTheme) {
            PFont f = ((TdTheme) theme).getFont();
            if (f != null) g.textFont(f);
        }
        float textSize = Math.max(12 * cardScale, h * 0.075f);
        g.textSize(textSize);
        float textAreaTop = y + previewH;
        float textAreaH = h - previewH - margin;
        float lineSpacing = textSize * 1.55f;
        float line1Y = textAreaTop + (textAreaH - lineSpacing) / 2f;
        float line2Y = line1Y + lineSpacing;
        int displayIdx = getDisplayIndex();
        if (displayIdx > 0) {
            g.text(toChineseNumber(displayIdx), x + w / 2f, line1Y);
        } else {
            g.text(levelId != null ? levelId : "", x + w / 2f, line1Y);
        }
        g.text(levelName, x + w / 2f, line2Y);

        // Border
        if (selected) {
            float pulse = (PApplet.sin(g.millis() * 0.005f) + 1f) * 0.5f;
            g.noFill();
            // Outer glow layers
            g.stroke(applyAlpha(ACCENT, alpha * (0.04f + pulse * 0.08f)));
            g.strokeWeight((6f + pulse * 7.5f) * cardScale);
            g.rect(x - 3 * cardScale, y - 3 * cardScale, w + 6 * cardScale, h + 6 * cardScale, 4 * cardScale);
            g.stroke(applyAlpha(ACCENT, alpha * (0.10f + pulse * 0.15f)));
            g.strokeWeight((3f + pulse * 3.75f) * cardScale);
            g.rect(x - 1 * cardScale, y - 1 * cardScale, w + 2 * cardScale, h + 2 * cardScale, 4 * cardScale);
            // Main border
            g.stroke(applyAlpha(ACCENT, alpha));
            g.strokeWeight((2f + pulse * 2f) * cardScale);
            g.rect(x + 1 * cardScale, y + 1 * cardScale, w - 2 * cardScale, h - 2 * cardScale, 3 * cardScale);
            // Inner accent line
            g.stroke(applyAlpha(ACCENT & 0x60FFFFFF, alpha * (0.5f + pulse * 0.5f)));
            g.strokeWeight((1f + pulse * 1f) * cardScale);
            g.rect(x + 2 * cardScale, y + 2 * cardScale, w - 4 * cardScale, h - 4 * cardScale, 2 * cardScale);
        } else {
            if (hover) {
                g.stroke(applyAlpha(ACCENT, alpha * 0.8f));
                g.strokeWeight(1.5f * cardScale);
            } else {
                g.stroke(applyAlpha(BORDER, alpha));
                g.strokeWeight(1 * cardScale);
            }
            g.noFill();
            g.rect(x + 0.5f * cardScale, y + 0.5f * cardScale, w - 1 * cardScale, h - 1 * cardScale, 4 * cardScale);
        }

        // Lock overlay
        if (!unlocked) {
            g.noStroke();
            g.fill(applyAlpha(0xB0000000, alpha));
            g.rect(x, y, w, h, 4 * cardScale);
            drawLock(g, x + w / 2f, y + h / 2f, alpha, cardScale);
        } else if (cleared) {
            drawClearedBadge(g, x + w - 28 * cardScale, y + 22 * cardScale, alpha, cardScale);
        }

        g.popMatrix();

        // Focus ring
        if (UIManager.isPaintingContext(this) && UIManager.isFocusRingVisible()) {
            theme.drawFocusRing(g, x, y, w, h);
        }
    }

    private void drawLock(PApplet g, float cx, float cy, float alpha, float scale) {
        g.pushStyle();
        g.noFill();
        g.stroke(applyAlpha(LOCK_COLOR, alpha));
        g.strokeWeight(2.0f * scale);
        g.strokeCap(PApplet.ROUND);
        float r = 5f * scale;
        g.arc(cx, cy - 1 * scale, r * 2, r * 2, PApplet.PI, PApplet.TWO_PI);
        g.noStroke();
        g.fill(applyAlpha(LOCK_COLOR, alpha));
        g.rect(cx - r, cy - 1 * scale, r * 2, r + 2 * scale, 1.5f * scale);
        g.fill(applyAlpha(0xFF444444, alpha));
        g.ellipse(cx, cy + 2 * scale, 2 * scale, 2 * scale);
        g.popStyle();
    }

    private void drawClearedBadge(PApplet g, float cx, float cy, float alpha, float scale) {
        g.pushStyle();
        g.noStroke();
        g.fill(applyAlpha(0x404ADE80, alpha));
        drawPolyCircle(g.g, cx, cy, 18 * scale, 16);
        g.fill(applyAlpha(0xFF4ADE80, alpha));
        drawPolyCircle(g.g, cx, cy, 11 * scale, 16);
        g.stroke(applyAlpha(0xFFFFFFFF, alpha));
        g.strokeWeight(3 * scale);
        g.strokeCap(PApplet.ROUND);
        g.line(cx - 7 * scale, cy, cx, cy + 7 * scale);
        g.line(cx, cy + 7 * scale, cx + 9 * scale, cy - 7 * scale);
        g.popStyle();
    }

    private int applyAlpha(int col, float alphaMul) {
        int a = (col >>> 24) & 0xFF;
        int rgb = col & 0xFFFFFF;
        int newA = Math.round(a * alphaMul);
        return (newA << 24) | rgb;
    }

}
