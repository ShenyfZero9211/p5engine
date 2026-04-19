package shenyf.p5engine.resource.ppak;

import java.io.*;
import java.util.*;
import processing.core.*;

public class PPakImage {
    private static class CacheEntry {
        PImage image;
        long accessTime;
        int pixelCount;

        CacheEntry(PImage img, long time) {
            this.image = img;
            this.accessTime = time;
            this.pixelCount = img.width * img.height;
        }

        long memorySize() {
            return pixelCount * 4L;
        }
    }

    private static LinkedHashMap<String, CacheEntry> _cache;
    private static long _totalMemory;
    private static final long MAX_MEMORY = PPakConstants.MAX_MEMORY_CACHE_SIZE;
    private static final int MAX_ITEMS = PPakConstants.MAX_IMAGE_CACHE_SIZE;

    static {
        _cache = new LinkedHashMap<>(16, 0.75f, true);
        _totalMemory = 0;
    }

    public static PImage load(PApplet parent, PPakDecoder decoder, String path) {
        return load(parent, decoder, path, null);
    }

    public static PImage load(PApplet parent, PPakDecoder decoder, String path, String fallbackPath) {
        if (decoder == null || !decoder.isValid()) {
            System.err.println("[PPakImage] Decoder is invalid");
            return createPlaceholder(parent);
        }

        String cacheKey = normalizePath(path);

        PImage cached = getFromCache(cacheKey);
        if (cached != null) {
            return cached;
        }

        byte[] imgData = decoder.read(path);
        if (imgData == null && fallbackPath != null) {
            imgData = decoder.read(fallbackPath);
            if (imgData != null) {
                cacheKey = normalizePath(fallbackPath);
            }
        }
        if (imgData == null) {
            System.err.println("[PPakImage] File not found in PPAK: " + path);
            return createPlaceholder(parent);
        }

        String ext = getExtension(path.isEmpty() ? fallbackPath : path);
        String tmpFile = tempFilePath("_img_" + cacheKey.hashCode() + "." + ext);

        PImage img = null;
        try {
            parent.saveBytes(tmpFile, imgData);
            img = parent.loadImage(tmpFile);
            new File(tmpFile).delete();

            if (img != null) {
                addToCache(cacheKey, img);
            }

            return img;

        } catch (Exception e) {
            System.err.println("[PPakImage] Load error: " + e.getMessage());
            new File(tmpFile).delete();
            return createPlaceholder(parent);
        }
    }

    public static PImage loadFromFile(PApplet parent, String filePath) {
        if (filePath == null || filePath.isEmpty()) {
            return createPlaceholder(parent);
        }

        String cacheKey = "file:" + normalizePath(filePath);

        PImage cached = getFromCache(cacheKey);
        if (cached != null) {
            return cached;
        }

        try {
            PImage img = parent.loadImage(filePath);
            if (img != null) {
                addToCache(cacheKey, img);
            }
            return img;
        } catch (Exception e) {
            System.err.println("[PPakImage] Load file error: " + e.getMessage());
            return createPlaceholder(parent);
        }
    }

    public static void preload(PApplet parent, PPakDecoder decoder, String path) {
        load(parent, decoder, path);
    }

    public static void preload(PApplet parent, PPakDecoder decoder, String[] paths) {
        for (String p : paths) {
            load(parent, decoder, p);
        }
    }

    public static void clearCache() {
        _cache.clear();
        _totalMemory = 0;
    }

    public static long cacheMemorySize() {
        return _totalMemory;
    }

    private static PImage getFromCache(String key) {
        synchronized (_cache) {
            CacheEntry entry = _cache.get(key);
            if (entry != null) {
                entry.accessTime = System.currentTimeMillis();
                return entry.image;
            }
        }
        return null;
    }

    private static void addToCache(String key, PImage img) {
        synchronized (_cache) {
            if (_cache.containsKey(key)) {
                CacheEntry old = _cache.get(key);
                _totalMemory -= old.memorySize();
                _cache.remove(key);
            }

            while (_cache.size() >= MAX_ITEMS || (_totalMemory + img.width * img.height * 4 > MAX_MEMORY)) {
                if (_cache.isEmpty()) break;
                String oldestKey = _cache.keySet().iterator().next();
                CacheEntry removed = _cache.remove(oldestKey);
                if (removed != null) {
                    _totalMemory -= removed.memorySize();
                }
            }

            _cache.put(key, new CacheEntry(img, System.currentTimeMillis()));
            _totalMemory += img.width * img.height * 4;
        }
    }

    private static PImage createPlaceholder(processing.core.PApplet parent) {
        return parent.createImage(1, 1, processing.core.PConstants.ARGB);
    }

    private static String normalizePath(String path) {
        if (path == null) return "";
        return path.replace("\\", "/");
    }

    private static String getExtension(String path) {
        if (path == null || path.isEmpty()) return "png";
        int lastDot = path.lastIndexOf('.');
        if (lastDot < 0) return "png";
        return path.substring(lastDot + 1).toLowerCase();
    }

    private static String tempFilePath(String suffix) {
        String tmpDir = System.getProperty("java.io.tmpdir");
        if (!tmpDir.endsWith(File.separator)) {
            tmpDir += File.separator;
        }
        return tmpDir + PPakConstants.TEMP_FILE_PREFIX + System.currentTimeMillis() + "_" +
               (int) (Math.random() * 10000) + suffix;
    }
}