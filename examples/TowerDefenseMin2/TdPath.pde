/**
 * Path system: polyline with distance sampling for enemy movement.
 */
static final class TdPath {
    public Vector2[] points;
    public float[] segmentLengths;
    public float totalLength;

    TdPath(Vector2[] points) {
        this.points = points;
        computeLengths();
    }

    private void computeLengths() {
        if (points == null || points.length < 2) {
            segmentLengths = new float[0];
            totalLength = 0;
            return;
        }
        segmentLengths = new float[points.length - 1];
        totalLength = 0;
        for (int i = 0; i < points.length - 1; i++) {
            float len = points[i].distance(points[i + 1]);
            segmentLengths[i] = len;
            totalLength += len;
        }
    }

    /** Sample position at distance along the path. */
    Vector2 sample(float dist) {
        if (points == null || points.length == 0) return new Vector2();
        if (dist <= 0) return points[0].copy();
        if (dist >= totalLength) return points[points.length - 1].copy();
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            if (accumulated + segmentLengths[i] >= dist) {
                float t = (dist - accumulated) / segmentLengths[i];
                return Vector2.lerp(points[i], points[i + 1], t);
            }
            accumulated += segmentLengths[i];
        }
        return points[points.length - 1].copy();
    }

    /** Get direction vector at distance along the path. */
    Vector2 direction(float dist) {
        if (points == null || points.length < 2) return new Vector2(1, 0);
        if (dist <= 0) return points[1].copy().sub(points[0]).normalize();
        if (dist >= totalLength) {
            return points[points.length - 1].copy().sub(points[points.length - 2]).normalize();
        }
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            if (accumulated + segmentLengths[i] >= dist) {
                return points[i + 1].copy().sub(points[i]).normalize();
            }
            accumulated += segmentLengths[i];
        }
        return points[points.length - 1].copy().sub(points[points.length - 2]).normalize();
    }

    /** Find the distance along the path closest to the given point. */
    float closestDistanceTo(Vector2 target) {
        if (points == null || points.length == 0) return 0;
        float bestDist = 0;
        float bestD = Float.MAX_VALUE;
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            Vector2 a = points[i];
            Vector2 b = points[i + 1];
            Vector2 ab = b.copy().sub(a);
            Vector2 at = target.copy().sub(a);
            float abLenSq = ab.x * ab.x + ab.y * ab.y;
            float t = abLenSq > 0 ? PApplet.constrain((at.x * ab.x + at.y * ab.y) / abLenSq, 0, 1) : 0;
            Vector2 closest = Vector2.lerp(a, b, t);
            float d = closest.distance(target);
            if (d < bestD) {
                bestD = d;
                bestDist = accumulated + segmentLengths[i] * t;
            }
            accumulated += segmentLengths[i];
        }
        return bestDist;
    }

    /** Get the segment index at the given distance along the path. */
    int getSegmentIndex(float dist) {
        if (points == null || points.length < 2) return 0;
        if (dist <= 0) return 0;
        if (dist >= totalLength) return segmentLengths.length - 1;
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            if (accumulated + segmentLengths[i] >= dist) {
                return i;
            }
            accumulated += segmentLengths[i];
        }
        return segmentLengths.length - 1;
    }

    float getTotalLength() { return totalLength; }
}
