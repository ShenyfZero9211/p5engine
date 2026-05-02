/**
 * Enemy instance on a path route.
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
    float targetSlowFactor = 1f;
    float slowTimer = 0f;   // remaining slow duration; 0 = no slow active
    static final float SLOW_TRANSITION_SPEED = 3.0f;
    boolean reachedEnd;

    EnemyDef enemyDef;
    int orbsCarried = 0;

    PathRoute inboundRoute;   // route from spawn to base
    PathRoute outboundRoute;  // route from base to exit (assigned after steal)
    PathRoute activeRoute;    // currently active route
    float routeProgress;
    GameObject gameObject;

    EnemyState state = EnemyState.MOVE_TO_BASE;
    boolean hasStolen = false;
    boolean backtracking = false;   // true when retreating along inbound route

    // Status effects (hit marks, debuffs) rendered alongside the enemy
    ArrayList<EnemyStatusEffect> statusEffects = new ArrayList<>();

    // Hit flash: white body flash when damaged
    float hitFlashTimer = 0;

    // Smooth turning state
    int currentSegment = 0;
    boolean isTurning = false;
    static final float TURN_DURATION = 0.2f;

    void update(float dt) {
        if (activeRoute == null || activeRoute.path == null) return;

        // Slow timer: recover to full speed when expired
        if (slowTimer > 0) {
            slowTimer -= dt;
            if (slowTimer <= 0) {
                slowTimer = 0;
                targetSlowFactor = 1f;
            }
        }
        // Smooth transition between current and target slow factor
        if (slowFactor != targetSlowFactor) {
            float delta = targetSlowFactor - slowFactor;
            if (Math.abs(delta) < 0.01f) {
                slowFactor = targetSlowFactor;
            } else {
                slowFactor += Math.signum(delta) * Math.min(Math.abs(delta), SLOW_TRANSITION_SPEED * dt);
            }
        }

        switch (state) {
            case MOVE_TO_BASE:
                routeProgress += speed * slowFactor * dt;
                if (routeProgress >= activeRoute.baseDistance) {
                    routeProgress = activeRoute.baseDistance;
                    if (orbsCarried > 0) {
                        // Already carrying orb(s) captured along the way; skip steal and retreat
                        state = EnemyState.FLEE;
                        pickOutboundRoute();
                    } else {
                        state = EnemyState.STEAL;
                    }
                }
                break;
            case STEAL:
                hasStolen = true;
                // Steal up to remaining capacity or remaining orbs
                int remainingCapacity = enemyDef.orbCapacity - orbsCarried;
                int stealCount = Math.min(remainingCapacity, TdGameWorld.orbits);
                orbsCarried += stealCount;
                TdGameWorld.orbits -= stealCount;
                TdSaveData.incOrbsLost(stealCount);
                // Switch to a random outbound route
                pickOutboundRoute();
                state = EnemyState.FLEE;
                break;
            case FLEE:
                if (backtracking) {
                    routeProgress -= speed * slowFactor * dt;
                    if (routeProgress <= 0) {
                        routeProgress = 0;
                        reachedEnd = true;
                    }
                } else {
                    routeProgress += speed * slowFactor * dt;
                    if (routeProgress >= activeRoute.path.getTotalLength()) {
                        reachedEnd = true;
                    }
                }
                break;
            case DEAD:
                return;
        }

        float clampedProgress = PApplet.constrain(routeProgress, 0, activeRoute.path.getTotalLength());
        pos = activeRoute.path.sample(clampedProgress);
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }

        // Update status effects
        for (int i = statusEffects.size() - 1; i >= 0; i--) {
            if (!statusEffects.get(i).update(dt)) {
                statusEffects.remove(i);
            }
        }

        // Hit flash timer
        if (hitFlashTimer > 0) hitFlashTimer -= dt;

        // Detect segment change and trigger smooth rotation
        int newSegment = activeRoute.path.getSegmentIndex(routeProgress);
        if (newSegment != currentSegment) {
            currentSegment = newSegment;
            triggerSmoothTurn();
        }
    }

    void pickOutboundRoute() {
        if (TdGameWorld.level == null || TdGameWorld.level.paths == null) return;
        java.util.ArrayList<PathRoute> candidates = new java.util.ArrayList<>();
        for (PathRoute pr : TdGameWorld.level.paths) {
            if (pr.type == RouteType.OUTBOUND && pr.path.getTotalLength() >= 1f) {
                candidates.add(pr);
            }
        }
        if (!candidates.isEmpty()) {
            outboundRoute = candidates.get(TdGameWorld.pathRng.nextInt(candidates.size()));
            activeRoute = outboundRoute;
            routeProgress = 0;
            backtracking = false;
            currentSegment = 0;
            triggerSmoothTurn();
            return;
        }
        // Fallback: backtrack along inbound route (spawn and exit are the same location)
        if (inboundRoute != null && inboundRoute.path.getTotalLength() >= 1f) {
            activeRoute = inboundRoute;
            routeProgress = inboundRoute.baseDistance;
            backtracking = true;
            currentSegment = inboundRoute.path.getSegmentIndex(routeProgress);
            triggerSmoothTurn();
        }
    }

    void onOrbCaptured() {
        if (state != EnemyState.MOVE_TO_BASE) return;
        hasStolen = true;
        boolean hasOutbound = false;
        if (TdGameWorld.level != null && TdGameWorld.level.paths != null) {
            for (PathRoute pr : TdGameWorld.level.paths) {
                if (pr.type == RouteType.OUTBOUND && pr.path.getTotalLength() >= 1f) {
                    hasOutbound = true;
                    break;
                }
            }
        }
        if (!hasOutbound) {
            // No outbound route: backtrack immediately from current position
            state = EnemyState.FLEE;
            backtracking = true;
            currentSegment = activeRoute.path.getSegmentIndex(routeProgress);
            triggerSmoothTurn();
        }
        // If has outbound: continue to base, will be handled in MOVE_TO_BASE
    }

    void triggerSmoothTurn() {
        if (gameObject == null) return;
        Vector2 dir = activeRoute.path.direction(routeProgress);
        if (dir == null) return;
        if (backtracking) {
            dir = dir.copy().mult(-1);
        }
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
