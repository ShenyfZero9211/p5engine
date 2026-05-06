package shenyf.p5engine.rendering;

import processing.core.PApplet;
import processing.core.PImage;
import shenyf.p5engine.resource.ppak.PPakImage;
import shenyf.p5engine.util.Logger;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Global image resource manager. Provides LRU caching, preload, and unified
 * loading from file system (data/) or PPak archives.
 *
 * <p>Usage:
 * <pre>
 *   Texture tex = engine.getImages().load("sprites/player.png");
 *   Texture region = tex.getRegion(32, 0, 32, 32);
 * </pre>
 */
public class ImageManager {
    private final PApplet applet;
    private final Map<String, Texture> cache = new LinkedHashMap<String, Texture>(16, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, Texture> eldest) {
            if (currentMemory > maxMemory && !cache.isEmpty()) {
                Texture evicted = eldest.getValue();
                currentMemory -= estimateMemory(evicted);
                Logger.debug("ImageManager", "Evicted: " + eldest.getKey());
                return true;
            }
            return false;
        }
    };

    private long maxMemory = 64 * 1024 * 1024; // 64MB default
    private long currentMemory = 0;

    public ImageManager(PApplet applet) {
        this.applet = applet;
    }

    public void setMaxMemory(long bytes) {
        this.maxMemory = bytes;
    }

    public long getMaxMemory() {
        return maxMemory;
    }

    public long getCurrentMemory() {
        return currentMemory;
    }

    /** Load from the sketch's data/ folder. */
    public Texture load(String path) {
        String key = normalizeKey(path);
        Texture cached = cache.get(key);
        if (cached != null) return cached;

        PImage img = applet.loadImage(path);
        if (img == null) {
            Logger.warn("ImageManager: failed to load " + path);
            return null;
        }
        return addToCache(key, img);
    }

    /** Load from a PPak archive. */
    public Texture load(String path, shenyf.p5engine.resource.ppak.PPakDecoder decoder) {
        String key = "ppak:" + normalizeKey(path);
        Texture cached = cache.get(key);
        if (cached != null) return cached;

        PImage img = PPakImage.load(applet, decoder, path);
        if (img == null) {
            Logger.warn("ImageManager: failed to load " + path + " from PPak");
            return null;
        }
        return addToCache(key, img);
    }

    /** Get a cached texture by key. */
    public Texture get(String key) {
        return cache.get(normalizeKey(key));
    }

    /** Preload multiple images into cache. */
    public void preload(String... paths) {
        for (String path : paths) {
            load(path);
        }
    }

    /** Remove a texture from cache. */
    public void unload(String key) {
        Texture removed = cache.remove(normalizeKey(key));
        if (removed != null) {
            currentMemory -= estimateMemory(removed);
        }
    }

    /** Clear all cached textures. */
    public void clear() {
        cache.clear();
        currentMemory = 0;
    }

    private Texture addToCache(String key, PImage img) {
        Texture tex = new Texture(img, key);
        currentMemory += estimateMemory(tex);
        cache.put(key, tex);
        Logger.debug("ImageManager", "Loaded: " + key + " (" + img.width + "x" + img.height + ")");
        return tex;
    }

    private static long estimateMemory(Texture tex) {
        PImage img = tex.getImage();
        return (long) img.width * img.height * 4;
    }

    private static String normalizeKey(String path) {
        if (path == null) return "";
        return path.replace('\\', '/');
    }
}
