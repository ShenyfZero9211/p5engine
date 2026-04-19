/** Enemies and rolling orbs (minimal TD entities). */
static final class TdEnemy {
  float s;
  float speed = 62f;
  float hp;
  float hpMax;
  /** Wave index when this unit was spawned (for rewards / tuning). */
  final int spawnWave;
  boolean alive = true;
  int phase;
  boolean stoleTriggered;
  boolean carriedOrb;
  float slowMul = 1f;

  TdEnemy(int spawnWave, float hpMult) {
    this.spawnWave = spawnWave;
    s = 0;
    hpMax = 55f + spawnWave * 14f;
    hp = hpMax * hpMult;
  }
}

static final class TdRollingOrb {
  float s;

  TdRollingOrb(float s0) {
    this.s = s0;
  }
}
