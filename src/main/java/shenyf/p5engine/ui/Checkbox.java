package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Checkbox extends UIComponent {

    private String label = "";
    private boolean checked;
    private boolean hover;

    public Checkbox(String id) {
        super(id);
        setFocusable(true);
        setSize(140, 24);
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label != null ? label : "";
    }

    public boolean isChecked() {
        return checked;
    }

    public void setChecked(boolean checked) {
        this.checked = checked;
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(applet.mouseX, applet.mouseY);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawCheckbox(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), label, checked, hover, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        if (event.getType() == UIEvent.Type.MOUSE_RELEASED && event.getMouseButton() == PApplet.LEFT) {
            if (containsPoint(absMouseX, absMouseY)) {
                checked = !checked;
                return true;
            }
        }
        return false;
    }
}
