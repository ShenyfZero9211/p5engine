package shenyf.p5engine.rendering;

import processing.core.PImage;
import shenyf.p5engine.core.P5Engine;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.Transform;
import shenyf.p5engine.util.Logger;

public class SpriteRenderer extends Component implements Renderable {
    private Texture texture;
    private String textureKey;
    private PImage image; // legacy fallback
    private float width = -1;
    private float height = -1;
    private int tintColor = -1;

    public SpriteRenderer() {
    }

    public SpriteRenderer(Texture texture) {
        this.texture = texture;
    }

    /** @deprecated Use SpriteRenderer(Texture) instead. */
    @Deprecated
    public SpriteRenderer(PImage image) {
        this.image = image;
    }

    @Override
    public void start() {
        Logger.debug("SpriteRenderer started for " + getGameObject().getName());
    }

    @Override
    public void render(IRenderer renderer) {
        if (!enabled) return;

        Texture tex = resolveTexture();
        if (tex == null && image == null) {
            return;
        }

        Transform transform = getTransform();

        if (tex != null) {
            float w = width > 0 ? width : tex.getWidth();
            float h = height > 0 ? height : tex.getHeight();
            renderer.setTransform(transform);
            if (tintColor != -1) {
                renderer.setColor(tintColor);
            }
            tex.draw(renderer, 0, 0, w, h);
            renderer.resetTransform();
        } else {
            float w = width > 0 ? width : image.width;
            float h = height > 0 ? height : image.height;
            renderer.setTransform(transform);
            if (tintColor != -1) {
                renderer.setColor(tintColor);
            }
            renderer.drawImage(image, 0, 0, w, h);
            renderer.resetTransform();
        }
    }

    private Texture resolveTexture() {
        if (texture != null) return texture;
        if (textureKey != null && P5Engine.isInitialized()) {
            texture = P5Engine.getInstance().getImages().get(textureKey);
            if (texture != null) {
                textureKey = null; // resolved
            }
        }
        return texture;
    }

    public Texture getTexture() {
        return resolveTexture();
    }

    public void setTexture(Texture texture) {
        this.texture = texture;
        this.textureKey = null;
    }

    public void setTexture(String key) {
        this.textureKey = key;
        this.texture = null;
    }

    public void setRegion(int x, int y, int w, int h) {
        Texture base = resolveTexture();
        if (base != null) {
            this.texture = base.getRegion(x, y, w, h);
        }
    }

    /** @deprecated Use getTexture() instead. */
    @Deprecated
    public PImage getImage() {
        return image;
    }

    /** @deprecated Use setTexture() instead. */
    @Deprecated
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
