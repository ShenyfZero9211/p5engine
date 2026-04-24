/**
 * Game world state: level data, towers, enemies, bullets, base/exit state.
 */
static final class TdGameWorld {

    static LevelDef level;
    static int money, orbits, currentWave, enemiesRemaining;
    static ArrayList<Tower> towers = new ArrayList<>();
    static ArrayList<Enemy> enemies = new ArrayList<>();
    static ArrayList<Bullet> bullets = new ArrayList<>();
    static float waveTimer, spawnTimer;
    static boolean waveInProgress;
    static TdPath path;
    static float basePathDist;

    static void startLevel(TowerDefenseMin2 app, int levelId) {
        // Clean up old entities
        for (Enemy e : enemies) {
            if (e.gameObject != null) e.gameObject.markForDestroy();
        }
        for (Tower t : towers) {
            if (t.gameObject != null) t.gameObject.markForDestroy();
        }
        for (Bullet b : bullets) {
            if (b.gameObject != null) b.gameObject.markForDestroy();
        }
        towers.clear();
        enemies.clear();
        bullets.clear();

        level = TdAssets.loadLevel(levelId);
        money = level.initialMoney;
        orbits = level.initialOrbs;
        currentWave = 0;
        enemiesRemaining = 0;
        waveTimer = 2.0f;
        spawnTimer = 0;
        waveInProgress = false;
        path = new TdPath(level.pathPoints);
        basePathDist = path.closestDistanceTo(level.basePos);

        // Resize world
        TowerDefenseMin2.WORLD_W = level.worldW;
        TowerDefenseMin2.WORLD_H = level.worldH;
        app.camera.setWorldBounds(new Rect(0, 0, level.worldW, level.worldH));
        app.camera.jumpCenterTo(level.basePos.x, level.basePos.y);
    }

    static void update(float dt) {
        if (level == null) return;

        // Wave management
        if (!waveInProgress && enemies.isEmpty() && currentWave < level.totalWaves) {
            waveTimer -= dt;
            if (waveTimer <= 0) {
                currentWave++;
                enemiesRemaining = level.enemyCountBase + level.enemyCountPerWave * (currentWave - 1);
                waveInProgress = true;
                spawnTimer = 0;
            }
        }

        // Spawning
        if (waveInProgress && enemiesRemaining > 0) {
            spawnTimer -= dt;
            if (spawnTimer <= 0) {
                spawnEnemy();
                enemiesRemaining--;
                spawnTimer = level.spawnCooldown;
                if (enemiesRemaining == 0) {
                    waveInProgress = false;
                    waveTimer = level.interWaveDelay;
                }
            }
        }

        // Check win/lose
        if (orbits <= 0 && enemies.isEmpty() && !waveInProgress && currentWave >= level.totalWaves) {
            TdFlow.showLose(TowerDefenseMin2.inst);
            return;
        }
        if (currentWave >= level.totalWaves && enemies.isEmpty() && !waveInProgress && orbits > 0) {
            TdFlow.showWin(TowerDefenseMin2.inst);
            return;
        }

        // Update entities
        for (int i = enemies.size() - 1; i >= 0; i--) {
            Enemy e = enemies.get(i);
            e.update(dt);
            if (e.reachedEnd) {
                if (e.gameObject != null) e.gameObject.markForDestroy();
                enemies.remove(i);
            } else if (e.hp <= 0) {
                e.state = EnemyState.DEAD;
                if (!e.hasStolen) {
                    money += TdConfig.KILL_REWARD_BASE;
                }
                TdSaveData.incEnemiesKilled();
                if (e.gameObject != null) e.gameObject.markForDestroy();
                enemies.remove(i);
            }
        }

        for (int i = bullets.size() - 1; i >= 0; i--) {
            Bullet b = bullets.get(i);
            b.update(dt);
            if (b.dead) bullets.remove(i);
        }

        // Tower AI
        for (Tower t : towers) {
            t.update(dt);
        }
    }

    static void spawnEnemy() {
        Enemy e = new Enemy();
        e.path = path;
        e.pathDistance = 0;
        e.pos = path.sample(0);
        e.hp = level.enemyHpBase + level.enemyHpPerWave * (currentWave - 1);
        e.maxHp = e.hp;
        e.speed = level.enemySpeed;
        e.radius = TdConfig.ENEMY_RADIUS;
        e.state = EnemyState.MOVE_TO_BASE;
        e.hasStolen = false;

        GameObject go = GameObject.create("Enemy");
        go.getTransform().setPosition(e.pos.x, e.pos.y);
        go.setRenderLayer(10);
        go.addComponent(new EnemyRenderer(e));
        TowerDefenseMin2.inst.gameScene.addGameObject(go);
        e.gameObject = go;

        enemies.add(e);
    }

    static boolean canPlaceTower(int gx, int gy) {
        if (level == null) return false;
        float wx = (gx + 0.5f) * TdConfig.GRID;
        float wy = (gy + 0.5f) * TdConfig.GRID;
        if (wx < 0 || wy < 0 || wx > level.worldW || wy > level.worldH) return false;
        for (Tower t : towers) {
            if (Math.abs(t.gridX - gx) < 1 && Math.abs(t.gridY - gy) < 1) return false;
        }
        return true;
    }

    static boolean tryPlaceTower(TdBuildMode mode, int gx, int gy) {
        if (!canPlaceTower(gx, gy)) return false;
        TowerDef def = TdAssets.loadTowerDef(TowerType.fromBuildMode(mode));
        if (def == null || money < def.cost) return false;
        money -= def.cost;
        Tower t = new Tower(def, gx, gy);
        TdSaveData.incTowersBuilt();

        GameObject go = GameObject.create("Tower");
        go.getTransform().setPosition(t.worldX, t.worldY);
        go.setRenderLayer(5);
        go.addComponent(new TowerRenderer(t));
        TowerDefenseMin2.inst.gameScene.addGameObject(go);
        t.gameObject = go;

        towers.add(t);
        TdAssets.playSfx(def.sfxPlace);
        return true;
    }
}
