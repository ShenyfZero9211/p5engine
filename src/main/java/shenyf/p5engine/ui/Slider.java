package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Slider extends UIComponent {

    private float value01;
    private boolean hover;
    private boolean dragging;

    public Slider(String id) {
        super(id);
        setFocusable(true);
        setSize(160, 24);
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
        theme.drawSliderTrack(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), value01, hover, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        switch (event.getType()) {
            case MOUSE_PRESSED:
                if (event.getMouseButton() == PApplet.LEFT && containsPoint(absMouseX, absMouseY)) {
                    dragging = true;
                    updateValueFromMouse(absMouseX);
                    return true;
                }
                return false;
            case MOUSE_DRAGGED:
                if (dragging) {
                    updateValueFromMouse(absMouseX);
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

    private void updateValueFromMouse(float absMouseX) {
        float ax = getAbsoluteX();
        float w = getWidth();
        if (w <= 1) return;
        value01 = clamp((absMouseX - ax) / w);
    }

    private static float clamp(float v) {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
}
