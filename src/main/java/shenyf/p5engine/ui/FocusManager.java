package shenyf.p5engine.ui;

public final class FocusManager {

    private UIComponent focused;

    public UIComponent getFocused() {
        return focused;
    }

    public void setFocused(UIComponent component) {
        if (focused == component) return;
        if (focused != null) {
            focused.onEvent(UIEvent.focus(UIEvent.Type.FOCUS_LOST), 0, 0);
        }
        this.focused = component;
        if (focused != null) {
            focused.onEvent(UIEvent.focus(UIEvent.Type.FOCUS_GAINED), 0, 0);
        }
    }

    public void clearFocus() {
        setFocused(null);
    }

    public void focusNext(Container root) {
        if (root == null) return;
        java.util.ArrayList<UIComponent> order = new java.util.ArrayList<>();
        collectFocusable(root, order);
        if (order.isEmpty()) {
            clearFocus();
            return;
        }
        int idx = focused != null ? order.indexOf(focused) : -1;
        int next = idx + 1;
        if (next >= order.size()) next = 0;
        setFocused(order.get(next));
    }

    public void focusPrevious(Container root) {
        if (root == null) return;
        java.util.ArrayList<UIComponent> order = new java.util.ArrayList<>();
        collectFocusable(root, order);
        if (order.isEmpty()) {
            clearFocus();
            return;
        }
        int idx = focused != null ? order.indexOf(focused) : 0;
        int prev = idx - 1;
        if (prev < 0) prev = order.size() - 1;
        setFocused(order.get(prev));
    }

    private void collectFocusable(Container container, java.util.ArrayList<UIComponent> out) {
        for (UIComponent c : container.getChildren()) {
            if (!c.isVisible() || !c.isEnabled()) continue;
            if (c instanceof Container) {
                collectFocusable((Container) c, out);
            }
            if (c.isFocusable()) {
                out.add(c);
            }
        }
    }
}
