package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Transform;

/**
 * A lightweight IRenderer implementation that draws directly into a specified PGraphics buffer.
 * Used for off-screen rendering (e.g. WorldViewport) without polluting the main ProcessingRenderer.
 */
public class OffscreenRenderer implements IRenderer {
    private final PGraphics g;
    private final int width;
    private final int height;

    public OffscreenRenderer(PGraphics g, int width, int height) {
        this.g = g;
        this.width = width;
        this.height = height;
    }

    @Override
    public void initialize() {
    }

    @Override
    public void clear(int color) {
        g.background(color);
    }

    @Override
    public void drawImage(processing.core.PImage image, float x, float y, float w, float h) {
        g.image(image, x, y, w, h);
    }

    @Override
    public void setTransform(Transform transform) {
        g.pushMatrix();
        Vector2 pos = transform.getPosition();
        g.translate(pos.x, pos.y);
        g.rotate(transform.getRotation());
        Vector2 scale = transform.getScale();
        g.scale(scale.x, scale.y);
    }

    @Override
    public void resetTransform() {
        g.popMatrix();
    }

    @Override
    public void pushTransform() {
        g.pushMatrix();
    }

    @Override
    public void popTransform() {
        g.popMatrix();
    }

    @Override
    public void translate(float x, float y) {
        g.translate(x, y);
    }

    @Override
    public void rotate(float angle) {
        g.rotate(angle);
    }

    @Override
    public void scale(float x, float y) {
        g.scale(x, y);
    }

    @Override
    public void setColor(int color) {
        g.tint(color);
    }

    @Override
    public int getWidth() {
        return width;
    }

    @Override
    public int getHeight() {
        return height;
    }

    @Override
    public PGraphics getGraphics() {
        return g;
    }
}
