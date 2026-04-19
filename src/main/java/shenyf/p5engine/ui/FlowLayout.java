package shenyf.p5engine.ui;

import processing.core.PApplet;

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

    @Override
    public void layout(Container parent, PApplet applet) {
        float maxW = parent.getContentWidth();
        float x = 0;
        float y = 0;
        float rowH = 0;
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
            x += prefW;
            rowH = Math.max(rowH, prefH);
        }
    }
}
