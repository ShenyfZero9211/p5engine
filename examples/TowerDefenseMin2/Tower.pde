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
    int upgradeLevel = 0;        // 0=未升级, 1=第一级, 2=第二级
    boolean isUpgrading = false;
    float upgradeProgress = 0f;
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

    float getEffectiveRange() {
        if (upgradeLevel >= 1) return def.range * def.upgradeRangeMult;
        return def.range;
    }

    float getFirePeriod() {
        if (upgradeLevel >= 1) return def.firePeriod * def.upgradeSpeedMult;
        return def.firePeriod;
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
        if (isUpgrading) {
            upgradeProgress += dt;
            float targetTime = (upgradeLevel == 0) ? def.upgradeBuildTime : def.upgrade2BuildTime;
            if (upgradeProgress >= targetTime) {
                isUpgrading = false;
                upgradeLevel++;
                TdAssets.playSfx(def.sfxComplete);
            }
            return;
        }
        cooldown -= dt;
        if (cooldown <= 0) {
            if (def.type == TowerType.COMMAND) {
                fireCommand();
                cooldown = getFirePeriod();
            } else {
                Enemy target = findTarget();
                if (target != null) {
                    fireAt(target);
                    cooldown = getFirePeriod();
                }
            }
        }
    }

    Enemy findTarget() {
        if (def.type == TowerType.COMMAND) return null;
        // Phase 1: per-route best threat in range
        java.util.HashMap<String, Enemy> routeBest = new java.util.HashMap<>();
        Vector2 towerPos = new Vector2(worldX, worldY);
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp <= 0) continue;
            float d = e.pos.distance(towerPos);
            if (d > getEffectiveRange()) continue;
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
            case POISON:
                firePoison(target);
                break;
            case COMMAND:
                fireCommand();
                break;
        }
    }

    void fireCommand() {
        // 指挥塔：周期性释放增效波
        TdGameWorld.effects.add(new CommandWaveEffect(worldX, worldY, getEffectiveRange()));
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }

    /**
     * 计算当前指挥塔提供的伤害倍率加成。
     * 多个指挥塔不叠加，取最大值。
     */
    float getCommandDamageMult() {
        float mult = 1f;
        for (Tower t : TdGameWorld.towers) {
            if (t == this) continue;
            if (t.def.type == TowerType.COMMAND && t.built && !t.isSelling) {
                float d = new Vector2(worldX, worldY).distance(new Vector2(t.worldX, t.worldY));
                if (d <= t.getEffectiveRange()) {
                    float cmdMult = (t.upgradeLevel >= 2) ? 1.3f : t.def.upgradeCommandMult;
                    mult = Math.max(mult, cmdMult);
                }
            }
        }
        return mult;
    }

    void fireMg(Enemy target) {
        // Instant damage — no bullet physics
        float dmgMult = (upgradeLevel >= 1) ? def.upgradeDamageMult : 1f;
        if (upgradeLevel >= 2) dmgMult = 2.0f;
        float dmg = def.damage * dmgMult * getCommandDamageMult();
        target.hp -= dmg;
        target.hitFlashTimer = 0.15f;
        // Visual tracer
        float tracerMult = (upgradeLevel >= 1) ? def.upgradeBulletSizeMult : 1f;
        TdGameWorld.effects.add(new MgTracerEffect(worldX, worldY, target.pos.x, target.pos.y, tracerMult));
        // Hit mark on enemy
        target.statusEffects.add(new MgHitMark());
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
        // Second shot at level 2
        if (upgradeLevel >= 2) {
            TdGameWorld.effects.add(new MgTracerEffect(worldX, worldY, target.pos.x, target.pos.y, tracerMult));
            target.statusEffects.add(new MgHitMark());
        }
    }

    void fireMissile(Enemy target) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Bullet b = app.bulletDataPool.acquire();
        GameObject bGo = app.bulletGoPool.acquire();
        bGo.setActive(true);
        BulletRenderer renderer = bGo.getComponent(BulletRenderer.class);
        renderer.bullet = b;
        Vector2 dir = calcInterceptDir(target);
        float dmgMult = (upgradeLevel >= 1) ? def.upgradeDamageMult : 1f;
        float aoeMult = (upgradeLevel >= 1) ? def.upgradeAoeMult : 1f;
        float bulletMult = (upgradeLevel >= 1) ? def.upgradeBulletSizeMult : 1f;
        float dmg = def.damage * dmgMult * getCommandDamageMult();
        float aoe = def.aoeRadius * aoeMult;
        b.reset(worldX, worldY, dir.x, dir.y, dmg, aoe, def.laserBonus, def.slowFactor, def.slowDuration, bulletMult);
        b.towerType = def.type;
        b.hasBurn = (upgradeLevel >= 2);
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
        float baseDmg = def.damage + def.laserBonus;
        if (upgradeLevel >= 2) baseDmg *= 1.6f;
        float dmg = baseDmg * getCommandDamageMult();
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
        float effRange = getEffectiveRange();
        float effSlow = def.slowFactor * ((upgradeLevel >= 1) ? def.upgradeSlowMult : 1f);
        float effDuration = def.slowDuration * ((upgradeLevel >= 2) ? 1.5f : 1f);
        // Apply slow to all enemies in range immediately
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp > 0 && e.pos.distance(towerPos) <= effRange) {
                e.targetSlowFactor = Math.min(e.targetSlowFactor, effSlow);
                e.slowTimer = Math.max(e.slowTimer, effDuration);
            }
        }
        // Visual wave
        TdGameWorld.effects.add(new SlowWaveEffect(worldX, worldY, effRange));
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }

    void firePoison(Enemy target) {
        if (target == null) return;
        Vector2 towerPos = new Vector2(worldX, worldY);
        float facingAngle = PApplet.atan2(target.pos.y - worldY, target.pos.x - worldX);
        float fanAngle = def.poisonFanAngle * ((upgradeLevel >= 2) ? 1.5f : 1f);
        float halfAngle = PApplet.radians(fanAngle) / 2; // 扇形半角
        int hitCount = 0;
        for (Enemy e : TdGameWorld.enemies) {
            if (e.hp <= 0) continue;
            float d = e.pos.distance(towerPos);
            if (d > def.range) continue;
            float angleToEnemy = PApplet.atan2(e.pos.y - worldY, e.pos.x - worldX);
            float angleDiff = angleToEnemy - facingAngle;
            while (angleDiff > PApplet.PI) angleDiff -= PApplet.TWO_PI;
            while (angleDiff < -PApplet.PI) angleDiff += PApplet.TWO_PI;
            if (Math.abs(angleDiff) <= halfAngle) {
                float effPoisonDmg = def.poisonDamage * ((upgradeLevel >= 1) ? def.upgradePoisonMult : 1f);
                if (upgradeLevel >= 2) effPoisonDmg *= 1.3f;
                e.addPoisonStack(effPoisonDmg, def.poisonDuration);
                hitCount++;
            }
        }
        // Visual fan-shaped poison cloud
        TdGameWorld.effects.add(new PoisonCloudEffect(worldX, worldY, def.range, facingAngle, halfAngle * 2));
        TdAssets.playSfx(def.sfxFire);
        TdLightingSystem.addFireFlash(this);
    }
}
