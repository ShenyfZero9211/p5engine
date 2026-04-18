package shenyf.p5engine.config;

import java.util.HashMap;
import java.util.Map;

public class MapConfigSource implements ConfigSource {

    private final String name;
    private final Map<String, String> values;
    private final int priority;

    public MapConfigSource(String name, Map<String, String> values) {
        this(name, values, 100);
    }

    public MapConfigSource(String name, Map<String, String> values, int priority) {
        this.name = name;
        this.values = new HashMap<>(values);
        this.priority = priority;
    }

    @Override
    public String getString(String key) {
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

    public void setValue(String key, String value) {
        values.put(key, value);
    }

    public void removeValue(String key) {
        values.remove(key);
    }

    public Map<String, String> getAllValues() {
        return new HashMap<>(values);
    }
}
