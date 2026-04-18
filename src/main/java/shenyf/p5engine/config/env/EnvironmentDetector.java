package shenyf.p5engine.config.env;

import java.awt.GraphicsEnvironment;

public class EnvironmentDetector {

    public enum Platform {
        WINDOWS,
        MACOS,
        LINUX,
        OTHER
    }

    private static Platform cachedPlatform = null;
    private static String cachedArch = null;
    private static String cachedJavaVersion = null;
    private static Boolean cachedIs64Bit = null;
    private static Boolean cachedIsHeadless = null;

    public static Platform getPlatform() {
        if (cachedPlatform != null) {
            return cachedPlatform;
        }

        String os = System.getProperty("os.name", "").toLowerCase();
        if (os.contains("windows") || os.contains("win")) {
            cachedPlatform = Platform.WINDOWS;
        } else if (os.contains("mac") || os.contains("darwin")) {
            cachedPlatform = Platform.MACOS;
        } else if (os.contains("linux")) {
            cachedPlatform = Platform.LINUX;
        } else {
            cachedPlatform = Platform.OTHER;
        }
        return cachedPlatform;
    }

    public static String getPlatformName() {
        Platform p = getPlatform();
        switch (p) {
            case WINDOWS: return "windows";
            case MACOS: return "macos";
            case LINUX: return "linux";
            default: return "unknown";
        }
    }

    public static String getArch() {
        if (cachedArch != null) {
            return cachedArch;
        }
        cachedArch = System.getProperty("os.arch", "unknown");
        return cachedArch;
    }

    public static String getJavaVersion() {
        if (cachedJavaVersion != null) {
            return cachedJavaVersion;
        }
        cachedJavaVersion = System.getProperty("java.version", "unknown");
        return cachedJavaVersion;
    }

    public static int getJavaVersionMajor() {
        String version = getJavaVersion();
        String[] parts = version.split("[.\\-]");
        if (parts.length >= 1) {
            try {
                return Integer.parseInt(parts[0]);
            } catch (NumberFormatException e) {
                return 0;
            }
        }
        return 0;
    }

    public static boolean is64Bit() {
        if (cachedIs64Bit != null) {
            return cachedIs64Bit;
        }
        String arch = getArch();
        cachedIs64Bit = arch.contains("64") || arch.equals("aarch64");
        return cachedIs64Bit;
    }

    public static boolean isHeadless() {
        if (cachedIsHeadless != null) {
            return cachedIsHeadless;
        }
        cachedIsHeadless = GraphicsEnvironment.isHeadless();
        return cachedIsHeadless;
    }

    public static String getConfigSuffix() {
        return getPlatformName() + "_" + getArch();
    }

    public static String getUserHome() {
        return System.getProperty("user.home", "");
    }

    public static String getUserDir() {
        return System.getProperty("user.dir", "");
    }

    public static String getTempDir() {
        return System.getProperty("java.io.tmpdir", "");
    }

    public static int getAvailableProcessors() {
        return Runtime.getRuntime().availableProcessors();
    }

    public static long getMaxMemory() {
        return Runtime.getRuntime().maxMemory();
    }

    public static long getTotalMemory() {
        return Runtime.getRuntime().totalMemory();
    }

    public static long getFreeMemory() {
        return Runtime.getRuntime().freeMemory();
    }

    public static String getSystemInfo() {
        return String.format(
            "Platform: %s (%s)\n" +
            "Java: %s (%d-bit)\n" +
            "Processors: %d\n" +
            "Max Memory: %d MB\n" +
            "Headless: %s",
            getPlatformName(),
            getArch(),
            getJavaVersion(),
            is64Bit() ? 64 : 32,
            getAvailableProcessors(),
            getMaxMemory() / (1024 * 1024),
            isHeadless()
        );
    }
}
