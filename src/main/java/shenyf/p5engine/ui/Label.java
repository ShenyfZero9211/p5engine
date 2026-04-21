package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Label extends UIComponent {

    private String text = "";
    private int textAlign = PApplet.LEFT;

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
