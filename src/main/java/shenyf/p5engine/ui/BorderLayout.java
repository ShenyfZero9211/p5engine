package shenyf.p5engine.ui;

import processing.core.PApplet;

public final class BorderLayout implements LayoutManager {

    public static final String NORTH = "North";
    public static final String SOUTH = "South";
    public static final String EAST = "East";
    public static final String WEST = "West";
    public static final String CENTER = "Center";

    private final int hgap;
    private final int vgap;

    public BorderLayout(int hgap, int vgap) {
        this.hgap = hgap;
        this.vgap = vgap;
    }

    public BorderLayout() {
        this(4, 4);
    }

    @Override
    public void layout(Container parent, PApplet applet) {
        float cw = parent.getContentWidth();
        float ch = parent.getContentHeight();
        UIComponent north = null;
        UIComponent south = null;
        UIComponent east = null;
        UIComponent west = null;
        UIComponent center = null;
        for (UIComponent c : parent.getChildren()) {
            if (!c.isVisible()) continue;
            Object con = c.getLayoutConstraint();
            if (NORTH.equals(con)) north = c;
            else if (SOUTH.equals(con)) south = c;
            else if (EAST.equals(con)) east = c;
            else if (WEST.equals(con)) west = c;
            else if (CENTER.equals(con) || con == null) center = c;
        }
        float left = 0;
        float top = 0;
        float right = cw;
        float bottom = ch;
        if (north != null) {
            north.measure(applet);
            float nh = Math.max(0, north.getHeight());
            north.setPosition(left, top);
            north.setSize(right - left, nh);
            top += nh + vgap;
        }
        if (south != null) {
            south.measure(applet);
            float sh = Math.max(0, south.getHeight());
            south.setPosition(left, bottom - sh);
            south.setSize(right - left, sh);
            bottom -= sh + vgap;
        }
        if (west != null) {
            west.measure(applet);
            float ww = Math.max(0, west.getWidth());
            west.setPosition(left, top);
            west.setSize(ww, bottom - top);
            left += ww + hgap;
        }
        if (east != null) {
            east.measure(applet);
            float ew = Math.max(0, east.getWidth());
            east.setPosition(right - ew, top);
            east.setSize(ew, bottom - top);
            right -= ew + hgap;
        }
        if (center != null) {
            center.setPosition(left, top);
            center.setSize(Math.max(0, right - left), Math.max(0, bottom - top));
        }
    }
}
