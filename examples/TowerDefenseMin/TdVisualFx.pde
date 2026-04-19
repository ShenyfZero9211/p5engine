/** Battlefield-only VFX (coordinates are playfield Y, same space as path / towers). */
static final class TdFxBolt {

  final TowerKind kind;
  final float sx;
  final float sy;
  final float ex;
  final float ey;
  float age;
  final float flyDur;
  float impactAge;

  TdFxBolt(TowerKind k, float sx, float sy, float ex, float ey) {
    this.kind = k;
    this.sx = sx;
    this.sy = sy;
    this.ex = ex;
    this.ey = ey;
    this.age = 0;
    if (k == TowerKind.MISSILE) {
      flyDur = 0.2f;
    } else if (k == TowerKind.LASER) {
      flyDur = 0.07f;
    } else {
      flyDur = 0.085f;
    }
    this.impactAge = -1f;
  }

  boolean update(float dt) {
    age += dt;
    if (kind == TowerKind.MISSILE) {
      if (age >= flyDur) {
        if (impactAge < 0f) impactAge = 0f;
        impactAge += dt;
        return impactAge < 0.16f;
      }
      return true;
    }
    return age < flyDur;
  }

  float travelT() {
    return min(1f, age / flyDur);
  }

  void draw(PApplet g) {
    if (kind == TowerKind.MISSILE && impactAge >= 0f) {
      float k = impactAge / 0.16f;
      float alpha = g.lerp(220, 0, k);
      g.pushStyle();
      g.noFill();
      g.stroke(255, 200, 80, alpha);
      g.strokeWeight(3);
      float r0 = g.lerp(10f, 48f, k);
      g.ellipse(ex, ey, r0 * 2, r0 * 2);
      g.stroke(255, 120, 40, alpha * 0.55f);
      g.strokeWeight(2);
      g.ellipse(ex, ey, r0 * 2.6f, r0 * 2.6f);
      g.popStyle();
      return;
    }
    float t = travelT();
    float x = g.lerp(sx, ex, t);
    float y = g.lerp(sy, ey, t);
    g.pushStyle();
    if (kind == TowerKind.LASER) {
      g.stroke(255, 90, 240, g.lerp(40, 220, min(1f, t * 4f)));
      g.strokeWeight(5);
      g.line(sx, sy, ex, ey);
      g.strokeWeight(2);
      g.stroke(255, 220, 255, 200);
      g.line(sx, sy, ex, ey);
    } else if (kind == TowerKind.MISSILE) {
      g.stroke(255, 170, 70, 200);
      g.strokeWeight(4);
      g.line(sx, sy, x, y);
      g.noStroke();
      g.fill(255, 230, 160);
      g.ellipse(x, y, 10, 10);
    } else {
      g.stroke(255, 240, 120, 210);
      g.strokeWeight(2);
      g.line(sx, sy, x, y);
      g.noStroke();
      g.fill(255, 255, 200);
      g.ellipse(x, y, 6, 6);
    }
    g.popStyle();
  }
}

static final class TdSlowRipple {

  final float x;
  final float y;
  float age;
  final float dur;
  final float maxR;

  TdSlowRipple(float x, float y) {
    this.x = x;
    this.y = y;
    this.age = 0;
    this.dur = 0.4f;
    this.maxR = TowerDef.forKind(TowerKind.SLOW).aoeRadius * 0.9f;
  }

  boolean update(float dt) {
    age += dt;
    return age < dur;
  }

  void draw(PApplet g) {
    float p = min(1f, age / dur);
    float r = maxR * p;
    float alpha = g.lerp(160, 0, p);
    g.pushStyle();
    g.noFill();
    g.stroke(120, 255, 200, alpha);
    g.strokeWeight(2);
    g.ellipse(x, y, r * 2, r * 2);
    g.stroke(180, 255, 220, alpha * 0.45f);
    g.strokeWeight(1);
    g.ellipse(x, y, r * 2 * 0.55f, r * 2 * 0.55f);
    g.popStyle();
  }
}
