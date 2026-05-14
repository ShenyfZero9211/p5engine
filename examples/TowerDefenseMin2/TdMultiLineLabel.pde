/**
 * TowerDefenseMin2 多行文本组件，支持自动换行和 ScrollPane 裁剪。
 * 渲染由 TdTheme.drawMultiLineLabel() 控制。
 */
static public class TdMultiLineLabel extends shenyf.p5engine.ui.UIComponent {

    String text = "";
    String[] rawLines;
    String[] wrappedLines;
    TdLabel.Style labelStyle = TdLabel.Style.DEFAULT;
    float customTextSize = -1;
    float lineHeightMul = 1.5f;
    float computedLineHeight = 0;

    public TdMultiLineLabel(String id) {
        super(id);
    }

    public void setText(String text) {
        this.text = text != null ? text : "";
        this.rawLines = this.text.split("\n");
        markLayoutDirtyUp();
    }

    public String getText() {
        return text;
    }

    public void setLabelStyle(TdLabel.Style style) {
        this.labelStyle = style != null ? style : TdLabel.Style.DEFAULT;
    }

    public TdLabel.Style getLabelStyle() {
        return labelStyle;
    }

    public void setCustomTextSize(float size) {
        this.customTextSize = size;
    }

    public float getCustomTextSize() {
        return customTextSize;
    }

    public void setLineHeightMultiplier(float mul) {
        this.lineHeightMul = mul > 0 ? mul : 1.5f;
    }

    public float getLineHeightMultiplier() {
        return lineHeightMul;
    }

    @Override
    public void measure(processing.core.PApplet applet) {
        applet.pushStyle();
        float size = customTextSize > 0 ? customTextSize : Math.min(18, getHeight() * 0.48f);
        if (size < 1) size = 14;
        applet.textSize(size);
        computedLineHeight = size * lineHeightMul + 4;
        float maxW = Math.max(1, getWidth() - 8);
        java.util.ArrayList<String> all = new java.util.ArrayList<String>();
        for (String line : rawLines) {
            String[] wrapped = wrapLine(line, maxW, applet);
            for (String w : wrapped) all.add(w);
        }
        wrappedLines = all.toArray(new String[0]);
        applet.popStyle();
        float totalH = wrappedLines.length * computedLineHeight + 8;
        setSize(maxW + 8, totalH);
    }

    @Override
    public void paint(processing.core.PApplet applet, shenyf.p5engine.ui.Theme theme) {
        if (wrappedLines == null || wrappedLines.length == 0) return;
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawMultiLineLabel(applet, this, getAbsoluteX(), getAbsoluteY(), getWidth(),
            wrappedLines, computedLineHeight, clipTop, clipBottom, !isEnabled());
    }

    String[] wrapLine(String line, float maxW, processing.core.PApplet applet) {
        if (line == null || line.isEmpty()) return new String[]{""};
        if (applet.textWidth(line) <= maxW) return new String[]{line};
        java.util.ArrayList<String> result = new java.util.ArrayList<String>();
        StringBuilder current = new StringBuilder();
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            String test = current.toString() + c;
            if (applet.textWidth(test) > maxW) {
                if (current.length() == 0) {
                    result.add(String.valueOf(c));
                } else {
                    result.add(current.toString());
                    current = new StringBuilder();
                    current.append(c);
                }
            } else {
                current.append(c);
            }
        }
        if (current.length() > 0) {
            result.add(current.toString());
        }
        return result.toArray(new String[0]);
    }
}
