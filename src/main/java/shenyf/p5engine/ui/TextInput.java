package shenyf.p5engine.ui;

import processing.core.PApplet;

public class TextInput extends UIComponent {

    private final StringBuilder text = new StringBuilder();
    private int caretIndex;
    private transient PApplet lastAppletForMeasure;

    public TextInput(String id) {
        super(id);
        setFocusable(true);
        setSize(200, 28);
    }

    public String getText() {
        return text.toString();
    }

    public void setText(String s) {
        text.setLength(0);
        if (s != null) {
            text.append(s);
        }
        caretIndex = text.length();
    }

    public int getCaretIndex() {
        return caretIndex;
    }

    public void setCaretIndex(int caretIndex) {
        this.caretIndex = Math.max(0, Math.min(text.length(), caretIndex));
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        lastAppletForMeasure = applet;
        boolean focused = UIManager.isPaintingContext(this);
        theme.drawTextField(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), text.toString(), caretIndex, focused, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        switch (event.getType()) {
            case MOUSE_PRESSED:
                if (event.getMouseButton() == PApplet.LEFT && containsPoint(absMouseX, absMouseY)) {
                    caretIndex = indexAtPixelX(absMouseX);
                    return true;
                }
                return false;
            case KEY_TYPED:
                char ch = event.getKeyChar();
                if (ch >= 32 && ch != 127) {
                    text.insert(caretIndex, ch);
                    caretIndex++;
                    return true;
                }
                return false;
            case KEY_PRESSED:
                int code = event.getKeyCode();
                if (code == PApplet.BACKSPACE) {
                    if (caretIndex > 0) {
                        text.deleteCharAt(caretIndex - 1);
                        caretIndex--;
                    }
                    return true;
                }
                if (code == PApplet.DELETE) {
                    if (caretIndex < text.length()) {
                        text.deleteCharAt(caretIndex);
                    }
                    return true;
                }
                if (code == PApplet.LEFT) {
                    caretIndex = Math.max(0, caretIndex - 1);
                    return true;
                }
                if (code == PApplet.RIGHT) {
                    caretIndex = Math.min(text.length(), caretIndex + 1);
                    return true;
                }
                if (code == java.awt.event.KeyEvent.VK_HOME) {
                    caretIndex = 0;
                    return true;
                }
                if (code == java.awt.event.KeyEvent.VK_END) {
                    caretIndex = text.length();
                    return true;
                }
                return false;
            default:
                return false;
        }
    }

    private int indexAtPixelX(float absMouseX) {
        String t = text.toString();
        float pad = 6;
        float innerX = absMouseX - getAbsoluteX() - pad;
        if (innerX <= 0) {
            return 0;
        }
        float h = getHeight();
        float textSize = Math.min(14, h * 0.45f);
        PApplet p = lastAppletForMeasure != null ? lastAppletForMeasure : UIManager.getActiveApplet();
        if (p == null) {
            return t.length();
        }
        p.pushStyle();
        p.textAlign(PApplet.LEFT, PApplet.CENTER);
        p.textSize(textSize);
        for (int i = 1; i <= t.length(); i++) {
            float w = p.textWidth(t.substring(0, i));
            if (w >= innerX) {
                float prev = p.textWidth(t.substring(0, i - 1));
                int pick = (innerX - prev) < (w - innerX) ? (i - 1) : i;
                p.popStyle();
                return Math.max(0, Math.min(t.length(), pick));
            }
        }
        p.popStyle();
        return t.length();
    }
}
