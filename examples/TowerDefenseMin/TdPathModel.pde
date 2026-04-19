/** Waypoint path: arc-length sampling + placement distance test. */
static final class TdPath {
  final Vector2[] points;
  float totalLength;
  float[] segLen;

  TdPath(Vector2[] pts) {
    this.points = pts;
    int n = pts.length;
    segLen = new float[max(0, n - 1)];
    totalLength = 0;
    for (int i = 0; i < n - 1; i++) {
      float d = pts[i].distance(pts[i + 1]);
      segLen[i] = d;
      totalLength += d;
    }
  }

  float[] vertexDistances() {
    float[] vd = new float[points.length];
    vd[0] = 0;
    for (int i = 1; i < points.length; i++) {
      vd[i] = vd[i - 1] + segLen[i - 1];
    }
    return vd;
  }

  Vector2 sample(float distAlong) {
    distAlong = constrain(distAlong, 0, totalLength - 0.0001f);
    float acc = 0;
    for (int i = 0; i < segLen.length; i++) {
      if (acc + segLen[i] >= distAlong) {
        float t = (distAlong - acc) / segLen[i];
        return Vector2.lerp(points[i], points[i + 1], t);
      }
      acc += segLen[i];
    }
    return points[points.length - 1].copy();
  }

  float minDistanceToPolyline(Vector2 p) {
    float best = 1e9f;
    for (int i = 0; i < points.length - 1; i++) {
      float d = distPointSegment(p, points[i], points[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  static float distPointSegment(Vector2 p, Vector2 a, Vector2 b) {
    float abx = b.x - a.x;
    float aby = b.y - a.y;
    float apx = p.x - a.x;
    float apy = p.y - a.y;
    float ab2 = abx * abx + aby * aby;
    float t = ab2 < 1e-6f ? 0 : constrain((apx * abx + apy * aby) / ab2, 0, 1);
    float qx = a.x + abx * t;
    float qy = a.y + aby * t;
    float dx = p.x - qx;
    float dy = p.y - qy;
    return (float) Math.sqrt(dx * dx + dy * dy);
  }
}
