package shenyf.p5engine.resource.ppak;

import java.io.*;
import java.util.*;

public class PPakVideo {
    private static ArrayList<String> _tempVideoFiles = new ArrayList<>();

    public static String saveTempFile(byte[] data, String ext) {
        String tmpDir = System.getProperty("java.io.tmpdir");
        if (!tmpDir.endsWith(File.separator)) {
            tmpDir += File.separator;
        }
        String tmpFile = tmpDir + PPakConstants.TEMP_FILE_PREFIX +
               System.currentTimeMillis() + "_" +
               (int) (Math.random() * 10000) + "_video." + ext;

        FileOutputStream fos = null;
        try {
            fos = new FileOutputStream(tmpFile);
            fos.write(data);
            fos.close();
            synchronized (_tempVideoFiles) {
                _tempVideoFiles.add(tmpFile);
            }
            return tmpFile;
        } catch (Exception e) {
            System.err.println("[PPakVideo] Failed to save temp file: " + e.getMessage());
            if (fos != null) {
                try { fos.close(); } catch (Exception ignored) {}
            }
            return null;
        }
    }

    public static void disposeAll() {
        synchronized (_tempVideoFiles) {
            for (String f : _tempVideoFiles) {
                try {
                    new File(f).delete();
                } catch (Exception e) {
                }
            }
            _tempVideoFiles.clear();
        }
    }
}
