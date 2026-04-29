/**
 * Game world state: level data, towers, enemies, bullets, orbs, base/exit state.
 */
static final class TdGameWorld {

    static LevelDef level;
    static int money, orbits, currentWave, escapedEnemies;
    static ArrayList<Tower> towers = new ArrayList<>();
    static ArrayList<Enemy> enemies = new ArrayList<>();
    static ArrayList<Bullet> bullets = new ArrayList<>();
    static ArrayList<Orb> orbs = new ArrayList<>();
    static ArrayList<Effect> effects = new ArrayList<>();
    static ArrayList<PendingLaserHit> pendingLaserHits = new ArrayList<>();
    static java.util.HashSet<String> blockedGrids = new java.util.HashSet<>();
    static float waveTimer, spawnTimer;
    static boolean waveInProgress;
    static float levelStartTotalTime = 0;
    static int waveSpawnIndex;        // current spawn group within wave
    static int waveSpawnCount;        // how many spawned in current group
    static java.util.Random pathRng = new java.util.Random();

    static void startLevel(TowerDefenseMin2 app, int levelId) {
        // Clean up old entities
        for (Enemy e : enemies) {
            if (e.gameObject != null) e.gameObject.markForDestroy();
        }
        for (Tower t : towers) {
            if (t.gameObject != null) t.gameObject.markForDestroy();
        }
        for (Orb o : orbs) {
            if (o.gameObject != null) o.gameObject.markForDestroy();
        }
        // Recycle all active bullets back to pools
        for (Bullet b : bullets) {
            if (!b.dead) b.recycle();
        }
        towers.clear();
        enemies.clear();
        bullets.clear();
        orbs.clear();
        effects.clear();
        pendingLaserHits.clear();
        TowerDefenseMin2.inst.lighting.clear();

        level = TdAssets.loadLevel(levelId);
        money = level.initialMoney;
        if (level.levelType == LevelType.DEFEND_BASE) {
            orbits = level.baseOrbs;
        } else {
            orbits = 0;
        }
        escapedEnemies = 0;
        levelStartTotalTime = app.engine.getGameTime().getTotalTime();
        currentWave = 0;
        waveSpawnIndex = 0;
        waveSpawnCount = 0;
        waveInProgress = false;
        waveTimer = (level.waves != null && level.waves.length > 0) ? level.waves[0].delay : 9999f;
        spawnTimer = 0;

        // Resize world
        TowerDefenseMin2.WORLD_W = level.worldW;
        TowerDefenseMin2.WORLD_H = level.worldH;
        app.camera.setWorldBounds(new Rect(0, 0, level.worldW, level.worldH));
        if (level.levelType == LevelType.DEFEND_BASE) {
            app.camera.jumpCenterTo(level.basePos.x, level.basePos.y);
            if (level.basePos != null) {
                TdLightingSystem.addBaseLight(level.basePos);
            }
        } else {
            app.camera.jumpCenterTo(level.worldW * 0.5f, level.worldH * 0.5f);
        }

        // Preload bullet pools for the new level
        app.bulletDataPool.preload(100);
        app.bulletGoPool.preload(100);

        computeBlockedGrids();
    }

