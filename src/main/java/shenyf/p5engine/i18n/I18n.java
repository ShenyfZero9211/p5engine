package shenyf.p5engine.i18n;

import processing.core.PApplet;
import processing.data.JSONObject;
import shenyf.p5engine.util.Logger;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * Lightweight JSON-based internationalization manager.
 *
 * <p>Loads translation strings from {@code data/i18n/{locale}.json}.
 * Supports parameterized messages with {@code {0}}, {@code {1}} placeholders.
 *
 * <p>Usage:
 * <pre>
 *   engine.getI18n().setLocale("zh");
 *   String text = engine.getI18n().get("menu.start");
 *   String wave = engine.getI18n().get("game.wave", 3); // "Wave {0}"
 * </pre>
 */
public class I18n {

    private final PApplet applet;
    private String locale = "zh";
    private JSONObject strings = new JSONObject();
    private final List<Runnable> listeners = new ArrayList<>();

    public I18n(PApplet applet) {
        this.applet = applet;
        reload();
    }

    /** Current active locale code, e.g. "zh", "en". */
    public String getLocale() {
        return locale;
    }

    /** Switch locale and reload strings. Notifies all registered listeners. */
    public void setLocale(String locale) {
        if (locale == null || locale.equals(this.locale)) return;
        this.locale = locale;
        reload();
        for (Runnable r : listeners) {
            try {
                r.run();
            } catch (Exception e) {
                Logger.warn("I18n", "listener error: " + e.getMessage());
            }
        }
        Logger.info("I18n: switched to " + locale);
    }

    /** Reload strings from disk for the current locale. */
    public void reload() {
        String path = "data/i18n/" + locale + ".json";
        File file = new File(applet.sketchPath(path));
        if (file.exists()) {
            strings = applet.loadJSONObject(file);
        } else {
            Logger.warn("I18n: resource file not found: " + path);
            strings = new JSONObject();
        }
    }

    /** Get a translated string. Falls back to the key itself if missing. */
    public String get(String key) {
        if (strings == null) return key;
        return strings.hasKey(key) ? strings.getString(key) : key;
    }

    /**
     * Get a translated string with positional placeholders replaced.
     * Placeholders use {@code {0}}, {@code {1}}, etc.
     */
    public String get(String key, Object... args) {
        String fmt = get(key);
        for (int i = 0; i < args.length; i++) {
            fmt = fmt.replace("{" + i + "}", String.valueOf(args[i]));
        }
        return fmt;
    }

    /** Register a callback invoked when the locale changes. */
    public void addListener(Runnable onLocaleChange) {
        listeners.add(onLocaleChange);
    }

    /** Unregister a previously added listener. */
    public void removeListener(Runnable onLocaleChange) {
        listeners.remove(onLocaleChange);
    }
}
