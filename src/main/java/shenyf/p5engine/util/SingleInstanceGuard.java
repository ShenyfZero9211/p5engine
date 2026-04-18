package shenyf.p5engine.util;

import java.io.File;
import java.io.RandomAccessFile;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.file.Path;
import java.nio.file.Paths;

public class SingleInstanceGuard {

    private static final String LOCK_FILE_PREFIX = ".p5engine_";
    private static final String LOCK_FILE_SUFFIX = ".lock";

    private final String appName;
    private final File lockFile;
    private RandomAccessFile randomAccessFile;
    private FileLock fileLock;

    public SingleInstanceGuard(String appName) {
        this.appName = appName;
        String lockFileName = LOCK_FILE_PREFIX + appName + LOCK_FILE_SUFFIX;
        this.lockFile = new File(System.getProperty("user.dir"), lockFileName);
    }

    public boolean isAnotherInstanceRunning() {
        try {
            randomAccessFile = new RandomAccessFile(lockFile, "rw");
            FileChannel channel = randomAccessFile.getChannel();
            fileLock = channel.tryLock();

            if (fileLock == null) {
                releaseLock();
                return true;
            }

            Runtime.getRuntime().addShutdownHook(new Thread(this::cleanup));

            return false;
        } catch (Exception e) {
            Logger.warn("SingleInstanceGuard: Failed to acquire lock: " + e.getMessage());
            return false;
        }
    }

    public void releaseLock() {
        try {
            if (fileLock != null && fileLock.isValid()) {
                fileLock.release();
            }
            if (randomAccessFile != null) {
                randomAccessFile.close();
            }
            cleanup();
        } catch (Exception e) {
            Logger.debug("SingleInstanceGuard: Failed to release lock: " + e.getMessage());
        }
    }

    public void cleanup() {
        try {
            if (fileLock != null && fileLock.isValid()) {
                fileLock.release();
                fileLock = null;
            }
        } catch (Exception e) {
        }

        try {
            if (randomAccessFile != null) {
                randomAccessFile.close();
                randomAccessFile = null;
            }
        } catch (Exception e) {
        }

        try {
            if (lockFile.exists()) {
                lockFile.delete();
            }
        } catch (Exception e) {
        }
    }

    public String getLockFilePath() {
        return lockFile.getAbsolutePath();
    }
}