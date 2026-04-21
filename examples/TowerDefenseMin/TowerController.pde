/** Tower behaviour; must stay {@code public static} for {@code addComponent(TowerController.class)}. */
public static class TowerController extends Component {
  TowerKind kind = TowerKind.MG;
  float cooldown;
  /** Elapsed build time in seconds until {@link #isOperational()}. */
  float buildAccum;

  boolean isOperational() {
    return buildAccum >= TdConfig.TOWER_BUILD_SECONDS;
  }

  float buildProgress01() {
    return min(1f, buildAccum / TdConfig.TOWER_BUILD_SECONDS);
  }

  void tick(TdGameWorld world, float dt, Vector2 pos) {
    if (!isOperational()) {
      buildAccum += dt;
      return;
    }
    TowerDef d = TowerDef.forKind(kind);
    if (kind == TowerKind.SLOW) {
      cooldown -= dt;
      if (cooldown > 0) return;
      world.addSlowRipple(pos.x, pos.y);
      cooldown = d.firePeriod > 0.05f ? d.firePeriod : 0.72f;
      if (world.app.flow != null) world.app.flow.playSfx("data/sounds/ambient-swoosh.wav");
      return;
    }

    cooldown -= dt;
    if (cooldown > 0) return;

    TdEnemy tgt = world.findNearestAliveEnemy(pos, d.range);
    if (tgt == null) {
      cooldown = d.firePeriod;
      return;
    }
    Vector2 ep = world.path.sample(tgt.s);

    if (kind == TowerKind.MISSILE) {
      world.addBoltFx(TowerKind.MISSILE, pos.x, pos.y, ep.x, ep.y);
      world.damageEnemyNearest(pos, d.range, d.damage, d.aoeRadius, true);
      if (world.app.flow != null) world.app.flow.playSfx("data/sounds/synthetic-honk.wav");
    } else if (kind == TowerKind.LASER) {
      world.addBoltFx(TowerKind.LASER, pos.x, pos.y, ep.x, ep.y);
      world.damageEnemyNearest(pos, d.range, d.damage, 0, false);
      if (world.app.flow != null) world.app.flow.playSfx("data/sounds/synthetic-rave.wav");
    } else {
      world.addBoltFx(TowerKind.MG, pos.x, pos.y, ep.x, ep.y);
      world.damageEnemyNearest(pos, d.range, d.damage, 0, false);
      if (world.app.flow != null) world.app.flow.playSfx("data/sounds/synthetic-spike.wav");
    }
    cooldown = d.firePeriod;
  }
}
