package shenyf.p5engine.util;

public class Logger {
    private static final String PREFIX = "[p5engine]";
    private static boolean debugEnabled = false;

    // ===== Simple single-arg versions (backward compatible) =====

    public static void info(String message) {
        System.out.println(PREFIX + " " + message);
    }

    public static void warn(String message) {
        System.out.println(PREFIX + " WARN: " + message);
    }

    public static void error(String message) {
        System.err.println(PREFIX + " ERROR: " + message);
    }

    public static void error(String message, Throwable t) {
        System.err.println(PREFIX + " ERROR: " + message);
        t.printStackTrace(System.err);
    }

    public static void debug(String message) {
        if (debugEnabled) {
            System.out.println(PREFIX + " DEBUG: " + message);
        }
    }

    // ===== Categorized versions with tag prefix =====

    public static void info(String tag, String message) {
        System.out.println(PREFIX + " [" + tag + "] " + message);
    }

    public static void warn(String tag, String message) {
        System.out.println(PREFIX + " [" + tag + "] WARN: " + message);
    }

    public static void error(String tag, String message) {
        System.err.println(PREFIX + " [" + tag + "] ERROR: " + message);
    }

    public static void error(String tag, String message, Throwable t) {
        System.err.println(PREFIX + " [" + tag + "] ERROR: " + message);
        t.printStackTrace(System.err);
    }

    public static void debug(String tag, String message) {
        if (debugEnabled) {
            System.out.println(PREFIX + " [" + tag + "] DEBUG: " + message);
        }
    }

    public static void setDebugEnabled(boolean enabled) {
        debugEnabled = enabled;
    }
}
