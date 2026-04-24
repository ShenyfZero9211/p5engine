/**
 * Asset loading: i18n, YAML configs, audio init.
 */
static final class TdAssets {

    // ── Load all ──

    static void loadAll(PApplet app) {
        loadConfigs(app);
        loadI18n(P5Engine.getInstance());
    }

    // ── i18n ──

    static void loadI18n(P5Engine engine) {
        // I18n auto-loads data/i18n/{locale}.json on setLocale
        engine.getI18n().setLocale("zh");
    }

    static String i18n(String key) {
        return P5Engine.getInstance().getI18n().get(key);
    }

    static String i18n(String key, Object... args) {
        return P5Engine.getInstance().getI18n().get(key, args);
    }

    // ── YAML configs ──

    static java.util.Map towerYamlRoot;
    static java.util.List levelYamlList;

    static void loadConfigs(PApplet app) {
        org.yaml.snakeyaml.Yaml yaml = new org.yaml.snakeyaml.Yaml();

        java.io.InputStream tis = app.createInput("config/towers.yaml");
        if (tis == null) throw new RuntimeException("Cannot load config/towers.yaml");
        towerYamlRoot = (java.util.Map) yaml.load(tis);

        java.io.InputStream lis = app.createInput("config/levels.yaml");
        if (lis == null) throw new RuntimeException("Cannot load config/levels.yaml");
        levelYamlList = (java.util.List) yaml.load(lis);
    }

    static TowerDef loadTowerDef(TowerType type) {
        String id = type.name().toLowerCase();
        java.util.Map towers = (java.util.Map) towerYamlRoot.get("towers");
        java.util.Map t = (java.util.Map) towers.get(id);
        if (t == null) return null;

        java.util.List c = (java.util.List) t.get("iconColor");
        int iconColor = 0xFF000000 | (((Number)c.get(0)).intValue() << 16)
                                      | (((Number)c.get(1)).intValue() << 8)
                                      | ((Number)c.get(2)).intValue();

        java.util.Map sfx = (java.util.Map) t.get("sfx");

        return new TowerDef(
            type,
            (String) t.get("nameKey"),
            (String) t.get("descKey"),
            ((Number) t.get("cost")).intValue(),
            ((Number) t.get("range")).floatValue(),
            ((Number) t.get("firePeriod")).floatValue(),
            ((Number) t.get("damage")).floatValue(),
            ((Number) t.get("aoeRadius")).floatValue(),
            ((Number) t.get("laserBonus")).floatValue(),
            ((Number) t.get("slowFactor")).floatValue(),
            ((Number) t.get("buildTime")).floatValue(),
            iconColor,
            sfx != null ? (String) sfx.get("fire") : null,
            sfx != null ? (String) sfx.get("place") : null
        );
    }

    static LevelDef loadLevel(int levelId) {
        for (Object obj : levelYamlList) {
            java.util.Map lvl = (java.util.Map) obj;
            int id = ((Number) lvl.get("id")).intValue();
            if (id == levelId) {
                return parseLevel(lvl);
            }
        }
        return null;
    }

    static int getLevelCount() {
        return levelYamlList != null ? levelYamlList.size() : 0;
    }

    private static LevelDef parseLevel(java.util.Map lvl) {
        LevelDef ld = new LevelDef();
        ld.id = ((Number) lvl.get("id")).intValue();
        ld.nameKey = (String) lvl.get("nameKey");
        ld.subtitleKey = (String) lvl.get("subtitleKey");
        ld.initialMoney = ((Number) lvl.get("initialMoney")).intValue();
        ld.initialOrbs = ((Number) lvl.get("initialOrbs")).intValue();
        ld.totalWaves = ((Number) lvl.get("totalWaves")).intValue();
        ld.worldW = ((Number) lvl.get("worldWidth")).intValue();
        ld.worldH = ((Number) lvl.get("worldHeight")).intValue();

        java.util.Map enemy = (java.util.Map) lvl.get("enemy");
        ld.enemyHpBase = ((Number) enemy.get("hpBase")).floatValue();
        ld.enemyHpPerWave = ((Number) enemy.get("hpPerWave")).floatValue();
        ld.enemySpeed = ((Number) enemy.get("speed")).floatValue();
        ld.enemyCountBase = ((Number) enemy.get("countBase")).intValue();
        ld.enemyCountPerWave = ((Number) enemy.get("countPerWave")).intValue();

        ld.spawnCooldown = ((Number) lvl.get("spawnCooldown")).floatValue();
        ld.interWaveDelay = ((Number) lvl.get("interWaveDelay")).floatValue();

        // Positions
        java.util.Map base = (java.util.Map) lvl.get("basePos");
        ld.basePos = new Vector2(((Number)base.get("x")).floatValue(), ((Number)base.get("y")).floatValue());
        java.util.Map exit = (java.util.Map) lvl.get("exitPos");
        ld.exitPos = new Vector2(((Number)exit.get("x")).floatValue(), ((Number)exit.get("y")).floatValue());
        java.util.Map spawn = (java.util.Map) lvl.get("spawnPos");
        ld.spawnPos = new Vector2(((Number)spawn.get("x")).floatValue(), ((Number)spawn.get("y")).floatValue());

        // Path points
        java.util.List pts = (java.util.List) lvl.get("pathPoints");
        ld.pathPoints = new Vector2[pts.size()];
        for (int i = 0; i < pts.size(); i++) {
            java.util.Map p = (java.util.Map) pts.get(i);
            ld.pathPoints[i] = new Vector2(((Number)p.get("x")).floatValue(), ((Number)p.get("y")).floatValue());
        }

        return ld;
    }

    // ── Audio helpers ──

    static void playSfx(String path) {
        try {
            P5Engine.getInstance().getAudio().playOneShot(path, "sfx");
        } catch (Exception e) {
            // ignore audio errors during development
        }
    }

    static void setMasterVolume(float v) {
        P5Engine.getInstance().getAudio().setMasterVolume(v);
    }

    static void setBgmVolume(float v) {
        P5Engine.getInstance().getAudio().setGroupVolume("bgm", v);
    }

    static void setSfxVolume(float v) {
        P5Engine.getInstance().getAudio().setGroupVolume("sfx", v);
    }
}
