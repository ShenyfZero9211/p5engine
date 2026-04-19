/** Layout and balance constants (sketch-local). */
static final class TdConfig {

  private TdConfig() {
  }

  static final int TOP_HUD = 40;
  static final int RIGHT_W = 240;
  static final int GRID = 40;
  /** Seconds after purchase before a tower attacks or applies slow. */
  static final float TOWER_BUILD_SECONDS = 2.25f;
  static final int INITIAL_ORBS = 3;
  static final int INITIAL_MONEY = 420;
  /** Per-kill income: scales with spawn wave and max HP so late waves pay more. */
  static final int KILL_REWARD_BASE = 10;
  static final int KILL_REWARD_PER_WAVE = 4;
  static final float KILL_REWARD_HP_FRAC = 0.06f;
  static final int TOTAL_WAVES = 5;
  static final float PICKUP_R = 48f;
  static final float ROLL_SPEED = 70f;
  /** Vertices per tower range ring (polygon outline); avoids huge P2D ellipse stroke cost. */
  static final int RANGE_RING_SEGMENTS = 40;

  static int killRewardFor(TdEnemy e) {
    return KILL_REWARD_BASE + e.spawnWave * KILL_REWARD_PER_WAVE + max(0, (int) (e.hpMax * KILL_REWARD_HP_FRAC));
  }
}
