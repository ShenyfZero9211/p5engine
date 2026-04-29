package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;

public class List extends UIComponent {

    private static final float ROW_H = 26;

    private final ArrayList<String> items = new ArrayList<>();
    private int selectedIndex = -1;
    private int firstVisibleIndex;
    private boolean hover;

    public List(String id) {
        super(id);
        setFocusable(true);
        setSize(180, 160);
    }

    public void clearItems() {
        items.clear();
        selectedIndex = -1;
        firstVisibleIndex = 0;
        markLayoutDirtyUp();
    }

    public void addItem(String item) {
        if (item != null) {
            items.add(item);
        }
        markLayoutDirtyUp();
    }

    public ArrayList<String> getItems() {
        return items;
    }

    public int getSelectedIndex() {
        return selectedIndex;
    }

    public void setSelectedIndex(int selectedIndex) {
        this.selectedIndex = selectedIndex;
    }

    public int getFirstVisibleIndex() {
        return firstVisibleIndex;
    }

    public void setFirstVisibleIndex(int firstVisibleIndex) {
        this.firstVisibleIndex = Math.max(0, firstVisibleIndex);
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(UIManager.getDesignMouseX(), UIManager.getDesignMouseY());
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        boolean focused = UIManager.isPaintingContext(this);
        theme.drawList(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), items, firstVisibleIndex, selectedIndex, focused, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        if (event.getType() == UIEvent.Type.MOUSE_WHEEL) {
            if (containsPoint(absMouseX, absMouseY)) {
                firstVisibleIndex -= (int) Math.signum(event.getScrollDelta());
                int visibleRows = Math.max(1, (int) (getHeight() / ROW_H));
                int maxFirst = Math.max(0, items.size() - visibleRows);
                firstVisibleIndex = Math.max(0, Math.min(maxFirst, firstVisibleIndex));
                return true;
            }
            return false;
        }
        if (event.getType() == UIEvent.Type.MOUSE_RELEASED && event.getMouseButton() == PApplet.LEFT) {
            if (containsPoint(absMouseX, absMouseY)) {
                float ry = absMouseY - getAbsoluteY();
                int row = (int) (ry / ROW_H);
                int idx = firstVisibleIndex + row;
                if (idx >= 0 && idx < items.size()) {
                    selectedIndex = idx;
                    return true;
                }
            }
        }
        return false;
    }
}
