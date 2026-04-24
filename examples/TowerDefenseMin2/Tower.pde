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
        Bullet b = new Bullet();
        b.pos = new Vector2(worldX, worldY);
        b.vel = target.pos.copy().sub(b.pos).normalize().mult(400);
        b.damage = def.damage;
        b.aoeRadius = def.aoeRadius;
        b.laserBonus = def.laserBonus;
        b.slowFactor = def.slowFactor;
        b.life = 3.0f;
        TdGameWorld.bullets.add(b);
        TdAssets.playSfx(def.sfxFire);

        GameObject bGo = GameObject.create("Bullet");
        bGo.getTransform().setPosition(b.pos.x, b.pos.y);
        bGo.setRenderLayer(15);
        bGo.addComponent(new BulletRenderer(b));
        TowerDefenseMin2.inst.gameScene.addGameObject(bGo);
        b.gameObject = bGo;
    }
}
