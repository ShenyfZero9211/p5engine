package shenyf.p5engine.config;

import processing.core.PApplet;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;

public class SketchConfig {

    public static final String FILE_NAME = "p5engine.ini";

    public static final String SECTION_P5ENGINE = "p5engine";
    public static final String SECTION_WINDOW = "window";
    public static final String SECTION_WINDOW_SIZE = "window_size";
    public static final String SECTION_CACHE = "cache";
    public static final String SECTION_SCRIPT = "script";
    public static final String SECTION_WINDOW_POSITION = "window_position";

    public static final String KEY_NAME = "name";
    public static final String KEY_VERSION = "version";
    public static final String KEY_DEBUG = "debug";
    public static final String KEY_SINGLE_INSTANCE = "single_instance";
    public static final String KEY_WIDTH = "width";
    public static final String KEY_HEIGHT = "height";
    public static final String KEY_TITLE = "title";
    public static final String KEY_MEMORY_MB = "memory_mb";
    public static final String KEY_CACHE_ENABLED = "enabled";
    public static final String KEY_LUA_PATH = "lua_path";
    public static final String KEY_HOT_RELOAD = "hot_reload";
    public static final String KEY_X = "x";
    public static final String KEY_Y = "y";

    private final Path configFile;
    private Map<String, String> data;
    private final PApplet applet;

    public SketchConfig(PApplet applet) {
        this.applet = applet;
        String basePath = getBasePath();
        this.configFile = Paths.get(basePath, FILE_NAME);
        load();
    }

    public SketchConfig(String configPath) {
        this.applet = null;
        this.configFile = Paths.get(configPath);
        load();
    }

    private String getBasePath() {
        String sketchPath = applet.sketchPath();
        if (sketchPath != null && Files.exists(Paths.get(sketchPath))) {
            return sketchPath;
        }
        return System.getProperty("user.dir");
    }

    private void load() {
        if (Files.exists(configFile)) {
            data = IniParser.parse(configFile);
            String savedName = get(SECTION_P5ENGINE, KEY_NAME);
            if (savedName != null && !savedName.isEmpty()) {
                set(SECTION_P5ENGINE, KEY_NAME, savedName);
            }
        } else {
            data = new LinkedHashMap<>();
            createDefaultConfig();
        }
    }

    private String getDefaultSketchName() {
        String basePath = getBasePath();
        if (basePath != null) {
            Path path = Paths.get(basePath);
            String fileName = path.getFileName().toString();
            int dotIndex = fileName.lastIndexOf('.');
            return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
        }
        return "p5engine";
    }

    private void createDefaultConfig() {
        String sketchName = getDefaultSketchName();

        set(SECTION_P5ENGINE, KEY_NAME, sketchName);
        set(SECTION_P5ENGINE, KEY_VERSION, "0.1.0");
        set(SECTION_P5ENGINE, KEY_DEBUG, "true");
        set(SECTION_P5ENGINE, KEY_SINGLE_INSTANCE, "false");

        set(SECTION_WINDOW, KEY_TITLE, sketchName);

        set(SECTION_WINDOW_SIZE, KEY_WIDTH, "800");
        set(SECTION_WINDOW_SIZE, KEY_HEIGHT, "600");

        set(SECTION_CACHE, KEY_MEMORY_MB, "1024");
        set(SECTION_CACHE, KEY_CACHE_ENABLED, "true");

        set(SECTION_SCRIPT, KEY_LUA_PATH, "scripts/");
        set(SECTION_SCRIPT, KEY_HOT_RELOAD, "true");

        save();
    }

    public void save() {
        try {
            IniParser.write(configFile, data);
        } catch (IOException e) {
            System.err.println("[p5engine] Failed to save config: " + e.getMessage());
        }
    }

    public String get(String section, String key) {
        String fullKey = section + "." + key;
        return data.get(fullKey);
    }

    public String get(String section, String key, String defaultValue) {
        String value = get(section, key);
        return value != null ? value : defaultValue;
    }

    public void set(String section, String key, String value) {
        String fullKey = section + "." + key;
        data.put(fullKey, value);
    }

    public void set(String section, String key, int value) {
        set(section, key, String.valueOf(value));
    }

    public void set(String section, String key, boolean value) {
        set(section, key, String.valueOf(value));
    }

    public int getInt(String section, String key, int defaultValue) {
        String value = get(section, key);
        if (value != null) {
            try {
                return Integer.parseInt(value);
            } catch (NumberFormatException e) {
                return defaultValue;
            }
        }
        return defaultValue;
    }

    public boolean getBoolean(String section, String key, boolean defaultValue) {
        String value = get(section, key);
        if (value != null) {
            return Boolean.parseBoolean(value);
        }
        return defaultValue;
    }

    public void saveWindowPosition(int x, int y) {
        set(SECTION_WINDOW_POSITION, KEY_X, x);
        set(SECTION_WINDOW_POSITION, KEY_Y, y);
        save();
    }

    public int[] getWindowPosition() {
        String xStr = get(SECTION_WINDOW_POSITION, KEY_X);
        String yStr = get(SECTION_WINDOW_POSITION, KEY_Y);
        if (xStr != null && yStr != null) {
            try {
                return new int[]{Integer.parseInt(xStr), Integer.parseInt(yStr)};
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }

    public int getWindowWidth() {
        return getInt(SECTION_WINDOW_SIZE, KEY_WIDTH, 800);
    }

    public int getWindowHeight() {
        return getInt(SECTION_WINDOW_SIZE, KEY_HEIGHT, 600);
    }

    public void setWindowSize(int width, int height) {
        set(SECTION_WINDOW_SIZE, KEY_WIDTH, width);
        set(SECTION_WINDOW_SIZE, KEY_HEIGHT, height);
        save();
    }

    public String getWindowTitle() {
        return get(SECTION_WINDOW, KEY_TITLE, "p5engine");
    }

    public void setWindowTitle(String title) {
        set(SECTION_WINDOW, KEY_TITLE, title);
        save();
    }

    public boolean isDebugMode() {
        return getBoolean(SECTION_P5ENGINE, KEY_DEBUG, false);
    }

    public void setDebugMode(boolean debug) {
        set(SECTION_P5ENGINE, KEY_DEBUG, debug);
        save();
    }

    public boolean isSingleInstance() {
        return getBoolean(SECTION_P5ENGINE, KEY_SINGLE_INSTANCE, false);
    }

    public void setSingleInstance(boolean singleInstance) {
        set(SECTION_P5ENGINE, KEY_SINGLE_INSTANCE, singleInstance);
        save();
    }

    public Path getConfigFile() {
        return configFile;
    }

    public String getConfigFilePath() {
        return configFile.toString();
    }

    public static int[] getCenterPosition(int windowWidth, int windowHeight) {
        java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
        java.awt.Rectangle screenBounds = ge.getMaximumWindowBounds();
        int x = (screenBounds.width - windowWidth) / 2 + screenBounds.x;
        int y = (screenBounds.height - windowHeight) / 2 + screenBounds.y;
        return new int[]{x, y};
    }
}