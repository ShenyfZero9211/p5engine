package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Window extends Container {

    private String title = "";
    private float titleBarHeight = 22;

    // Window control flags
    private boolean closable = true;
    private boolean minimizable = true;
    private boolean maximizable = true;
    private boolean resizable = true;
    private boolean paintBackground = true;

    // Window state
    private boolean minimized = false;
    private boolean maximized = false;

    // Restore bounds (x, y, w, h)
    private final float[] restoreBounds = new float[4];

    private Runnable onClose;

    // Button metrics (must match DefaultTheme rendering)
    private static final float BTN_W = 22;
    private static final float BTN_GAP = 2;

    // Resize state
    public enum ResizeEdge {
        NONE, LEFT, RIGHT, TOP, BOTTOM, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT
    }

    private boolean resizing = false;
    private ResizeEdge currentResizeEdge = ResizeEdge.NONE;
    private float resizeStartMouseX;
    private float resizeStartMouseY;
    private final float[] resizeStartBounds = new float[4];

    // Hot-zone sizes
    private static final float BORDER_HOT = 6;
    private static final float CORNER_HOT = 12;
    private static final float MIN_W = 120;
    private static final float MIN_H_BODY = 60;

    public Window(String id) {
        super(id);
        setInsets(new Insets((int) titleBarHeight, 0, 0, 0));
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title != null ? title : "";
    }

    public float getTitleBarHeight() {
        return titleBarHeight;
    }

    public void setTitleBarHeight(float titleBarHeight) {
        this.titleBarHeight = Math.max(0, titleBarHeight);
        setInsets(new Insets((int) this.titleBarHeight, 0, 0, 0));
    }

    public void hideTitleBar() {
        setTitleBarHeight(0);
        setClosable(false);
        setMaximizable(false);
        setMinimizable(false);
    }

    // ── Control flags ──

    public boolean isClosable() { return closable; }
    public void setClosable(boolean v) { this.closable = v; }

    public boolean isMinimizable() { return minimizable; }
    public void setMinimizable(boolean v) { this.minimizable = v; }

    public boolean isMaximizable() { return maximizable; }
    public void setMaximizable(boolean v) { this.maximizable = v; }

    public boolean isResizable() { return resizable; }
    public void setResizable(boolean v) { this.resizable = v; }

    public boolean isPaintBackground() { return paintBackground; }
    public void setPaintBackground(boolean v) { this.paintBackground = v; }

    // ── State ──

    public boolean isMinimized() { return minimized; }
    public boolean isMaximized() { return maximized; }
    public boolean isResizing() { return resizing; }

    public Runnable getOnClose() { return onClose; }
    public void setOnClose(Runnable onClose) { this.onClose = onClose; }

    // ── Actions ──

    public void close() {
        if (onClose != null) {
            onClose.run();
        }
        setVisible(false);
    }

    public void minimize() {
        if (minimized) return;
        saveRestoreBounds();
        minimized = true;
        maximized = false;
        setSize(getWidth(), titleBarHeight);
    }

    public void maximize() {
        if (maximized) return;
        saveRestoreBounds();
        maximized = true;
        minimized = false;
        // Fill entire parent (assumes parent is root or fills design area)
        Container p = getParent();
        float pw = p != null ? p.getWidth() : 1280;
        float ph = p != null ? p.getHeight() : 720;
        setBounds(0, 0, pw, ph);
    }

    public void restore() {
        if (!minimized && !maximized) return;
        minimized = false;
        maximized = false;
        setBounds(restoreBounds[0], restoreBounds[1], restoreBounds[2], restoreBounds[3]);
    }

    private void saveRestoreBounds() {
        if (!minimized && !maximized) {
            restoreBounds[0] = getX();
            restoreBounds[1] = getY();
            restoreBounds[2] = getWidth();
            restoreBounds[3] = getHeight();
        }
    }

    // ── Resize support ──

    public ResizeEdge getResizeEdge(float absX, float absY) {
        if (!resizable) return ResizeEdge.NONE;
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();

        if (absX < ax || absX >= ax + w || absY < ay || absY >= ay + h) {
            return ResizeEdge.NONE;
        }

        // Exclude title-bar area from top-edge resize (title bar has its own drag behaviour)
        boolean onLeft   = absX < ax + BORDER_HOT;
        boolean onRight  = absX >= ax + w - BORDER_HOT;
        boolean onTop    = absY < ay + BORDER_HOT && absY >= ay + titleBarHeight;
        boolean onBottom = absY >= ay + h - BORDER_HOT;

        // Corners take precedence
        if (onLeft && onTop)    return ResizeEdge.TOP_LEFT;
        if (onRight && onTop)   return ResizeEdge.TOP_RIGHT;
        if (onLeft && onBottom) return ResizeEdge.BOTTOM_LEFT;
        if (onRight && onBottom) return ResizeEdge.BOTTOM_RIGHT;

        // Edges
        if (onLeft)   return ResizeEdge.LEFT;
        if (onRight)  return ResizeEdge.RIGHT;
        if (onTop)    return ResizeEdge.TOP;
        if (onBottom) return ResizeEdge.BOTTOM;

        return ResizeEdge.NONE;
    }

    public void beginResize(ResizeEdge edge, float mouseX, float mouseY) {
        this.currentResizeEdge = edge;
        this.resizing = true;
        this.resizeStartMouseX = mouseX;
        this.resizeStartMouseY = mouseY;
        this.resizeStartBounds[0] = getX();
        this.resizeStartBounds[1] = getY();
        this.resizeStartBounds[2] = getWidth();
        this.resizeStartBounds[3] = getHeight();
        setChildrenFreezeRender(true);
    }

    public void updateResize(float mouseX, float mouseY) {
        if (!resizing || currentResizeEdge == ResizeEdge.NONE) return;

        float dx = mouseX - resizeStartMouseX;
        float dy = mouseY - resizeStartMouseY;

        float nx = resizeStartBounds[0];
        float ny = resizeStartBounds[1];
        float nw = resizeStartBounds[2];
        float nh = resizeStartBounds[3];

        switch (currentResizeEdge) {
            case LEFT:
                nx += dx;
                nw -= dx;
                break;
            case RIGHT:
                nw += dx;
                break;
            case TOP:
                ny += dy;
                nh -= dy;
                break;
            case BOTTOM:
                nh += dy;
                break;
            case TOP_LEFT:
                nx += dx;
                ny += dy;
                nw -= dx;
                nh -= dy;
                break;
            case TOP_RIGHT:
                ny += dy;
                nw += dx;
                nh -= dy;
                break;
            case BOTTOM_LEFT:
                nx += dx;
                nw -= dx;
                nh += dy;
                break;
            case BOTTOM_RIGHT:
                nw += dx;
                nh += dy;
                break;
        }

        // Enforce minimum size
        float minH = titleBarHeight + MIN_H_BODY;
        if (nw < MIN_W) {
            if (currentResizeEdge == ResizeEdge.LEFT || currentResizeEdge == ResizeEdge.TOP_LEFT || currentResizeEdge == ResizeEdge.BOTTOM_LEFT) {
                nx = resizeStartBounds[0] + resizeStartBounds[2] - MIN_W;
            }
            nw = MIN_W;
        }
        if (nh < minH) {
            if (currentResizeEdge == ResizeEdge.TOP || currentResizeEdge == ResizeEdge.TOP_LEFT || currentResizeEdge == ResizeEdge.TOP_RIGHT) {
                ny = resizeStartBounds[1] + resizeStartBounds[3] - minH;
            }
            nh = minH;
        }

        setBounds(nx, ny, nw, nh);
    }

    public void endResize() {
        resizing = false;
        currentResizeEdge = ResizeEdge.NONE;
        setChildrenFreezeRender(false);
    }

    private void setChildrenFreezeRender(boolean freeze) {
        for (UIComponent c : getChildren()) {
            if (c instanceof WorldViewport) {
                ((WorldViewport) c).setFreezeRender(freeze);
            }
        }
    }

    // ── Hit testing ──

    public boolean isTitleBarHit(float absX, float absY) {
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        return absX >= ax && absY >= ay && absX < ax + getWidth() && absY < ay + titleBarHeight;
    }

    /** Returns the x position of the first button from the right edge. */
    private float buttonsRightX() {
        return getAbsoluteX() + getWidth() - BTN_GAP;
    }

    public boolean isCloseButtonHit(float absX, float absY) {
        if (!closable) return false;
        float right = buttonsRightX();
        float left = right - BTN_W;
        float top = getAbsoluteY();
        return absX >= left && absX < right && absY >= top && absY < top + titleBarHeight;
    }

    public boolean isMaxButtonHit(float absX, float absY) {
        if (!maximizable) return false;
        float right = buttonsRightX() - (closable ? BTN_W + BTN_GAP : 0);
        float left = right - BTN_W;
        float top = getAbsoluteY();
        return absX >= left && absX < right && absY >= top && absY < top + titleBarHeight;
    }

    public boolean isMinButtonHit(float absX, float absY) {
        if (!minimizable) return false;
        float right = buttonsRightX()
            - (closable ? BTN_W + BTN_GAP : 0)
            - (maximizable ? BTN_W + BTN_GAP : 0);
        float left = right - BTN_W;
        float top = getAbsoluteY();
        return absX >= left && absX < right && absY >= top && absY < top + titleBarHeight;
    }

    /** Title text should not overlap buttons. Returns max usable width for title. */
    public float getTitleTextMaxWidth() {
        int btnCount = (closable ? 1 : 0) + (maximizable ? 1 : 0) + (minimizable ? 1 : 0);
        return Math.max(40, getWidth() - (btnCount * BTN_W + (btnCount + 1) * BTN_GAP + 8));
    }

    // ── Paint ──

    @Override
    protected void paintChildren(PApplet applet, Theme theme) {
        if (minimized) return; // skip content when minimized
        super.paintChildren(applet, theme);
    }

    @Override
    public boolean containsPoint(float px, float py) {
        if (!super.containsPoint(px, py)) return false;
        if (minimized) {
            float ax = getAbsoluteX();
            float ay = getAbsoluteY();
            return px >= ax && px < ax + getWidth() && py >= ay && py < ay + titleBarHeight;
        }
        return true;
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        if (!isPaintBackground()) return;
        theme.drawWindowChrome(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), titleBarHeight, title, false);
    }
}
