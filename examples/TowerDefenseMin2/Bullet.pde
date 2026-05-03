/**
 * Projectile fired by a tower. Pooled for zero-GC performance.
 */
static class Bullet {
    Vector2 pos = new Vector2();
    Vector2 vel = new Vector2();
    float damage;
    float aoeRadius;
    float laserBonus;
    float slowFactor;
    float slowDuration;
    float life;
    boolean dead;
    GameObject gameObject;
    float lastSmokeX, lastSmokeY;
    TowerType towerType;
    float sizeMult;
    boolean hasBurn = false;

    void reset(float x, float y, float vx, float vy, float dmg, float aoe, float laser, float slow, float slowDur) {
        reset(x, y, vx, vy, dmg, aoe, laser, slow, slowDur, 1f);
    }

    void reset(float x, float y, float vx, float vy, float dmg, float aoe, float laser, float slow, float slowDur, float sizeMult) {
        pos.set(x, y);
        vel.set(vx, vy);
        damage = dmg;
        aoeRadius = aoe;
        laserBonus = laser;
        slowFactor = slow;
        slowDuration = slowDur;
        life = 3.0f;
        dead = false;
        lastSmokeX = x;
        lastSmokeY = y;
        this.sizeMult = sizeMult;
        hasBurn = false;
    }

    void update(float dt) {
        if (dead) return;
        life -= dt;
        if (life <= 0) {
            dead = true;
            recycle();
            return;
        }

        pos.x += vel.x * dt;
        pos.y += vel.y * dt;
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }

        // Emit smoke trail every ~10px
        float smokeDx = pos.x - lastSmokeX;
        float smokeDy = pos.y - lastSmokeY;
        if (smokeDx * smokeDx + smokeDy * smokeDy >= 100) {
            TdGameWorld.effects.add(new MissileSmokeEffect(pos.x, pos.y, vel.x, vel.y));
            lastSmokeX = pos.x;
            lastSmokeY = pos.y;
        }

        for (Enemy e : TdGameWorld.enemies) {
            float dx = pos.x - e.pos.x;
            float dy = pos.y - e.pos.y;
            if (dx * dx + dy * dy < (e.radius + 4) * (e.radius + 4)) {
                hit(e);
                dead = true;
                recycle();
                return;
            }
        }
    }

    void hit(Enemy e) {
        float dmg = damage;
        if (laserBonus > 0) dmg += laserBonus;
        e.hp -= dmg;
        e.hitFlashTimer = 0.15f;
        if (slowFactor > 0) {
            e.slowFactor = Math.min(e.slowFactor, slowFactor);
            e.slowTimer = Math.max(e.slowTimer, slowDuration);
        }

        if (aoeRadius > 0) {
            for (Enemy ne : TdGameWorld.enemies) {
                if (ne != e) {
                    float dx = e.pos.x - ne.pos.x;
                    float dy = e.pos.y - ne.pos.y;
                    if (dx * dx + dy * dy <= aoeRadius * aoeRadius) {
                        ne.hp -= dmg * 0.5f;
                        ne.hitFlashTimer = 0.15f;
                    }
                }
            }
            TdGameWorld.effects.add(new ExplosionEffect(pos.x, pos.y, aoeRadius, sizeMult));
        }
        // Hit mark on primary target
        e.statusEffects.add(new MissileHitMark());
        // Burn effect from level-2 missile tower
        if (hasBurn) {
            e.statusEffects.add(new BurnStatusEffect(5f, 3.0f));
        }
    }

    void recycle() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (gameObject != null) {
            gameObject.setActive(false);
            app.bulletGoPool.release(gameObject);
            gameObject = null;
        }
        app.bulletDataPool.release(this);
    }
}
