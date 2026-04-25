/**
 * Enemy instance on the path.
 */

enum EnemyState {
    MOVE_TO_BASE,
    STEAL,
    FLEE,
    DEAD
}

static class Enemy {
    Vector2 pos;
    float hp, maxHp;
    float speed;
    float radius;
    float slowFactor = 1f;
    boolean reachedEnd;

    TdPath path;
    float pathDistance;
    GameObject gameObject;

    EnemyState state = EnemyState.MOVE_TO_BASE;
    boolean hasStolen = false;

    // Smooth turning state
    int currentSegment = 0;
    boolean isTurning = false;
    static final float TURN_DURATION = 0.2f;

    void update(float dt) {
        if (path == null) return;

        switch (state) {
            case MOVE_TO_BASE:
                pathDistance += speed * slowFactor * dt;
                if (pathDistance >= TdGameWorld.basePathDist) {
                    pathDistance = TdGameWorld.basePathDist;
                    state = EnemyState.STEAL;
                }
                break;
            case STEAL:
                hasStolen = true;
                TdGameWorld.orbits--;
                TdSaveData.incOrbsLost();
                state = EnemyState.FLEE;
                break;
            case FLEE:
                pathDistance += speed * slowFactor * dt;
                if (pathDistance >= path.getTotalLength()) {
                    reachedEnd = true;
                }
                break;
            case DEAD:
                return;
        }

        if (pathDistance >= path.getTotalLength()) {
            pos = path.sample(path.getTotalLength());
        } else {
            pos = path.sample(pathDistance);
        }
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }

        // Detect segment change and trigger smooth rotation
        int newSegment = path.getSegmentIndex(pathDistance);
        if (newSegment != currentSegment) {
            currentSegment = newSegment;
            triggerSmoothTurn();
        }
    }

    void triggerSmoothTurn() {
        if (gameObject == null) return;
        Vector2 dir = path.direction(pathDistance);
        if (dir == null) return;
        float targetAngle = PApplet.atan2(dir.y, dir.x);
        float currentAngle = gameObject.getTransform().getRotation();
        // Normalize angle difference to [-PI, PI]
        float angleDiff = targetAngle - currentAngle;
        while (angleDiff > PApplet.PI) angleDiff -= PApplet.TWO_PI;
        while (angleDiff < -PApplet.PI) angleDiff += PApplet.TWO_PI;
        float finalTarget = currentAngle + angleDiff;
        // Kill any existing rotation tween on this game object
        TowerDefenseMin2.inst.engine.getTweenManager().killTarget(gameObject);
        TowerDefenseMin2.inst.engine.getTweenManager()
            .toRotation(gameObject, finalTarget, TURN_DURATION)
            .ease(Ease::outQuad)
            .onComplete(() -> isTurning = false)
            .start();
        isTurning = true;
    }
}
