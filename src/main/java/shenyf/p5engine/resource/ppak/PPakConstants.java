package shenyf.p5engine.resource.ppak;

public class PPakConstants {
    public static final String PPAK_MAGIC = "PPAK";
    public static final int PPAK_VERSION = 1;
    public static final int PPAK_HEADER_SIZE = 14;
    public static final int PPAK_INDEX_ENTRY_SIZE = 10;

    public static final String DEFAULT_PPAK_FILENAME = "data.ppak";

    public static final int MAX_IMAGE_CACHE_SIZE = 64;
    public static final int MAX_FONT_CACHE_SIZE = 16;
    public static final int DEFAULT_AUDIO_BUFFER_SIZE = 1024;

    public static final long MAX_MEMORY_CACHE_SIZE = 50 * 1024 * 1024; // 50MB

    public static final String TEMP_FILE_PREFIX = "__ppak_";
    public static final String TEMP_FILE_PATTERN = TEMP_FILE_PREFIX + "*";

    private PPakConstants() {}
}