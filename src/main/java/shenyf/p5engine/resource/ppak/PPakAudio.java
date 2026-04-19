package shenyf.p5engine.resource.ppak;

import java.io.*;
import java.util.*;

public class PPakAudio {
    private static class AudioCacheEntry {
        byte[] data;
        long accessTime;

        AudioCacheEntry(byte[] d, long time) {
            this.data = d;
            this.accessTime = time;
        }
    }

    private static LinkedHashMap<String, AudioCacheEntry> _cache;
    private static final int MAX_CACHE_SIZE = 32;
    private static final long MAX_MEMORY_CACHE_SIZE = 100 * 1024 * 1024; // 100MB
    private static long _totalMemory;

    static {
        _cache = new LinkedHashMap<>(16, 0.75f, true);
        _totalMemory = 0;
    }

    public static byte[] loadAudioBytes(PPakDecoder decoder, String path) {
        return loadAudioBytes(decoder, path, null);
    }

    public static byte[] loadAudioBytes(PPakDecoder decoder, String path, String fallbackPath) {
        if (decoder == null || !decoder.isValid()) {
            System.err.println("[PPakAudio] Decoder is invalid");
            return null;
        }

        String cacheKey = "audio:" + normalizePath(path);

        byte[] cached = getFromCache(cacheKey);
        if (cached != null) {
            return cached;
        }

        byte[] audioData = decoder.read(path);
        if (audioData == null && fallbackPath != null) {
            audioData = decoder.read(fallbackPath);
            if (audioData != null) {
                cacheKey = "audio:" + normalizePath(fallbackPath);
            }
        }

        if (audioData == null) {
            System.err.println("[PPakAudio] Audio not found in PPAK: " + path);
            return null;
        }

        addToCache(cacheKey, audioData);
        return audioData;
    }

    public static byte[] loadSampleBytes(PPakDecoder decoder, String path) {
        return loadSampleBytes(decoder, path, null);
    }

    public static byte[] loadSampleBytes(PPakDecoder decoder, String path, String fallbackPath) {
        if (decoder == null || !decoder.isValid()) {
            System.err.println("[PPakAudio] Decoder is invalid");
            return null;
        }

        String cacheKey = "sample:" + normalizePath(path);

        byte[] cached = getFromCache(cacheKey);
        if (cached != null) {
            return cached;
        }

        byte[] sampleData = decoder.read(path);
        if (sampleData == null && fallbackPath != null) {
            sampleData = decoder.read(fallbackPath);
            if (sampleData != null) {
                cacheKey = "sample:" + normalizePath(fallbackPath);
            }
        }

        if (sampleData == null) {
            System.err.println("[PPakAudio] Sample not found in PPAK: " + path);
            return null;
        }

        addToCache(cacheKey, sampleData);
        return sampleData;
    }

    public static String saveToTempFile(PPakDecoder decoder, String path, String suffix) {
        return saveToTempFile(decoder, path, suffix, null);
    }

    public static String saveToTempFile(PPakDecoder decoder, String path, String suffix, String fallbackPath) {
        byte[] data = loadAudioBytes(decoder, path, fallbackPath);
        if (data == null) {
            data = loadSampleBytes(decoder, path, fallbackPath);
        }
        if (data == null) {
            return null;
        }

        String ext = getExtension(path);
        String tmpFile = tempFilePath(suffix + "." + ext);

        FileOutputStream fos = null;
        try {
            fos = new FileOutputStream(tmpFile);
            fos.write(data);
            fos.close();
            return tmpFile;
        } catch (Exception e) {
            System.err.println("[PPakAudio] Failed to save temp file: " + e.getMessage());
            if (fos != null) {
                try { fos.close(); } catch (Exception ignored) {}
            }
            new File(tmpFile).delete();
            return null;
        }
    }

    public static void clearCache() {
        synchronized (_cache) {
            _cache.clear();
            _totalMemory = 0;
        }
    }

    public static long cacheMemorySize() {
        return _totalMemory;
    }

    private static byte[] getFromCache(String key) {
        synchronized (_cache) {
            AudioCacheEntry entry = _cache.get(key);
            if (entry != null) {
                entry.accessTime = System.currentTimeMillis();
                return entry.data;
            }
        }
        return null;
    }

    private static void addToCache(String key, byte[] data) {
        synchronized (_cache) {
            if (_cache.containsKey(key)) {
                AudioCacheEntry old = _cache.remove(key);
                if (old != null) {
                    _totalMemory -= old.data.length;
                }
            }

            while (_cache.size() >= MAX_CACHE_SIZE || (_totalMemory + data.length > MAX_MEMORY_CACHE_SIZE)) {
                if (_cache.isEmpty()) break;
                String oldestKey = _cache.keySet().iterator().next();
                AudioCacheEntry removed = _cache.remove(oldestKey);
                if (removed != null) {
                    _totalMemory -= removed.data.length;
                }
            }

            _cache.put(key, new AudioCacheEntry(data, System.currentTimeMillis()));
            _totalMemory += data.length;
        }
    }

    private static String normalizePath(String path) {
        if (path == null) return "";
        return path.replace("\\", "/");
    }

    private static String getExtension(String path) {
        if (path == null || path.isEmpty()) return "mp3";
        int lastDot = path.lastIndexOf('.');
        if (lastDot < 0) return "mp3";
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