package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;
import java.util.Comparator;

/**
 * Horizontal menu strip with a single shared dropdown ({@link MenuPopup}). Only one menu open at a time.
 */
public final class MenuBar extends Panel {

    private final Panel menuRow;
    private final MenuPopup popup;
    private final ArrayList<Menu> menus = new ArrayList<>();
    private Menu openMenu;
    /** Restored in {@link #closeAllPopups()} after the first open in a session (e.g. NORTH vs CENTER siblings in BorderLayout). */
    private Integer savedZOrderBeforePopup;

    public MenuBar(String id) {
        super(id);
        setLayoutManager(null);
        setPaintBackground(false);
        menuRow = new Panel(id + "_row");
        menuRow.setLayoutManager(new FlowLayout(6, 4, false));
        menuRow.setPaintBackground(false);
        super.add(menuRow);
        popup = new MenuPopup(id + "_popup");
        popup.setZOrder(1000);
        super.add(popup);
    }

    public Menu addMenu(String title) {
        String mid = getId() + "_m" + menus.size();
        Menu m = new Menu(mid, this, title);
        menus.add(m);
        menuRow.add(m);
        markLayoutDirtyUp();
        return m;
    }

    public void closeAllPopups() {
        if (popup.isVisible() && savedZOrderBeforePopup != null) {
            setZOrder(savedZOrderBeforePopup);
            savedZOrderBeforePopup = null;
        }
        openMenu = null;
        popup.clearItems();
        popup.setVisible(false);

        // Restore popup back to MenuBar
        Container currentParent = popup.getParent();
        if (currentParent != null && currentParent != this) {
            currentParent.remove(popup);
            super.add(popup);
        }

        markLayoutDirtyUp();
    }

    public boolean isPopupVisible() {
        return popup.isVisible();
    }

    /**
     * @return true if a popup was open and has been closed (click was outside popup and all titles)
     */
    public boolean closePopupsIfClickOutside(float mx, float my) {
        if (!popup.isVisible()) {
            return false;
        }
        if (popup.containsPoint(mx, my)) {
            return false;
        }
        for (Menu m : menus) {
            if (m.getTitleButton().containsPoint(mx, my)) {
                return false;
            }
        }
        closeAllPopups();
        return true;
    }

    boolean isMenuShowing(Menu menu) {
        return openMenu == menu && popup.isVisible();
    }

    void onMenuTitleClicked(Menu menu) {
        if (openMenu == menu && popup.isVisible()) {
            closeAllPopups();
            return;
        }
        boolean wasPopupOpen = popup.isVisible();
        openMenu = menu;
        popup.populateFromMenu(menu);
        popup.setVisible(true);

        // Reparent popup to UI root so it paints above siblings (e.g. viewport)
        Container root = findUiRoot();
        if (root != null && popup.getParent() != root) {
            Button t = openMenu.getTitleButton();
            float absPopX = t.getAbsoluteX();
            float absPopY = t.getAbsoluteY() + t.getHeight();
            float pw = popup.getWidth();
            float ph = popup.getHeight();
            float maxX = Math.max(0, root.getWidth() - pw);
            float maxY = Math.max(0, root.getHeight() - ph);
            if (absPopX > maxX) absPopX = maxX;
            if (absPopY > maxY) absPopY = maxY;

            super.remove(popup);
            root.add(popup);
            popup.setPosition(
                absPopX - root.getAbsoluteX() - root.getContentOffsetX(),
                absPopY - root.getAbsoluteY() - root.getContentOffsetY()
            );
        }

        if (!wasPopupOpen) {
            savedZOrderBeforePopup = getZOrder();
            raiseZOrderAboveSiblings();
        }
        markLayoutDirtyUp();
    }

