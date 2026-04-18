package shenyf.p5engine.config;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;

public class FileConfigSource implements ConfigSource {

    private final String name;
    private final Path filePath;
    private Map<String, String> values;
    private long lastModified;
    private final int priority;
    private final boolean watchChanges;

    public FileConfigSource(String name, String filePath) {
        this(name, filePath, 50, false);
    }

    public FileConfigSource(String name, String filePath, int priority) {
        this(name, filePath, priority, false);
    }

    public FileConfigSource(String name, String filePath, int priority, boolean watchChanges) {
        this.name = name;
        this.filePath = Paths.get(filePath);
        this.priority = priority;
        this.watchChanges = watchChanges;
        load();
    }

    private void load() {
        if (Files.exists(filePath)) {
            values = IniParser.parse(filePath);
            try {
                lastModified = Files.getLastModifiedTime(filePath).toMillis();
            } catch (IOException e) {
                lastModified = 0;
            }
        } else {
            values = new java.util.LinkedHashMap<>();
            lastModified = 0;
        }
    }

    @Override
    public String getString(String key) {
        if (watchChanges && hasFileChanged()) {
            reload();
        }
        return values.get(key);
    }

    @Override
    public boolean containsKey(String key) {
        return values.containsKey(key);
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public int getPriority() {
        return priority;
    }

    public boolean hasFileChanged() {
        if (!Files.exists(filePath)) {
            return false;
        }
        try {
            long currentMod = Files.getLastModifiedTime(filePath).toMillis();
            return currentMod > lastModified;
        } catch (IOException e) {
            return false;
        }
    }

    public void reload() {
        System.out.println("[p5engine] Reloading config from: " + filePath);
        load();
    }

    public Path getFilePath() {
        return filePath;
    }

    public void save() throws IOException {
        IniParser.write(filePath, values);
        lastModified = Files.getLastModifiedTime(filePath).toMillis();
    }

    public void setValue(String key, String value) {
        values.put(key, value);
    }
}
