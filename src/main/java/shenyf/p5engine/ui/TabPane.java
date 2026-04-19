package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;

public class TabPane extends Container {

    private final ArrayList<String> titles = new ArrayList<>();
    private final ArrayList<Container> pages = new ArrayList<>();
    private int selectedIndex;
    private float tabHeaderHeight = 26;

    public TabPane(String id) {
        super(id);
        setInsets(new Insets((int) tabHeaderHeight, 0, 0, 0));
    }

    public float getTabHeaderHeight() {
        return tabHeaderHeight;
    }

    public void setTabHeaderHeight(float tabHeaderHeight) {
        this.tabHeaderHeight = Math.max(16, tabHeaderHeight);
        setInsets(new Insets((int) this.tabHeaderHeight, 0, 0, 0));
        markLayoutDirtyUp();
    }

    public int addTab(String title, Container page) {
        titles.add(title != null ? title : "");
        pages.add(page);
        super.add(page);
        syncVisibility();
        markLayoutDirtyUp();
        return pages.size() - 1;
    }

    public int getSelectedIndex() {
        return selectedIndex;
    }

    public void setSelectedIndex(int selectedIndex) {
        if (selectedIndex < 0 || selectedIndex >= pages.size()) return;
        this.selectedIndex = selectedIndex;
        syncVisibility();
        markLayoutDirtyUp();
    }

    private void syncVisibility() {
        for (int i = 0; i < pages.size(); i++) {
            pages.get(i).setVisible(i == selectedIndex);
        }
    }

    @Override
    public void measure(PApplet applet) {
        for (Container p : pages) {
            p.measure(applet);
        }
    }

    @Override
    public void layout(PApplet applet) {
        float cw = getContentWidth();
        float ch = getContentHeight();
        for (Container p : pages) {
            p.setPosition(0, 0);
            p.setSize(cw, ch);
            p.measure(applet);
            p.layout(applet);
        }
        clearLayoutDirty();
    }

    @Override
    public void update(PApplet applet, float dt) {
        if (selectedIndex >= 0 && selectedIndex < pages.size()) {
            pages.get(selectedIndex).update(applet, dt);
        }
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        String[] arr = titles.toArray(new String[0]);
        theme.drawTabHeader(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), tabHeaderHeight, arr, selectedIndex, UIManager.isPaintingContext(this));
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        paintSelf(applet, theme);
        if (selectedIndex >= 0 && selectedIndex < pages.size()) {
            pages.get(selectedIndex).paint(applet, theme);
        }
    }

    @Override
    public UIComponent hitTest(float px, float py) {
        if (!isVisible() || !isEnabled()) return null;
        if (!containsPoint(px, py)) return null;
        float ay = getAbsoluteY();
        if (py < ay + tabHeaderHeight) {
            return this;
        }
        if (selectedIndex >= 0 && selectedIndex < pages.size()) {
            UIComponent h = pages.get(selectedIndex).hitTest(px, py);
            if (h != null) {
                return h;
            }
        }
        return this;
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (event.getType() == UIEvent.Type.MOUSE_RELEASED && event.getMouseButton() == PApplet.LEFT) {
            if (titles.isEmpty()) return false;
            float ax = getAbsoluteX();
            float ay = getAbsoluteY();
            float w = getWidth();
            if (absMouseY >= ay && absMouseY < ay + tabHeaderHeight && absMouseX >= ax && absMouseX < ax + w) {
                float tw = w / titles.size();
                int idx = (int) ((absMouseX - ax) / tw);
                idx = Math.max(0, Math.min(titles.size() - 1, idx));
                setSelectedIndex(idx);
                return true;
            }
        }
        return false;
    }
}
