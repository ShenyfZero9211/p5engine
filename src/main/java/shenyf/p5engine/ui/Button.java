package shenyf.p5engine.ui;

import processing.core.PApplet;

public class Button extends UIComponent {

    private String label = "";
    private Runnable action;
    protected boolean hover;
    protected boolean pressedVisual;
    private String i18nKey;
    private Object[] i18nArgs;
    private Runnable localeListener;
    private String sfxPath;

    public Button(String id) {
        super(id);
        setFocusable(true);
        setSize(96, 28);
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

    public Runnable getAction() {
        return action;
    }

    public void setAction(Runnable action) {
        this.action = action;
    }

    public void setSfxPath(String path) {
        this.sfxPath = path;
    }

    public String getSfxPath() {
        return sfxPath;
    }

    @Override
    public void update(PApplet applet, float dt) {
        hover = isEnabled() && isVisible() && containsPoint(UIManager.getDesignMouseX(), UIManager.getDesignMouseY());
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawButton(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), label, hover, pressedVisual, !isEnabled());
    }

    @Override
    public boolean onEvent(UIEvent event, float absMouseX, float absMouseY) {
        if (!isEnabled()) return false;
        switch (event.getType()) {
            case MOUSE_PRESSED:
                if (event.getMouseButton() == PApplet.LEFT && containsPoint(absMouseX, absMouseY)) {
                    pressedVisual = true;
                    return true;
                }
                return false;
            case MOUSE_RELEASED:
                if (pressedVisual && event.getMouseButton() == PApplet.LEFT) {
                    pressedVisual = false;
                    if (containsPoint(absMouseX, absMouseY) && action != null) {
                        action.run();
                        if (sfxPath != null) {
                            var engine = shenyf.p5engine.core.P5Engine.getInstance();
                            if (engine != null) {
                                try {
                                    engine.getAudio().playOneShot(sfxPath, "sfx");
                                } catch (Exception e) {
                                    // ignore audio errors
                                }
                            }
                        }
                    }
                    return true;
                }
                pressedVisual = false;
                return false;
            case MOUSE_DRAGGED:
                return pressedVisual;
            default:
                return false;
        }
    }
}
