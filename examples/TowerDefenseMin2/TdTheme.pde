/**
 * Sci-Fi dark theme for TowerDefenseMin2.
 * Overrides DefaultTheme with a cyan/orange accent palette.
 */
public class TdTheme implements Theme {

    private float currentAlpha = 1f;
    private processing.core.PFont font;

    public void setFont(processing.core.PFont font) {
        this.font = font;
    }

    private void applyFont(PApplet g, float size) {
        if (font != null) {
            g.textFont(font);
        }
        g.textSize(size);
    }

    static final int BG_DARK   = 0xFF0E1222;
    static final int BG_PANEL  = 0xFF1A2035;
    static final int BG_TITLE  = 0xFF151B2E;
    static final int BORDER    = 0xFF2A3A55;
    static final int ACCENT    = 0xFF4A9EFF;
    static final int HIGHLIGHT = 0xFFFF8C42;
    static final int TEXT      = 0xFFE0E6F0;
    static final int TEXT_DIM  = 0xFF8899AA;
    static final int BTN_BG    = 0xFF252F45;
    static final int BTN_HOVER = 0xFF2F3D5A;
    static final int BTN_PRESS = 0xFF1A3A5C;

    // ── Theme interface ──

    @Override
    public void drawPanel(PApplet g, float x, float y, float w, float h, boolean focused) {
        g.noStroke();
        g.fill(a(BG_PANEL));
        g.rect(x, y, w, h, 4);
        g.stroke(a(focused ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1, 4);
    }

    @Override
    public void drawFrame(PApplet g, float x, float y, float w, float h) {
        g.noStroke();
        g.fill(a(BG_PANEL));
        g.rect(x, y, w, h, 4);
        g.stroke(a(ACCENT));
        g.strokeWeight(2);
        g.noFill();
        g.rect(x + 1, y + 1, w - 2, h - 2, 4);
    }

    @Override
    public void drawWindowChrome(PApplet g, float x, float y, float w, float h, float titleH, String title, boolean focused) {
        if (titleH <= 0) {
            // No title bar: just content + border
            g.noStroke();
            g.fill(a(BG_PANEL));
            g.rect(x, y, w, h, 4);
            g.stroke(a(focused ? ACCENT : BORDER));
            g.strokeWeight(1.5f);
            g.noFill();
            g.rect(x + 0.75f, y + 0.75f, w - 1.5f, h - 1.5f, 4);
            return;
        }
        // Title bar
        g.noStroke();
        g.fill(a(BG_TITLE));
        g.rect(x, y, w, titleH, 4, 4, 0, 0);
        // Content
        g.fill(a(BG_PANEL));
        g.rect(x, y + titleH - 1, w, h - titleH + 1, 0, 0, 4, 4);
        // Border glow
        g.stroke(a(focused ? ACCENT : BORDER));
        g.strokeWeight(1.5f);
        g.noFill();
        g.rect(x + 0.75f, y + 0.75f, w - 1.5f, h - 1.5f, 4);
        // Title text
        g.fill(a(TEXT));
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        applyFont(g, Math.min(16, titleH * 0.55f));
        g.text(title != null ? title : "", x + 12, y + titleH * 0.5f);

        // Control buttons (close/max/min) — simplified as small rects
        float btnW = 20, btnH = 14, btnGap = 4;
        float btnY = y + (titleH - btnH) * 0.5f;
        float btnRight = x + w - btnGap;
        // Close
        btnRight -= btnW;
        drawWinButton(g, btnRight, btnY, btnW, btnH, "\u00D7");
        // Max
        btnRight -= btnW + btnGap;
        drawWinButton(g, btnRight, btnY, btnW, btnH, "\u25A1");
        // Min
        btnRight -= btnW + btnGap;
        drawWinButton(g, btnRight, btnY, btnW, btnH, "\u2212");
    }

    private void drawWinButton(PApplet g, float x, float y, float w, float h, String label) {
        g.noStroke();
        g.fill(a(0xFF333333));
        g.rect(x, y, w, h, 2);
        g.stroke(a(BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1, 2);
        g.fill(a(TEXT));
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        applyFont(g, 9);
        g.text(label, x + w * 0.5f, y + h * 0.5f);
    }

    @Override
    public void drawButton(PApplet g, float x, float y, float w, float h, String label, boolean hover, boolean pressed, boolean disabled) {
        int fill = disabled ? 0xFF333333 : (pressed ? BTN_PRESS : (hover ? BTN_HOVER : BTN_BG));
        float r = 6;
        g.noStroke();
        g.fill(a(fill));
        g.rect(x, y, w, h, r);

        // Glow border on hover
        if (hover && !disabled) {
            g.stroke(a(ACCENT));
            g.strokeWeight(2);
            g.noFill();
            g.rect(x + 1, y + 1, w - 2, h - 2, r);
            // Subtle inner glow
            g.stroke(a(ACCENT & 0x40FFFFFF));
            g.strokeWeight(1);
            g.rect(x + 2, y + 2, w - 4, h - 4, r - 1);
        } else {
            g.stroke(a(disabled ? BORDER : BORDER));
            g.strokeWeight(1);
            g.noFill();
            g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1, r);
        }

        g.fill(a(disabled ? TEXT_DIM : (hover ? 0xFFFFFFFF : TEXT)));
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        applyFont(g, Math.min(18, h * 0.48f));
        g.text(label != null ? label : "", x + w * 0.5f, y + h * 0.5f);
    }

    @Override
    public void drawCheckbox(PApplet g, float x, float y, float w, float h, String label, boolean checked, boolean hover, boolean disabled) {
        float box = Math.min(h - 6, 16);
        float bx = x + 4;
        float by = y + (h - box) * 0.5f;
        g.stroke(a(disabled ? BORDER : (hover ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF333333 : BG_DARK));
        g.rect(bx, by, box, box, 2);
        if (checked) {
            g.stroke(a(ACCENT));
            g.line(bx + 3, by + box * 0.5f, bx + box * 0.35f, by + box - 3);
            g.line(bx + box * 0.35f, by + box - 3, bx + box - 2, by + 2);
        }
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        applyFont(g, Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", bx + box + 8, y + h * 0.5f);
    }

    @Override
    public void drawRadio(PApplet g, float x, float y, float w, float h, String label, boolean selected, boolean hover, boolean disabled) {
        float r = Math.min(h - 6, 14) * 0.5f;
        float cx = x + 4 + r;
        float cy = y + h * 0.5f;
        g.stroke(a(disabled ? BORDER : (hover ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF333333 : BG_DARK));
        g.ellipse(cx, cy, r * 2, r * 2);
        if (selected) {
            g.noStroke();
            g.fill(a(ACCENT));
            g.ellipse(cx, cy, r * 1.1f, r * 1.1f);
        }
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        applyFont(g, Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", x + 4 + r * 2 + 10, y + h * 0.5f);
    }

    @Override
    public void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled, int textAlign) {
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.noStroke();
        g.textAlign(textAlign, PApplet.CENTER);
        applyFont(g, Math.min(14, h * 0.5f));
        g.text(text != null ? text : "", x, y, w, h);
    }

    @Override
    public void drawTextField(PApplet g, float x, float y, float w, float h, String text, int caretIndex, boolean focused, boolean disabled) {
        g.stroke(a(disabled ? BORDER : (focused ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF333333 : BG_DARK));
        g.rect(x, y, w, h, 3);
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        float textSize = Math.min(14, h * 0.45f);
        applyFont(g, textSize);
        String t = text != null ? text : "";
        g.text(t, x + 6, y + h * 0.5f);
        if (focused && !disabled) {
            int ci = caretIndex < 0 ? t.length() : Math.min(caretIndex, t.length());
            String prefix = t.substring(0, ci);
            float tw = g.textWidth(prefix);
            g.stroke(a(ACCENT));
            g.line(x + 6 + tw, y + 6, x + 6 + tw, y + h - 6);
        }
    }

    @Override
    public void drawSliderTrack(PApplet g, float x, float y, float w, float h, float value01, boolean hover, boolean disabled) {
        float v = Math.max(0, Math.min(1, value01));
        g.noStroke();
        g.fill(a(disabled ? 0xFF333333 : 0xFF252525));
        g.rect(x, y + h * 0.35f, w, h * 0.3f, 2);
        g.fill(a(disabled ? BORDER : ACCENT));
        g.rect(x, y + h * 0.35f, w * v, h * 0.3f, 2);
        float knobX = x + w * v;
        g.stroke(a(hover && !disabled ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF555555 : 0xFFCCCCCC));
        g.ellipse(knobX, y + h * 0.5f, h * 0.55f, h * 0.55f);
    }

    @Override
    public void drawScrollBar(PApplet g, float x, float y, float w, float h, float thumbStart, float thumbLen, boolean vertical, boolean hover, boolean disabled) {
        g.noStroke();
        g.fill(a(0xFF222222));
        g.rect(x, y, w, h, 2);
        g.fill(a(disabled ? 0xFF555555 : (hover ? 0xFF777777 : 0xFF666666)));
        if (vertical) {
            g.rect(x + 1, y + thumbStart, w - 2, Math.max(8, thumbLen), 2);
        } else {
            g.rect(x + thumbStart, y + 1, Math.max(8, thumbLen), h - 2, 2);
        }
    }

    @Override
    public void drawProgressBar(PApplet g, float x, float y, float w, float h, float value01, boolean disabled) {
        float v = Math.max(0, Math.min(1, value01));
        g.noStroke();
        g.fill(a(disabled ? 0xFF333333 : 0xFF252525));
        g.rect(x, y, w, h, 3);
        g.fill(a(disabled ? BORDER : ACCENT));
        g.rect(x, y, w * v, h, 3);
        g.stroke(a(BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1, 3);
    }

    @Override
    public void drawList(PApplet g, float x, float y, float w, float h, java.util.List<String> items, int firstIndex, int selectedIndex, boolean focused, boolean disabled) {
        g.stroke(a(disabled ? BORDER : (focused ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(BG_DARK));
        g.rect(x, y, w, h, 3);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        applyFont(g, 13);
        float rowH = 26;
        int idx = 0;
        for (int i = firstIndex; i < items.size(); i++) {
            float ry = y + idx * rowH;
            if (ry + rowH > y + h) break;
            if (i == selectedIndex) {
                g.noStroke();
                g.fill(a(0xFF2A4A6A));
                g.rect(x + 1, ry, w - 2, rowH, 2);
            }
            g.fill(a(disabled ? TEXT_DIM : TEXT));
            g.noStroke();
            g.text(items.get(i), x + 6, ry + rowH * 0.5f);
            idx++;
        }
    }

    @Override
    public void drawTabHeader(PApplet g, float x, float y, float w, float h, String[] titles, int selected, boolean focused) {
        if (titles == null || titles.length == 0) return;
        float tw = w / titles.length;
        for (int i = 0; i < titles.length; i++) {
            float tx = x + i * tw;
            boolean sel = i == selected;
            g.noStroke();
            g.fill(a(sel ? BG_PANEL : 0xFF2A2A2A));
            g.rect(tx, y, tw, h, 3, 3, 0, 0);
            g.stroke(a(focused && sel ? ACCENT : BORDER));
            g.strokeWeight(1);
            g.noFill();
            g.rect(tx + 0.5f, y + 0.5f, tw - 1, h - 1, 3, 3, 0, 0);
            g.fill(a(TEXT));
            g.textAlign(PApplet.CENTER, PApplet.CENTER);
            applyFont(g, Math.min(13, h * 0.45f));
            g.text(titles[i], tx + tw * 0.5f, y + h * 0.5f);
        }
    }

    @Override
    public void drawImage(PApplet g, float x, float y, float w, float h, processing.core.PImage img, boolean disabled) {
        if (img == null) {
            g.noStroke();
            g.fill(a(0xFF333333));
            g.rect(x, y, w, h, 3);
            return;
        }
        g.pushStyle();
        int baseAlpha = Math.round(255 * currentAlpha);
        if (disabled) {
            g.tint(255, Math.round(baseAlpha * 120f / 255f));
        } else if (currentAlpha < 1f) {
            g.tint(255, baseAlpha);
        }
        g.image(img, x, y, w, h);
        g.popStyle();
    }

    @Override
    public void setCurrentAlpha(float alpha) {
        this.currentAlpha = Math.max(0f, Math.min(1f, alpha));
    }

    private int a(int c) {
        if (currentAlpha >= 1f) return c;
        int origA = (c >>> 24) & 0xFF;
        int newA = Math.round(origA * currentAlpha);
        return (newA << 24) | (c & 0x00FFFFFF);
    }
}
