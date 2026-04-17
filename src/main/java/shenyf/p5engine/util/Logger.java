package shenyf.p5engine.util;

public class Logger {
    private static final String PREFIX = "[p5engine] ";
    private static boolean debugEnabled = false;

    public static void info(String message) {
        System.out.println(PREFIX + message);
    }

    public static void warn(String message) {
        System.out.println(PREFIX + "WARN: " + message);
    }

    public static void error(String message) {
        System.err.println(PREFIX + "ERROR: " + message);
    }

    public static void error(String message, Throwable t) {
        System.err.println(PREFIX + "ERROR: " + message);
        t.printStackTrace(System.err);
    }

    public static void debug(String message) {
        if (debugEnabled) {
            System.out.println(PREFIX + "DEBUG: " + message);
        }
    }

    public static void setDebugEnabled(boolean enabled) {
        debugEnabled = enabled;
    }
}