    static void update(float dt) {
        if (level == null) return;
        int totalWaves = (level.waves != null) ? level.waves.length : 0;

        // Wave management
        if (!waveInProgress && currentWave < totalWaves) {
            waveTimer -= dt;
            if (waveTimer <= 0) {
                currentWave++;
                waveSpawnIndex = 0;
                waveSpawnCount = 0;
                waveInProgress = true;
                spawnTimer = 0;
            }
        }

        // Spawning
        if (waveInProgress && currentWave <= totalWaves && level.waves != null) {
            WaveDef wave = level.waves[currentWave - 1];
            if (waveSpawnIndex < wave.spawns.length) {
                WaveSpawn spawn = wave.spawns[waveSpawnIndex];
                spawnTimer -= dt;
                if (spawnTimer <= 0) {
                    spawnEnemy(spawn.enemyType, spawn.route);
                    waveSpawnCount++;
                    if (waveSpawnCount >= spawn.count) {
                        waveSpawnIndex++;
                        waveSpawnCount = 0;
                        spawnTimer = 0;
                    } else {
                        spawnTimer = spawn.interval;
                    }
                }
            } else {
                waveInProgress = false;
                waveTimer = (currentWave < totalWaves)
                    ? level.waves[currentWave].delay : 9999f;
            }
        }

        // Update orbs
        for (int i = orbs.size() - 1; i >= 0; i--) {
            Orb o = orbs.get(i);
            o.update(dt);
            if (o.reachedBase()) {
                orbits++;
                if (o.gameObject != null) o.gameObject.markForDestroy();
                orbs.remove(i);
                continue;
            }
            Enemy captor = o.findNearbyEnemy();
            if (captor != null) {
                captor.orbsCarried++;
                if (o.gameObject != null) o.gameObject.markForDestroy();
                orbs.remove(i);
            }
        }

        // Update entities
        for (int i = enemies.size() - 1; i >= 0; i--) {
            Enemy e = enemies.get(i);
            e.update(dt);
            if (e.reachedEnd) {
                effects.add(new EnemyEscapeEffect(e.pos.x, e.pos.y, e.radius));
                TdLightingSystem.addEscapeFlash(e.pos.x, e.pos.y);
                escapedEnemies++;
                // Orbs carried by escaped enemies are permanently lost in DEFEND_BASE mode
                if (level.levelType == LevelType.DEFEND_BASE && e.orbsCarried > 0) {
                    // orbs already deducted from base when stolen, nothing to do
                }
                if (e.gameObject != null) e.gameObject.markForDestroy();
                enemies.remove(i);
            } else if (e.hp <= 0) {
                e.state = EnemyState.DEAD;
                // Drop carried orbs as returning Orbs
                for (int j = 0; j < e.orbsCarried; j++) {
                    releaseOrb(e.routeProgress, e.activeRoute);
                }
                if (!e.hasStolen && level != null && level.earnMoneyOnKill) {
                    money += TdConfig.KILL_REWARD_BASE;
                }
                TdSaveData.incEnemiesKilled();
                // Death animation effect
                effects.add(new DeathEffect(e.pos.x, e.pos.y, e.radius, e.orbsCarried > 0));
                String deathSfx = (e.enemyDef != null && e.enemyDef.sfxDeath != null)
                    ? e.enemyDef.sfxDeath : TdSound.SFX_DEATH;
                TdAssets.playSfx(deathSfx);
                if (e.gameObject != null) e.gameObject.markForDestroy();
                enemies.remove(i);
            }
        }

        for (int i = bullets.size() - 1; i >= 0; i--) {
            Bullet b = bullets.get(i);
            b.update(dt);
            if (b.dead) {
                bullets.remove(i);
            }
        }

        for (int i = effects.size() - 1; i >= 0; i--) {
            Effect e = effects.get(i);
            e.update(dt);
            if (e.isDead()) {
                effects.remove(i);
            }
        }

        // Tower AI
        for (int i = towers.size() - 1; i >= 0; i--) {
            Tower t = towers.get(i);
            if (t.isSelling) {
                t.sellFade -= dt * 2.5f;
                if (t.sellFade <= 0) {
                    t.sellFade = 0;
                    if (t.gameObject != null) t.gameObject.markForDestroy();
                    towers.remove(i);
                    continue;
                }
            }
            t.update(dt);
        }

        // Process delayed laser hits
        for (int i = pendingLaserHits.size() - 1; i >= 0; i--) {
            PendingLaserHit plh = pendingLaserHits.get(i);
            plh.delay -= dt;
            if (plh.delay <= 0) {
                if (plh.target != null && plh.target.hp > 0) {
                    plh.target.hp -= plh.damage;
                    plh.target.hitFlashTimer = 0.15f;
                }
                pendingLaserHits.remove(i);
            }
        }

        // Check win/lose
        checkWinLose();
    }

    static void releaseOrb(float atPathDistance, PathRoute route) {
        Orb o = new Orb();
        o.route = route;
        o.pathDistance = atPathDistance;
        o.pos = route != null ? route.path.sample(atPathDistance) : new Vector2();

        GameObject go = GameObject.create("Orb");
        go.getTransform().setPosition(o.pos.x, o.pos.y);
        go.setRenderLayer(12);
        go.addComponent(new OrbRenderer(o));
        TowerDefenseMin2.inst.gameScene.addGameObject(go);
        o.gameObject = go;

        orbs.add(o);
    }

