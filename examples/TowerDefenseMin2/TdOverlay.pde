/**
 * TdOverlay — 屏幕覆盖层与UI坐标转换工具集
 *
 * 提供两类能力：
 * 1. ScreenOverlay: 在物理屏幕像素坐标系中直接绘制（绕过 FIT 缩放矩阵）
 * 2. UiCoords: 将鼠标/物理坐标正确转换为 UI 框架内 Panel 的可用坐标
 *
 * 使用场景：
 *   - 物理屏幕固定位置的提示、标签、调试信息 → ScreenOverlay
 *   - 动态创建跟随鼠标的 UI Panel（如右键菜单、弹窗）→ UiCoords
 */

// ============================================
//  ScreenOverlay — 物理屏幕坐标系绘制
// ============================================

static class ScreenOverlay {

    /** 进入物理屏幕坐标系绘制模式 */
    static void begin(PGraphics g) {
        g.pushMatrix();
        g.resetMatrix();
        g.pushStyle();
    }

    /** 退出物理屏幕坐标系绘制模式 */
    static void end(PGraphics g) {
        g.popStyle();
        g.popMatrix();
    }

    // ── 基础形状 ──

    static void rect(PGraphics g, float x, float y, float w, float h, int fillColor) {
        g.noStroke();
        g.fill(fillColor);
        g.rect(x, y, w, h);
    }

    static void rect(PGraphics g, float x, float y, float w, float h, int fillColor, float radius) {
        g.noStroke();
        g.fill(fillColor);
        g.rect(x, y, w, h, radius);
    }

    static void circle(PGraphics g, float x, float y, float r, int fillColor) {
        g.noStroke();
        g.fill(fillColor);
        g.ellipse(x, y, r * 2, r * 2);
    }

    static void line(PGraphics g, float x1, float y1, float x2, float y2, int strokeColor, float strokeWeight) {
        g.stroke(strokeColor);
        g.strokeWeight(strokeWeight);
        g.line(x1, y1, x2, y2);
    }

    // ── 描边形状 ──

    static void strokeRect(PGraphics g, float x, float y, float w, float h, int strokeColor, float strokeWeight) {
        g.noFill();
        g.stroke(strokeColor);
        g.strokeWeight(strokeWeight);
        g.rect(x, y, w, h);
    }

    static void strokeCircle(PGraphics g, float x, float y, float r, int strokeColor, float strokeWeight) {
        g.noFill();
        g.stroke(strokeColor);
        g.strokeWeight(strokeWeight);
        g.ellipse(x, y, r * 2, r * 2);
    }

    // ── 文本 ──

    static void text(PGraphics g, String text, float x, float y, int textColor, int textSize, int align) {
        g.fill(textColor);
        g.textAlign(align);
        g.textSize(textSize);
        g.text(text, x, y);
    }

    static void text(PGraphics g, String text, float x, float y, int textColor, int textSize, int alignH, int alignV) {
        g.fill(textColor);
        g.textAlign(alignH, alignV);
        g.textSize(textSize);
        g.text(text, x, y);
    }

    // ── 组合控件 ──

    /**
     * 标签：圆角矩形背景 + 单行居中文字。
     * alignV 传 PApplet.CENTER 时文本在矩形中心；传 TOP/BOTTOM 时文本在顶/底边居中。
     */
    static void label(PGraphics g, String text, float x, float y, float w, float h,
                      int bgColor, int textColor, int textSize) {
        label(g, text, x, y, w, h, bgColor, textColor, textSize, PApplet.CENTER, PApplet.CENTER);
    }

    static void label(PGraphics g, String text, float x, float y, float w, float h,
                      int bgColor, int textColor, int textSize, int alignH, int alignV) {
        rect(g, x, y, w, h, bgColor, 4);
        float ty;
        if (alignV == PApplet.TOP)      ty = y + textSize + 2;
        else if (alignV == PApplet.BOTTOM) ty = y + h - 4;
        else                            ty = y + h * 0.5f;
        text(g, text, x + w * 0.5f, ty, textColor, textSize, alignH, alignV);
    }

