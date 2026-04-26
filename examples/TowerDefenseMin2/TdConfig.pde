/**
 * TowerDefenseMin2 — Global constants and configuration.
 */
static final class TdConfig {

    // ── Display ──
    static final int DESIGN_W = 1280;
    static final int DESIGN_H = 720;
    static final int TOP_HUD = 48;
    static final int RIGHT_W = 240;
    static final int WORLD_W = 1280 - RIGHT_W;
    static final int WORLD_H = 720 - TOP_HUD;

    // ── World ──
    static final int GRID = 40;
    static final int WORLD_MAP_W = 2400;
    static final int WORLD_MAP_H = 1600;

    // ── Colors (Sci-Fi dark theme) ──
    static final int C_BG_DARK   = 0xFF0E1222;
    static final int C_BG_PANEL  = 0xFF1A2035;
    static final int C_BORDER    = 0xFF2A3A55;
    static final int C_ACCENT    = 0xFF4A9EFF;
    static final int C_HIGHLIGHT = 0xFFFF8C42;
    static final int C_TEXT      = 0xFFE0E6F0;
    static final int C_TEXT_DIM  = 0xFF8899AA;
    static final int C_PATH      = 0xFF3A5068;
    static final int C_BASE      = 0xFF28C76F;
    static final int C_EXIT      = 0xFFFF5B5B;
    static final int C_ORB       = 0xFFFFD700;
    static final int C_ENEMY     = 0xFFFF6B6B;
    static final int C_GHOST_OK  = 0xFF4A9EFF;
    static final int C_GHOST_BAD = 0xFFFF5B5B;

    // ── Camera ──
    static final float CAM_MIN_ZOOM = 0.4f;
    static final float CAM_MAX_ZOOM = 3.0f;
    static final float CAM_EDGE_SCROLL_SPEED = 480f; // design pixels/sec
    static final int CAM_EDGE_MARGIN = 20; // actual pixels

    // ── Towers ──
    static final float TOWER_BUILD_TIME = 0.8f;
    static final float TOWER_SNAP_RADIUS = 36f;

    // ── Game ──
    static final int INITIAL_MONEY = 420;
    static final int MAX_LEVELS = 7;
    static final float ENEMY_RADIUS = 14;
    static final int KILL_REWARD_BASE = 15;
}

/**
 * Tower type enum. Actual stats loaded from YAML at runtime.
 */
enum TowerType {
    MG,       // Machine Gun — fast, low dmg, single target
    MISSILE,  // Missile — slow, high dmg, AOE
    LASER,    // Laser — continuous beam, armor piercing
    SLOW;     // Slow — no dmg, slows enemies in range

    static TowerType fromBuildMode(TdBuildMode mode) {
        switch (mode) {
            case MG: return MG;
            case MISSILE: return MISSILE;
            case LASER: return LASER;
            case SLOW: return SLOW;
            default: return null;
        }
    }

    static TdBuildMode toBuildMode(TowerType type) {
        switch (type) {
            case MG: return TdBuildMode.MG;
            case MISSILE: return TdBuildMode.MISSILE;
            case LASER: return TdBuildMode.LASER;
            case SLOW: return TdBuildMode.SLOW;
            default: return TdBuildMode.NONE;
        }
    }
}

/**
 * Mutable tower definition loaded from towers.yaml.
 */
static final class TowerDef {
    final TowerType type;
    final String nameKey;
    final String descKey;
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
    final String sfxComplete;

    TowerDef(TowerType type, String nameKey, String descKey, int cost, float range,
             float firePeriod, float damage, float aoeRadius, float laserBonus,
             float slowFactor, float buildTime, int iconColor,
             String sfxFire, String sfxPlace, String sfxComplete) {
        this.type = type;
        this.nameKey = nameKey;
        this.descKey = descKey;
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
        this.sfxComplete = sfxComplete;
    }
}

/**
 * Level definition loaded from levels.yaml.
 */
static final class LevelDef {
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
    Vector2[] pathPoints;
    Vector2 basePos;
    Vector2 exitPos;
    Vector2 spawnPos;
    int worldW;
    int worldH;
}

/**
 * Per-wave configuration.
 */
static final class WaveDef {
    int enemyCount;
    float hp;
    float speed;
    float interval;
    float reward;
}
