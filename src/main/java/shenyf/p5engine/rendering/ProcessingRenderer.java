package shenyf.p5engine.rendering;

import processing.core.PApplet;
import processing.core.PGraphics;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Transform;
import shenyf.p5engine.util.Logger;

public class ProcessingRenderer implements IRenderer {
    private final PApplet applet;
    private PGraphics graphics;
    private int width;
    private int height;

    public ProcessingRenderer(PApplet applet, int width, int height) {
        this.applet = applet;
        this.width = width;
        this.height = height;
    }

    @Override
    public void initialize() {
        this.graphics = applet.g;
        Logger.debug("ProcessingRenderer initialized");
    }

    @Override
    public void clear(int color) {
        graphics.background(color);
    }

    @Override
    public void drawImage(processing.core.PImage image, float x, float y, float w, float h) {
        graphics.image(image, x, y, w, h);
    }

    @Override
    public void setTransform(Transform transform) {
        graphics.push();
        Vector2 pos = transform.getPosition();
        graphics.translate(pos.x, pos.y);
        graphics.rotate(transform.getRotation());
        Vector2 scale = transform.getScale();
        graphics.scale(scale.x, scale.y);
    }

    @Override
    public void resetTransform() {
        graphics.pop();
    }

    @Override
    public void setColor(int color) {
        graphics.tint(color);
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
        return graphics;
    }

    public PApplet getApplet() {
        return applet;
    }

    public void syncSizeFromApplet() {
        if (applet == null) {
            return;
        }
        this.width = applet.width;
        this.height = applet.height;
    }
}
