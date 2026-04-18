package shenyf.p5engine.config;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class IniParser {

    private static final Pattern SECTION_PATTERN = Pattern.compile("^\\s*\\[([^\\]]+)\\]\\s*$");
    private static final Pattern KEY_VALUE_PATTERN = Pattern.compile("^\\s*([^=]+?)\\s*=\\s*(.*)$");

    public static Map<String, String> parse(Path filePath) {
        Map<String, String> result = new LinkedHashMap<>();

        if (!Files.exists(filePath)) {
            return result;
        }

        try (BufferedReader reader = Files.newBufferedReader(filePath)) {
            String currentSection = "";
            String line;

            while ((line = reader.readLine()) != null) {
                line = line.trim();

                if (isCommentOrEmpty(line)) {
                    continue;
                }

                Matcher sectionMatcher = SECTION_PATTERN.matcher(line);
                if (sectionMatcher.matches()) {
                    currentSection = sectionMatcher.group(1).trim();
                    continue;
                }

                Matcher kvMatcher = KEY_VALUE_PATTERN.matcher(line);
                if (kvMatcher.matches()) {
                    String key = kvMatcher.group(1).trim();
                    String value = kvMatcher.group(2).trim();

                    value = removeQuotes(value);

                    String fullKey = buildFullKey(currentSection, key);
                    result.put(fullKey, value);

                    result.put(key, value);
                }
            }
        } catch (IOException e) {
            System.err.println("[p5engine] Failed to parse INI file: " + filePath);
        }

        return result;
    }

    public static void write(Path filePath, Map<String, String> data) throws IOException {
        StringBuilder sb = new StringBuilder();
        String currentSection = "";

        for (Map.Entry<String, String> entry : data.entrySet()) {
            String fullKey = entry.getKey();
            String value = entry.getValue();

            int dotIndex = fullKey.lastIndexOf('.');
            String section = dotIndex > 0 ? fullKey.substring(0, dotIndex) : "";
            String key = dotIndex > 0 ? fullKey.substring(dotIndex + 1) : fullKey;

            if (!section.equals(currentSection)) {
                if (!currentSection.isEmpty()) {
                    sb.append('\n');
                }
                currentSection = section;
                if (!currentSection.isEmpty()) {
                    sb.append('[').append(currentSection).append(']').append('\n');
                }
            }

            sb.append(key).append('=').append(value).append('\n');
        }

        Files.writeString(filePath, sb.toString());
    }

    private static boolean isCommentOrEmpty(String line) {
        return line.isEmpty() || line.startsWith(";") || line.startsWith("#");
    }

    private static String buildFullKey(String section, String key) {
        if (section == null || section.isEmpty()) {
            return key;
        }
        return section + "." + key;
    }

    private static String removeQuotes(String value) {
        if ((value.startsWith("\"") && value.endsWith("\"")) ||
            (value.startsWith("'") && value.endsWith("'"))) {
            return value.substring(1, value.length() - 1);
        }
        return value;
    }

    public static Map<String, String> parseString(String content) {
        Map<String, String> result = new LinkedHashMap<>();
        String currentSection = "";
        String[] lines = content.split("\\r?\\n");

        for (String line : lines) {
            line = line.trim();

            if (isCommentOrEmpty(line)) {
                continue;
            }

            Matcher sectionMatcher = SECTION_PATTERN.matcher(line);
            if (sectionMatcher.matches()) {
                currentSection = sectionMatcher.group(1).trim();
                continue;
            }

            Matcher kvMatcher = KEY_VALUE_PATTERN.matcher(line);
            if (kvMatcher.matches()) {
                String key = kvMatcher.group(1).trim();
                String value = removeQuotes(kvMatcher.group(2).trim());
                String fullKey = buildFullKey(currentSection, key);
                result.put(fullKey, value);
            }
        }

        return result;
    }
}
