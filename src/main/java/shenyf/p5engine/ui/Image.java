package shenyf.p5engine.ui;

import processing.core.PApplet;
import processing.core.PImage;

public class Image extends UIComponent {

    private PImage image;

    public Image(String id) {
        super(id);
        setSize(64, 64);
    }

    public PImage getImage() {
        return image;
    }

    public void setImage(PImage image) {
        this.image = image;
        markLayoutDirtyUp();
    }

    @Override
    public void paint(PApplet applet, Theme theme) {
        theme.setCurrentAlpha(getEffectiveAlpha());
        theme.drawImage(applet, getAbsoluteX(), getAbsoluteY(), getWidth(), getHeight(), image, !isEnabled());
    }
}
