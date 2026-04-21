package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;

/**
 * Single dropdown panel shared by a {@link MenuBar}. Filled when a menu opens; cleared when closed.
 */
public final class MenuPopup extends Panel {

    private static final float ITEM_H = 26f;
    private static final float PAD = 4f;
    private static final float MIN_W = 120f;

    public MenuPopup(String id) {
        super(id);
        setLayoutManager(null);
        setPaintBackground(true);
        setVisible(false);
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        if (!isPaintBackground()) {
            return;
        }
        theme.drawMenuPopupBackground(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), false);
    }

    void clearItems() {
        removeAllChildren();
        markLayoutDirtyUp();
    }

    void populateFromMenu(Menu menu) {
        clearItems();
        PApplet applet = UIManager.getActiveApplet();
        if (applet == null) {
            setSize(MIN_W + PAD * 2, ITEM_H + PAD * 2);
            return;
        }
        ArrayList<Menu.MenuEntry> entries = menu.getEntries();
        applet.pushStyle();
        applet.textSize(14);
        float maxLabelW = MIN_W - PAD * 2;
        for (Menu.MenuEntry e : entries) {
            maxLabelW = Math.max(maxLabelW, applet.textWidth(e.label) + 12);
        }
        applet.popStyle();
        float innerW = maxLabelW;
        float y = PAD;
        int i = 0;
        for (Menu.MenuEntry e : entries) {
            MenuItemButton b = new MenuItemButton(menu.getId() + "_mi_" + i);
            b.setLabel(e.label);
            b.setSize(innerW, ITEM_H);
            b.setPosition(PAD, y);
            b.setEnabled(e.enabled);
            b.setAction(() -> {
                menu.getMenuBar().closeAllPopups();
                if (e.action != null) {
                    e.action.run();
                }
            });
            add(b);
            y += ITEM_H + 2f;
            i++;
        }
        setSize(innerW + PAD * 2, Math.max(ITEM_H + PAD * 2, y + PAD));
    }

    static final class MenuItemButton extends Button {

        MenuItemButton(String id) {
            super(id);
            setFocusable(true);
        }

        @Override
        public void paint(PApplet applet, Theme theme) {
            theme.setCurrentAlpha(getEffectiveAlpha());
            theme.drawMenuItem(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(),
                getLabel(), hover, pressedVisual, !isEnabled());
        }
    }
}
