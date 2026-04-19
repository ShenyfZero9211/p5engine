package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Label extends UIComponent {

    private String text = "";

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
        theme.drawLabel(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), text, !isEnabled());
    }
}
