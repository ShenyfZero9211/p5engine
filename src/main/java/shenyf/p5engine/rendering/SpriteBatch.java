package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import processing.core.PImage;
import processing.core.PShape;

/**
 * A sprite batch for reducing draw calls when rendering many sprites
 * that share the same texture (e.g. particles, tilemaps).
 *
 * <p>Usage:
 * <pre>
 *   batch.begin(g);
 *   batch.draw(tex, x1, y1, w, h);
 *   batch.draw(tex, x2, y2, w, h);
 *   batch.end();
 * </pre>
 *
 * <p>Limitations: Processing PShape texture support is basic; rotation and
 * per-sprite alpha require falling back to individual image() calls.</p>
 */
public class SpriteBatch {

    private PGraphics g;
    private PImage currentTexture;
    private PShape shape;
    private int count = 0;
    private static final int MAX_BATCH = 500;

    public void begin(PGraphics g) {
        this.g = g;
        this.currentTexture = null;
        this.count = 0;
        this.shape = null;
    }

    public void draw(PImage texture, float x, float y, float w, float h) {
        if (texture != currentTexture) {
            flush();
            currentTexture = texture;
            shape = g.createShape();
            shape.beginShape(PShape.QUADS);
            shape.noStroke();
            shape.texture(currentTexture);
        }
        if (count >= MAX_BATCH) {
            flush();
            shape = g.createShape();
            shape.beginShape(PShape.QUADS);
            shape.noStroke();
            shape.texture(currentTexture);
            count = 0;
        }

        // Quad vertices with UVs
        shape.vertex(x, y, 0, 0);
        shape.vertex(x + w, y, 1, 0);
        shape.vertex(x + w, y + h, 1, 1);
        shape.vertex(x, y + h, 0, 1);
        count++;
    }

    public void end() {
        flush();
        g = null;
        currentTexture = null;
    }

    private void flush() {
        if (shape != null && count > 0) {
            shape.endShape();
            g.shape(shape);
        }
        shape = null;
        count = 0;
    }
}
