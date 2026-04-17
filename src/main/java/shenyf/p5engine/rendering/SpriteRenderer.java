package shenyf.p5engine.rendering;

import processing.core.PImage;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.Transform;
import shenyf.p5engine.util.Logger;

public class SpriteRenderer extends Component implements Renderable {
    private PImage image;
    private float width = -1;
    private float height = -1;
    private int tintColor = -1;

    public SpriteRenderer() {
    }

    public SpriteRenderer(PImage image) {
        this.image = image;
    }

    @Override
    public void start() {
        Logger.debug("SpriteRenderer started for " + getGameObject().getName());
    }

    @Override
    public void render(IRenderer renderer) {
        if (image == null || !enabled) {
            return;
        }

        Transform transform = getTransform();

        float w = width > 0 ? width : image.width;
        float h = height > 0 ? height : image.height;

        renderer.setTransform(transform);
        if (tintColor != -1) {
            renderer.setColor(tintColor);
        }
        renderer.drawImage(image, 0, 0, w, h);
        renderer.resetTransform();
    }

    public PImage getImage() {
        return image;
    }

    public void setImage(PImage image) {
        this.image = image;
    }

    public float getWidth() {
        return width;
    }

    public void setWidth(float width) {
        this.width = width;
    }

    public float getHeight() {
        return height;
    }

    public void setHeight(float height) {
        this.height = height;
    }

    public int getTintColor() {
        return tintColor;
    }

    public void setTintColor(int color) {
        this.tintColor = color;
    }
}
