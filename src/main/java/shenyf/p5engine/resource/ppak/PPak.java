package shenyf.p5engine.resource.ppak;

import java.io.*;
import java.util.*;
import processing.core.*;

public class PPak {
    private static PPak _instance;

    private PPakDecoder _decoder;
    private PApplet _parent;
    private String _ppakPath;
    private String _sketchPath;
    private boolean _ready;

    private PPak() {
        _decoder = null;
        _parent = null;
        _ppakPath = null;
        _sketchPath = null;
        _ready = false;
    }

    public static PPak getInstance() {
        if (_instance == null) {
            _instance = new PPak();
        }
        return _instance;
    }

    public static void reset() {
        if (_instance != null) {
            _instance.cleanup();
        }
        _instance = new PPak();
    }

    public void init(PApplet parent) {
        init(parent, PPakConstants.DEFAULT_PPAK_FILENAME);
    }

    public void init(PApplet parent, String ppakFilename) {
        if (parent == null) {
            System.err.println("[PPak] PApplet is null");
            return;
        }

        cleanupOldTempFiles();
        cleanup();

        _parent = parent;
        _sketchPath = resolveSketchPath(parent.sketchPath());

        File ppakFile = null;
        String foundPath = null;

        if (new File(ppakFilename).isAbsolute()) {
            ppakFile = new File(ppakFilename);
        } else {
            File dataSubDir = new File(_sketchPath + File.separator + "data" + File.separator + ppakFilename);
            if (dataSubDir.exists()) {
                ppakFile = dataSubDir;
                foundPath = dataSubDir.getAbsolutePath();
            } else {
                File rootFile = new File(_sketchPath + File.separator + ppakFilename);
                if (rootFile.exists()) {
                    ppakFile = rootFile;
                    foundPath = rootFile.getAbsolutePath();
                }
            }
        }

        if (ppakFile != null && ppakFile.exists()) {
            _ppakPath = foundPath != null ? foundPath : ppakFile.getAbsolutePath();
            _decoder = new PPakDecoder(_ppakPath);
            _ready = _decoder.isValid();
            if (_ready) {
                System.out.println("[PPak] Initialized with PPAK: " + _ppakPath + " (" + _decoder.count() + " files)");
            } else {
                System.err.println("[PPak] Failed to parse PPAK: " + _ppakPath);
            }
        } else {
            System.out.println("[PPak] PPAK not found (checked: sketch/data/ and sketch root) (will use data/ fallback)");
            _ppakPath = null;
            _ready = false;
        }
    }

    public void initPath(String ppakPath) {
        if (_parent == null) {
            System.err.println("[PPak] Call init(PApplet) first");
            return;
        }

        if (_ready) {
            cleanup();
        }

        File ppakFile = new File(ppakPath);
        if (!ppakFile.exists()) {
            System.err.println("[PPak] PPAK file not found: " + ppakPath);
            return;
        }

        _ppakPath = ppakFile.getAbsolutePath();
        _decoder = new PPakDecoder(_ppakPath);
        _ready = _decoder.isValid();

        if (_ready) {
            System.out.println("[PPak] Initialized with PPAK: " + _ppakPath + " (" + _decoder.count() + " files)");
        } else {
            System.err.println("[PPak] Failed to parse PPAK: " + _ppakPath);
        }
    }

    public boolean isReady() {
        return _ready && _decoder != null && _decoder.isValid();
    }

    public boolean hasDecoder() {
        return _decoder != null && _decoder.isValid();
    }

    public PPakDecoder decoder() {
        return _decoder;
    }

    public String getPath() {
        return _ppakPath;
    }

    public String getSketchPath() {
        return _sketchPath;
    }

    public int count() {
        if (_decoder != null && _decoder.isValid()) {
            return _decoder.count();
        }
        return 0;
    }

    public String[] list() {
        if (_decoder != null && _decoder.isValid()) {
            return _decoder.list();
        }
        return new String[0];
    }

    public boolean contains(String path) {
        if (_decoder != null && _decoder.isValid() && _decoder.contains(path)) {
            return true;
        }
        String fallbackPath = toFallbackPath(path);
        File fallbackFile = new File(_sketchPath + File.separator + fallbackPath);
        return fallbackFile.exists();
    }

    public byte[] read(String path) {
        if (_decoder != null && _decoder.isValid()) {
            byte[] data = _decoder.read(path);
            if (data != null) {
                return data;
            }
        }
        String fallbackPath = toFallbackPath(path);
        return readFileFromSketch(fallbackPath);
    }

    public PImage image(String path) {
        return image(path, null);
    }

