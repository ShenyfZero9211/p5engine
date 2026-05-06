package shenyf.p5engine.rendering;

/**
 * Defines a layer group for parallax rendering.
 * All renderable objects with renderLayer within [layerMin, layerMax] will be rendered
 * with the specified parallax coefficients.
 */
public class LayerGroup {
    public final int layerMin;
    public final int layerMax;
    public final float parallaxX;
    public final float parallaxY;

    public LayerGroup(int layerMin, int layerMax, float parallaxX, float parallaxY) {
        this.layerMin = layerMin;
        this.layerMax = layerMax;
        this.parallaxX = parallaxX;
        this.parallaxY = parallaxY;
    }

    public boolean contains(int layer) {
        return layer >= layerMin && layer <= layerMax;
    }
}
