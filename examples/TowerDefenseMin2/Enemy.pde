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
    }
}
