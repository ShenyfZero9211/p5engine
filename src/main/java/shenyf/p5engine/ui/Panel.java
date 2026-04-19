package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Panel extends Container {

    private boolean chromeFocused;
    private boolean paintBackground = true;

    public Panel(String id) {
        super(id);
    }

    @Override
    public void measure(PApplet applet) {
        LayoutManager lm = getLayoutManager();
        if (lm instanceof FlowLayout) {
            FlowLayout fl = (FlowLayout) lm;
            float totalW = 0;
            float maxH = 0;
            int count = 0;
            for (UIComponent c : getChildren()) {
                if (!c.isVisible()) {
                    continue;
                }
                c.measure(applet);
                totalW += Math.max(1, c.getWidth());
                maxH = Math.max(maxH, Math.max(1, c.getHeight()));
                count++;
            }
            if (count > 0) {
                totalW += fl.getHgap() * (count - 1);
            }
            Insets ins = getInsets();
            float prefW = totalW + ins.left + ins.right;
            float prefH = maxH + ins.top + ins.bottom;
            if (getWidth() > prefW) {
                prefW = getWidth();
            }
            if (getHeight() > prefH) {
                prefH = getHeight();
            }
            setSize(prefW, prefH);
            return;
        }
        if (lm instanceof BorderLayout) {
            BorderLayout bl = (BorderLayout) lm;
            for (UIComponent c : getChildren()) {
                if (c.isVisible()) {
                    c.measure(applet);
                }
            }
            UIComponent north = null;
            UIComponent south = null;
            UIComponent east = null;
            UIComponent west = null;
            UIComponent center = null;
            for (UIComponent c : getChildren()) {
                if (!c.isVisible()) {
                    continue;
                }
                Object con = c.getLayoutConstraint();
                if (BorderLayout.NORTH.equals(con)) {
                    north = c;
                } else if (BorderLayout.SOUTH.equals(con)) {
                    south = c;
                } else if (BorderLayout.EAST.equals(con)) {
                    east = c;
                } else if (BorderLayout.WEST.equals(con)) {
                    west = c;
                } else if (BorderLayout.CENTER.equals(con) || con == null) {
                    center = c;
                }
            }
            int hg = bl.getHgap();
            int vg = bl.getVgap();
            float nh = north != null ? north.getHeight() : 0;
            float sh = south != null ? south.getHeight() : 0;
            float ww = west != null ? west.getWidth() : 0;
            float ew = east != null ? east.getWidth() : 0;
            float cw = center != null ? center.getWidth() : 0;
            float midW = 0;
            if (west != null) {
                midW += ww;
            }
            if (center != null) {
                if (midW > 0) {
                    midW += hg;
                }
                midW += cw;
            }
            if (east != null) {
                if (midW > 0) {
                    midW += hg;
                }
                midW += ew;
            }
            float topW = north != null ? north.getWidth() : 0;
            float botW = south != null ? south.getWidth() : 0;
            float prefW = Math.max(midW, Math.max(topW, botW));
            float wh = west != null ? west.getHeight() : 0;
            float ch = center != null ? center.getHeight() : 0;
            float eh = east != null ? east.getHeight() : 0;
            float midH = Math.max(wh, Math.max(ch, eh));
            float prefH = nh;
            if (nh > 0 && midH > 0) {
                prefH += vg;
            }
            prefH += midH;
            if (midH > 0 && sh > 0) {
                prefH += vg;
            }
            prefH += sh;
            Insets ins = getInsets();
            prefW += ins.left + ins.right;
            prefH += ins.top + ins.bottom;
            if (getWidth() > prefW) {
                prefW = getWidth();
            }
            if (getHeight() > prefH) {
                prefH = getHeight();
            }
            setSize(prefW, prefH);
            return;
        }
        super.measure(applet);
    }

    public boolean isPaintBackground() {
        return paintBackground;
    }

    public void setPaintBackground(boolean paintBackground) {
        this.paintBackground = paintBackground;
    }

    public boolean isChromeFocused() {
        return chromeFocused;
    }

    public void setChromeFocused(boolean chromeFocused) {
        this.chromeFocused = chromeFocused;
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        if (!paintBackground) {
            return;
        }
        theme.drawPanel(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), chromeFocused);
    }
}
