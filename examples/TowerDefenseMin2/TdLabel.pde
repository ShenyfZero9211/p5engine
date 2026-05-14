/**
 * TowerDefenseMin2 自定义 Label，支持样式、颜色、大小覆盖。
 * 渲染完全由 TdTheme 控制。
 */
static public class TdLabel extends shenyf.p5engine.ui.Label {

    public enum Style { DEFAULT, HINT, TITLE, STATUS, SUCCESS, ERROR }

    private int customTextColor = -1;
    private float customTextSize = -1;
    private Style labelStyle = Style.DEFAULT;

    public TdLabel(String id) {
        super(id);
    }

    public void setCustomTextColor(int c) {
        this.customTextColor = c;
    }

    public int getCustomTextColor() {
        return customTextColor;
    }

    public void setCustomTextSize(float size) {
        this.customTextSize = size;
    }

    public float getCustomTextSize() {
        return customTextSize;
    }

    public void setLabelStyle(Style style) {
        this.labelStyle = style != null ? style : Style.DEFAULT;
    }

    public Style getLabelStyle() {
        return labelStyle;
    }
}
