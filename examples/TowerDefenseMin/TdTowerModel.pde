/** Tower taxonomy + numeric definitions (extend here + UI button). */
enum TowerKind {
  MG, MISSILE, LASER, SLOW
}

static final class TowerDef {
  final TowerKind kind;
  final String name;
  final String blurb;
  final int cost;
  final float range;
  final float firePeriod;
  final float damage;
  final float aoeRadius;
  final float laserBonus;
  final float slowFactor;
  final int iconColor;

  TowerDef(TowerKind kind, String name, String blurb, int cost, float range,
    float firePeriod, float damage, float aoeRadius, float laserBonus, float slowFactor, int iconColor) {
    this.kind = kind;
    this.name = name;
    this.blurb = blurb;
    this.cost = cost;
    this.range = range;
    this.firePeriod = firePeriod;
    this.damage = damage;
    this.aoeRadius = aoeRadius;
    this.laserBonus = laserBonus;
    this.slowFactor = slowFactor;
    this.iconColor = iconColor;
  }

  static TowerDef forKind(TowerKind k) {
    switch (k) {
      case MG:
        return new TowerDef(k, "机枪", "高射速，单体最近。", 80, 190f, 0.11f, 7f, 0, 0, 1f, inst.color(120, 200, 255));
      case MISSILE:
        return new TowerDef(k, "导弹", "远程小范围溅射。", 150, 300f, 0.85f, 38f, 52f, 0, 1f, inst.color(255, 180, 80));
      case LASER:
        return new TowerDef(k, "激光", "长冷却，高单发。", 200, 400f, 2.1f, 115f, 0, 0, 1f, inst.color(255, 80, 220));
      case SLOW:
        return new TowerDef(k, "减速", "范围内时间减速。", 100, 130f, 0.72f, 0, 130f, 0, 0.38f, inst.color(160, 255, 200));
      default:
        return new TowerDef(k, "减速", "范围内时间减速。", 100, 130f, 0.72f, 0, 130f, 0, 0.38f, inst.color(160, 255, 200));
    }
  }
}
