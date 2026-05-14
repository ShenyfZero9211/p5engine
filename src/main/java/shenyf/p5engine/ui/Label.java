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
    private processing.core.PFont font;
    private int textMode = -1; // -1 = default (MODEL), otherwise PApplet.MODEL or PApplet.SHAPE

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

    public void setFont(processing.core.PFont font) {
        this.font = font;
    }

    public processing.core.PFont getFont() {
        return font;
    }

    public void setTextMode(int mode) {
        this.textMode = mode;
    }

    public int getTextMode() {
        return textMode;
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
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawLabel(applet, this, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), text, !isEnabled(), textAlign);
    }
}