    /**
     * 在屏幕锚点位置绘制标签。
     * anchor: ScreenAnchor.TOP_LEFT / TOP_CENTER / TOP_RIGHT / ...
     * margin: 与屏幕边缘的间距（像素）
     */
    static void anchoredLabel(PGraphics g, String text, int anchor, float margin,
                              float w, float h, int bgColor, int textColor, int textSize) {
        float x, y;
        float sw = g.width;
        float sh = g.height;
        switch (anchor) {
            case ScreenAnchor.TOP_LEFT:     x = margin;          y = margin;          break;
            case ScreenAnchor.TOP_CENTER:   x = (sw - w) * 0.5f; y = margin;          break;
            case ScreenAnchor.TOP_RIGHT:    x = sw - w - margin; y = margin;          break;
            case ScreenAnchor.CENTER_LEFT:  x = margin;          y = (sh - h) * 0.5f; break;
            case ScreenAnchor.CENTER:       x = (sw - w) * 0.5f; y = (sh - h) * 0.5f; break;
            case ScreenAnchor.CENTER_RIGHT: x = sw - w - margin; y = (sh - h) * 0.5f; break;
            case ScreenAnchor.BOTTOM_LEFT:  x = margin;          y = sh - h - margin; break;
            case ScreenAnchor.BOTTOM_CENTER:x = (sw - w) * 0.5f; y = sh - h - margin; break;
            case ScreenAnchor.BOTTOM_RIGHT: x = sw - w - margin; y = sh - h - margin; break;
            default:                        x = margin;          y = margin;
        }
        label(g, text, x, y, w, h, bgColor, textColor, textSize);
    }
}

// ============================================
//  ScreenAnchor — 屏幕锚点枚举
// ============================================

static class ScreenAnchor {
    static final int TOP_LEFT      = 0;
    static final int TOP_CENTER    = 1;
    static final int TOP_RIGHT     = 2;
    static final int CENTER_LEFT   = 3;
    static final int CENTER        = 4;
    static final int CENTER_RIGHT  = 5;
    static final int BOTTOM_LEFT   = 6;
    static final int BOTTOM_CENTER = 7;
    static final int BOTTOM_RIGHT  = 8;
}

// ============================================
//  UiCoords — UI 框架坐标转换
// ============================================

static class UiCoords {

    /**
     * 将物理屏幕坐标转换为 UI 框架内 Panel 的正确坐标。
     *
     * p5engine UI 框架为了处理 FIT letterboxing，将 root 的 bounds 设为 (-ox, -oy)。
     * 因此，通过 actualToDesign() 得到的设计原点相对坐标，必须加上 ox/oy 补偿，
     * 才能作为子 Panel 的 setBounds() 参数使用。
     */
    static Vector2 fromActual(DisplayManager dm, float actualX, float actualY) {
        float scale = dm.getUniformScale();
        float ox = dm.getOffsetX() / scale;
        float oy = dm.getOffsetY() / scale;
        Vector2 design = dm.actualToDesign(new Vector2(actualX, actualY));
        return new Vector2(design.x + ox, design.y + oy);
    }

    /** 快捷方法：将当前鼠标位置转换为 UI Panel 坐标 */
    static Vector2 fromMouse(DisplayManager dm, float mouseX, float mouseY) {
        return fromActual(dm, mouseX, mouseY);
    }

    /**
     * 计算在 UI 框架中全屏覆盖的 Panel bounds。
     * 返回的 bounds 可以覆盖整个物理屏幕（包括 FIT letterboxing 黑边区域）。
     */
    static void setFullscreenBounds(Panel panel, DisplayManager dm) {
        float scale = dm.getUniformScale();
        float ox = dm.getOffsetX() / scale;
        float oy = dm.getOffsetY() / scale;
        float w = dm.getActualWidth() / scale;
        float h = dm.getActualHeight() / scale;
        panel.setBounds((int)(-ox), (int)(-oy), (int)w, (int)h);
    }
}
