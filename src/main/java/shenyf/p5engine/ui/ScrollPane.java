package shenyf.p5engine.ui;

import processing.core.PApplet;

public class ScrollPane extends Container {

    private final Panel viewport;
    private float scrollY;
    private boolean showVerticalBar = true;
    private int backgroundColor = -1;

    // ── Scroll-bar interaction state ──
    private boolean draggingBar = false;
    private float dragStartMouseY;
    private float dragStartScrollY;
    private boolean barHover = false;

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
        markLayoutDirtyUp();
    }

    public boolean isShowVerticalBar() {
        return showVerticalBar;
    }

    public void setShowVerticalBar(boolean showVerticalBar) {
        this.showVerticalBar = showVerticalBar;
        markLayoutDirtyUp();
    }

    public int getBackgroundColor() {
        return backgroundColor;
    }

    public void setBackgroundColor(int backgroundColor) {
        this.backgroundColor = backgroundColor;
    }

    private float maxScrollY(float viewH) {
        return Math.max(0, viewport.getHeight() - viewH);
    }

    // ── Thumb geometry (shared by paint & interaction) ──

    private static final class ThumbMetrics {
        final float start;
        final float length;
        ThumbMetrics(float start, float length) {
            this.start = start;
            this.length = length;
        }
    }

    private ThumbMetrics calcThumbMetrics(float viewH) {
        float maxS = Math.max(1, viewport.getHeight() - viewH);
        float thumbLen = viewH * (viewH / Math.max(viewH, viewport.getHeight()));
        thumbLen = Math.max(16, thumbLen);
        float t0 = (maxS <= 0.001f) ? 0 : (scrollY / maxS) * (viewH - thumbLen);
        return new ThumbMetrics(t0, thumbLen);
    }

    private boolean isOverThumb(float absMouseX, float absMouseY) {
        float viewH = getContentHeight();
        if (!showVerticalBar || viewport.getHeight() <= viewH + 0.5f) {
            return false;
        }
        float ax = getAbsoluteX() + getInsets().left;
        float ay = getAbsoluteY() + getInsets().top;
        float iw = getContentWidth();
        float ih = viewH;
        float barW = 12f;
        float clipW = Math.max(1, iw - barW);
        if (absMouseX < ax + clipW || absMouseX >= ax + iw
                || absMouseY < ay || absMouseY >= ay + ih) {
            return false;
        }
        ThumbMetrics thumb = calcThumbMetrics(ih);
        float thumbY = ay + thumb.start;
        return absMouseY >= thumbY && absMouseY < thumbY + thumb.length;
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
        if (backgroundColor != -1) {
            applet.noStroke();
            applet.fill(backgroundColor);
            applet.rect(ax, ay, w, h, 4);
        } else {
            theme.drawPanel(applet, ax, ay, w, h, false);
        }
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
            ThumbMetrics thumb = calcThumbMetrics(ih);
            boolean hoverOrDrag = barHover || draggingBar;
            theme.drawScrollBar(applet, ix + clipW, iy, barW, ih,
                    thumb.start, thumb.length, true, hoverOrDrag, !isEnabled());
        }
    }

    @Override
    public UIComponent hitTest(float px, float py) {
        if (!isVisible() || !isEnabled()) {
            barHover = false;
            return null;
        }
        if (!containsPoint(px, py)) {
            barHover = false;
            return null;
        }
        float ax = getAbsoluteX() + getInsets().left;
        float ay = getAbsoluteY() + getInsets().top;
        float iw = getContentWidth();
        float ih = getContentHeight();
        float barW = (showVerticalBar && viewport.getHeight() > ih + 0.5f) ? 12f : 0f;
        float clipW = Math.max(1, iw - barW);

        // Update hover state while we're here
        barHover = isOverThumb(px, py);

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
            markLayoutDirtyUp();
            return true;
        }

        if (event.getType() == UIEvent.Type.MOUSE_PRESSED) {
            if (isOverThumb(absMouseX, absMouseY)) {
                draggingBar = true;
                dragStartMouseY = absMouseY;
                dragStartScrollY = scrollY;
                return true;
            }
        }

        if (event.getType() == UIEvent.Type.MOUSE_DRAGGED && draggingBar) {
            float viewH = getContentHeight();
            ThumbMetrics thumb = calcThumbMetrics(viewH);
            float trackLen = viewH - thumb.length;
            if (trackLen > 0.5f) {
                float deltaMouse = absMouseY - dragStartMouseY;
                float maxS = Math.max(1, viewport.getHeight() - viewH);
                float deltaScroll = (deltaMouse / trackLen) * maxS;
                float newScrollY = dragStartScrollY + deltaScroll;
                if (newScrollY > maxS) newScrollY = maxS;
                if (newScrollY < 0) newScrollY = 0;
                setScrollY(newScrollY);
            }
            return true;
        }

        if (event.getType() == UIEvent.Type.MOUSE_RELEASED) {
            if (draggingBar) {
                draggingBar = false;
                return true;
            }
        }

        return false;
    }
}
