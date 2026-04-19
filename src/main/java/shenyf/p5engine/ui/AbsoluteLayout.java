package shenyf.p5engine.ui;

import processing.core.PApplet;

public final class AbsoluteLayout implements LayoutManager {

    @Override
    public void layout(Container parent, PApplet applet) {
        float cw = parent.getContentWidth();
        float ch = parent.getContentHeight();
        for (UIComponent c : parent.getChildren()) {
            if (!c.isVisible()) continue;
            float w = c.getWidth();
            float h = c.getHeight();
            if (w > cw) c.setSize(cw, h);
            if (c.getHeight() > ch) c.setSize(c.getWidth(), ch);
        }
    }
}
