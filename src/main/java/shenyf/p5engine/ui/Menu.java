package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;

/**
 * One top-level menu (title button + list of actions shown in the bar's {@link MenuPopup}).
 */
public final class Menu extends Panel {

    public static final class MenuEntry {
        final String label;
        final Runnable action;
        final boolean enabled;

        MenuEntry(String label, Runnable action, boolean enabled) {
            this.label = label != null ? label : "";
            this.action = action;
            this.enabled = enabled;
        }
    }

    private final MenuBar menuBar;
    private final MenuTitleButton titleBtn;
    private final ArrayList<MenuEntry> entries = new ArrayList<>();

    public Menu(String id, MenuBar menuBar, String title) {
        super(id);
        this.menuBar = menuBar;
        setLayoutManager(null);
        setPaintBackground(false);
        titleBtn = new MenuTitleButton(this, id + "_title");
        titleBtn.setLabel(title != null ? title : "");
        titleBtn.setSize(48, 22);
        titleBtn.setPosition(0, 0);
        titleBtn.setAction(() -> menuBar.onMenuTitleClicked(this));
        add(titleBtn);
    }

    public Button getTitleButton() {
        return titleBtn;
    }

    public MenuBar getMenuBar() {
        return menuBar;
    }

    public Menu addItem(String label, Runnable action) {
        return addItem(label, action, true);
    }

    public Menu addItem(String label, Runnable action, boolean enabled) {
        entries.add(new MenuEntry(label, action, enabled));
        markLayoutDirtyUp();
        return this;
    }

    ArrayList<MenuEntry> getEntries() {
        return entries;
    }

    boolean isOpen() {
        return menuBar.isMenuShowing(this);
    }

    @Override
    public void measure(PApplet applet) {
        titleBtn.measure(applet);
        float w = Math.max(1, titleBtn.getWidth());
        float h = Math.max(1, titleBtn.getHeight());
        setSize(w, h);
    }

    @Override
    public void layout(PApplet applet) {
        titleBtn.setPosition(0, 0);
        titleBtn.setSize(getWidth(), getHeight());
        titleBtn.layout(applet);
        clearLayoutDirty();
    }

    static final class MenuTitleButton extends Button {

        private final Menu menu;

        MenuTitleButton(Menu menu, String id) {
            super(id);
            this.menu = menu;
            setFocusable(true);
        }

        @Override
        public void paint(PApplet applet, Theme theme) {
            theme.setCurrentAlpha(getEffectiveAlpha());
            theme.drawMenuTitle(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(),
                getLabel(), hover, pressedVisual, menu.isOpen(), !isEnabled());
        }
    }
}
