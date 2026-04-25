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
    float life;
    boolean dead;
    GameObject gameObject;

    void reset(float x, float y, float vx, float vy, float dmg, float aoe, float laser, float slow) {
        pos.set(x, y);
        vel.set(vx, vy);
        damage = dmg;
        aoeRadius = aoe;
        laserBonus = laser;
        slowFactor = slow;
        life = 3.0f;
        dead = false;
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
        if (slowFactor > 0) e.slowFactor = Math.min(e.slowFactor, slowFactor);

        if (aoeRadius > 0) {
            for (Enemy ne : TdGameWorld.enemies) {
                if (ne != e) {
                    float dx = e.pos.x - ne.pos.x;
                    float dy = e.pos.y - ne.pos.y;
                    if (dx * dx + dy * dy <= aoeRadius * aoeRadius) {
                        ne.hp -= dmg * 0.5f;
                    }
                }
            }
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
