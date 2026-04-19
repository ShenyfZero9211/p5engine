package shenyf.p5engine.ui;

import processing.core.PApplet;

public final class GridLayout implements LayoutManager {

    private final int rows;
    private final int cols;
    private final int hgap;
    private final int vgap;

    public GridLayout(int rows, int cols, int hgap, int vgap) {
        this.rows = Math.max(1, rows);
        this.cols = Math.max(1, cols);
        this.hgap = hgap;
        this.vgap = vgap;
    }

    public GridLayout(int rows, int cols) {
        this(rows, cols, 4, 4);
    }

    @Override
    public void layout(Container parent, PApplet applet) {
        float cw = parent.getContentWidth();
        float ch = parent.getContentHeight();
        int n = parent.getChildren().size();
        if (n == 0) return;
        int useCols = cols;
        int useRows = rows;
        if (useRows * useCols < n) {
            useCols = (int) Math.ceil(Math.sqrt(n));
            useRows = (int) Math.ceil((double) n / useCols);
        }
        float cellW = (cw - hgap * (useCols - 1)) / useCols;
        float cellH = (ch - vgap * (useRows - 1)) / useRows;
        int i = 0;
        for (UIComponent c : parent.getChildren()) {
            if (!c.isVisible()) continue;
            int col = i % useCols;
            int row = i / useCols;
            float x = col * (cellW + hgap);
            float y = row * (cellH + vgap);
            c.setPosition(x, y);
            c.setSize(Math.max(0, cellW), Math.max(0, cellH));
            i++;
        }
    }
}
