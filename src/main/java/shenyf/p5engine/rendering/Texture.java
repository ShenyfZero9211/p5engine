package shenyf.p5engine.rendering;

import processing.core.PImage;

/**
 * Engine-level texture abstraction. Wraps a PImage with optional sub-region cropping.
 * Regions share the same PImage reference (no pixel copy) for high performance.
 */
public class Texture {
    private final PImage image;
    private final String key;
    private final int width;
    private final int height;
    private final int sx, sy, sw, sh;
    private final boolean flipX;
    private final boolean flipY;

    public Texture(PImage image, String key) {
        this(image, key, image.width, image.height, 0, 0, image.width, image.height, false, false);
    }

    private Texture(PImage image, String key, int width, int height,
                    int sx, int sy, int sw, int sh,
                    boolean flipX, boolean flipY) {
        this.image = image;
        this.key = key;
        this.width = width;
        this.height = height;
        this.sx = sx;
        this.sy = sy;
        this.sw = sw;
        this.sh = sh;
        this.flipX = flipX;
        this.flipY = flipY;
    }

    public PImage getImage() {
        return image;
    }

    public String getKey() {
        return key;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public boolean isFlipX() {
        return flipX;
    }

    public boolean isFlipY() {
        return flipY;
    }

    /**
     * Returns a new Texture representing a sub-region of this texture.
     * Shares the same underlying PImage (no pixel copy).
     */
    public Texture getRegion(int x, int y, int w, int h) {
        int srcX = this.sx + x;
        int srcY = this.sy + y;
        return new Texture(image, key + "[" + x + "," + y + "," + w + "," + h + "]",
            w, h, srcX, srcY, w, h, flipX, flipY);
    }

    public Texture withFlip(boolean flipX, boolean flipY) {
        return new Texture(image, key, width, height, sx, sy, sw, sh, flipX, flipY);
    }

    public void draw(IRenderer renderer, float x, float y) {
        draw(renderer, x, y, width, height);
    }

    public void draw(IRenderer renderer, float x, float y, float w, float h) {
        int u1 = sx;
        int v1 = sy;
        int u2 = sx + sw;
        int v2 = sy + sh;

        if (flipX) {
            int tmp = u1;
            u1 = u2;
            u2 = tmp;
        }
        if (flipY) {
            int tmp = v1;
            v1 = v2;
            v2 = tmp;
        }

        renderer.drawImage(image, x, y, w, h, u1, v1, u2, v2);
    }
}
