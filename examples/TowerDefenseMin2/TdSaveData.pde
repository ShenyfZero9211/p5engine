/**
 * Persistent save data using p5engine SketchConfig.
 * Stored in TowerDefenseMin2.ini under [stats] and [camera] sections.
 */
static final class TdSaveData {

    static shenyf.p5engine.config.SketchConfig cfg;
    static boolean startupFullscreen;

    static void load(PApplet app) {
        String path = app.sketchPath("TowerDefenseMin2.ini");
        java.io.File f = new java.io.File(path);
        boolean firstRun = !f.exists();
        if (firstRun) {
            try { f.createNewFile(); } catch (Exception e) {}
        }
        cfg = new shenyf.p5engine.config.SketchConfig(path);
        startupFullscreen = isFullscreen();

        if (firstRun) {
            // Initialize all defaults on first launch
            cfg.set("stats", "gamesPlayed", 0);
            cfg.set("stats", "towersBuilt", 0);
            cfg.set("stats", "enemiesKilled", 0);
            cfg.set("stats", "gamesLost", 0);
            cfg.set("stats", "orbsLost", 0);
            cfg.set("audio", "masterVolume", "1.0");
            cfg.set("audio", "bgmVolume", "1.0");
            cfg.set("audio", "sfxVolume", "1.0");
            cfg.set("ui", "language", "zh");
            cfg.set("camera", "zoomAtMouse", false);
            cfg.set("display", "fullscreen", false);
            cfg.set("display", "playIntro", true);
            cfg.save();
        }

        TdCompletion.load(app);
    }

    static void save() {
        if (cfg != null) cfg.save();
    }

    // ── Stats ──

    static int gamesPlayed()   { return cfg.getInt("stats", "gamesPlayed", 0); }
    static int towersBuilt()   { return cfg.getInt("stats", "towersBuilt", 0); }
    static int enemiesKilled() { return cfg.getInt("stats", "enemiesKilled", 0); }
    static int gamesLost()     { return cfg.getInt("stats", "gamesLost", 0); }
    static int orbsLost()      { return cfg.getInt("stats", "orbsLost", 0); }

    static void incGamesPlayed()   { cfg.set("stats", "gamesPlayed", gamesPlayed() + 1); }
    static void incTowersBuilt()   { cfg.set("stats", "towersBuilt", towersBuilt() + 1); }
    static void incEnemiesKilled() { cfg.set("stats", "enemiesKilled", enemiesKilled() + 1); }
    static void incGamesLost()     { cfg.set("stats", "gamesLost", gamesLost() + 1); }
    static void incOrbsLost(int count) { cfg.set("stats", "orbsLost", orbsLost() + count); }

    // ── Settings (not auto-saved; call saveSettings() manually) ──

    static boolean isZoomAtMouse() {
        return cfg.getBoolean("camera", "zoomAtMouse", false);
    }

    static void setZoomAtMouse(boolean v) {
        cfg.set("camera", "zoomAtMouse", v);
    }

    static float getMasterVolume() { return parseFloat(cfg.get("audio", "masterVolume", "1.0")); }
    static float getBgmVolume()    { return parseFloat(cfg.get("audio", "bgmVolume", "1.0")); }
    static float getSfxVolume()    { return parseFloat(cfg.get("audio", "sfxVolume", "1.0")); }
    static String getLanguage()    { return cfg.get("ui", "language", "zh"); }

    static void setMasterVolume(float v) { cfg.set("audio", "masterVolume", String.valueOf(v)); }
    static void setBgmVolume(float v)    { cfg.set("audio", "bgmVolume", String.valueOf(v)); }
    static void setSfxVolume(float v)    { cfg.set("audio", "sfxVolume", String.valueOf(v)); }
    static void setLanguage(String v)    { cfg.set("ui", "language", v); }

    static boolean isFullscreen() { return cfg.getBoolean("display", "fullscreen", false); }
    static void setFullscreen(boolean v) { cfg.set("display", "fullscreen", v); }

    static boolean isPlayIntro() { return cfg.getBoolean("display", "playIntro", true); }
    static void setPlayIntro(boolean v) { cfg.set("display", "playIntro", v); }

    // ── Progress ──

    static int getMaxLevelReached() {
        int iniMax = cfg.getInt("progress", "maxLevelReached", 1);
        // Migrate old format: old ini stored raw 1~10 (max level index).
        // New format also stores 1-based level index (1~10).
        // Old values 1~10 are already correct as indices, no conversion needed.
        // However, if iniMax was migrated once to 11~110 (bug from earlier code),
        // treat values > 10 as indices too (they were incorrectly stored as id values).
        if (iniMax > 10) {
            // Heuristic: if value looks like an id (11,12..19,110), convert back to index
            int idx = getLevelIndex(String.valueOf(iniMax));
            if (idx > 0) iniMax = idx;
        }
        int completionMax = 1; // default unlocks first level (index 1 = id "11")
        if (TdCompletion.data != null) {
            for (Object keyObj : TdCompletion.data.keys()) {
                String key = (String) keyObj;
                int idx = getLevelIndex(key);
                if (idx > 0 && TdCompletion.hasAnyCompletion(key)) {
                    completionMax = Math.max(completionMax, idx + 1);
                }
            }
        }
        return Math.max(iniMax, completionMax);
    }

    static void setMaxLevelReached(int levelIndex) {
        cfg.set("progress", "maxLevelReached", levelIndex);
    }

    static void saveSettings() {
        if (cfg != null) cfg.save();
    }
}