    static void spawnEnemy(String enemyTypeKey) {
        spawnEnemy(enemyTypeKey, null);
    }

    static void spawnEnemy(String enemyTypeKey, String routeId) {
        EnemyDef def = TdAssets.loadEnemyDef(enemyTypeKey);
        if (def == null) return;

        PathRoute route = pickSpawnRoute(routeId);
        if (route == null) return;

        Enemy e = new Enemy();
        e.enemyDef = def;
        e.inboundRoute = route;
        e.activeRoute = route;
        e.routeProgress = 0;
        e.pos = route.path.sample(0);
        e.hp = level.enemyHpBase * def.hpMultiplier;
        e.maxHp = e.hp;
        e.speed = def.speedMultiplier * 60; // base speed 60
        e.radius = def.radius;
        e.state = EnemyState.MOVE_TO_BASE;
        e.hasStolen = false;
        e.orbsCarried = 0;

        GameObject go = GameObject.create("Enemy");
        go.getTransform().setPosition(e.pos.x, e.pos.y);
        // Set initial rotation to face the path direction from spawn
        Vector2 initialDir = route.path.direction(0);
        if (initialDir != null) {
            go.getTransform().setRotation(PApplet.atan2(initialDir.y, initialDir.x));
        }
        go.setRenderLayer(10);
        go.addComponent(new EnemyRenderer(e));
        TowerDefenseMin2.inst.gameScene.addGameObject(go);
        e.gameObject = go;

        enemies.add(e);
        effects.add(new EnemySpawnEffect(e.pos.x, e.pos.y, e.radius, e.orbsCarried > 0));
        TdLightingSystem.addSpawnFlash(e.pos.x, e.pos.y);
    }

    static PathRoute pickSpawnRoute(String routeId) {
        if (level == null || level.paths == null) return null;
        // If routeId specified, find it
        if (routeId != null) {
            for (PathRoute pr : level.paths) {
                if (routeId.equals(pr.id)) return pr;
            }
        }
        // Auto-pick based on level type
        java.util.ArrayList<PathRoute> candidates = new java.util.ArrayList<>();
        for (PathRoute pr : level.paths) {
            if (level.levelType == LevelType.DEFEND_BASE) {
                if (pr.type == RouteType.INBOUND) candidates.add(pr);
            } else {
                if (pr.type == RouteType.DIRECT) candidates.add(pr);
                // Fallback: if no DIRECT, use INBOUND
                if (candidates.isEmpty() && pr.type == RouteType.INBOUND) candidates.add(pr);
            }
        }
        if (candidates.isEmpty()) return null;
        return candidates.get(pathRng.nextInt(candidates.size()));
    }

    static void checkWinLose() {
        if (level == null) return;
        int totalWaves = (level.waves != null) ? level.waves.length : 0;

        if (level.levelType == LevelType.DEFEND_BASE) {
            // Lose: all orbs have been carried away to the exit by escaped enemies.
            // Base is empty, no orbs returning, and no enemy on the field is still carrying orbs.
            boolean noOrbsLeft = orbits <= 0 && orbs.isEmpty();
            boolean noCarriersOnField = true;
            for (Enemy e : enemies) {
                if (e.orbsCarried > 0) {
                    noCarriersOnField = false;
                    break;
                }
            }
            if (noOrbsLeft && noCarriersOnField) {
                TdFlow.showLose(TowerDefenseMin2.inst);
                return;
            }
            // Win: all waves done, no enemies, and at least one orb in base or returning
            boolean allWavesDone = currentWave >= totalWaves;
            boolean noEnemies = enemies.isEmpty();
            if (allWavesDone && noEnemies && (orbits > 0 || !orbs.isEmpty())) {
                TdFlow.showWin(TowerDefenseMin2.inst);
                return;
            }
        } else {
            // SURVIVAL
            if (escapedEnemies >= level.maxEscapeCount) {
                TdFlow.showLose(TowerDefenseMin2.inst);
                return;
            }
            boolean allWavesDone = currentWave >= totalWaves;
            boolean noEnemies = enemies.isEmpty();
            if (allWavesDone && noEnemies && escapedEnemies < level.maxEscapeCount) {
                TdFlow.showWin(TowerDefenseMin2.inst);
                return;
            }
        }
    }

