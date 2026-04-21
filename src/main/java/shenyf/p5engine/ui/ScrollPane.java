package shenyf.p5engine.ui;

import processing.core.PApplet;

public class ScrollPane extends Container {

    private final Panel viewport;
    private float scrollY;
    private boolean showVerticalBar = true;

    public ScrollPane(String id) {
        super(id);
        viewport = new Panel(id + "_viewport");
        super.add(viewport);
    }

    public Panel getViewport() {
        return viewport;
    }

    public float getScrollY() {
        return scrollY;
    }

    public void setScrollY(float scrollY) {
        this.scrollY = scrollY;
        markLayoutDirty();
    }

    public boolean isShowVerticalBar() {
        return showVerticalBar;
    }

    public void setShowVerticalBar(boolean showVerticalBar) {
        this.showVerticalBar = showVerticalBar;
        markLayoutDirty();
    }

    private float maxScrollY(float viewH) {
        return Math.max(0, viewport.getHeight() - viewH);
    }

    @Override
    public void measure(PApplet applet) {
        viewport.measure(applet);
    }

    @Override
    public void layout(PApplet applet) {
        float viewH = getContentHeight();
        float viewW = getContentWidth();
        float barW = (showVerticalBar && viewport.getHeight() > viewH + 0.5f) ? 12f : 0f;
        float innerW = Math.max(1, viewW - barW);
        float max = maxScrollY(viewH);
        if (scrollY > max) {
            scrollY = max;
        }
        if (scrollY < 0) {
            scrollY = 0;
        }
        viewport.setPosition(0, -scrollY);
        viewport.setSize(Math.max(innerW, viewport.getWidth()), Math.max(viewport.getHeight(), viewH));
        viewport.measure(applet);
        viewport.layout(applet);
        clearLayoutDirty();
    }

    @Override
    public void update(PApplet applet, float dt) {
        viewport.update(applet, dt);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        theme.drawPanel(applet, ax, ay, w, h, false);
        float ix = ax + getInsets().left;
        float iy = ay + getInsets().top;
        float iw = getContentWidth();
        float ih = getContentHeight();
        float barW = (showVerticalBar && viewport.getHeight() > ih + 0.5f) ? 12f : 0f;
        float clipW = Math.max(1, iw - barW);
        applet.clip(ix, iy, clipW, ih);
        viewport.paint(applet, theme);
        applet.noClip();
        if (barW > 0) {
            float maxS = Math.max(1, viewport.getHeight() - ih);
            float thumbLen = ih * (ih / Math.max(ih, viewport.getHeight()));
            thumbLen = Math.max(16, thumbLen);
            float t0 = (maxS <= 0.001f) ? 0 : (scrollY / maxS) * (ih - thumbLen);
            theme.drawScrollBar(applet, ix + clipW, iy, barW, ih, t0, thumbLen, true, false, !isEnabled());
        }
    }

    @Override
    public UIComponent hitTest(float px, float py) {
        if (!isVisible() || !isEnabled()) return null;
        if (!containsPoint(px, py)) return null;
        float ax = getAbsoluteX() + getInsets().left;
        float ay = getAbsoluteY() + getInsets().top;
        float iw = getContentWidth();
        float ih = getContentHeight();
        float barW = (showVerticalBar && viewport.getHeight() > ih + 0.5f) ? 12f : 0f;
        float clipW = Math.max(1, iw - barW);
        if (px >= ax && px < ax + clipW && py >= ay && py < ay + ih) {
            UIComponent inner = viewport.hitTest(px, py);
            return inner != null ? inner : this;
        }
        if (barW > 0 && px >= ax + clipW && px < ax + iw && py >= ay && py < ay + ih) {
            return this;
        }
        return this;
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (event.getType() == UIEvent.Type.MOUSE_WHEEL && containsPoint(absMouseX, absMouseY)) {
            float viewH = getContentHeight();
            float max = maxScrollY(viewH);
            setScrollY(scrollY - event.getScrollDelta() * 28f);
            if (scrollY > max) {
                scrollY = max;
            }
            if (scrollY < 0) {
                scrollY = 0;
            }
            markLayoutDirty();
            return true;
        }
        return false;
    }
}
