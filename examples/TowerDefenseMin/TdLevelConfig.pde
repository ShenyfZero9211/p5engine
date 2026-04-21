/**
 * 塔防游戏关卡配置系统
 * 定义三个关卡的路径、难度参数和游戏设置
 */
static final class TdLevelConfig {

  private TdLevelConfig() {
  }

  /** 关卡总数 */
  static final int TOTAL_LEVELS = 3;

  /** 关卡名称 i18n key */
  static final String[] LEVEL_NAME_KEYS = {
    "level.1.name",
    "level.2.name",
    "level.3.name"
  };

  /** 关卡副标题 i18n key */
  static final String[] LEVEL_SUBTITLE_KEYS = {
    "level.1.subtitle",
    "level.2.subtitle",
    "level.3.subtitle"
  };

  /** 初始金钱 */
  static final int[] INITIAL_MONEY = { 420, 380, 350 };

  /** 基地球数量 */
  static final int[] INITIAL_ORBS = { 3, 3, 2 };

  /** 总波次 */
  static final int[] TOTAL_WAVES = { 5, 6, 7 };

  /** 敌人HP基数 = baseHp + spawnWave * hpPerWave */
  static final float[] ENEMY_HP_BASE = { 55f, 70f, 90f };
  static final float[] ENEMY_HP_PER_WAVE = { 14f, 18f, 22f };

  /** 敌人基础速度 */
  static final float[] ENEMY_SPEED = { 62f, 68f, 72f };

  /** 每波敌人生成数量 = baseCount + wave * countPerWave */
  static final int[] ENEMY_COUNT_BASE = { 4, 5, 6 };
  static final int[] ENEMY_COUNT_PER_WAVE = { 2, 2, 2 };

  /** 敌人生成冷却时间 */
  static final float[] SPAWN_COOLDOWN = { 1.1f, 1.0f, 0.9f };

  /** 波次间隔时间 */
  static final float[] INTER_WAVE_DELAY = { 2.4f, 2.0f, 1.8f };

  /** 路径是否已初始化 */
  static boolean pathsInitialized = false;

  /** 获取关卡名称 i18n key */
  static String getLevelNameKey(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return "level.unknown";
    return LEVEL_NAME_KEYS[level - 1];
  }

  /** 获取关卡副标题 i18n key */
  static String getLevelSubtitleKey(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return "";
    return LEVEL_SUBTITLE_KEYS[level - 1];
  }

  /** 获取初始金钱 */
  static int getInitialMoney(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return INITIAL_MONEY[0];
    return INITIAL_MONEY[level - 1];
  }

  /** 获取基地球数量 */
  static int getInitialOrbs(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return INITIAL_ORBS[0];
    return INITIAL_ORBS[level - 1];
  }

  /** 获取总波次 */
  static int getTotalWaves(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return TOTAL_WAVES[0];
    return TOTAL_WAVES[level - 1];
  }

  /** 获取敌人HP基数 */
  static float getEnemyHpBase(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return ENEMY_HP_BASE[0];
    return ENEMY_HP_BASE[level - 1];
  }

  /** 获取敌人每波HP增长 */
  static float getEnemyHpPerWave(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return ENEMY_HP_PER_WAVE[0];
    return ENEMY_HP_PER_WAVE[level - 1];
  }

  /** 获取敌人基础速度 */
  static float getEnemySpeed(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return ENEMY_SPEED[0];
    return ENEMY_SPEED[level - 1];
  }

  /** 获取敌人生成数量基数 */
  static int getEnemyCountBase(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return ENEMY_COUNT_BASE[0];
    return ENEMY_COUNT_BASE[level - 1];
  }

  /** 获取敌人生成数量每波增长 */
  static int getEnemyCountPerWave(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return ENEMY_COUNT_PER_WAVE[0];
    return ENEMY_COUNT_PER_WAVE[level - 1];
  }

  /** 获取敌人生成冷却时间 */
  static float getSpawnCooldown(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return SPAWN_COOLDOWN[0];
    return SPAWN_COOLDOWN[level - 1];
  }

  /** 获取波次间隔时间 */
  static float getInterWaveDelay(int level) {
    if (level < 1 || level > TOTAL_LEVELS) return INTER_WAVE_DELAY[0];
    return INTER_WAVE_DELAY[level - 1];
  }
}

/**
 * 关卡路径配置 - 每个关卡都有独特的敌人行进路径
 * 路径使用相对于游戏区域宽高的百分比坐标，在 setup() 时初始化一次
 */
static final class TdLevelPath {

  /** 关卡路径点数组 - 索引1-3对应关卡1-3 */
  static Vector2[][] levelPaths = new Vector2[4][];

  /**
   * 初始化所有关卡的路径
   * 只初始化一次，确保在游戏开始前调用
   */
  static synchronized void initPaths(PApplet app) {
    if (TdLevelConfig.pathsInitialized) {
      return; // 已初始化，跳过
    }
    
    int pw = app.width - TdConfig.RIGHT_W;
    int ph = app.height - TdConfig.TOP_HUD;

    // 第一关 - 新手试炼（较直的路径）
    levelPaths[1] = new Vector2[] {
      new Vector2(48, ph * 0.12f),
      new Vector2(pw * 0.18f, ph * 0.22f),
      new Vector2(pw * 0.32f, ph * 0.38f),
      new Vector2(pw * 0.44f, ph * 0.52f),
      new Vector2(pw * 0.52f, ph * 0.48f),
      new Vector2(pw * 0.66f, ph * 0.62f),
      new Vector2(pw * 0.82f, ph * 0.78f),
      new Vector2(pw - 40, ph - 36)
    };

    // 第二关 - 强化防线（S形曲折路径）
    levelPaths[2] = new Vector2[] {
      new Vector2(48, ph * 0.10f),
      new Vector2(pw * 0.25f, ph * 0.10f),
      new Vector2(pw * 0.25f, ph * 0.40f),
      new Vector2(pw * 0.50f, ph * 0.40f),
      new Vector2(pw * 0.50f, ph * 0.70f),
      new Vector2(pw * 0.75f, ph * 0.70f),
      new Vector2(pw * 0.75f, ph * 0.45f),
      new Vector2(pw - 40, ph * 0.45f)
    };

    // 第三关 - 极限挑战（复杂回旋路径）
    levelPaths[3] = new Vector2[] {
      new Vector2(48, ph * 0.08f),
      new Vector2(pw * 0.20f, ph * 0.08f),
      new Vector2(pw * 0.20f, ph * 0.35f),
      new Vector2(pw * 0.40f, ph * 0.35f),
      new Vector2(pw * 0.40f, ph * 0.15f),
      new Vector2(pw * 0.60f, ph * 0.15f),
      new Vector2(pw * 0.60f, ph * 0.55f),
      new Vector2(pw * 0.80f, ph * 0.55f),
      new Vector2(pw * 0.80f, ph * 0.30f),
      new Vector2(pw - 40, ph * 0.30f)
    };
    
    TdLevelConfig.pathsInitialized = true;
  }

  /** 获取指定关卡的路径点 */
  static Vector2[] getPath(int level) {
    if (level < 1 || level > TdLevelConfig.TOTAL_LEVELS) return levelPaths[1];
    return levelPaths[level];
  }
}
