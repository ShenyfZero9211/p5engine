package shenyf.p5engine.ui;

import processing.core.PApplet;
import java.util.ArrayList;

/**
 * A dropdown (combo-box) component that shows a single line when collapsed
 * and expands into a scrollable list below when clicked.
 *
 * <p>Reuses {@link Theme#drawButton} for the collapsed row and
 * {@link Theme#drawList} for the expanded popup. Automatically raises
 * {@code zOrder} to 999 while expanded so the list paints above siblings.
 * Supports mouse-wheel scrolling and scroll-bar thumb dragging when the
 * item count exceeds the currently visible row count.
 * Adaptive height: if there is not enough room below, the list shortens
 * first; only if even the minimum rows do not fit does it expand upward.</p>
 */
public class Dropdown extends UIComponent {

    private final ArrayList<String> items = new ArrayList<>();
    private int selectedIndex = -1;
    private boolean expanded = false;
    private float rowHeight = 26;
    private int maxVisibleRows = 12;
    private Runnable onSelect;
    private int savedZOrder = 0;
    private int firstVisibleIndex = 0;

    protected boolean hover;
    protected boolean pressedVisual;
    private boolean scrollBarHover;
    private boolean scrollBarDragging;

    private static final float SCROLLBAR_W = 10f;
    private static final int MIN_VISIBLE_ROWS = 3;

    // For reparenting to UI root while expanded
    private Container savedParent;
    private float savedX;
    private float savedY;
    private boolean expandUpward = false;
    private int currentVisibleRows = 12; // dynamic at expand time

    public Dropdown(String id) {
        super(id);
        setSize(180, 28);
        setFocusable(true);
        this.currentVisibleRows = maxVisibleRows;
    }

    // ── Items ──

    public void addItem(String item) {
        if (item != null) {
            items.add(item);
        }
    }

    public void clearItems() {
        items.clear();
        selectedIndex = -1;
        firstVisibleIndex = 0;
    }

    public String getItem(int index) {
        if (index < 0 || index >= items.size()) return null;
        return items.get(index);
    }

    public int getItemCount() {
        return items.size();
    }

    // ── Selection ──

    public int getSelectedIndex() {
        return selectedIndex;
    }

    public void setSelectedIndex(int index) {
        this.selectedIndex = (index >= -1 && index < items.size()) ? index : -1;
    }

    public String getSelectedLabel() {
        if (selectedIndex < 0 || selectedIndex >= items.size()) return "";
        return items.get(selectedIndex);
    }

    // ── Callback ──

    public void setOnSelect(Runnable callback) {
        this.onSelect = callback;
    }

    // ── Appearance ──

    public void setRowHeight(float h) {
        this.rowHeight = Math.max(1, h);
    }

    public void setMaxVisibleRows(int n) {
        this.maxVisibleRows = Math.max(1, n);
        if (!expanded) {
            this.currentVisibleRows = this.maxVisibleRows;
        }
    }

    /** Returns the effective number of visible rows (dynamic when expanded). */
    private int getVisibleRows() {
        return expanded ? currentVisibleRows : maxVisibleRows;
    }

    // ── Expand / Collapse ──

    private void setExpanded(boolean expand) {
        if (this.expanded == expand) return;

        if (expand) {
            // Decide expand strategy BEFORE reparenting (still have valid parent bounds)
            Container parent = getParent();
            float roomBelow = (parent != null)
                ? (parent.getAbsoluteY() + parent.getHeight()) - (getAbsoluteY() + getHeight())
                : Float.MAX_VALUE;
            int fitRows = (int) (roomBelow / rowHeight);

            if (fitRows >= maxVisibleRows) {
                // Enough room: expand downward with full height
                currentVisibleRows = maxVisibleRows;
                expandUpward = false;
            } else if (fitRows >= MIN_VISIBLE_ROWS) {
                // Not enough room: shorten downward
                currentVisibleRows = fitRows;
                expandUpward = false;
            } else {
                // Even minimum rows don't fit: fallback to upward expansion
                currentVisibleRows = maxVisibleRows;
                expandUpward = true;
            }

            // Save current state BEFORE removing (getAbsoluteX/Y needs parent chain)
            savedParent = getParent();
            savedX = getX();
            savedY = getY();
            savedZOrder = getZOrder();
            float absX = getAbsoluteX();
            float absY = getAbsoluteY();

            // Find root BEFORE removing (after remove, getParent() is null)
            Container root = findUiRoot();

            // Remove from current parent and add to UI root
            // so the popup is not clipped by parent bounds (e.g. Window)
            if (savedParent != null) {
                savedParent.remove(this);
            }
            if (root != null) {
                root.add(this);
                // In root, absolute coords become relative coords.
                // However root itself may have a non-zero position (e.g. FIT
                // scaling mode sets root.x = -offsetX/scale), so we must
                // subtract root's absolute position to keep the same screen
                // position after reparenting.
                setPosition(
                    absX - root.getAbsoluteX() - root.getContentOffsetX(),
                    absY - root.getAbsoluteY() - root.getContentOffsetY()
                );
                setZOrder(999);
            }
            this.expanded = true;
        } else {
            // Remove from current parent (UI root)
            Container currentParent = getParent();
            if (currentParent != null) {
                currentParent.remove(this);
            }
            // Restore to original parent and position
            if (savedParent != null) {
                savedParent.add(this);
                setPosition(savedX, savedY);
                setZOrder(savedZOrder);
            }
            this.expanded = false;
            expandUpward = false;
            currentVisibleRows = maxVisibleRows;
            scrollBarDragging = false;
        }
    }

