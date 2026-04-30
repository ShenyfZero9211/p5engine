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

    // Anchor constraints for adaptive layout (bitmask)
    public static final int ANCHOR_TOP = 1;
    public static final int ANCHOR_BOTTOM = 2;
    public static final int ANCHOR_LEFT = 4;
    public static final int ANCHOR_RIGHT = 8;
    public static final int ANCHOR_HCENTER = 16;
    public static final int ANCHOR_VCENTER = 32;
    private int anchor = 0;

    // Original design-space bounds for anchor calculations (set once on first setBounds)
    private float anchorBaseX = Float.NaN;
    private float anchorBaseY = Float.NaN;
    private float anchorBaseW = Float.NaN;
    private float anchorBaseH = Float.NaN;

    // Fade-in animation state
    private boolean fadeInPending = false;
    private float fadeInDelay = 0f;
    private float fadeInDuration = 0.5f;

    // Slide-up animation state
    private boolean slideUpPending = false;
    private float slideUpDelay = 0f;
    private float slideUpOffsetY = 20f;
    private float slideUpDuration = 0.5f;
    private float slideUpOriginalY = 0f;

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
        if (Float.isNaN(anchorBaseX)) anchorBaseX = x;
        if (Float.isNaN(anchorBaseY)) anchorBaseY = y;
        if (Float.isNaN(anchorBaseW)) anchorBaseW = w;
        if (Float.isNaN(anchorBaseH)) anchorBaseH = h;
        setPosition(x, y);
        setSize(w, h);
    }

    public float getAnchorBaseX() { return Float.isNaN(anchorBaseX) ? x : anchorBaseX; }
    public float getAnchorBaseY() { return Float.isNaN(anchorBaseY) ? y : anchorBaseY; }
    public float getAnchorBaseWidth() { return Float.isNaN(anchorBaseW) ? width : anchorBaseW; }
    public float getAnchorBaseHeight() { return Float.isNaN(anchorBaseH) ? height : anchorBaseH; }

    public void setAnchor(int anchor) {
        this.anchor = anchor;
    }

    public int getAnchor() {
        return anchor;
    }

    public boolean hasAnchor(int flag) {
        return (anchor & flag) != 0;
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

    // ── Fade-in animation ──

    public void fadeIn(float delay) {
        this.fadeInPending = true;
        this.fadeInDelay = delay;
    }

    public void fadeIn(float delay, float duration) {
        this.fadeInPending = true;
        this.fadeInDelay = delay;
        this.fadeInDuration = duration;
    }

    public boolean isFadeInPending() {
        return fadeInPending;
    }

    public void clearFadeInPending() {
        this.fadeInPending = false;
    }

    public float getFadeInDelay() {
        return fadeInDelay;
    }

    public float getFadeInDuration() {
        return fadeInDuration;
    }

    // ── Slide-up animation ──

    public void slideUp(float delay) {
        this.slideUpPending = true;
        this.slideUpDelay = delay;
    }

    public void slideUp(float delay, float offsetY, float duration) {
        this.slideUpPending = true;
        this.slideUpDelay = delay;
        this.slideUpOffsetY = offsetY;
        this.slideUpDuration = duration;
    }

    public boolean isSlideUpPending() {
        return slideUpPending;
    }

    public void clearSlideUpPending() {
        this.slideUpPending = false;
    }

    public float getSlideUpDelay() {
        return slideUpDelay;
    }

    public float getSlideUpOffsetY() {
        return slideUpOffsetY;
    }

    public float getSlideUpDuration() {
        return slideUpDuration;
    }

    public float getSlideUpOriginalY() {
        return slideUpOriginalY;
    }

    public void setSlideUpOriginalY(float y) {
        this.slideUpOriginalY = y;
    }

    // ── Appear animation (fade-in + slide-up combo) ──

    public void appear(float delay) {
        fadeIn(delay);
        slideUp(delay);
    }

    public void appear(float delay, float offsetY, float duration) {
        fadeIn(delay, duration);
        slideUp(delay, offsetY, duration);
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
