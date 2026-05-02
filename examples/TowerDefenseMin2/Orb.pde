/**
 * Orb: energy ball returning to base along its route.
 * Can be re-captured by enemies along the way.
 */
static class Orb {
    Vector2 pos;
    float pathDistance;
    static final float RETURN_SPEED = 80f;
    static final float CAPTURE_RADIUS = 20f;
    GameObject gameObject;
    PathRoute route; // the route this orb is traveling on

    void update(float dt) {
        if (route == null || route.path == null) return;
        if (pathDistance < route.baseDistance) {
            pathDistance += RETURN_SPEED * dt;
            if (pathDistance > route.baseDistance) pathDistance = route.baseDistance;
        } else if (pathDistance > route.baseDistance) {
            pathDistance -= RETURN_SPEED * dt;
            if (pathDistance < route.baseDistance) pathDistance = route.baseDistance;
        }
        pos = route.path.sample(pathDistance);
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }
    }

    boolean reachedBase() {
        return Math.abs(pathDistance - route.baseDistance) < 0.5f;
    }

    Enemy findNearbyEnemy() {
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp <= 0) continue;
            if (e.orbsCarried >= e.enemyDef.orbCapacity) continue;
            float dx = pos.x - e.pos.x;
            float dy = pos.y - e.pos.y;
            if (dx * dx + dy * dy <= CAPTURE_RADIUS * CAPTURE_RADIUS) {
                return e;
            }
        }
        return null;
    }
}

static class OrbRenderer extends RendererComponent {
    Orb orb;
    OrbRenderer(Orb orb) { this.orb = orb; }

    protected void renderShape(PGraphics g) {
        if (orb == null) return;
        float x = orb.pos.x;
        float y = orb.pos.y;
        g.noStroke();
        g.fill(0xFFFFD700, 200);
        g.ellipse(x, y, 10, 10);
        g.fill(0xFFFFFFFF, 120);
        g.ellipse(x, y, 5, 5);
        TdLightingSystem.addOrbGlow(x, y);
    }
}