    /**
     * Dropdown extends below the bar; siblings with the same z-order paint later (e.g. BorderLayout CENTER after NORTH)
     * and would cover the popup. Ensure this bar paints (and hit-tests) after every sibling.
     */
    private void raiseZOrderAboveSiblings() {
        Container p = getParent();
        if (p == null) {
            return;
        }
        int maxOther = Integer.MIN_VALUE;
        for (UIComponent c : p.getChildren()) {
            if (c != this) {
                maxOther = Math.max(maxOther, c.getZOrder());
            }
        }
        if (maxOther == Integer.MIN_VALUE) {
            return;
        }
        setZOrder(Math.max(getZOrder(), maxOther + 1));
    }

    /**
     * The popup is positioned below the title row and often extends outside this component's
     * {@link #getHeight()} (narrow bar). Default {@link Container#hitTest} rejects those coordinates first.
     */
    @Override
    public UIComponent hitTest(float px, float py) {
        if (!isVisible() || !isEnabled()) {
            return null;
        }
        if (popup.isVisible()) {
            UIComponent inPopup = popup.hitTest(px, py);
            if (inPopup != null) {
                return inPopup;
            }
        }
        if (!containsPoint(px, py)) {
            return null;
        }
        ArrayList<UIComponent> sorted = new ArrayList<>(getChildren());
        sorted.sort(Comparator.comparingInt(UIComponent::getZOrder).reversed());
        for (UIComponent c : sorted) {
            if (!c.isVisible()) {
                continue;
            }
            if (c == popup) {
                continue;
            }
            UIComponent hit = c.hitTest(px, py);
            if (hit != null) {
                return hit;
            }
        }
        return this;
    }

    @Override
    public void measure(PApplet applet) {
        menuRow.measure(applet);
        Insets ins = getInsets();
        float prefW = menuRow.getWidth() + ins.left + ins.right;
        float prefH = menuRow.getHeight() + ins.top + ins.bottom;
        if (getWidth() < prefW) {
            setSize(prefW, getHeight());
        }
        if (getHeight() < prefH) {
            setSize(getWidth(), prefH);
        }
        if (popup.isVisible()) {
            popup.measure(applet);
        }
    }

    @Override
    public void layout(PApplet applet) {
        float insL = getInsets().left;
        float insT = getInsets().top;
        float cw = getContentWidth();
        float ch = getContentHeight();
        menuRow.setBounds(insL, insT, cw, ch);
        menuRow.layout(applet);

        if (popup.isVisible() && openMenu != null) {
            Button t = openMenu.getTitleButton();
            float ax = t.getAbsoluteX();
            float ay = t.getAbsoluteY() + t.getHeight();
            float pw = popup.getWidth();
            float ph = popup.getHeight();

            Container popupParent = popup.getParent();
            if (popupParent == this) {
                float barAbsX = getAbsoluteX();
                float barAbsY = getAbsoluteY();
                float maxX = Math.max(0, applet.width - pw);
                float maxY = Math.max(0, applet.height - ph);
                float absPopX = ax;
                float absPopY = ay;
                if (absPopX > maxX) absPopX = maxX;
                if (absPopY > maxY) absPopY = maxY;
                popup.setPosition(absPopX - barAbsX, absPopY - barAbsY);
            } else if (popupParent != null) {
                float maxX = Math.max(0, popupParent.getWidth() - pw);
                float maxY = Math.max(0, popupParent.getHeight() - ph);
                float absPopX = ax;
                float absPopY = ay;
                if (absPopX > maxX) absPopX = maxX;
                if (absPopY > maxY) absPopY = maxY;
                popup.setPosition(
                    absPopX - popupParent.getAbsoluteX() - popupParent.getContentOffsetX(),
                    absPopY - popupParent.getAbsoluteY() - popupParent.getContentOffsetY()
                );
            }
        }
        popup.layout(applet);
        clearLayoutDirty();
    }

    /** Walk up the parent chain to find the top-level UI root (Panel with null parent). */
    private Container findUiRoot() {
        Container p = this;
        while (p.getParent() != null) {
            p = p.getParent();
        }
        return p;
    }
}
