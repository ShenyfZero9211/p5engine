/**
 * Completion tracking: per-level, per-difficulty.
 * Stored in data/completion.json
 */
static final class TdCompletion {

    static JSONObject data;
    static String filePath;

    static void load(PApplet app) {
        filePath = app.sketchPath("data/completion.json");
        java.io.File f = new java.io.File(filePath);
        if (f.exists()) {
            try {
                data = app.loadJSONObject(filePath);
            } catch (Exception e) {
                System.err.println("[TdCompletion] Failed to load " + filePath + ", initializing fresh: " + e.getMessage());
                data = new JSONObject();
                save(app);
            }
        } else {
            data = new JSONObject();
            save(app);
        }
    }

    static void save(PApplet app) {
        if (data != null && filePath != null) {
            app.saveJSONObject(data, filePath);
        }
    }

    static boolean isCompleted(int levelId, String difficultyKey) {
        if (data == null || difficultyKey == null) return false;
        String key = String.valueOf(levelId);
        if (!data.hasKey(key)) return false;
        JSONObject levelObj = data.getJSONObject(key);
        if (levelObj == null || !levelObj.hasKey(difficultyKey)) return false;
        return levelObj.getBoolean(difficultyKey, false);
    }

    static void setCompleted(int levelId, String difficultyKey) {
        if (data == null) data = new JSONObject();
        if (difficultyKey == null) return;
        String key = String.valueOf(levelId);
        JSONObject levelObj = data.hasKey(key) ? data.getJSONObject(key) : new JSONObject();
        levelObj.setBoolean(difficultyKey, true);
        data.setJSONObject(key, levelObj);
    }

    static boolean hasAnyCompletion(int levelId) {
        if (data == null) return false;
        String key = String.valueOf(levelId);
        if (!data.hasKey(key)) return false;
        JSONObject levelObj = data.getJSONObject(key);
        if (levelObj == null) return false;
        for (Object diffKeyObj : levelObj.keys()) {
            String diffKey = (String) diffKeyObj;
            if (levelObj.getBoolean(diffKey, false)) return true;
        }
        return false;
    }
}
