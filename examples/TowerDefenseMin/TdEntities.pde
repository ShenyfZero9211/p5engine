/** Enemies and rolling orbs (minimal TD entities). */
static final class TdEnemy {
  float s;
  float speed;
  float hp;
  float hpMax;
  /** Wave index when this unit was spawned (for rewards / tuning). */
  final int spawnWave;
  /** 当前关卡ID，用于获取敌人属性 */
  final int level;
  boolean alive = true;
  int phase;
  boolean stoleTriggered;
  boolean carriedOrb;
  float slowMul = 1f;

  TdEnemy(int spawnWave, int level, float hpMult) {
    this.spawnWave = spawnWave;
    this.level = level;
    s = 0;
    // 使用当前关卡的敌人属性配置
    hpMax = TdLevelConfig.getEnemyHpBase(level) 
            + spawnWave * TdLevelConfig.getEnemyHpPerWave(level);
    hp = hpMax * hpMult;
    speed = TdLevelConfig.getEnemySpeed(level);
  }
}

static final class TdRollingOrb {
  float s;

  TdRollingOrb(float s0) {
    this.s = s0;
  }
}
