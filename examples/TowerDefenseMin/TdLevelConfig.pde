/**
 * Level configuration loaded from YAML.
 * All numeric data comes from {@link LevelData} parsed by {@link TdYamlConfig}.
 */
static final class TdLevelConfig {

    private TdLevelConfig() {}

    static int getTotalLevels() {
        return TdYamlConfig.getLevelCount();
    }

    static LevelData getLevel(int level) {
        LevelData ld = TdYamlConfig.loadLevel(level);
        return ld != null ? ld : TdYamlConfig.loadLevel(1);
    }

    static String getLevelNameKey(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.nameKey : "level.unknown";
    }

    static String getLevelSubtitleKey(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.subtitleKey : "";
    }

    static int getInitialMoney(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.initialMoney : 420;
    }

    static int getInitialOrbs(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.initialOrbs : 3;
    }

    static int getTotalWaves(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.totalWaves : 5;
    }

    static float getEnemyHpBase(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.enemyHpBase : 55f;
    }

    static float getEnemyHpPerWave(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.enemyHpPerWave : 14f;
    }

    static float getEnemySpeed(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.enemySpeed : 62f;
    }

    static int getEnemyCountBase(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.enemyCountBase : 4;
    }

    static int getEnemyCountPerWave(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.enemyCountPerWave : 2;
    }

    static float getSpawnCooldown(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.spawnCooldown : 1.1f;
    }

    static float getInterWaveDelay(int level) {
        LevelData ld = getLevel(level);
        return ld != null ? ld.interWaveDelay : 2.4f;
    }
}

/**
 * Level path configuration — converts YAML percentage coordinates to world coordinates.
 */
static final class TdLevelPath {

    static Vector2[][] levelPaths = new Vector2[4][];
    static boolean pathsInitialized = false;

    static synchronized void initPaths(PApplet app, float worldW, float worldH) {
        if (pathsInitialized) return;

        int totalLevels = TdLevelConfig.getTotalLevels();
        levelPaths = new Vector2[totalLevels + 1][];

        for (int lvl = 1; lvl <= totalLevels; lvl++) {
            LevelData ld = TdLevelConfig.getLevel(lvl);
            if (ld == null || ld.pathPercent == null) continue;

            Vector2[] pts = new Vector2[ld.pathPercent.length];
            for (int i = 0; i < ld.pathPercent.length; i++) {
                float px = ld.pathPercent[i][0] * worldW;
                float py = ld.pathPercent[i][1] * worldH;
                pts[i] = new Vector2(px, py);
            }
            levelPaths[lvl] = pts;
        }

        pathsInitialized = true;
    }

    static Vector2[] getPath(int level) {
        if (level < 1 || level >= levelPaths.length) return levelPaths[1];
        return levelPaths[level];
    }
}
