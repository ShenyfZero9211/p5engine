package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Panel extends Container {

    private boolean chromeFocused;

    public Panel(String id) {
        super(id);
    }

    public boolean isChromeFocused() {
        return chromeFocused;
    }

    public void setChromeFocused(boolean chromeFocused) {
        this.chromeFocused = chromeFocused;
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        theme.drawPanel(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), chromeFocused);
    }
}
