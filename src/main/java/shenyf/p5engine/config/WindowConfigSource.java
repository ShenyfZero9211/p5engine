package shenyf.p5engine.config;

import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;

public class WindowConfigSource implements ConfigSource {

    private static final String SECTION = "window_position";
    private static final String KEY_X = "x";
    private static final String KEY_Y = "y";

    private final String name;
    private final Path configFile;
    private Map<String, String> values;
    private final int priority;

    public WindowConfigSource(String name, int priority) {
        this.name = name;
        this.priority = priority;
        this.configFile = getDefaultConfigPath();
        load();
    }

    private Path getDefaultConfigPath() {
        String userDir = System.getProperty("user.dir");
        return Paths.get(userDir, "p5engine_window.ini");
    }

    private void load() {
        if (configFile.toFile().exists()) {
            values = IniParser.parse(configFile);
        } else {
            values = new java.util.LinkedHashMap<>();
        }
    }

    @Override
    public String getString(String key) {
        String fullKey = SECTION + "." + key;
        return values.get(fullKey);
    }

    @Override
    public boolean containsKey(String key) {
        return values.containsKey(SECTION + "." + key);
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public int getPriority() {
        return priority;
    }

    public void savePosition(int x, int y) {
        values.put(SECTION + "." + KEY_X, String.valueOf(x));
        values.put(SECTION + "." + KEY_Y, String.valueOf(y));
        try {
            IniParser.write(configFile, values);
            System.out.println("[p5engine] Window position saved: " + x + ", " + y);
        } catch (Exception e) {
            System.err.println("[p5engine] Failed to save window position: " + e.getMessage());
        }
    }

    public int[] getSavedPosition() {
        String xStr = getString(KEY_X);
        String yStr = getString(KEY_Y);
        if (xStr != null && yStr != null) {
            try {
                return new int[]{Integer.parseInt(xStr), Integer.parseInt(yStr)};
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }

    public static int[] getCenterPosition(int windowWidth, int windowHeight) {
        GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
        GraphicsDevice gd = ge.getDefaultScreenDevice();
        // Use GraphicsConfiguration bounds to get logical resolution.
        // This matches the coordinate system used by Frame.setLocation()
        // which operates in DPI-scaled logical pixels on HiDPI displays.
        java.awt.Rectangle screenBounds = gd.getDefaultConfiguration().getBounds();
        java.awt.Rectangle usableBounds = ge.getMaximumWindowBounds();
        int x = (screenBounds.width - windowWidth) / 2 + screenBounds.x;
        int y = (usableBounds.height - windowHeight) / 2 + usableBounds.y;
        return new int[]{x, y};
    }

    public Path getConfigFile() {
        return configFile;
    }
}
