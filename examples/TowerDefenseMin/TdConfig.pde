/** Layout and balance constants (sketch-local). Pure layout values only — tower and level data now live in YAML. */
static final class TdConfig {

  private TdConfig() {}

  static final int TOP_HUD = 40;
  static final int RIGHT_W = 240;
  static final int GRID = 40;

  static final int KILL_REWARD_BASE = 10;
  static final int KILL_REWARD_PER_WAVE = 4;
  static final float KILL_REWARD_HP_FRAC = 0.06f;

  static final float PICKUP_R = 48f;
  static final float ROLL_SPEED = 70f;
  static final int RANGE_RING_SEGMENTS = 40;

  static int killRewardFor(TdEnemy e) {
    return KILL_REWARD_BASE + e.spawnWave * KILL_REWARD_PER_WAVE + max(0, (int) (e.hpMax * KILL_REWARD_HP_FRAC));
  }
}
