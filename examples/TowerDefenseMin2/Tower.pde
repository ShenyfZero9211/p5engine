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
    GameObject gameObject;

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
        if (!built) {
            buildProgress += dt;
            if (buildProgress >= def.buildTime) built = true;
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
        Enemy best = null;
        float bestDist = def.range;
        for (Enemy e : TdGameWorld.enemies) {
            float d = e.pos.distance(new Vector2(worldX, worldY));
            if (d <= bestDist) {
                bestDist = d;
                best = e;
            }
        }
        return best;
    }

    void fireAt(Enemy target) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;

        // Acquire from object pools
        Bullet b = app.bulletDataPool.acquire();
        GameObject bGo = app.bulletGoPool.acquire();
        bGo.setActive(true);

        // Bind renderer
        BulletRenderer renderer = bGo.getComponent(BulletRenderer.class);
        renderer.bullet = b;

        // Initialize bullet data
        Vector2 dir = target.pos.copy().sub(worldX, worldY).normalize().mult(400);
        b.reset(worldX, worldY, dir.x, dir.y, def.damage, def.aoeRadius, def.laserBonus, def.slowFactor);
        b.gameObject = bGo;
        bGo.getTransform().setPosition(b.pos.x, b.pos.y);

        TdGameWorld.bullets.add(b);
        TdAssets.playSfx(def.sfxFire);
    }
}
