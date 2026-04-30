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
 * Level type enum.
 */
enum LevelType {
    DEFEND_BASE,   // 守护基地：保护能量球不被全部夺走
    SURVIVAL       // 生存模式：控制敌人逃离数量
}

/**
 * Route type for multi-path levels.
 */
enum RouteType {
    INBOUND,    // spawn -> base
    OUTBOUND,   // base -> exit
    DIRECT      // spawn -> exit (no base)
}

/**
 * A named path route in a level. Reuses TdPath as the underlying polyline.
 */
static final class PathRoute {
    public String id;
    public RouteType type;
    public TdPath path;
    public int baseIndex;      // index of base point in path.points (-1 if not applicable)
    public float baseDistance; // distance along path to the base point

    PathRoute(String id, RouteType type, Vector2[] points, Vector2 basePos) {
        this.id = id;
        this.type = type;
        this.path = new TdPath(points);
        if (basePos != null) {
            this.baseDistance = this.path.closestDistanceTo(basePos);
            // Find closest point index
            this.baseIndex = -1;
            float bestD = Float.MAX_VALUE;
            for (int i = 0; i < points.length; i++) {
                float d = points[i].distance(basePos);
                if (d < bestD) {
                    bestD = d;
                    baseIndex = i;
                }
            }
        } else {
            this.baseDistance = -1;
            this.baseIndex = -1;
        }
    }
}

/**
 * Enemy definition loaded from enemies.yaml.
 */
static final class EnemyDef {
    final String key;
    final String nameKey;
    final float speedMultiplier;
    final float hpMultiplier;
    final int orbCapacity;
    final float radius;
    final String sfxDeath;

    EnemyDef(String key, String nameKey, float speedMultiplier, float hpMultiplier,
             int orbCapacity, float radius, String sfxDeath) {
        this.key = key;
        this.nameKey = nameKey;
        this.speedMultiplier = speedMultiplier;
        this.hpMultiplier = hpMultiplier;
        this.orbCapacity = orbCapacity;
        this.radius = radius;
        this.sfxDeath = sfxDeath;
    }
}

/**
 * Per-enemy-type spawn config within a wave.
 */
static final class WaveSpawn {
    final String enemyType;
    final int count;
    final float interval;
    final String route;      // optional path route id

    WaveSpawn(String enemyType, int count, float interval, String route) {
        this.enemyType = enemyType;
        this.count = count;
        this.interval = interval;
        this.route = route;
    }
}

/**
 * Per-wave configuration.
 */
static final class WaveDef {
    final float delay;
    final WaveSpawn[] spawns;

    WaveDef(float delay, WaveSpawn[] spawns) {
        this.delay = delay;
        this.spawns = spawns;
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
    final float slowDuration;
    final float laserDelay;
    final float buildTime;
    final int iconColor;
    final String sfxFire;
    final String sfxPlace;
    final String sfxComplete;

    TowerDef(TowerType type, String nameKey, String descKey, int cost, float range,
             float firePeriod, float damage, float aoeRadius, float laserBonus,
             float slowFactor, float slowDuration, float laserDelay, float buildTime, int iconColor,
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
        this.slowDuration = slowDuration;
        this.laserDelay = laserDelay;
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
    LevelType levelType;
    int initialMoney;
    int baseOrbs;        // DEFEND_BASE: 基地能量球总数
    int maxEscapeCount;  // SURVIVAL: 最大允许逃离敌人数
    float enemyHpBase;
    Vector2[] pathPoints;      // legacy single-path format (kept for compatibility)
    PathRoute[] paths;         // new multi-path format
    Vector2 basePos;
    Vector2 exitPos;
    Vector2 spawnPos;
    int worldW;
    int worldH;
    WaveDef[] waves;
    TowerType[] allowedTowers; // null = all towers allowed
    boolean earnMoneyOnKill;   // default true
}

enum TdState { MENU, LEVEL_SELECT, SETTINGS, PLAYING, PAUSED, WIN, LOSE }
enum TdBuildMode { NONE, MG, MISSILE, LASER, SLOW }
