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
    static java.util.HashSet<String> zoneBlockedGrids = new java.util.HashSet<>();
    static float waveTimer, spawnTimer;
    static boolean waveInProgress;
    static boolean firstTowerPlaced;
    static float levelStartTotalTime = 0;
    static float levelPlayTime = 0;
    static int waveSpawnIndex;        // current spawn group within wave
    static int waveSpawnCount;        // how many spawned in current group
    static java.util.Random pathRng = new java.util.Random();
    static ArrayList<PendingAttach> pendingAttaches = new ArrayList<>();
    static float baseIncomeAccumulator = 0;
    static float difficultyHpMulti = 1.0f;
    static float difficultyRewardMulti = 1.0f;
    static String currentDifficultyKey = "normal";
    static float winLoseDelay = 0;
    static boolean pendingWin = false;

    /** Parallel wave spawn tracking. Replaces legacy waveSpawnIndex/waveSpawnCount/spawnTimer. */
    static class ActiveSpawn {
        WaveSpawn spawn;
        int remaining;
        float timer;
        ActiveSpawn(WaveSpawn spawn) {
            this.spawn = spawn;
            this.remaining = spawn.count;
            this.timer = 0;
        }
    }
    static ArrayList<ActiveSpawn> activeSpawns = new ArrayList<>();

    static boolean startLevel(TowerDefenseMin2 app, int levelId, String difficultyKey) {
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
        pendingAttaches.clear();
        TowerDefenseMin2.inst.lighting.clear();
        winLoseDelay = 0;
        pendingWin = false;
        activeSpawns.clear();
        activeSpawns.clear();

        level = TdAssets.loadLevel(levelId, difficultyKey);
        if (level == null) {
            app.state = TdState.MENU;
            return false;
        }
        // Apply difficulty multipliers
        DifficultyDef diff = TdAssets.getDifficulty(difficultyKey);
        if (diff != null) {
            difficultyHpMulti = diff.enemyHpMultiplier;
            difficultyRewardMulti = diff.killRewardMultiplier;
            currentDifficultyKey = difficultyKey;
        } else {
            difficultyHpMulti = 1.0f;
            difficultyRewardMulti = 1.0f;
            currentDifficultyKey = "normal";
        }
        // Clear cached layer/drift data so YAML changes always take effect
        ZONE_LAYER_CACHE.clear();
        ZONE_DRIFT_CACHE.clear();
        ASTEROID_ROCK_CACHE.clear();
        app.devMode = level.devMode;
        money = (int)(level.initialMoney * (diff != null ? diff.startingMoneyMultiplier : 1.0f));
        if (level.levelType == LevelType.DEFEND_BASE) {
            orbits = level.baseOrbs;
        } else {
            orbits = 0;
        }
        escapedEnemies = 0;
        baseIncomeAccumulator = 0;
        levelStartTotalTime = app.engine.getGameTime().getTotalTime();
        levelPlayTime = 0;
        currentWave = 0;
        waveSpawnIndex = 0;
        waveSpawnCount = 0;
        waveInProgress = false;
        firstTowerPlaced = false;
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
        return true;
    }

    static void update(float dt) {
        if (level == null) return;
        levelPlayTime += dt;
        int totalWaves = (level.waves != null) ? level.waves.length : 0;

        // Base income (DEFEND_BASE mode only)
        if (level.levelType == LevelType.DEFEND_BASE) {
            baseIncomeAccumulator += TdAssets.getBaseIncomeRate() * dt;
            if (baseIncomeAccumulator >= 1f) {
                int add = (int) baseIncomeAccumulator;
                money += add;
                baseIncomeAccumulator -= add;
            }
        }

        // Wave management
        if (!waveInProgress && currentWave < totalWaves && firstTowerPlaced) {
            waveTimer -= dt;
            if (waveTimer <= 0) {
                currentWave++;
                if (currentWave == 2) {
                    TdTutorial.triggerEvent("wave_2_start");
                }
                waveInProgress = true;
                activeSpawns.clear();
                WaveDef wave = level.waves[currentWave - 1];
                if (wave.parallel && wave.spawns != null) {
                    // Parallel: all spawns start simultaneously
                    for (WaveSpawn s : wave.spawns) {
                        activeSpawns.add(new ActiveSpawn(s));
                    }
                } else if (wave.spawns != null && wave.spawns.length > 0) {
                    // Serial (legacy): only first spawn starts
                    activeSpawns.add(new ActiveSpawn(wave.spawns[0]));
                }
                // Sync legacy fields for save compatibility
                waveSpawnIndex = 0;
                waveSpawnCount = 0;
                spawnTimer = 0;
            }
        }

        // Spawning
        if (waveInProgress && currentWave <= totalWaves && level.waves != null) {
            WaveDef wave = level.waves[currentWave - 1];
            boolean allDone = true;
            for (int i = 0; i < activeSpawns.size(); i++) {
                ActiveSpawn asp = activeSpawns.get(i);
                if (asp.remaining > 0) {
                    allDone = false;
                    asp.timer -= dt;
                    if (asp.timer <= 0) {
                        spawnEnemy(asp.spawn.enemyType, asp.spawn.route, asp.spawn.attaches, asp.spawn.hpMulti);
                        asp.remaining--;
                        asp.timer = asp.spawn.interval;
                    }
                } else if (!wave.parallel) {
                    // Serial mode: advance to next spawn when current finishes
                    if (i + 1 < wave.spawns.length) {
                        activeSpawns.set(i, new ActiveSpawn(wave.spawns[i + 1]));
                        allDone = false;
                    }
                }
            }
            // Sync legacy fields for save compatibility
            if (!activeSpawns.isEmpty()) {
                ActiveSpawn first = activeSpawns.get(0);
                waveSpawnIndex = wave.parallel ? 0 : Math.min(wave.spawns.length - 1, activeSpawns.size() - 1);
                waveSpawnCount = first.spawn.count - first.remaining;
                spawnTimer = first.timer;
            }
            if (allDone) {
                waveInProgress = false;
                waveTimer = (currentWave < totalWaves)
                    ? level.waves[currentWave].delay : 9999f;
            }
        }

        // Process pending attach spawns
        for (int i = pendingAttaches.size() - 1; i >= 0; i--) {
            PendingAttach pa = pendingAttaches.get(i);
            pa.timer -= dt;
            if (pa.timer <= 0) {
                for (int j = 0; j < pa.count; j++) {
                    spawnEnemy(pa.enemyType, pa.route, pa.childAttaches, pa.hpMulti);
                }
                pendingAttaches.remove(i);
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
                captor.onOrbCaptured();
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
                if (level != null && level.earnMoneyOnKill) {
                    int reward = (e.enemyDef != null) ? e.enemyDef.killReward : 10;
                    // Command tower kill bonus for tier-2+ enemies
                    int tier = (e.enemyDef != null && e.enemyDef.key.length() > 0)
                        ? e.enemyDef.key.charAt(e.enemyDef.key.length() - 1) - '0' : 1;
                    if (tier >= 2) {
                        for (Tower t : towers) {
                            if (t.def.type == TowerType.COMMAND && t.built && !t.isSelling) {
                                float d = e.pos.distance(new Vector2(t.worldX, t.worldY));
                                if (d <= t.getEffectiveRange()) {
                                    int lvl = t.upgradeLevel;
                                    int bmin = t.def.commandKillBonusMin[lvl];
                                    int bmax = t.def.commandKillBonusMax[lvl];
                                    if (bmax > 0) {
                                        reward += bmin + pathRng.nextInt(bmax - bmin + 1);
                                    }
                                    break; // 不叠加
                                }
                            }
                        }
                    }
                    reward = (int)(reward * difficultyRewardMulti);
                    money += reward;
                }
                TdSaveData.incEnemiesKilled();
                TdTutorial.onEnemyKilled();
                // Death animation effect
                float dir = 0;
                if (e.gameObject != null) {
                    dir = e.gameObject.getTransform().getRotation();
                } else if (e.activeRoute != null && e.activeRoute.path != null) {
                    Vector2 d = e.activeRoute.path.direction(e.routeProgress);
                    if (d != null) dir = PApplet.atan2(d.y, d.x);
                }
                effects.add(new DeathEffect(e.pos.x, e.pos.y, e.radius, e.orbsCarried > 0, dir));
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

        // Win/Lose delay countdown
        if (winLoseDelay > 0) {
            winLoseDelay -= dt;
            if (winLoseDelay <= 0) {
                if (pendingWin) {
                    TdFlow.showWin(TowerDefenseMin2.inst);
                } else {
                    TdFlow.showLose(TowerDefenseMin2.inst);
                }
            }
        }
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
        spawnEnemy(enemyTypeKey, null, null, 1.0f);
    }

    static void spawnEnemy(String enemyTypeKey, String routeId) {
        spawnEnemy(enemyTypeKey, routeId, null, 1.0f);
    }

    static void spawnEnemy(String enemyTypeKey, String routeId, SpawnAttach[] attaches) {
        spawnEnemy(enemyTypeKey, routeId, attaches, 1.0f);
    }

    static void spawnEnemy(String enemyTypeKey, String routeId, SpawnAttach[] attaches, float hpMulti) {
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
        e.hp = level.enemyHpBase * def.hpMultiplier * hpMulti * difficultyHpMulti;
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

        // Queue up attach spawns
        if (attaches != null) {
            for (SpawnAttach a : attaches) {
                pendingAttaches.add(new PendingAttach(a.delay, a.enemyType, a.count, a.route, a.hpMulti, a.attaches));
            }
        }
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
        boolean shouldWin = false;
        boolean shouldLose = false;

        if (level.levelType == LevelType.DEFEND_BASE) {
            // Lose: all orbs have been carried away to the exit by escaped enemies.
            boolean noOrbsLeft = orbits <= 0 && orbs.isEmpty();
            boolean noCarriersOnField = true;
            for (Enemy e : enemies) {
                if (e.orbsCarried > 0) {
                    noCarriersOnField = false;
                    break;
                }
            }
            if (noOrbsLeft && noCarriersOnField) shouldLose = true;

            // Win: all waves done, no enemies, and at least one orb in base or returning
            boolean allWavesDone = currentWave >= totalWaves;
            boolean noEnemies = enemies.isEmpty();
            if (allWavesDone && noEnemies && (orbits > 0 || !orbs.isEmpty())) shouldWin = true;
        } else {
            // SURVIVAL
            if (escapedEnemies >= level.maxEscapeCount) shouldLose = true;
            boolean allWavesDone = currentWave >= totalWaves;
            boolean noEnemies = enemies.isEmpty();
            if (allWavesDone && noEnemies && escapedEnemies < level.maxEscapeCount) shouldWin = true;
        }

        if (shouldWin || shouldLose) {
            if (winLoseDelay <= 0) {
                winLoseDelay = TdAssets.getWinLoseDelay();
                pendingWin = shouldWin;
            }
        } else {
            // Condition no longer met — cancel pending delay
            winLoseDelay = 0;
        }
    }

    /**
     * 检查目标格子是否处于任意升级指挥塔的增益范围内。
     */
    static boolean isGridInCommandAura(int gx, int gy) {
        if (towers == null || towers.isEmpty()) return false;
        float cx = (gx + 0.5f) * TdConfig.GRID;
        float cy = (gy + 0.5f) * TdConfig.GRID;
        Vector2 gridCenter = new Vector2(cx, cy);
        for (Tower t : towers) {
            if (t.def.type == TowerType.COMMAND && t.built && !t.isSelling) {
                float d = gridCenter.distance(new Vector2(t.worldX, t.worldY));
                if (d <= t.getEffectiveRange()) return true;
            }
        }
        return false;
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

    /**
     * Ray-casting point-in-polygon test.
     */
    static boolean pointInPolygon(float px, float py, Vector2[] poly) {
        if (poly == null || poly.length < 3) return false;
        boolean inside = false;
        for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            if (((poly[i].y > py) != (poly[j].y > py)) &&
                (px < (poly[j].x - poly[i].x) * (py - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x)) {
                inside = !inside;
            }
        }
        return inside;
    }

    static void computeBlockedGrids() {
        blockedGrids.clear();
        zoneBlockedGrids.clear();
        if (level == null) return;
        int maxGX = (int)(level.worldW / TdConfig.GRID) + 1;
        int maxGY = (int)(level.worldH / TdConfig.GRID) + 1;

        boolean hasPlatforms = level.platforms != null && level.platforms.length > 0;
        boolean isDebugGrid = level.mapTheme == MapTheme.DEBUG_GRID;

        // Step 1: if platforms defined, default ALL grids to blocked (deep space)
        // DEBUG_GRID skips platform restrictions — entire grid is buildable except near path
        if (hasPlatforms && !isDebugGrid) {
            for (int gx = 0; gx <= maxGX; gx++) {
                for (int gy = 0; gy <= maxGY; gy++) {
                    blockedGrids.add(gx + "," + gy);
                }
            }
            // Step 2: unlock grids inside platforms
            for (PlatformZone pz : level.platforms) {
                float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
                float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
                for (Vector2 v : pz.vertices) {
                    minX = Math.min(minX, v.x);
                    minY = Math.min(minY, v.y);
                    maxX = Math.max(maxX, v.x);
                    maxY = Math.max(maxY, v.y);
                }
                int gx0 = (int)(minX / TdConfig.GRID);
                int gy0 = (int)(minY / TdConfig.GRID);
                int gx1 = (int)(maxX / TdConfig.GRID) + 1;
                int gy1 = (int)(maxY / TdConfig.GRID) + 1;
                for (int gx = gx0; gx <= gx1; gx++) {
                    for (int gy = gy0; gy <= gy1; gy++) {
                        float cx = (gx + 0.5f) * TdConfig.GRID;
                        float cy = (gy + 0.5f) * TdConfig.GRID;
                        // Tower visual size is GRID * 0.75f; ensure all four corners
                        // of the tower's occupied area are inside the platform polygon
                        float th = TdConfig.GRID * 0.375f;
                        if (pointInPolygon(cx - th, cy - th, pz.vertices) &&
                            pointInPolygon(cx + th, cy - th, pz.vertices) &&
                            pointInPolygon(cx - th, cy + th, pz.vertices) &&
                            pointInPolygon(cx + th, cy + th, pz.vertices)) {
                            blockedGrids.remove(gx + "," + gy);
                        }
                    }
                }
            }
        }

        // Step 3: path proximity → blocked (overrides platform unlock)
        for (int gx = 0; gx <= maxGX; gx++) {
            for (int gy = 0; gy <= maxGY; gy++) {
                float cx = (gx + 0.5f) * TdConfig.GRID;
                float cy = (gy + 0.5f) * TdConfig.GRID;
                if (isTooCloseToPath(cx, cy)) {
                    blockedGrids.add(gx + "," + gy);
                }
            }
        }

        // Step 4: blockedZones in layer 3 (Platform) → blocked
        // Only platform-layer blockedZones affect building; Far/Mid/Near layers are decorative only
        // DEBUG_GRID skips blockedZones — entire grid is buildable except near path
        if (level.blockedZones != null && !isDebugGrid) {
            int[] zoneLayers = getZoneLayers(level);
            for (int i = 0; i < level.blockedZones.length; i++) {
                if (zoneLayers[i] != 3) continue; // skip non-platform layers (decorative)
                BlockedZone bz = level.blockedZones[i];
                if (bz.type == BlockedZoneType.RECT) {
                    int gx0 = (int)(bz.x / TdConfig.GRID);
                    int gy0 = (int)(bz.y / TdConfig.GRID);
                    int gx1 = (int)((bz.x + bz.w) / TdConfig.GRID) + 1;
                    int gy1 = (int)((bz.y + bz.h) / TdConfig.GRID) + 1;
                    for (int gx = gx0; gx <= gx1; gx++) {
                        for (int gy = gy0; gy <= gy1; gy++) {
                            float cx = (gx + 0.5f) * TdConfig.GRID;
                            float cy = (gy + 0.5f) * TdConfig.GRID;
                            if (cx >= bz.x && cx <= bz.x + bz.w && cy >= bz.y && cy <= bz.y + bz.h) {
                                blockedGrids.add(gx + "," + gy);
                                zoneBlockedGrids.add(gx + "," + gy);
                            }
                        }
                    }
                } else if (bz.type == BlockedZoneType.CIRCLE) {
                    int gx0 = (int)((bz.cx - bz.radius) / TdConfig.GRID);
                    int gy0 = (int)((bz.cy - bz.radius) / TdConfig.GRID);
                    int gx1 = (int)((bz.cx + bz.radius) / TdConfig.GRID) + 1;
                    int gy1 = (int)((bz.cy + bz.radius) / TdConfig.GRID) + 1;
                    float rSq = bz.radius * bz.radius;
                    for (int gx = gx0; gx <= gx1; gx++) {
                        for (int gy = gy0; gy <= gy1; gy++) {
                            float cx = (gx + 0.5f) * TdConfig.GRID;
                            float cy = (gy + 0.5f) * TdConfig.GRID;
                            float dx = cx - bz.cx;
                            float dy = cy - bz.cy;
                            if (dx * dx + dy * dy <= rSq) {
                                blockedGrids.add(gx + "," + gy);
                                zoneBlockedGrids.add(gx + "," + gy);
                            }
                        }
                    }
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
        if (def == null) return false;
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app != null && !app.devMode && money < def.cost) {
            if (app.hudBuildPanel != null) {
                app.hudBuildPanel.flashButton(TowerType.fromBuildMode(mode));
            }
            return false;
        }
        if (app == null || !app.devMode) {
            money -= def.cost;
        }
        Tower t = new Tower(def, gx, gy);
        TdSaveData.incTowersBuilt();

        GameObject go = GameObject.create("Tower");
        go.getTransform().setPosition(t.worldX, t.worldY);
        go.setRenderLayer(5);
        go.addComponent(new TowerRenderer(t));
        TowerDefenseMin2.inst.gameScene.addGameObject(go);
        t.gameObject = go;

        towers.add(t);
        if (!firstTowerPlaced) {
            firstTowerPlaced = true;
            if (level.waves != null && level.waves.length > 0) {
                waveTimer = level.waves[0].delay;
            }
        }
        TdAssets.playSfx(def.sfxPlace);
        return true;
    }

    static void sellTower(int gridX, int gridY) {
        for (Tower t : towers) {
            if (t.gridX == gridX && t.gridY == gridY && !t.isSelling) {
                int totalCost = t.def.cost;
                if (t.upgradeLevel >= 1) totalCost += t.def.upgradeCost;
                if (t.upgradeLevel >= 2) totalCost += t.def.upgrade2Cost;
                money += (int)(totalCost * 0.3f);
                t.isSelling = true;
                TdLightingSystem.removeTowerLight(t);
                return;
            }
        }
    }
}

/**
 * Delayed attach spawn triggered when a parent enemy is spawned.
 */
static class PendingAttach {
    float timer;
    final String enemyType;
    final int count;
    final String route;
    final float hpMulti;
    final SpawnAttach[] childAttaches;

    PendingAttach(float delay, String enemyType, int count, String route, float hpMulti, SpawnAttach[] childAttaches) {
        this.timer = delay;
        this.enemyType = enemyType;
        this.count = count;
        this.route = route;
        this.hpMulti = hpMulti;
        this.childAttaches = childAttaches;
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