    public PImage image(String path, String fallbackPath) {
        if (!hasDecoder()) {
            return PPakImage.loadFromFile(_parent, toSketchDataPath(path));
        }

        PImage img = PPakImage.load(_parent, _decoder, path, fallbackPath != null ? toFallbackPath(fallbackPath) : null);
        if (img == null || (img.width == 1 && img.height == 1)) {
            String fp = fallbackPath != null ? fallbackPath : path;
            return PPakImage.loadFromFile(_parent, toSketchDataPath(fp));
        }
        return img;
    }

    public PFont font(String path, float size) {
        return font(path, size, null);
    }

    public PFont font(String path, float size, String fallbackPath) {
        if (!hasDecoder()) {
            return PPakFont.loadFromFile(_parent, toSketchDataPath(path), size);
        }

        PFont font = PPakFont.load(_parent, _decoder, path, size, fallbackPath != null ? toFallbackPath(fallbackPath) : null);
        if (font == null) {
            String fp = fallbackPath != null ? fallbackPath : path;
            return PPakFont.loadFromFile(_parent, toSketchDataPath(fp), size);
        }
        return font;
    }

    public byte[] audioBytes(String path) {
        return audioBytes(path, null);
    }

    public byte[] audioBytes(String path, String fallbackPath) {
        if (!hasDecoder()) {
            return readFileFromSketch(toFallbackPath(path));
        }

        byte[] data = PPakAudio.loadAudioBytes(_decoder, path, fallbackPath != null ? toFallbackPath(fallbackPath) : null);
        if (data == null) {
            return readFileFromSketch(toFallbackPath(fallbackPath != null ? fallbackPath : path));
        }
        return data;
    }

    public byte[] sampleBytes(String path) {
        return sampleBytes(path, null);
    }

    public byte[] sampleBytes(String path, String fallbackPath) {
        if (!hasDecoder()) {
            return readFileFromSketch(toFallbackPath(path));
        }

        byte[] data = PPakAudio.loadSampleBytes(_decoder, path, fallbackPath != null ? toFallbackPath(fallbackPath) : null);
        if (data == null) {
            return readFileFromSketch(toFallbackPath(fallbackPath != null ? fallbackPath : path));
        }
        return data;
    }

    public String audioFile(String path) {
        return audioFile(path, null);
    }

    public String audioFile(String path, String fallbackPath) {
        if (!hasDecoder()) {
            String filePath = toSketchDataPath(fallbackPath != null ? fallbackPath : path);
            if (new File(filePath).exists()) {
                return filePath;
            }
            return null;
        }

        String tmpFile = PPakAudio.saveToTempFile(_decoder, path, "_audio", fallbackPath != null ? toFallbackPath(fallbackPath) : null);
        if (tmpFile == null) {
            String fp = toSketchDataPath(fallbackPath != null ? fallbackPath : path);
            if (new File(fp).exists()) {
                return fp;
            }
            return null;
        }
        return tmpFile;
    }

    public String sampleFile(String path) {
        return sampleFile(path, null);
    }

    public String sampleFile(String path, String fallbackPath) {
        if (!hasDecoder()) {
            String filePath = toSketchDataPath(fallbackPath != null ? fallbackPath : path);
            if (new File(filePath).exists()) {
                return filePath;
            }
            return null;
        }

        String tmpFile = PPakAudio.saveToTempFile(_decoder, path, "_sample", fallbackPath != null ? toFallbackPath(fallbackPath) : null);
        if (tmpFile == null) {
            String fp = toSketchDataPath(fallbackPath != null ? fallbackPath : path);
            if (new File(fp).exists()) {
                return fp;
            }
            return null;
        }
        return tmpFile;
    }

    public void preload(String path) {
        if (hasDecoder()) {
            PPakImage.preload(_parent, _decoder, path);
        }
    }

    public void preload(String[] paths) {
        if (hasDecoder()) {
            PPakImage.preload(_parent, _decoder, paths);
        }
    }

    public String moviePath(String path) {
        return moviePath(path, null);
    }

    public String moviePath(String path, String fallbackPath) {
        if (!hasDecoder()) {
            String filePath = toSketchDataPath(fallbackPath != null ? fallbackPath : path);
            if (new File(filePath).exists()) {
                return filePath;
            }
            return null;
        }

        byte[] videoData = _decoder.read(path);
        if (videoData == null && fallbackPath != null) {
            videoData = _decoder.read(toFallbackPath(fallbackPath));
        }

        if (videoData == null) {
            String filePath = toSketchDataPath(fallbackPath != null ? fallbackPath : path);
            if (new File(filePath).exists()) {
                return filePath;
            }
            return null;
        }

        String ext = getExtension(path);
        return PPakVideo.saveTempFile(videoData, ext);
    }

