package shenyf.p5engine.util;

import java.io.*;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Lightweight logging utility for p5engine.
 *
 * <p>Supports console output (default) and optional file persistence,
 * with log levels, category filtering, and automatic file rotation.</p>
 *
 * <p>All existing static methods remain backward compatible.</p>
 */
public class Logger {

    public enum Level {
        DEBUG(0), INFO(1), WARN(2), ERROR(3);
        private final int priority;
        Level(int priority) { this.priority = priority; }
        public int getPriority() { return priority; }
    }

    private static final String PREFIX = "[p5engine]";
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");

    private static boolean debugEnabled = false;
    private static Level level = Level.INFO;
    private static boolean fileLogging = false;
    private static String logDir = "logs";
    private static int maxFileSizeMB = 5;
    private static int maxFileCount = 7;
    private static Set<String> tagFilter = null;

    private static PrintWriter fileWriter;
    private static File currentLogFile;
    private static long currentFileSize;

    // ═══════════════════════════════════════════════════════════════
    // Backward-compatible API
    // ═══════════════════════════════════════════════════════════════

    public static void info(String message) {
        log(Level.INFO, null, message);
    }

    public static void warn(String message) {
        log(Level.WARN, null, message);
    }

    public static void error(String message) {
        log(Level.ERROR, null, message);
    }

    public static void error(String message, Throwable t) {
        log(Level.ERROR, null, message);
        if (t != null) t.printStackTrace(System.err);
    }

    public static void debug(String message) {
        if (debugEnabled) {
            log(Level.DEBUG, null, message);
        }
    }

    public static void info(String tag, String message) {
        log(Level.INFO, tag, message);
    }

    public static void warn(String tag, String message) {
        log(Level.WARN, tag, message);
    }

    public static void error(String tag, String message) {
        log(Level.ERROR, tag, message);
    }

    public static void error(String tag, String message, Throwable t) {
        log(Level.ERROR, tag, message);
        if (t != null) t.printStackTrace(System.err);
    }

    public static void debug(String tag, String message) {
        if (debugEnabled) {
            log(Level.DEBUG, tag, message);
        }
    }

    public static void setDebugEnabled(boolean enabled) {
        debugEnabled = enabled;
    }

    // ═══════════════════════════════════════════════════════════════
    // New configuration API
    // ═══════════════════════════════════════════════════════════════

    public static void setLevel(Level newLevel) {
        level = newLevel != null ? newLevel : Level.INFO;
    }

    public static Level getLevel() {
        return level;
    }

    public static void setFileLogging(boolean enabled) {
        if (fileLogging == enabled) return;
        fileLogging = enabled;
        if (enabled) {
            openLogFile();
        } else {
            closeLogFile();
        }
    }

    public static boolean isFileLogging() {
        return fileLogging;
    }

    public static void setLogDirectory(String path) {
        logDir = path != null && !path.isEmpty() ? path : "logs";
        if (fileLogging) {
            closeLogFile();
            openLogFile();
        }
    }

    public static String getLogDirectory() {
        return logDir;
    }

    public static void setMaxFileSizeMB(int mb) {
        maxFileSizeMB = Math.max(1, mb);
    }

    public static void setMaxFileCount(int count) {
        maxFileCount = Math.max(1, count);
    }

    public static void setTagFilter(String... tags) {
        if (tags == null || tags.length == 0) {
            tagFilter = null;
        } else {
            tagFilter = new HashSet<>(Arrays.asList(tags));
        }
    }

    public static Set<String> getTagFilter() {
        return tagFilter != null ? new HashSet<>(tagFilter) : null;
    }

    public static String getCurrentLogFilePath() {
        return currentLogFile != null ? currentLogFile.getAbsolutePath() : null;
    }

    public static void cycleLevel() {
        Level[] levels = Level.values();
        int next = (level.ordinal() + 1) % levels.length;
        level = levels[next];
        info("Logger", "Log level changed to " + level);
    }

