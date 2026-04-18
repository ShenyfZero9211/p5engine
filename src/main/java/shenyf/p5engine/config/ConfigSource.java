package shenyf.p5engine.config;

import java.util.Collection;

public interface ConfigSource extends Comparable<ConfigSource> {

    String getString(String key);

    default String getString(String key, String defaultValue) {
        String val = getString(key);
        return val != null ? val : defaultValue;
    }

    default int getInt(String key, int defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Integer.parseInt(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    default long getLong(String key, long defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Long.parseLong(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    default float getFloat(String key, float defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Float.parseFloat(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    default double getDouble(String key, double defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Double.parseDouble(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    default boolean getBoolean(String key, boolean defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        String lower = val.trim().toLowerCase();
        return "true".equals(lower) || "1".equals(lower) || "yes".equals(lower) || "on".equals(lower);
    }

    boolean containsKey(String key);

    String getName();

    int getPriority();

    default int compareTo(ConfigSource other) {
        return Integer.compare(this.getPriority(), other.getPriority());
    }

    interface ChangeListener {
        void onConfigChanged(String key, String oldValue, String newValue);
    }
}
