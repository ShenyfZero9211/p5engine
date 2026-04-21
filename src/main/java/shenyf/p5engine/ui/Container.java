package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

public class Container extends UIComponent {

    public static final class Insets {
        public int top;
        public int left;
        public int bottom;
        public int right;

        public Insets(int top, int left, int bottom, int right) {
            this.top = top;
            this.left = left;
            this.bottom = bottom;
            this.right = right;
        }

        public static Insets uniform(int v) {
            return new Insets(v, v, v, v);
        }
    }

    private final ArrayList<UIComponent> children = new ArrayList<>();
    private LayoutManager layoutManager;
    private Insets insets = new Insets(0, 0, 0, 0);

    public Container(String id) {
        super(id);
    }

    public Insets getInsets() {
        return insets;
    }

    public void setInsets(Insets insets) {
        this.insets = insets != null ? insets : new Insets(0, 0, 0, 0);
        markLayoutDirtyUp();
    }

    public LayoutManager getLayoutManager() {
        return layoutManager;
    }

    public void setLayoutManager(LayoutManager layoutManager) {
        this.layoutManager = layoutManager;
        markLayoutDirtyUp();
    }

    public float getContentOffsetX() {
        return insets.left;
    }

    public float getContentOffsetY() {
        return insets.top;
    }

    public float getContentWidth() {
        return Math.max(0, getWidth() - insets.left - insets.right);
    }

    public float getContentHeight() {
        return Math.max(0, getHeight() - insets.top - insets.bottom);
    }

    public List<UIComponent> getChildren() {
        return Collections.unmodifiableList(children);
    }

    public void add(UIComponent child) {
        add(child, null);
    }

    public void add(UIComponent child, Object constraint) {
        if (child == null) return;
        if (child.getParent() != null) {
            child.getParent().remove(child);
        }
        child.setLayoutConstraint(constraint);
        child.setParentInternal(this);
        children.add(child);
        markLayoutDirtyUp();
    }

    public void remove(UIComponent child) {
        if (child == null) return;
        if (children.remove(child)) {
            child.setParentInternal(null);
            markLayoutDirtyUp();
        }
    }

    public void removeAllChildren() {
        for (UIComponent c : new ArrayList<>(children)) {
            c.setParentInternal(null);
        }
        children.clear();
        markLayoutDirtyUp();
    }

    @Override
    public void measure(PApplet applet) {
        for (UIComponent c : children) {
            c.measure(applet);
        }
        if (layoutManager != null) {
        }
    }

    @Override
    public void layout(PApplet applet) {
        if (layoutManager != null) {
            layoutManager.layout(this, applet);
        }
        for (UIComponent c : children) {
            c.layout(applet);
        }
        clearLayoutDirty();
    }

    @Override
    public void update(PApplet applet, float dt) {
        super.update(applet, dt);
        for (UIComponent c : children) {
            if (c.isVisible()) {
                c.update(applet, dt);
            }
        }
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        paintSelf(applet, theme);
        paintChildren(applet, theme);
    }

    protected void paintSelf(PApplet applet, Theme theme) {
    }

    protected void paintChildren(PApplet applet, Theme theme) {
        ArrayList<UIComponent> sorted = new ArrayList<>(children);
        sorted.sort(Comparator.comparingInt(UIComponent::getZOrder));
        for (UIComponent c : sorted) {
            if (c.isVisible()) {
                c.paint(applet, theme);
            }
        }
    }

    @Override
    public UIComponent hitTest(float px, float py) {
        if (!isVisible() || !isEnabled()) return null;
        if (!containsPoint(px, py)) return null;
        ArrayList<UIComponent> sorted = new ArrayList<>(children);
        sorted.sort(Comparator.comparingInt(UIComponent::getZOrder).reversed());
        for (UIComponent c : sorted) {
            if (!c.isVisible()) continue;
            UIComponent hit = c.hitTest(px, py);
            if (hit != null) return hit;
        }
        return this;
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        return false;
    }
}