    // ═══════════════════════════════════════════════════════════════
    // Internal
    // ═══════════════════════════════════════════════════════════════

    private static void log(Level msgLevel, String tag, String message) {
        // Global level filter
        if (msgLevel.getPriority() < level.getPriority()) return;

        // Tag filter applies only to DEBUG messages
        if (msgLevel == Level.DEBUG && tagFilter != null && tag != null) {
            if (!tagFilter.contains(tag)) return;
        }

        String timestamp = LocalDateTime.now().format(TIME_FMT);
        StringBuilder sb = new StringBuilder();
        sb.append("[").append(timestamp).append("]");
        sb.append(" [").append(msgLevel.name()).append("]");
        if (tag != null && !tag.isEmpty()) {
            sb.append(" [").append(tag).append("]");
        }
        sb.append(" ").append(message);
        String line = sb.toString();

        // Console output
        if (msgLevel == Level.ERROR) {
            System.err.println(line);
        } else {
            System.out.println(line);
        }

        // File output
        if (fileLogging && fileWriter != null) {
            writeToFile(line);
        }
    }

    private static synchronized void writeToFile(String line) {
        try {
            // Check rotation
            if (currentLogFile != null && currentFileSize > maxFileSizeMB * 1024L * 1024L) {
                closeLogFile();
                openLogFile();
            }
            if (fileWriter != null) {
                fileWriter.println(line);
                fileWriter.flush();
                currentFileSize += line.getBytes(java.nio.charset.StandardCharsets.UTF_8).length + 1;
            }
        } catch (Exception e) {
            System.err.println(PREFIX + " ERROR: Failed to write log file: " + e.getMessage());
        }
    }

    private static void openLogFile() {
        try {
            File dir = new File(logDir);
            if (!dir.exists()) {
                dir.mkdirs();
            }

            // Clean up empty files
            cleanupEmptyFiles(dir);

            // Rotate if too many files
            cleanupOldFiles(dir);

            String filename = "p5engine_" + LocalDateTime.now().format(
                DateTimeFormatter.ofPattern("yyyy-MM-dd_HH-mm-ss")) + ".log";
            currentLogFile = new File(dir, filename);
            fileWriter = new PrintWriter(new BufferedWriter(new FileWriter(currentLogFile, true)));
            currentFileSize = currentLogFile.length();

            String header = "[" + LocalDateTime.now().format(TIME_FMT) + "] [INFO] Logger file opened: " + filename;
            fileWriter.println(header);
            fileWriter.flush();
            currentFileSize += header.getBytes(java.nio.charset.StandardCharsets.UTF_8).length + 1;
        } catch (Exception e) {
            System.err.println(PREFIX + " ERROR: Failed to open log file: " + e.getMessage());
            fileLogging = false;
        }
    }

    private static void closeLogFile() {
        if (fileWriter != null) {
            try {
                fileWriter.println("[" + LocalDateTime.now().format(TIME_FMT) + "] [INFO] Logger file closed.");
                fileWriter.flush();
                fileWriter.close();
            } catch (Exception ignored) {}
            fileWriter = null;
        }
        currentLogFile = null;
        currentFileSize = 0;
    }

    private static void cleanupEmptyFiles(File dir) {
        File[] files = dir.listFiles((d, name) -> name.startsWith("p5engine_") && name.endsWith(".log"));
        if (files == null) return;
        for (File f : files) {
            if (f.length() == 0) {
                f.delete();
            }
        }
    }

    private static void cleanupOldFiles(File dir) {
        File[] files = dir.listFiles((d, name) -> name.startsWith("p5engine_") && name.endsWith(".log"));
        if (files == null || files.length < maxFileCount) return;
        Arrays.sort(files, Comparator.comparingLong(File::lastModified));
        int toDelete = files.length - maxFileCount + 1; // +1 to make room for new file
        for (int i = 0; i < toDelete && i < files.length; i++) {
            files[i].delete();
        }
    }
}
