package shenyf.p5engine.ui;

public final class UIEvent {

    public enum Type {
        MOUSE_PRESSED,
        MOUSE_RELEASED,
        MOUSE_DRAGGED,
        MOUSE_MOVED,
        MOUSE_ENTERED,
        MOUSE_EXITED,
        MOUSE_WHEEL,
        KEY_TYPED,
        KEY_PRESSED,
        KEY_RELEASED,
        FOCUS_GAINED,
        FOCUS_LOST
    }

    private final Type type;
    private final float mouseX;
    private final float mouseY;
    private final int mouseButton;
    private final char keyChar;
    private final int keyCode;
    private final float scrollDelta;

    public UIEvent(Type type, float mouseX, float mouseY, int mouseButton, char keyChar, int keyCode, float scrollDelta) {
        this.type = type;
        this.mouseX = mouseX;
        this.mouseY = mouseY;
        this.mouseButton = mouseButton;
        this.keyChar = keyChar;
        this.keyCode = keyCode;
        this.scrollDelta = scrollDelta;
    }

    public static UIEvent mouse(Type type, float mx, float my, int button) {
        return new UIEvent(type, mx, my, button, (char) 0, 0, 0);
    }

    public static UIEvent wheel(float mx, float my, float delta) {
        return new UIEvent(Type.MOUSE_WHEEL, mx, my, 0, (char) 0, 0, delta);
    }

    public static UIEvent key(Type type, char keyChar, int keyCode) {
        return new UIEvent(type, 0, 0, 0, keyChar, keyCode, 0);
    }

    public static UIEvent focus(Type type) {
        return new UIEvent(type, 0, 0, 0, (char) 0, 0, 0);
    }

    public Type getType() {
        return type;
    }

    public float getMouseX() {
        return mouseX;
    }

    public float getMouseY() {
        return mouseY;
    }

    public int getMouseButton() {
        return mouseButton;
    }

    public char getKeyChar() {
        return keyChar;
    }

    public int getKeyCode() {
        return keyCode;
    }

    public float getScrollDelta() {
        return scrollDelta;
    }
}
