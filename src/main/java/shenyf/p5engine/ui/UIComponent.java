package shenyf.p5engine.ui;

import processing.core.PApplet;

public abstract class UIComponent {

    private String id;
    private Container parent;
    private float x;
    private float y;
    private float width = 32;
    private float height = 24;
    private boolean visible = true;
    private boolean enabled = true;
    private int zOrder;
    private boolean focusable;
    private float alpha = 1.0f;
    private Object layoutConstraint;
    private boolean layoutDirty = true;

    protected UIComponent(String id) {
        this.id = id != null ? id : "";
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id != null ? id : "";
    }

    public Container getParent() {
        return parent;
    }

    void setParentInternal(Container parent) {
        this.parent = parent;
    }

    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }

    public void setPosition(float x, float y) {
        if (this.x != x || this.y != y) {
            this.x = x;
            this.y = y;
            markLayoutDirtyUp();
        }
    }

    public float getWidth() {
        return width;
    }

    public float getHeight() {
        return height;
    }

    public void setSize(float w, float h) {
        if (width != w || height != h) {
            this.width = Math.max(0, w);
            this.height = Math.max(0, h);
            markLayoutDirtyUp();
        }
    }

    public void setBounds(float x, float y, float w, float h) {
        setPosition(x, y);
        setSize(w, h);
    }

    public boolean isVisible() {
        return visible;
    }

    public void setVisible(boolean visible) {
        this.visible = visible;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public int getZOrder() {
        return zOrder;
    }

    public void setZOrder(int zOrder) {
        this.zOrder = zOrder;
    }

    public boolean isFocusable() {
        return focusable;
    }

    public void setFocusable(boolean focusable) {
        this.focusable = focusable;
    }

    public float getAlpha() {
        return alpha;
    }

    public void setAlpha(float alpha) {
        this.alpha = Math.max(0f, Math.min(1f, alpha));
    }

    /**
     * Returns the effective alpha by multiplying this component's alpha
     * with all parent alphas, allowing child components to fade with their parent.
     */
    public float getEffectiveAlpha() {
        if (parent == null) {
            return alpha;
        }
        return alpha * parent.getEffectiveAlpha();
    }

    public Object getLayoutConstraint() {
        return layoutConstraint;
    }

    public void setLayoutConstraint(Object layoutConstraint) {
        this.layoutConstraint = layoutConstraint;
    }

    public boolean isLayoutDirty() {
        return layoutDirty;
    }

    public void markLayoutDirty() {
        this.layoutDirty = true;
    }

    public void clearLayoutDirty() {
        this.layoutDirty = false;
    }

    /**
     * Marks this component and ancestors dirty so layout runs again (e.g. after changing the tree from sketch code).
     */
    public void invalidateLayout() {
        markLayoutDirtyUp();
    }

    protected void markLayoutDirtyUp() {
        markLayoutDirty();
        if (parent != null) {
            parent.markLayoutDirtyUp();
        }
    }

    public float getAbsoluteX() {
        if (parent == null) {
            return x;
        }
        return parent.getAbsoluteX() + parent.getContentOffsetX() + x;
    }

    public float getAbsoluteY() {
        if (parent == null) {
            return y;
        }
        return parent.getAbsoluteY() + parent.getContentOffsetY() + y;
    }

    public boolean containsPoint(float px, float py) {
        if (!visible) return false;
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        return px >= ax && py >= ay && px < ax + width && py < ay + height;
    }

    public void measure(PApplet applet) {
    }

    public void layout(PApplet applet) {
    }

    public void update(PApplet applet, float dt) {
    }

    public abstract void paint(PApplet applet, Theme theme);

    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        return false;
    }

    public UIComponent hitTest(float px, float py) {
        if (!visible || !enabled) return null;
        if (containsPoint(px, py)) return this;
        return null;
    }

    protected void paintChildrenIfAny(PApplet applet, Theme theme) {
    }
}
