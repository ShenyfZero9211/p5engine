package shenyf.p5engine.config;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class ConfigManager {

    private static ConfigManager instance;

    private final List<ConfigSource> sources;
    private final Map<String, String> cache;
    private final List<ChangeListener> listeners;
    private ScheduledExecutorService watchService;
    private boolean autoReloadEnabled;
    private long autoReloadIntervalMs;

    private ConfigManager() {
        sources = new ArrayList<>();
        cache = new HashMap<>();
        listeners = new CopyOnWriteArrayList<>();
        autoReloadEnabled = false;
        autoReloadIntervalMs = 1000;
    }

    public static synchronized ConfigManager getInstance() {
        if (instance == null) {
            instance = new ConfigManager();
        }
        return instance;
    }

    public static synchronized void reset() {
        if (instance != null) {
            instance.disableAutoReload();
            instance.sources.clear();
            instance.cache.clear();
            instance = null;
        }
    }

    public void addSource(ConfigSource source) {
        sources.add(source);
        Collections.sort(sources);
        clearCache();
        System.out.println("[p5engine] Config source added: " + source.getName() + " (priority=" + source.getPriority() + ")");
    }

    public void removeSource(String name) {
        sources.removeIf(s -> s.getName().equals(name));
        clearCache();
    }

    public ConfigSource getSource(String name) {
        return sources.stream()
                .filter(s -> s.getName().equals(name))
                .findFirst()
                .orElse(null);
    }

    public Collection<ConfigSource> getSources() {
        return new ArrayList<>(sources);
    }

    public void clearSources() {
        sources.clear();
        clearCache();
    }

    private void clearCache() {
        cache.clear();
    }

    private String resolveKey(String key) {
        for (ConfigSource source : sources) {
            if (source.containsKey(key)) {
                return source.getString(key);
            }
        }
        return null;
    }

    public String getString(String key) {
        if (cache.containsKey(key)) {
            return cache.get(key);
        }
        String value = resolveKey(key);
        cache.put(key, value);
        return value;
    }

    public String getString(String key, String defaultValue) {
        String value = getString(key);
        return value != null ? value : defaultValue;
    }

    public int getInt(String key, int defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Integer.parseInt(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public long getLong(String key, long defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Long.parseLong(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public float getFloat(String key, float defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Float.parseFloat(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public double getDouble(String key, double defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        try {
            return Double.parseDouble(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public boolean getBoolean(String key, boolean defaultValue) {
        String val = getString(key);
        if (val == null) return defaultValue;
        String lower = val.trim().toLowerCase();
        return "true".equals(lower) || "1".equals(lower) || "yes".equals(lower) || "on".equals(lower);
    }

    public boolean hasKey(String key) {
        return getString(key) != null;
    }

    public void reload() {
        System.out.println("[p5engine] Reloading configuration...");
        clearCache();
        for (ConfigSource source : sources) {
            if (source instanceof FileConfigSource) {
                ((FileConfigSource) source).reload();
            }
        }
        notifyListeners(null, null, null);
        System.out.println("[p5engine] Configuration reloaded");
    }

    public void enableAutoReload(long intervalMs) {
        disableAutoReload();
        this.autoReloadIntervalMs = intervalMs;
        this.autoReloadEnabled = true;
        watchService = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "p5engine-config-watcher");
            t.setDaemon(true);
            return t;
        });
        watchService.scheduleAtFixedRate(this::checkForChanges, intervalMs, intervalMs, TimeUnit.MILLISECONDS);
        System.out.println("[p5engine] Auto-reload enabled (interval=" + intervalMs + "ms)");
    }

    public void disableAutoReload() {
        if (watchService != null) {
            watchService.shutdown();
            try {
                if (!watchService.awaitTermination(1, TimeUnit.SECONDS)) {
                    watchService.shutdownNow();
                }
            } catch (InterruptedException e) {
                watchService.shutdownNow();
                Thread.currentThread().interrupt();
            }
            watchService = null;
        }
        autoReloadEnabled = false;
        System.out.println("[p5engine] Auto-reload disabled");
    }

    public boolean isAutoReloadEnabled() {
        return autoReloadEnabled;
    }

    private void checkForChanges() {
        boolean changed = false;
        for (ConfigSource source : sources) {
            if (source instanceof FileConfigSource) {
                if (((FileConfigSource) source).hasFileChanged()) {
                    changed = true;
                    break;
                }
            }
        }
        if (changed) {
            reload();
        }
    }

    public void addChangeListener(ChangeListener listener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener);
        }
    }

    public void removeChangeListener(ChangeListener listener) {
        listeners.remove(listener);
    }

    private void notifyListeners(String key, String oldValue, String newValue) {
        for (ChangeListener listener : listeners) {
            listener.onConfigChanged(key, oldValue, newValue);
        }
    }

    public interface ChangeListener {
        void onConfigChanged(String key, String oldValue, String newValue);
    }
}
