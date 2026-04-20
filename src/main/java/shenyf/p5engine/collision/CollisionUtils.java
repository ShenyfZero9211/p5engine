package shenyf.p5engine.collision;

/**
 * Static collision detection utilities.
 * Pure math functions — no dependency on Component or GameObject.
 * Can be used anywhere: inside Components, global functions, or standalone logic.
 */
public final class CollisionUtils {

    private CollisionUtils() {
        // utility class
    }

    // ===== Rectangle vs Rectangle (AABB) =====

    /**
     * Checks if two axis-aligned rectangles overlap.
     *
     * @param ax, ay  top-left corner of rectangle A
     * @param aw, ah  width and height of rectangle A
     * @param bx, by  top-left corner of rectangle B
     * @param bw, bh  width and height of rectangle B
     */
    public static boolean rectRect(float ax, float ay, float aw, float ah,
                                   float bx, float by, float bw, float bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    // ===== Circle vs Circle =====

    /**
     * Checks if two circles overlap.
     *
     * @param ax, ay  center of circle A
     * @param ar      radius of circle A
     * @param bx, by  center of circle B
     * @param br      radius of circle B
     */
    public static boolean circleCircle(float ax, float ay, float ar,
                                       float bx, float by, float br) {
        float dx = ax - bx;
        float dy = ay - by;
        float minDist = ar + br;
        return dx * dx + dy * dy < minDist * minDist;
    }

    // ===== Circle vs Rectangle =====

    /**
     * Checks if a circle overlaps an axis-aligned rectangle.
     * This is the classic breakout/paddle-ball collision.
     *
     * @param cx, cy  center of the circle
     * @param cr      radius of the circle
     * @param rx, ry  top-left corner of the rectangle
     * @param rw, rh  width and height of the rectangle
     */
    public static boolean circleRect(float cx, float cy, float cr,
                                     float rx, float ry, float rw, float rh) {
        // Find the closest point on the rectangle to the circle center
        float closestX = clamp(cx, rx, rx + rw);
        float closestY = clamp(cy, ry, ry + rh);

        float dx = cx - closestX;
        float dy = cy - closestY;

        return dx * dx + dy * dy < cr * cr;
    }

    // ===== Point vs shapes =====

    public static boolean pointRect(float px, float py, float rx, float ry, float rw, float rh) {
        return px >= rx && px <= rx + rw && py >= ry && py <= ry + rh;
    }

    public static boolean pointCircle(float px, float py, float cx, float cy, float cr) {
        float dx = px - cx;
        float dy = py - cy;
        return dx * dx + dy * dy < cr * cr;
    }

    // ===== Utility =====

    private static float clamp(float value, float min, float max) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }
}