    /** Walk up the parent chain to find the top-level UI root ( Panel with null parent ). */
    private Container findUiRoot() {
        Container p = getParent();
        if (p == null) return null;
        while (p.getParent() != null) {
            p = p.getParent();
        }
        return p;
    }

    public boolean isExpanded() {
        return expanded;
    }

    // ── Hit testing ──

    @Override
    public boolean containsPoint(float px, float py) {
        if (!isVisible()) return false;
        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        if (expanded) {
            int visible = Math.min(items.size(), getVisibleRows());
            float listH = visible * rowHeight;
            if (expandUpward) {
                return px >= ax && py >= ay - listH && px < ax + w && py < ay + h;
            } else {
                return px >= ax && py >= ay && px < ax + w && py < ay + h + listH;
            }
        }
        return px >= ax && py >= ay && px < ax + w && py < ay + h;
    }

    /** Check if a point is inside the scroll-bar track (expanded state only). */
    private boolean isScrollBarHit(float px, float py) {
        if (!expanded || items.size() <= getVisibleRows()) return false;
        float contentW = getWidth() - SCROLLBAR_W;
        int visible = Math.min(items.size(), getVisibleRows());
        float listH = visible * rowHeight;
        float listTop = expandUpward ? getAbsoluteY() - listH : getAbsoluteY() + getHeight();
        float scrollX = getAbsoluteX() + contentW;
        return px >= scrollX && px < scrollX + SCROLLBAR_W
            && py >= listTop && py < listTop + listH;
    }

    // ── Update ──

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible()
            && containsPoint(UIManager.getDesignMouseX(), UIManager.getDesignMouseY());

        // Scroll-bar hover detection
        scrollBarHover = isEnabled() && isVisible()
            && isScrollBarHit(UIManager.getDesignMouseX(), UIManager.getDesignMouseY());

