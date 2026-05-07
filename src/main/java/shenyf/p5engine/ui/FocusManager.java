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
        order.sort((a, b) -> {
            int cmp = Integer.compare(a.getTabIndex(), b.getTabIndex());
            return cmp != 0 ? cmp : Integer.compare(order.indexOf(a), order.indexOf(b));
        });
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
        order.sort((a, b) -> {
            int cmp = Integer.compare(a.getTabIndex(), b.getTabIndex());
            return cmp != 0 ? cmp : Integer.compare(order.indexOf(a), order.indexOf(b));
        });
        int idx = focused != null ? order.indexOf(focused) : 0;
        int prev = idx - 1;
        if (prev < 0) prev = order.size() - 1;
        setFocused(order.get(prev));
    }

    public void focusDirection(Container root, int direction) {
        if (root == null) return;
        if (focused != null) {
            UIComponent explicit = focused.getFocusNeighbor(direction);
            if (explicit != null && explicit.isVisible() && explicit.isEnabled() && explicit.isFocusable()) {
                setFocused(explicit);
                return;
            }
        }
        java.util.ArrayList<UIComponent> order = new java.util.ArrayList<>();
        collectFocusable(root, order);
        if (order.isEmpty()) {
            clearFocus();
            return;
        }
        UIComponent current = focused != null ? focused : order.get(0);
        float cx = current.getAbsoluteX() + current.getWidth() * 0.5f;
        float cy = current.getAbsoluteY() + current.getHeight() * 0.5f;

        UIComponent best = null;
        float bestDist = Float.MAX_VALUE;

        for (UIComponent c : order) {
            if (c == current) continue;
            float tx = c.getAbsoluteX() + c.getWidth() * 0.5f;
            float ty = c.getAbsoluteY() + c.getHeight() * 0.5f;
            boolean inDirection = false;
            switch (direction) {
                case 0: inDirection = ty < cy; break; // UP
                case 1: inDirection = ty > cy; break; // DOWN
                case 2: inDirection = tx < cx; break; // LEFT
                case 3: inDirection = tx > cx; break; // RIGHT
            }
            if (!inDirection) continue;
            float dist = Math.abs(tx - cx) + Math.abs(ty - cy);
            if (dist < bestDist) {
                bestDist = dist;
                best = c;
            }
        }
        if (best != null) {
            setFocused(best);
        }
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
