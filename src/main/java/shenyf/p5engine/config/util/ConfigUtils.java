package shenyf.p5engine.config.util;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.HashMap;
import java.util.Map;
import shenyf.p5engine.config.ConfigManager;
import shenyf.p5engine.config.annotation.Config;
import shenyf.p5engine.config.annotation.ConfigProperty;

public class ConfigUtils {

    public static <T> T bindConfig(Class<T> configClass) {
        return bindConfig(configClass, ConfigManager.getInstance());
    }

    public static <T> T bindConfig(Class<T> configClass, ConfigManager manager) {
        try {
            T instance = configClass.getDeclaredConstructor().newInstance();
            bindConfigToInstance(instance, manager);
            return instance;
        } catch (Exception e) {
            throw new RuntimeException("Failed to bind config class: " + configClass.getName(), e);
        }
    }

    public static <T> void bindConfigToInstance(T instance, ConfigManager manager) {
        Class<?> clazz = instance.getClass();
        Field[] fields = clazz.getDeclaredFields();

        for (Field field : fields) {
            if (Modifier.isStatic(field.getModifiers()) || Modifier.isFinal(field.getModifiers())) {
                continue;
            }

            ConfigProperty annotation = field.getAnnotation(ConfigProperty.class);
            if (annotation == null) {
                continue;
            }

            String key = annotation.key();
            String defaultValue = annotation.defaultValue();

            field.setAccessible(true);

            try {
                Class<?> fieldType = field.getType();
                Object value = null;

                if (fieldType == int.class || fieldType == Integer.class) {
                    value = manager.getInt(key, Integer.parseInt(defaultValue));
                } else if (fieldType == long.class || fieldType == Long.class) {
                    value = manager.getLong(key, Long.parseLong(defaultValue));
                } else if (fieldType == float.class || fieldType == Float.class) {
                    value = manager.getFloat(key, Float.parseFloat(defaultValue));
                } else if (fieldType == double.class || fieldType == Double.class) {
                    value = manager.getDouble(key, Double.parseDouble(defaultValue));
                } else if (fieldType == boolean.class || fieldType == Boolean.class) {
                    value = manager.getBoolean(key, Boolean.parseBoolean(defaultValue));
                } else if (fieldType == String.class) {
                    value = manager.getString(key, defaultValue);
                } else if (fieldType == String[].class) {
                    value = parseStringArray(manager.getString(key, defaultValue));
                }

                if (value != null) {
                    field.set(instance, value);
                }
            } catch (Exception e) {
                System.err.println("[p5engine] Failed to bind config field: " + key);
            }
        }
    }

    public static Map<String, String> toMap(Object instance) {
        Map<String, String> result = new HashMap<>();
        Class<?> clazz = instance.getClass();
        Field[] fields = clazz.getDeclaredFields();

        for (Field field : fields) {
            if (Modifier.isStatic(field.getModifiers()) || Modifier.isFinal(field.getModifiers())) {
                continue;
            }

            ConfigProperty annotation = field.getAnnotation(ConfigProperty.class);
            if (annotation == null) {
                continue;
            }

            String key = annotation.key();
            field.setAccessible(true);

            try {
                Object value = field.get(instance);
                if (value != null) {
                    result.put(key, value.toString());
                }
            } catch (Exception e) {
                // Skip
            }
        }

        return result;
    }

    private static String[] parseStringArray(String value) {
        if (value == null || value.isEmpty()) {
            return new String[0];
        }
        return value.split(",");
    }

    public static String getConfigFilePath(String fileName) {
        return System.getProperty("user.dir") + "/" + fileName;
    }

    public static String getUserConfigPath(String fileName) {
        String userHome = System.getProperty("user.home", "");
        String os = System.getProperty("os.name", "").toLowerCase();

        String configDir;
        if (os.contains("windows")) {
            configDir = userHome + "/AppData/Roaming";
        } else if (os.contains("mac")) {
            configDir = userHome + "/Library/Application Support";
        } else {
            configDir = userHome + "/.config";
        }

        return configDir + "/p5engine/" + fileName;
    }
}
