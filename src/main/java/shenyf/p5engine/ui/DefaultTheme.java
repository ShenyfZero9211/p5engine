package shenyf.p5engine.ui;

import processing.core.PApplet;

public final class DefaultTheme implements Theme {

    private static final int BG = 0xFF2B2B2B;
    private static final int PANEL = 0xFF3A3A3A;
    private static final int BORDER = 0xFF555555;
    private static final int ACCENT = 0xFF4A9EFF;
    private static final int TEXT = 0xFFEAEAEA;
    private static final int TEXT_DIM = 0xFFAAAAAA;

    @Override
    public void drawPanel(PApplet g, float x, float y, float w, float h, boolean focused) {
        g.noStroke();
        g.fill(PANEL);
        g.rect(x, y, w, h);
        g.stroke(focused ? ACCENT : BORDER);
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    }

    @Override
    public void drawFrame(PApplet g, float x, float y, float w, float h) {
        g.noStroke();
        g.fill(PANEL);
        g.rect(x, y, w, h);
        g.stroke(BORDER);
        g.strokeWeight(2);
        g.noFill();
        g.rect(x + 1, y + 1, w - 2, h - 2);
    }

    @Override
    public void drawWindowChrome(PApplet g, float x, float y, float w, float h, float titleH, String title, boolean focused) {
        g.noStroke();
        g.fill(0xFF1E1E1E);
        g.rect(x, y, w, titleH);
        g.fill(PANEL);
        g.rect(x, y + titleH, w, h - titleH);
        g.stroke(focused ? ACCENT : BORDER);
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
        g.fill(TEXT);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, titleH * 0.55f));
        float tx = x + 8;
        float ty = y + titleH * 0.5f;
        g.text(title != null ? title : "", tx, ty);
    }

    @Override
    public void drawMenuTitle(PApplet g, float x, float y, float w, float h, String title,
                               boolean hover, boolean pressed, boolean open, boolean disabled) {
        drawButton(g, x, y, w, h, title, hover, pressed || open, disabled);
    }

    @Override
    public void drawButton(PApplet g, float x, float y, float w, float h, String label, boolean hover, boolean pressed, boolean disabled) {
        int fill = disabled ? 0xFF444444 : (pressed ? 0xFF2A5A8A : (hover ? 0xFF3D5F80 : 0xFF333333));
        g.noStroke();
        g.fill(fill);
        g.rect(x, y, w, h);
        g.stroke(disabled ? BORDER : (hover ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
        g.fill(disabled ? TEXT_DIM : TEXT);
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", x + w * 0.5f, y + h * 0.5f);
    }

    @Override
    public void drawCheckbox(PApplet g, float x, float y, float w, float h, String label, boolean checked, boolean hover, boolean disabled) {
        float box = Math.min(h - 6, 16);
        float bx = x + 4;
        float by = y + (h - box) * 0.5f;
        g.stroke(disabled ? BORDER : (hover ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.fill(disabled ? 0xFF333333 : BG);
        g.rect(bx, by, box, box);
        if (checked) {
            g.stroke(ACCENT);
            g.line(bx + 3, by + box * 0.5f, bx + box * 0.35f, by + box - 3);
            g.line(bx + box * 0.35f, by + box - 3, bx + box - 2, by + 2);
        }
        g.fill(disabled ? TEXT_DIM : TEXT);
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", bx + box + 8, y + h * 0.5f);
    }

    @Override
    public void drawRadio(PApplet g, float x, float y, float w, float h, String label, boolean selected, boolean hover, boolean disabled) {
        float r = Math.min(h - 6, 14) * 0.5f;
        float cx = x + 4 + r;
        float cy = y + h * 0.5f;
        g.stroke(disabled ? BORDER : (hover ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.fill(disabled ? 0xFF333333 : BG);
        g.ellipse(cx, cy, r * 2, r * 2);
        if (selected) {
            g.noStroke();
            g.fill(ACCENT);
            g.ellipse(cx, cy, r * 1.1f, r * 1.1f);
        }
        g.fill(disabled ? TEXT_DIM : TEXT);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", x + 4 + r * 2 + 10, y + h * 0.5f);
    }

    @Override
    public void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled) {
        g.fill(disabled ? TEXT_DIM : TEXT);
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.5f));
        g.text(text != null ? text : "", x + 4, y + h * 0.5f);
    }

    @Override
    public void drawTextField(PApplet g, float x, float y, float w, float h, String text, int caretIndex, boolean focused, boolean disabled) {
        g.stroke(disabled ? BORDER : (focused ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.fill(disabled ? 0xFF333333 : BG);
        g.rect(x, y, w, h);
        g.fill(disabled ? TEXT_DIM : TEXT);
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        float textSize = Math.min(14, h * 0.45f);
        g.textSize(textSize);
        String t = text != null ? text : "";
        g.text(t, x + 6, y + h * 0.5f);
        if (focused && !disabled) {
            int ci = caretIndex;
            if (ci < 0) {
                ci = t.length();
            }
            if (ci > t.length()) {
                ci = t.length();
            }
            String prefix = t.substring(0, ci);
            float tw = g.textWidth(prefix);
            g.stroke(ACCENT);
            g.line(x + 6 + tw, y + 6, x + 6 + tw, y + h - 6);
        }
    }

    @Override
    public void drawSliderTrack(PApplet g, float x, float y, float w, float h, float value01, boolean hover, boolean disabled) {
        float v = clamp01(value01);
        g.noStroke();
        g.fill(disabled ? 0xFF333333 : 0xFF252525);
        g.rect(x, y + h * 0.35f, w, h * 0.3f);
        g.fill(disabled ? BORDER : ACCENT);
        g.rect(x, y + h * 0.35f, w * v, h * 0.3f);
        float knobX = x + w * v;
        g.stroke(hover && !disabled ? ACCENT : BORDER);
        g.strokeWeight(1);
        g.fill(disabled ? 0xFF555555 : 0xFFCCCCCC);
        g.ellipse(knobX, y + h * 0.5f, h * 0.55f, h * 0.55f);
    }

    @Override
    public void drawScrollBar(PApplet g, float x, float y, float w, float h, float thumbStart, float thumbLen, boolean vertical, boolean hover, boolean disabled) {
        g.noStroke();
        g.fill(0xFF222222);
        g.rect(x, y, w, h);
        g.fill(disabled ? 0xFF555555 : (hover ? 0xFF777777 : 0xFF666666));
        if (vertical) {
            g.rect(x + 1, y + thumbStart, w - 2, Math.max(8, thumbLen));
        } else {
            g.rect(x + thumbStart, y + 1, Math.max(8, thumbLen), h - 2);
        }
    }

    @Override
    public void drawProgressBar(PApplet g, float x, float y, float w, float h, float value01, boolean disabled) {
        float v = clamp01(value01);
        g.noStroke();
        g.fill(disabled ? 0xFF333333 : 0xFF252525);
        g.rect(x, y, w, h);
        g.fill(disabled ? BORDER : ACCENT);
        g.rect(x, y, w * v, h);
        g.stroke(BORDER);
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    }

    @Override
    public void drawList(PApplet g, float x, float y, float w, float h, java.util.List<String> items, int firstIndex, int selectedIndex, boolean focused, boolean disabled) {
        g.stroke(disabled ? BORDER : (focused ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.fill(BG);
        g.rect(x, y, w, h);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(13);
        float rowH = 26;
        int idx = 0;
        for (int i = firstIndex; i < items.size(); i++) {
            float ry = y + idx * rowH;
            if (ry + rowH > y + h) break;
            if (i == selectedIndex) {
                g.noStroke();
                g.fill(0xFF2A4A6A);
                g.rect(x + 1, ry, w - 2, rowH);
            }
            g.fill(disabled ? TEXT_DIM : TEXT);
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
            g.fill(sel ? PANEL : 0xFF2A2A2A);
            g.rect(tx, y, tw, h);
            g.stroke(focused && sel ? ACCENT : BORDER);
            g.strokeWeight(1);
            g.noFill();
            g.rect(tx + 0.5f, y + 0.5f, tw - 1, h - 1);
            g.fill(TEXT);
            g.textAlign(PApplet.CENTER, PApplet.CENTER);
            g.textSize(Math.min(13, h * 0.45f));
            g.text(titles[i], tx + tw * 0.5f, y + h * 0.5f);
        }
    }

    @Override
    public void drawImage(PApplet g, float x, float y, float w, float h, processing.core.PImage img, boolean disabled) {
        if (img == null) {
            g.noStroke();
            g.fill(0xFF333333);
            g.rect(x, y, w, h);
            return;
        }
        g.pushStyle();
        if (disabled) {
            g.tint(255, 120);
        }
        g.image(img, x, y, w, h);
        g.popStyle();
    }

    private static float clamp01(float v) {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
}
