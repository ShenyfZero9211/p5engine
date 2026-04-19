package shenyf.p5engine.resource.ppak;

import java.io.*;
import java.util.*;
import processing.core.*;

public class PPakFont {
    private static class FontCacheEntry {
        PFont font;
        long accessTime;

        FontCacheEntry(PFont f, long time) {
            this.font = f;
            this.accessTime = time;
        }
    }

    private static LinkedHashMap<String, FontCacheEntry> _cache;
    private static final int MAX_CACHE_SIZE = PPakConstants.MAX_FONT_CACHE_SIZE;

    static {
        _cache = new LinkedHashMap<>(16, 0.75f, true);
    }

    public static PFont load(PApplet parent, PPakDecoder decoder, String path, float size) {
        return load(parent, decoder, path, size, null);
    }

    public static PFont load(PApplet parent, PPakDecoder decoder, String path, float size, String fallbackPath) {
        if (decoder == null || !decoder.isValid()) {
            System.err.println("[PPakFont] Decoder is invalid");
            return createDefaultFont(parent, size);
        }

        String cacheKey = normalizePath(path) + "@" + (int) size;

        PFont cached = getFromCache(cacheKey);
        if (cached != null) {
            return cached;
        }

        byte[] fontData = decoder.read(path);
        if (fontData == null && fallbackPath != null) {
            fontData = decoder.read(fallbackPath);
            if (fontData != null) {
                cacheKey = normalizePath(fallbackPath) + "@" + (int) size;
            }
        }
        if (fontData == null) {
            System.err.println("[PPakFont] Font not found in PPAK: " + path);
            return createDefaultFont(parent, size);
        }

        String tmpFile = tempFilePath("_font_" + cacheKey.hashCode() + ".ttf");

        try {
            parent.saveBytes(tmpFile, fontData);
            PFont font = parent.createFont(tmpFile, size);
            new File(tmpFile).delete();

            if (font != null) {
                addToCache(cacheKey, font);
            }

            return font;

        } catch (Exception e) {
            System.err.println("[PPakFont] Load error: " + e.getMessage());
            new File(tmpFile).delete();
            return createDefaultFont(parent, size);
        }
    }

    public static PFont loadFromFile(PApplet parent, String filePath, float size) {
        if (filePath == null || filePath.isEmpty()) {
            return createDefaultFont(parent, size);
        }

        String cacheKey = "file:" + normalizePath(filePath) + "@" + (int) size;

        PFont cached = getFromCache(cacheKey);
        if (cached != null) {
            return cached;
        }

        try {
            PFont font = parent.createFont(filePath, size);
            if (font != null) {
                addToCache(cacheKey, font);
            }
            return font;
        } catch (Exception e) {
            System.err.println("[PPakFont] Load file error: " + e.getMessage());
            return createDefaultFont(parent, size);
        }
    }

    public static void clearCache() {
        _cache.clear();
    }

    private static PFont getFromCache(String key) {
        synchronized (_cache) {
            FontCacheEntry entry = _cache.get(key);
            if (entry != null) {
                entry.accessTime = System.currentTimeMillis();
                return entry.font;
            }
        }
        return null;
    }

    private static void addToCache(String key, PFont font) {
        synchronized (_cache) {
            if (_cache.size() >= MAX_CACHE_SIZE) {
                String oldestKey = _cache.keySet().iterator().next();
                _cache.remove(oldestKey);
            }
            _cache.put(key, new FontCacheEntry(font, System.currentTimeMillis()));
        }
    }

    private static PFont createDefaultFont(PApplet parent, float size) {
        try {
            return parent.createFont("Arial", (int) size);
        } catch (Exception e) {
            return null;
        }
    }

    private static String normalizePath(String path) {
        if (path == null) return "";
        return path.replace("\\", "/");
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