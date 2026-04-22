package shenyf.p5engine.rendering;

import processing.core.PApplet;
import processing.core.PImage;
import processing.data.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * Loads a texture atlas (single large image + JSON descriptor)
 * and provides cropped sub-images by name.
 *
 * <p>Use tools like FreeTexturePacker or TexturePacker to generate
 * the atlas image and JSON from individual sprite files.</p>
 */
public class TextureAtlas {

    public static class Region {
        public final String name;
        public final int x;
        public final int y;
        public final int width;
        public final int height;

        public Region(String name, int x, int y, int width, int height) {
            this.name = name;
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }

    private final PImage atlasImage;
    private final Map<String, Region> regions = new HashMap<>();

    /**
     * Load an atlas from an image and a JSON descriptor.
     *
     * @param applet    the PApplet for loading resources
     * @param imagePath path to the atlas image (e.g. "data/atlas.png")
     * @param jsonPath  path to the atlas JSON (e.g. "data/atlas.json")
     */
    public TextureAtlas(PApplet applet, String imagePath, String jsonPath) {
        this.atlasImage = applet.loadImage(imagePath);
        loadJson(applet, jsonPath);
    }

    private void loadJson(PApplet applet, String jsonPath) {
        JSONObject json = applet.loadJSONObject(jsonPath);
        if (json == null || !json.hasKey("frames")) return;
        JSONObject frames = json.getJSONObject("frames");
        for (Object keyObj : frames.keys()) {
            String name = (String) keyObj;
            JSONObject frame = frames.getJSONObject(name);
            JSONObject rect = frame.getJSONObject("frame");
            int x = rect.getInt("x", 0);
            int y = rect.getInt("y", 0);
            int w = rect.getInt("w", 0);
            int h = rect.getInt("h", 0);
            regions.put(name, new Region(name, x, y, w, h));
        }
    }

    /** Get a region descriptor by name. */
    public Region getRegion(String name) {
        return regions.get(name);
    }

    /**
     * Get a cropped PImage for the named region.
     * Returns a copy (sub-image); safe to modify/tint independently.
     */
    public PImage get(String name) {
        Region r = regions.get(name);
        if (r == null || atlasImage == null) return null;
        return atlasImage.get(r.x, r.y, r.width, r.height);
    }

    /** Returns true if the atlas contains the named region. */
    public boolean has(String name) {
        return regions.containsKey(name);
    }

    public PImage getAtlasImage() {
        return atlasImage;
    }

    public int getRegionCount() {
        return regions.size();
    }
}