        // Click-outside-to-close
        if (expanded && applet.mousePressed && !scrollBarDragging) {
            float mx = UIManager.getDesignMouseX();
            float my = UIManager.getDesignMouseY();
            if (!containsPoint(mx, my)) {
                setExpanded(false);
            }
        }
    }

    // ── Paint ──

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());

        float x = getAbsoluteX();
        float y = getAbsoluteY();
        float w = getWidth();
        float h = getHeight();
        String label = getSelectedLabel();

        // Collapsed row drawn as a button
        theme.drawButton(applet, x, y, w, h, label, hover, pressedVisual, !isEnabled());

        // Dropdown arrow on the right
        drawArrow(applet, x + w - 14, y + h * 0.5f, getEffectiveAlpha());

        if (expanded && !items.isEmpty()) {
            int visible = Math.min(items.size(), getVisibleRows());
            float listY = expandUpward ? y - visible * rowHeight : y + h;
            drawExpandedList(applet, theme, x, listY, w);
        }
    }

    private void drawArrow(PApplet g, float cx, float cy, float alpha) {
        g.noStroke();
        int a = Math.round(255 * alpha);
        g.fill(180, a);
        if (expanded) {
            g.triangle(cx - 4, cy + 2, cx + 4, cy + 2, cx, cy - 3);
        } else {
            g.triangle(cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3);
        }
    }

    private void drawExpandedList(PApplet g, Theme theme, float x, float y, float w) {
        int total = items.size();
        int visible = Math.min(total, getVisibleRows());
        float listH = visible * rowHeight;
        boolean needsScroll = total > getVisibleRows();
        float contentW = needsScroll ? w - SCROLLBAR_W : w;

        // Determine hover row
        int hoverRow = -1;
        float mx = UIManager.getDesignMouseX();
        float my = UIManager.getDesignMouseY();
        if (mx >= x && mx < x + contentW && my >= y && my < y + listH) {
            hoverRow = firstVisibleIndex + (int) ((my - y) / rowHeight);
            if (hoverRow < firstVisibleIndex || hoverRow >= total) hoverRow = -1;
        }

        // Draw list background via theme
        theme.drawList(g, x, y, contentW, listH, items, firstVisibleIndex, selectedIndex, true, !isEnabled());

        // Draw hover highlight on top (if not the selected row)
        if (hoverRow >= 0 && hoverRow != selectedIndex) {
            float ry = y + (hoverRow - firstVisibleIndex) * rowHeight;
            g.noStroke();
            int hoverA = Math.round(40 * getEffectiveAlpha());
            g.fill(255, 255, 255, hoverA);
            g.rect(x + 1, ry, contentW - 2, rowHeight);
        }

        // Draw scroll bar if needed
        if (needsScroll) {
            float trackLen = listH;
            float visibleRatio = (float) getVisibleRows() / total;
            float thumbLen = trackLen * visibleRatio;
            float thumbPos = trackLen * ((float) firstVisibleIndex / total);
            float scrollX = x + contentW;
            theme.drawScrollBar(g, scrollX, y, SCROLLBAR_W, listH, thumbPos, thumbLen, true, scrollBarHover, !isEnabled());
        }
    }

    // ── Events ──

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;

        int visible = Math.min(items.size(), getVisibleRows());
        float listH = visible * rowHeight;
        float listTop = expandUpward ? getAbsoluteY() - listH : getAbsoluteY() + getHeight();
        float btnTop = getAbsoluteY();
        float btnBottom = getAbsoluteY() + getHeight();

        switch (event.getType()) {
            case MOUSE_PRESSED:
                if (event.getMouseButton() != PApplet.LEFT) return false;
                if (!containsPoint(absMouseX, absMouseY)) return false;

                // Check scroll bar hit first (expanded only)
                if (expanded && isScrollBarHit(absMouseX, absMouseY)) {
                    scrollBarDragging = true;
                    updateScrollFromMouse(absMouseY);
                    return true;
                }

                if (!expanded) {
                    pressedVisual = true;
                    setExpanded(true);
                    return true;
                } else {
                    if (absMouseY >= btnTop && absMouseY < btnBottom) {
                        // Click on the button area while expanded -> collapse
                        setExpanded(false);
                        return true;
                    } else {
                        // Click on a list row -> select and collapse
                        int row = firstVisibleIndex + (int) ((absMouseY - listTop) / rowHeight);
                        if (row >= 0 && row < items.size()) {
                            selectedIndex = row;
                            setExpanded(false);
                            if (onSelect != null) onSelect.run();
                        }
                        return true;
                    }
                }

            case MOUSE_DRAGGED:
                if (expanded && scrollBarDragging) {
                    updateScrollFromMouse(absMouseY);
                    return true;
                }
                return false;

            case MOUSE_RELEASED:
                pressedVisual = false;
                scrollBarDragging = false;
                return false;

            case MOUSE_WHEEL:
                if (expanded) {
                    int delta = (int) Math.signum(event.getScrollDelta());
                    int maxFirst = Math.max(0, items.size() - getVisibleRows());
                    firstVisibleIndex += delta;
                    firstVisibleIndex = Math.max(0, Math.min(maxFirst, firstVisibleIndex));
                    return true;
                }
                return false;

            default:
                return false;
        }
    }

    private void updateScrollFromMouse(float absMouseY) {
        if (items.size() <= getVisibleRows()) return;
        int visible = Math.min(items.size(), getVisibleRows());
        float listH = visible * rowHeight;
        float listTop = expandUpward ? getAbsoluteY() - listH : getAbsoluteY() + getHeight();
        float trackLen = listH;
        float clickPos = absMouseY - listTop;
        int maxFirst = items.size() - getVisibleRows();
        firstVisibleIndex = (int) (maxFirst * (clickPos / trackLen));
        firstVisibleIndex = Math.max(0, Math.min(maxFirst, firstVisibleIndex));
    }
}
