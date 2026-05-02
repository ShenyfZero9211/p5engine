/**
 * Active tower instance in the game world.
 */
static class Tower {
    TowerDef def;
    int gridX, gridY;
    float worldX, worldY;
    float cooldown;
    float buildProgress;
    boolean built;
    boolean isSelling = false;
    float sellFade = 1.0f;
    GameObject gameObject;
    TdLight ambientLight;

    Tower(TowerDef def, int gx, int gy) {
        this.def = def;
        this.gridX = gx;
        this.gridY = gy;
        this.worldX = (gx + 0.5f) * TdConfig.GRID;
        this.worldY = (gy + 0.5f) * TdConfig.GRID;
        this.cooldown = 0;
        this.buildProgress = 0;
        this.built = false;
    }

    void update(float dt) {
        if (isSelling) return;
        if (!built) {
            buildProgress += dt;
            if (buildProgress >= def.buildTime) {
                built = true;
                TdAssets.playSfx(def.sfxComplete);
            }
            return;
        }
        cooldown -= dt;
        if (cooldown <= 0) {
            Enemy target = findTarget();
            if (target != null) {
                fireAt(target);
                cooldown = def.firePeriod;
            }
        }
    }

    Enemy findTarget() {
        // Phase 1: per-route best threat in range
        java.util.HashMap<String, Enemy> routeBest = new java.util.HashMap<>();
        Vector2 towerPos = new Vector2(worldX, worldY);
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp <= 0) continue;
            float d = e.pos.distance(towerPos);
            if (d > def.range) continue;
            float score = getThreatScore(e);
            String routeId = (e.activeRoute != null) ? e.activeRoute.id : "";
            Enemy current = routeBest.get(routeId);
            if (current == null || score < getThreatScore(current)) {
                routeBest.put(routeId, e);
            }
        }
        // Phase 2: pick globally most dangerous among route representatives
        Enemy best = null;
        float bestScore = Float.MAX_VALUE;
        for (Enemy e : routeBest.values()) {
            float score = getThreatScore(e);
            if (score < bestScore) {
                bestScore = score;
                best = e;
            }
        }
        return best;
    }

    /**
     * Threat score: lower = more dangerous.
     * State-tier priority ensures FLEE always outranks MOVE_TO_BASE,
     * regardless of raw remaining distance.
     */
    static float getThreatScore(Enemy e) {
        if (e.activeRoute == null || e.hp <= 0) return Float.MAX_VALUE;
        PathRoute r = e.activeRoute;
        float score;
        switch (e.state) {
            case STEAL:
                score = 0;
                break;
            case FLEE:
                // Tier 1000: any FLEE is more dangerous than any MOVE_TO_BASE
                if (e.backtracking) {
                    // Backtrack: closer to exit as routeProgress -> 0
                    score = 1000f + e.routeProgress;
                } else {
                    score = 1000f + (r.path.getTotalLength() - e.routeProgress);
                }
                break;
            case MOVE_TO_BASE:
                // Tier 10000: lowest priority
                score = 10000f + (r.baseDistance - e.routeProgress);
                break;
            default:
                return Float.MAX_VALUE;
        }
        // Carrying orbs makes enemy more dangerous across all states
        if (e.orbsCarried > 0) {
            score -= e.orbsCarried * 100f;
        }
        return score;
    }

    void fireAt(Enemy target) {
        switch (def.type) {
            case MG:
                fireMg(target);
                break;
            case MISSILE:
                fireMissile(target);
                break;
            case LASER:
                fireLaser(target);
                break;
            case SLOW:
                fireSlow();
                break;
        }
    }

    void fireMg(Enemy target) {
        // Instant damage — no bullet physics
        target.hp -= def.damage;
        target.hitFlashTimer = 0.15f;
        // Visual tracer
        TdGameWorld.effects.add(new MgTracerEffect(worldX, worldY, target.pos.x, target.pos.y));
        // Hit mark on enemy
        target.statusEffects.add(new MgHitMark());
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }

    void fireMissile(Enemy target) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Bullet b = app.bulletDataPool.acquire();
        GameObject bGo = app.bulletGoPool.acquire();
        bGo.setActive(true);
        BulletRenderer renderer = bGo.getComponent(BulletRenderer.class);
        renderer.bullet = b;
        Vector2 dir = calcInterceptDir(target);
        b.reset(worldX, worldY, dir.x, dir.y, def.damage, def.aoeRadius, def.laserBonus, def.slowFactor, def.slowDuration);
        b.towerType = def.type;
        b.gameObject = bGo;
        bGo.getTransform().setPosition(b.pos.x, b.pos.y);
        TdGameWorld.bullets.add(b);
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }

    Vector2 calcInterceptDir(Enemy target) {
        float vm = 400f;
        Vector2 d = target.pos.copy().sub(worldX, worldY);

        // Get enemy velocity vector
        Vector2 ve = new Vector2(0, 0);
        if (target.activeRoute != null && target.activeRoute.path != null) {
            Vector2 edir = target.activeRoute.path.direction(target.routeProgress);
            if (edir != null) {
                ve.set(edir.x, edir.y);
                float speed = target.speed * target.slowFactor;
                if (target.backtracking) speed *= -1;
                ve.mult(speed);
            }
        }

        // If enemy not moving, aim directly
        if (ve.magnitudeSq() <= 0.001f) {
            return d.normalize().mult(vm);
        }

        // Solve quadratic: (|Ve|² - Vm²) * t² + 2(D·Ve) * t + |D|² = 0
        float a = ve.magnitudeSq() - vm * vm;
        float b = 2 * d.dot(ve);
        float c = d.magnitudeSq();

        float disc = b * b - 4 * a * c;
        if (disc < 0 || a == 0) {
            return d.normalize().mult(vm);
        }

        float sqrtDisc = PApplet.sqrt(disc);
        float t1 = (-b - sqrtDisc) / (2 * a);
        float t2 = (-b + sqrtDisc) / (2 * a);
        float t = (t1 > 0) ? t1 : (t2 > 0 ? t2 : 0);

        if (t <= 0) {
            return d.normalize().mult(vm);
        }

        Vector2 intercept = d.copy().add(ve.copy().mult(t));
        return intercept.normalize().mult(vm);
    }

    void fireLaser(Enemy target) {
        // Schedule delayed damage
        float dmg = def.damage + def.laserBonus;
        TdGameWorld.pendingLaserHits.add(new PendingLaserHit(target, dmg, def.laserDelay));
        // Visual beam
        TdGameWorld.effects.add(new LaserBeamEffect(worldX, worldY, target.pos.x, target.pos.y));
        // Hit mark on enemy
        target.statusEffects.add(new LaserHitMark());
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }

    void fireSlow() {
        Vector2 towerPos = new Vector2(worldX, worldY);
        // Apply slow to all enemies in range immediately
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp > 0 && e.pos.distance(towerPos) <= def.range) {
                e.targetSlowFactor = Math.min(e.targetSlowFactor, def.slowFactor);
                e.slowTimer = Math.max(e.slowTimer, def.slowDuration);
            }
        }
        // Visual wave
        TdGameWorld.effects.add(new SlowWaveEffect(worldX, worldY, def.range));
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }
}
