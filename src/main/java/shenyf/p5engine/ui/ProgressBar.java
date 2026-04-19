package shenyf.p5engine.ui;

import processing.core.PApplet;

public class ProgressBar extends UIComponent {

    private float value01;

    public ProgressBar(String id) {
        super(id);
        setSize(200, 18);
    }

    public float getValue() {
        return value01;
    }

    public void setValue(float value01) {
        this.value01 = clamp(value01);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.drawProgressBar(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), value01, !isEnabled());
    }

    private static float clamp(float v) {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
}
