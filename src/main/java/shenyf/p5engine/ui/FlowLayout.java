package shenyf.p5engine.ui;

import processing.core.PApplet;

import java.util.ArrayList;

public final class FlowLayout implements LayoutManager {

    private final int hgap;
    private final int vgap;
    private final boolean wrap;

    public FlowLayout(int hgap, int vgap, boolean wrap) {
        this.hgap = hgap;
        this.vgap = vgap;
        this.wrap = wrap;
    }

    public FlowLayout() {
        this(6, 6, true);
    }

    public int getHgap() {
        return hgap;
    }

    public int getVgap() {
        return vgap;
    }

    public boolean isWrap() {
        return wrap;
    }

    @Override
    public void layout(Container parent, PApplet applet) {
        float maxW = parent.getContentWidth();
        float x = 0;
        float y = 0;
        float rowH = 0;
        ArrayList<UIComponent> row = wrap ? null : new ArrayList<>();
        for (UIComponent c : parent.getChildren()) {
            if (!c.isVisible()) continue;
            c.measure(applet);
            float prefW = Math.max(1, c.getWidth());
            float prefH = Math.max(1, c.getHeight());
            if (wrap && x > 0 && x + hgap + prefW > maxW) {
                x = 0;
                y += rowH + vgap;
                rowH = 0;
            }
            if (x > 0) {
                x += hgap;
            }
            c.setPosition(x, y);
            c.setSize(prefW, prefH);
            if (row != null) {
                row.add(c);
            }
            x += prefW;
            rowH = Math.max(rowH, prefH);
        }
        if (!wrap && row != null && rowH > 0) {
            float contentH = parent.getContentHeight();
            if (contentH > rowH + 0.5f) {
                float dy = (contentH - rowH) * 0.5f;
                for (UIComponent c : row) {
                    c.setPosition(c.getX(), c.getY() + dy);
                }
            }
        }
    }
}
