package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Label extends UIComponent {

    private String text = "";
    private int textAlign = PApplet.LEFT;
    private int textColor = -1;
    private String i18nKey;
    private Object[] i18nArgs;
    private Runnable localeListener;
    private float wrapWidth = 0;
    private float textSize = -1;

    public Label(String id) {
        super(id);
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text != null ? text : "";
        markLayoutDirtyUp();
    }

    public void setI18nKey(String key) {
        if (this.i18nKey != null && this.localeListener != null) {
            var i18n = shenyf.p5engine.core.P5Engine.getInstance() != null
                ? shenyf.p5engine.core.P5Engine.getInstance().getI18n() : null;
            if (i18n != null) i18n.removeListener(this.localeListener);
        }
        this.i18nKey = key;
        if (key != null) {
            this.localeListener = this::updateFromI18n;
            var i18n = shenyf.p5engine.core.P5Engine.getInstance() != null
                ? shenyf.p5engine.core.P5Engine.getInstance().getI18n() : null;
            if (i18n != null) i18n.addListener(this.localeListener);
        }
        updateFromI18n();
    }

    public void setI18nArgs(Object... args) {
        this.i18nArgs = args;
        updateFromI18n();
    }

    private void updateFromI18n() {
        if (i18nKey == null) return;
        var engine = shenyf.p5engine.core.P5Engine.getInstance();
        if (engine == null) return;
        var i18n = engine.getI18n();
        if (i18n == null) return;
        String t = i18nArgs != null ? i18n.get(i18nKey, i18nArgs) : i18n.get(i18nKey);
        setText(t);
    }

    public int getTextAlign() {
        return textAlign;
    }

    public void setTextAlign(int textAlign) {
        this.textAlign = textAlign;
    }

    public void setTextColor(int color) {
        this.textColor = color;
    }

    public int getTextColor() {
        return textColor;
    }

    public void setWrapWidth(float wrapWidth) {
        this.wrapWidth = wrapWidth;
        markLayoutDirtyUp();
    }

    public float getWrapWidth() {
        return wrapWidth;
    }

    public void setTextSize(float textSize) {
        this.textSize = textSize;
        markLayoutDirtyUp();
    }

    public float getTextSize() {
        return textSize;
    }

    @Override
    public void measure(PApplet applet) {
        applet.pushStyle();
        float ts = textSize > 0 ? textSize : 14;
        applet.textSize(ts);
        if (wrapWidth > 0) {
            float tw = wrapWidth + 12;
            float lineH = applet.textAscent() + applet.textDescent();
            int lines = countWrapLines(applet, text, wrapWidth);
            float th = lines * lineH + 8;
            setSize(Math.max(getWidth(), tw), Math.max(getHeight(), th));
        } else {
            float tw = applet.textWidth(text) + 12;
            float th = 22;
            setSize(Math.max(getWidth(), tw), Math.max(getHeight(), th));
        }
        applet.popStyle();
    }

    private int countWrapLines(PApplet applet, String text, float maxW) {
        if (text == null || text.isEmpty()) return 1;
        int lines = 1;
        int lineStart = 0;
        for (int i = 0; i < text.length(); i++) {
            if (text.charAt(i) == '\n') {
                lines++;
                lineStart = i + 1;
            } else {
                float w = applet.textWidth(text.substring(lineStart, i + 1));
                if (w > maxW && i > lineStart) {
                    lines++;
                    lineStart = i;
                }
            }
        }
        return Math.max(1, lines);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        if (textColor != -1) {
            float alpha = getEffectiveAlpha();
            int c = textColor;
            if (alpha < 1f) {
                int origA = (c >>> 24) & 0xFF;
                int newA = Math.round(origA * alpha);
                c = (newA << 24) | (c & 0x00FFFFFF);
            }
            applet.fill(c);
            applet.noStroke();
            float ts = textSize > 0 ? textSize : Math.min(14, getHeight() * 0.5f);
            applet.textSize(ts);
            float tx;
            if (textAlign == PApplet.CENTER) {
                tx = getAbsoluteX() + getWidth() * 0.5f;
            } else if (textAlign == PApplet.RIGHT) {
                tx = getAbsoluteX() + getWidth() - 4;
            } else {
                tx = getAbsoluteX() + 4;
            }
            if (wrapWidth > 0) {
                applet.textAlign(textAlign, PApplet.TOP);
                applet.text(text != null ? text : "", getAbsoluteX() + 4, getAbsoluteY() + 4, getWidth() - 8, getHeight() - 8);
            } else {
                applet.textAlign(textAlign, PApplet.BASELINE);
                float ty = getAbsoluteY() + getHeight() * 0.5f + (applet.textAscent() - applet.textDescent()) * 0.5f;
                applet.text(text != null ? text : "", tx, ty);
            }
        } else {
            theme.setCurrentAlpha(getEffectiveAlpha());
            theme.drawLabel(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), text, !isEnabled(), textAlign);
        }
    }
}
