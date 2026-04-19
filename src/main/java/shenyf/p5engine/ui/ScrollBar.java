package shenyf.p5engine.ui;

import processing.core.PApplet;

public class ScrollBar extends UIComponent {

    private boolean vertical = true;
    private float value01;
    private boolean hover;
    private boolean dragging;

    public ScrollBar(String id) {
        super(id);
        setFocusable(true);
        setSize(14, 120);
    }

    public boolean isVertical() {
        return vertical;
    }

    public void setVertical(boolean vertical) {
        this.vertical = vertical;
    }

    public float getValue() {
        return value01;
    }

    public void setValue(float value01) {
        this.value01 = clamp(value01);
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(applet.mouseX, applet.mouseY);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        float span = vertical ? h : w;
        float thumb = Math.max(18, span * 0.25f);
        float t0 = value01 * Math.max(0.1f, span - thumb);
        theme.drawScrollBar(applet, ax, ay, w, h, t0, thumb, vertical, hover, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        switch (event.getType()) {
            case MOUSE_PRESSED:
                if (event.getMouseButton() == PApplet.LEFT && containsPoint(absMouseX, absMouseY)) {
                    dragging = true;
                    updateFromMouse(absMouseX, absMouseY);
                    return true;
                }
                return false;
            case MOUSE_DRAGGED:
                if (dragging) {
                    updateFromMouse(absMouseX, absMouseY);
                    return true;
                }
                return false;
            case MOUSE_RELEASED:
                if (dragging && event.getMouseButton() == PApplet.LEFT) {
                    dragging = false;
                    return true;
                }
                return false;
            default:
                return false;
        }
    }

    private void updateFromMouse(float absMouseX, float absMouseY) {
        if (vertical) {
            float ay = getAbsoluteY();
            float h = getHeight();
            float thumb = Math.max(18, h * 0.25f);
            float span = Math.max(0.1f, h - thumb);
            value01 = clamp((absMouseY - ay - thumb * 0.5f) / span);
        } else {
            float ax = getAbsoluteX();
            float w = getWidth();
            float thumb = Math.max(18, w * 0.25f);
            float span = Math.max(0.1f, w - thumb);
            value01 = clamp((absMouseX - ax - thumb * 0.5f) / span);
        }
    }

    private static float clamp(float v) {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
}
