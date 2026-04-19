package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Button extends UIComponent {

    private String label = "";
    private Runnable action;
    private boolean hover;
    private boolean pressedVisual;

    public Button(String id) {
        super(id);
        setFocusable(true);
        setSize(96, 28);
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label != null ? label : "";
    }

    public Runnable getAction() {
        return action;
    }

    public void setAction(Runnable action) {
        this.action = action;
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(applet.mouseX, applet.mouseY);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.drawButton(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), label, hover, pressedVisual, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        switch (event.getType()) {
            case MOUSE_PRESSED:
                if (event.getMouseButton() == PApplet.LEFT && containsPoint(absMouseX, absMouseY)) {
                    pressedVisual = true;
                    return true;
                }
                return false;
            case MOUSE_RELEASED:
                if (pressedVisual && event.getMouseButton() == PApplet.LEFT) {
                    pressedVisual = false;
                    if (containsPoint(absMouseX, absMouseY) && action != null) {
                        action.run();
                    }
                    return true;
                }
                pressedVisual = false;
                return false;
            case MOUSE_DRAGGED:
                return pressedVisual;
            default:
                return false;
        }
    }
}
