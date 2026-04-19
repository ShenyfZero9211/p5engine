package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Window extends Container {

    private String title = "";
    private float titleBarHeight = 22;

    public Window(String id) {
        super(id);
        setInsets(new Insets((int) titleBarHeight, 0, 0, 0));
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title != null ? title : "";
    }

    public float getTitleBarHeight() {
        return titleBarHeight;
    }

    public void setTitleBarHeight(float titleBarHeight) {
        this.titleBarHeight = Math.max(12, titleBarHeight);
        setInsets(new Insets((int) this.titleBarHeight, 0, 0, 0));
    }

    public boolean isTitleBarHit(float absX, float absY) {
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        return absX >= ax && absY >= ay && absX < ax + getWidth() && absY < ay + titleBarHeight;
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        theme.drawWindowChrome(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), titleBarHeight, title, false);
    }
}
