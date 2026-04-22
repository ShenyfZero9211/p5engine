package shenyf.p5engine.rendering;

import processing.core.PGraphics;
import shenyf.p5engine.scene.Transform;

public interface IRenderer {
    void initialize();

    void clear(int color);

    void drawImage(processing.core.PImage image, float x, float y, float w, float h);

    void setTransform(Transform transform);

    void resetTransform();

    void pushTransform();

    void popTransform();

    void translate(float x, float y);

    void rotate(float angle);

    void scale(float x, float y);

    void setColor(int color);

    int getWidth();

    int getHeight();

    PGraphics getGraphics();
}
