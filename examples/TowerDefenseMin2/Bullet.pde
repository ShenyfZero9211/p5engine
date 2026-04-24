/**
 * Projectile or beam fired by a tower.
 */
static class Bullet {
    Vector2 pos;
    Vector2 vel;
    float damage;
    float aoeRadius;
    float laserBonus;
    float slowFactor;
    float life;
    boolean dead;
    GameObject gameObject;

    void update(float dt) {
        if (dead) return;
        life -= dt;
        if (life <= 0) { dead = true; markDead(); return; }

        pos.add(vel.copy().mult(dt));
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }

        for (Enemy e : TdGameWorld.enemies) {
            if (pos.distance(e.pos) < e.radius + 4) {
                hit(e);
                dead = true;
                markDead();
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
                if (ne != e && e.pos.distance(ne.pos) <= aoeRadius) {
                    ne.hp -= dmg * 0.5f;
                }
            }
        }
    }

    void markDead() {
        if (gameObject != null) {
            gameObject.markForDestroy();
        }
    }
}
