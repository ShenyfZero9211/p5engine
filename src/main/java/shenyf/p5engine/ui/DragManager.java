package shenyf.p5engine.ui;

public final class DragManager {

    private UIComponent dragSource;
    private float grabOffsetX;
    private float grabOffsetY;

    public UIComponent getDragSource() {
        return dragSource;
    }

    public void beginDrag(UIComponent source, float absMouseX, float absMouseY) {
        this.dragSource = source;
        if (source != null) {
            this.grabOffsetX = absMouseX - source.getAbsoluteX();
            this.grabOffsetY = absMouseY - source.getAbsoluteY();
        }
    }

    public void updateDrag(float absMouseX, float absMouseY) {
        if (dragSource == null) return;
        float nx = absMouseX - grabOffsetX;
        float ny = absMouseY - grabOffsetY;
        Container p = dragSource.getParent();
        if (p != null) {
            nx -= p.getAbsoluteX() + p.getContentOffsetX();
            ny -= p.getAbsoluteY() + p.getContentOffsetY();
        }
        dragSource.setPosition(nx, ny);
    }

    public void endDrag() {
        dragSource = null;
    }

    public boolean isDragging() {
        return dragSource != null;
    }
}
