package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Label extends UIComponent {

    private String text = "";
    private int textAlign = PApplet.LEFT;
    private String i18nKey;
    private Object[] i18nArgs;
    private Runnable localeListener;

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

    @Override
    public void measure(PApplet applet) {
        applet.pushStyle();
        applet.textSize(14);
        float tw = applet.textWidth(text) + 12;
        float th = 22;
        setSize(Math.max(getWidth(), tw), Math.max(getHeight(), th));
        applet.popStyle();
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawLabel(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), text, !isEnabled(), textAlign);
    }
}
