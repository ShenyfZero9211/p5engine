package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Frame extends Container {

    public Frame(String id) {
        super(id);
        setInsets(new Insets(4, 4, 4, 4));
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        theme.drawFrame(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight());
    }
}