    static boolean canPlaceTower(int gx, int gy) {
        if (level == null) return false;
        float wx = (gx + 0.5f) * TdConfig.GRID;
        float wy = (gy + 0.5f) * TdConfig.GRID;
        if (wx < 0 || wy < 0 || wx > level.worldW || wy > level.worldH) return false;
        if (blockedGrids.contains(gx + "," + gy)) return false;
        for (Tower t : towers) {
            if (Math.abs(t.gridX - gx) < 1 && Math.abs(t.gridY - gy) < 1) return false;
        }
        return true;
    }

    static void computeBlockedGrids() {
        blockedGrids.clear();
        if (level == null) return;
        int maxGX = (int)(level.worldW / TdConfig.GRID) + 1;
        int maxGY = (int)(level.worldH / TdConfig.GRID) + 1;
        for (int gx = 0; gx <= maxGX; gx++) {
            for (int gy = 0; gy <= maxGY; gy++) {
                float cx = (gx + 0.5f) * TdConfig.GRID;
                float cy = (gy + 0.5f) * TdConfig.GRID;
                if (isTooCloseToPath(cx, cy)) {
                    blockedGrids.add(gx + "," + gy);
                }
            }
        }
    }

    static boolean isTooCloseToPath(float wx, float wy) {
        if (level == null) return false;
        float threshold = TdConfig.GRID;
        // Check all routes (new multi-path format)
        if (level.paths != null) {
            for (PathRoute pr : level.paths) {
                if (pr.path == null || pr.path.points == null || pr.path.points.length < 2) continue;
                Vector2[] pts = pr.path.points;
                for (int i = 1; i < pts.length; i++) {
                    if (distPointToSegment(wx, wy, pts[i-1].x, pts[i-1].y, pts[i].x, pts[i].y) <= threshold) {
                        return true;
                    }
                }
            }
        }
        // Check legacy pathPoints
        if (level.pathPoints != null && level.pathPoints.length > 1) {
            for (int i = 1; i < level.pathPoints.length; i++) {
                if (distPointToSegment(wx, wy, level.pathPoints[i-1].x, level.pathPoints[i-1].y,
                                       level.pathPoints[i].x, level.pathPoints[i].y) <= threshold) {
                    return true;
                }
            }
        }
        return false;
    }

    static float distPointToSegment(float px, float py, float ax, float ay, float bx, float by) {
        float abx = bx - ax;
        float aby = by - ay;
        float apx = px - ax;
        float apy = py - ay;
        float abLenSq = abx * abx + aby * aby;
        float t = abLenSq > 0 ? PApplet.constrain((apx * abx + apy * aby) / abLenSq, 0, 1) : 0;
        float closestX = ax + abx * t;
        float closestY = ay + aby * t;
        float dx = px - closestX;
        float dy = py - closestY;
        return PApplet.sqrt(dx * dx + dy * dy);
    }

    static boolean tryPlaceTower(TdBuildMode mode, int gx, int gy) {
        if (!canPlaceTower(gx, gy)) return false;
        TowerDef def = TdAssets.loadTowerDef(TowerType.fromBuildMode(mode));
        if (def == null || money < def.cost) {
            if (def != null && TowerDefenseMin2.inst != null && TowerDefenseMin2.inst.hudBuildPanel != null) {
                TowerDefenseMin2.inst.hudBuildPanel.flashButton(TowerType.fromBuildMode(mode));
            }
            return false;
        }
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

    static void sellTower(int gridX, int gridY) {
        for (Tower t : towers) {
            if (t.gridX == gridX && t.gridY == gridY && !t.isSelling) {
                money += (int)(t.def.cost * 0.3f);
                t.isSelling = true;
                TdLightingSystem.removeTowerLight(t);
                return;
            }
        }
    }
}

/**
 * Delayed laser damage scheduled by Tower.fireLaser().
 * Damage is applied after delay seconds if target is still alive.
 */
static class PendingLaserHit {
    Enemy target;
    float damage;
    float delay;

    PendingLaserHit(Enemy target, float damage, float delay) {
        this.target = target;
        this.damage = damage;
        this.delay = delay;
    }
}
