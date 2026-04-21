package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Checkbox extends UIComponent {

    private String label = "";
    private boolean checked;
    private boolean hover;
    private String i18nKey;
    private Object[] i18nArgs;
    private Runnable localeListener;

    public Checkbox(String id) {
        super(id);
        setFocusable(true);
        setSize(140, 24);
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label != null ? label : "";
    }

    public void setI18nKey(String key) {
        if (this.i18nKey != null && this.localeListener != null) {
            var i18n = shenyf.p5engine.core.P5Engine.getInstance() != null
                ? shenyf.p5engine.core.P5Engine.getInstance().getI18n() : null;
            if (i18n != null) i18n.removeListener(this.localeListener);
        }
        this.i18nKey = key;
        if (key != null) {
            this.localeListener = this::updateFromI18n;
            var i18n = shenyf.p5engine.core.P5Engine.getInstance() != null
                ? shenyf.p5engine.core.P5Engine.getInstance().getI18n() : null;
            if (i18n != null) i18n.addListener(this.localeListener);
        }
        updateFromI18n();
    }

    public void setI18nArgs(Object... args) {
        this.i18nArgs = args;
        updateFromI18n();
    }

    private void updateFromI18n() {
        if (i18nKey == null) return;
        var engine = shenyf.p5engine.core.P5Engine.getInstance();
        if (engine == null) return;
        var i18n = engine.getI18n();
        if (i18n == null) return;
        String t = i18nArgs != null ? i18n.get(i18nKey, i18nArgs) : i18n.get(i18nKey);
        setLabel(t);
    }

    public boolean isChecked() {
        return checked;
    }

    public void setChecked(boolean checked) {
        this.checked = checked;
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(applet.mouseX, applet.mouseY);
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawCheckbox(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), label, checked, hover, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        if (event.getType() == UIEvent.Type.MOUSE_RELEASED && event.getMouseButton() == PApplet.LEFT) {
            if (containsPoint(absMouseX, absMouseY)) {
                checked = !checked;
                return true;
            }
        }
        return false;
    }
}
