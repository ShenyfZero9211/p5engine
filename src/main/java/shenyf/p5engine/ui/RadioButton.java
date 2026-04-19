package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.HashMap;
import java.util.Map;

public class RadioButton extends UIComponent {

    private static final Map<String, String> GROUP_SELECTED_ID = new HashMap<>();

    private String groupId = "default";
    private String label = "";
    private boolean hover;

    public RadioButton(String id) {
        super(id);
        setFocusable(true);
        setSize(140, 24);
    }

    public String getGroupId() {
        return groupId;
    }

    public void setGroupId(String groupId) {
        this.groupId = groupId != null ? groupId : "default";
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label != null ? label : "";
    }

    public boolean isSelected() {
        return getId().equals(GROUP_SELECTED_ID.get(groupId));
    }

    public void setSelected(boolean selected) {
        if (selected) {
            GROUP_SELECTED_ID.put(groupId, getId());
        } else if (getId().equals(GROUP_SELECTED_ID.get(groupId))) {
            GROUP_SELECTED_ID.remove(groupId);
        }
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(applet.mouseX, applet.mouseY);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.drawRadio(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), label, isSelected(), hover, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        if (event.getType() == UIEvent.Type.MOUSE_RELEASED && event.getMouseButton() == PApplet.LEFT) {
            if (containsPoint(absMouseX, absMouseY)) {
                GROUP_SELECTED_ID.put(groupId, getId());
                return true;
            }
        }
        return false;
    }
}