    public void disposeVideos() {
        PPakVideo.disposeAll();
    }

    public void clearCache() {
        PPakImage.clearCache();
        PPakFont.clearCache();
        PPakAudio.clearCache();
    }

    public void clearAudioCache() {
        PPakAudio.clearCache();
    }

    public long cacheMemorySize() {
        return PPakImage.cacheMemorySize() + PPakAudio.cacheMemorySize();
    }

    public void cleanup() {
        clearCache();
        clearTempFiles();
        disposeVideos();

        if (_decoder != null) {
            _decoder.close();
            _decoder = null;
        }

        _ready = false;
        _ppakPath = null;
    }

    public void cleanupOldTempFiles() {
        File tmpDir = new File(System.getProperty("java.io.tmpdir"));
        if (!tmpDir.exists() || !tmpDir.isDirectory()) {
            return;
        }

        File[] files = tmpDir.listFiles();
        if (files == null) {
            return;
        }

        int count = 0;
        for (File f : files) {
            if (f.isFile() && f.getName().startsWith(PPakConstants.TEMP_FILE_PREFIX)) {
                if (f.delete()) {
                    count++;
                }
            }
        }

        if (count > 0) {
            System.out.println("[PPak] Cleaned up " + count + " old temp files");
        }
    }

    public void clearTempFiles() {
        File tmpDir = new File(System.getProperty("java.io.tmpdir"));
        if (!tmpDir.exists() || !tmpDir.isDirectory()) {
            return;
        }

        File[] files = tmpDir.listFiles();
        if (files == null) {
            return;
        }

        int count = 0;
        for (File f : files) {
            if (f.isFile() && f.getName().startsWith(PPakConstants.TEMP_FILE_PREFIX)) {
                if (f.delete()) {
                    count++;
                }
            }
        }

        if (count > 0) {
            System.out.println("[PPak] Cleared " + count + " temp files");
        }
    }

    private String resolveSketchPath(String sketchPath) {
        if (sketchPath == null) return "";

        if (sketchPath.endsWith(".pde") || sketchPath.endsWith(".java")) {
            int sep = sketchPath.lastIndexOf(File.separator);
            if (sep > 0) {
                sketchPath = sketchPath.substring(0, sep);
            }
        }

        while (sketchPath.endsWith(File.separator)) {
            sketchPath = sketchPath.substring(0, sketchPath.length() - 1);
        }

        int lastSep = sketchPath.lastIndexOf(File.separator);
        if (lastSep > 0) {
            String parentName = sketchPath.substring(lastSep + 1);
            String grandParent = sketchPath.substring(0, lastSep);
            int prevSep = grandParent.lastIndexOf(File.separator);
            if (prevSep > 0) {
                String grandParentName = grandParent.substring(prevSep + 1);
                if (parentName.equals(grandParentName)) {
                    sketchPath = grandParent;
                }
            }
        }

        return sketchPath;
    }

    private String toFallbackPath(String path) {
        if (path == null) return null;
        String normalized = path.replace("\\", "/");
        if (normalized.startsWith("data/")) {
            return normalized;
        }
        return "data/" + normalized;
    }

    private String toSketchDataPath(String path) {
        if (path == null) return null;
        if (_sketchPath == null) return path;
        String normalized = path.replace("\\", "/");
        if (normalized.startsWith("data/")) {
            return _sketchPath + File.separator + normalized;
        }
        return _sketchPath + File.separator + "data" + File.separator + normalized;
    }

    private String getExtension(String path) {
        if (path == null || path.isEmpty()) return "mp4";
        int lastDot = path.lastIndexOf('.');
        if (lastDot < 0) return "mp4";
        return path.substring(lastDot + 1).toLowerCase();
    }

    private byte[] readFileFromSketch(String relativePath) {
        if (_sketchPath == null || relativePath == null) return null;
        File f = new File(_sketchPath + File.separator + relativePath);
        if (!f.exists()) return null;

        FileInputStream fis = null;
        try {
            fis = new FileInputStream(f);
            byte[] data = new byte[(int) f.length()];
            int read = 0;
            while (read < data.length) {
                int r = fis.read(data, read, data.length - read);
                if (r == -1) break;
                read += r;
            }
            fis.close();
            return data;
        } catch (Exception e) {
            System.err.println("[PPak] Error reading fallback file: " + e.getMessage());
            return null;
        } finally {
            if (fis != null) {
                try { fis.close(); } catch (Exception ignored) {}
            }
        }
    }
}