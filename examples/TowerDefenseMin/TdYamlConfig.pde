import org.yaml.snakeyaml.Yaml;
import java.io.InputStream;
import java.util.Map;
import java.util.List;

/**
 * YAML configuration loader for towers and levels.
 * Call {@link #load(PApplet)} once in setup() before any game logic.
 */
static final class TdYamlConfig {

    static Map towers;
    static List levels;

    static void load(PApplet app) {
        Yaml yaml = new Yaml();

        InputStream is1 = app.createInput("config/towers.yaml");
        if (is1 == null) throw new RuntimeException("Cannot load config/towers.yaml");
        Map root1 = yaml.load(is1);
        towers = (Map) root1.get("towers");

        InputStream is2 = app.createInput("config/levels.yaml");
        if (is2 == null) throw new RuntimeException("Cannot load config/levels.yaml");
        Map root2 = yaml.load(is2);
        levels = (List) root2.get("levels");
    }

    static TowerDef loadTowerDef(String id) {
        Map t = (Map) towers.get(id);
        if (t == null) return null;

        TowerKind kind = TowerKind.valueOf(id.toUpperCase());
        String nameKey = (String) t.get("nameKey");
        String blurbKey = (String) t.get("blurbKey");
        int cost = ((Number) t.get("cost")).intValue();
        float range = ((Number) t.get("range")).floatValue();
        float firePeriod = ((Number) t.get("firePeriod")).floatValue();
        float damage = ((Number) t.get("damage")).floatValue();
        float aoeRadius = ((Number) t.get("aoeRadius")).floatValue();
        float laserBonus = ((Number) t.get("laserBonus")).floatValue();
        float slowFactor = ((Number) t.get("slowFactor")).floatValue();
        float buildTime = ((Number) t.get("buildTime")).floatValue();

        List colorList = (List) t.get("iconColor");
        int r = ((Number) colorList.get(0)).intValue();
        int g = ((Number) colorList.get(1)).intValue();
        int b = ((Number) colorList.get(2)).intValue();
        int iconColor = 0xFF000000 | (r << 16) | (g << 8) | b;

        Map sfx = (Map) t.get("sfx");
        String sfxFire = sfx != null ? (String) sfx.get("fire") : null;
        String sfxPlace = sfx != null ? (String) sfx.get("place") : null;

        return new TowerDef(kind, nameKey, blurbKey, cost, range, firePeriod,
            damage, aoeRadius, laserBonus, slowFactor, buildTime, iconColor,
            sfxFire, sfxPlace);
    }

    static LevelData loadLevel(int levelId) {
        for (Object obj : levels) {
            Map lvl = (Map) obj;
            int id = ((Number) lvl.get("id")).intValue();
            if (id == levelId) {
                return parseLevel(lvl);
            }
        }
        return null;
    }

    static int getLevelCount() {
        return levels != null ? levels.size() : 0;
    }

    private static LevelData parseLevel(Map lvl) {
        LevelData ld = new LevelData();
        ld.id = ((Number) lvl.get("id")).intValue();
        ld.nameKey = (String) lvl.get("nameKey");
        ld.subtitleKey = (String) lvl.get("subtitleKey");
        ld.initialMoney = ((Number) lvl.get("initialMoney")).intValue();
        ld.initialOrbs = ((Number) lvl.get("initialOrbs")).intValue();
        ld.totalWaves = ((Number) lvl.get("totalWaves")).intValue();

        Map enemy = (Map) lvl.get("enemy");
        ld.enemyHpBase = ((Number) enemy.get("hpBase")).floatValue();
        ld.enemyHpPerWave = ((Number) enemy.get("hpPerWave")).floatValue();
        ld.enemySpeed = ((Number) enemy.get("speed")).floatValue();
        ld.enemyCountBase = ((Number) enemy.get("countBase")).intValue();
        ld.enemyCountPerWave = ((Number) enemy.get("countPerWave")).intValue();

        ld.spawnCooldown = ((Number) lvl.get("spawnCooldown")).floatValue();
        ld.interWaveDelay = ((Number) lvl.get("interWaveDelay")).floatValue();

        List pathList = (List) lvl.get("path");
        ld.pathPercent = new float[pathList.size()][2];
        for (int i = 0; i < pathList.size(); i++) {
            List pt = (List) pathList.get(i);
            ld.pathPercent[i][0] = ((Number) pt.get(0)).floatValue();
            ld.pathPercent[i][1] = ((Number) pt.get(1)).floatValue();
        }

        return ld;
    }
}

/** Tower definition data object (mutable fields loaded from YAML). */
static final class TowerDef {
    final TowerKind kind;
    final String nameKey;
    final String blurbKey;
    final int cost;
    final float range;
    final float firePeriod;
    final float damage;
    final float aoeRadius;
    final float laserBonus;
    final float slowFactor;
    final float buildTime;
    final int iconColor;
    final String sfxFire;
    final String sfxPlace;

    TowerDef(TowerKind kind, String nameKey, String blurbKey, int cost, float range,
             float firePeriod, float damage, float aoeRadius, float laserBonus,
             float slowFactor, float buildTime, int iconColor,
             String sfxFire, String sfxPlace) {
        this.kind = kind;
        this.nameKey = nameKey;
        this.blurbKey = blurbKey;
        this.cost = cost;
        this.range = range;
        this.firePeriod = firePeriod;
        this.damage = damage;
        this.aoeRadius = aoeRadius;
        this.laserBonus = laserBonus;
        this.slowFactor = slowFactor;
        this.buildTime = buildTime;
        this.iconColor = iconColor;
        this.sfxFire = sfxFire;
        this.sfxPlace = sfxPlace;
    }

    static TowerDef forKind(TowerKind k) {
        return TdYamlConfig.loadTowerDef(k.name().toLowerCase());
    }
}

/** Level data object loaded from YAML. */
static final class LevelData {
    int id;
    String nameKey;
    String subtitleKey;
    int initialMoney;
    int initialOrbs;
    int totalWaves;
    float enemyHpBase;
    float enemyHpPerWave;
    float enemySpeed;
    int enemyCountBase;
    int enemyCountPerWave;
    float spawnCooldown;
    float interWaveDelay;
    float[][] pathPercent;
}
