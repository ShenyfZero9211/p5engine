/**
 * One match: path, waves, economy, combat.
 * Enemies, towers, and FX are now GameObjects managed by the Scene.
 * TdGameWorld handles spawning, wave logic, collision, economy, and win/lose.
 */
static final class TdGameWorld {

    final TowerDefenseMin app;
    final P5Engine engine;

    TdPath path;
    int baseVertexIndex = 4;
    float[] vertexDist;
    float pathTotal;

    int currentLevel = 1;
    int money = 420;
    int baseOrbs = 3;
    int lostOrbs = 0;
    int currentWave = 0;
    int toSpawnInWave = 0;
    float spawnCooldown = 0;
    float matchElapsed = 0;
    float enemyHpMult = 1f;

    int nextTowerId = 1;

    boolean betweenWaves = false;
    float interWaveDelay = 0;
    boolean allWavesSpawned = false;

    TdGameWorld(TowerDefenseMin app, P5Engine engine) {
        this.app = app;
        this.engine = engine;
    }

    void configurePath() {
        Vector2[] levelWaypoints = TdLevelPath.getPath(currentLevel);
        path = new TdPath(levelWaypoints);
        vertexDist = path.vertexDistances();
        pathTotal = path.totalLength;
        baseVertexIndex = min((int) (path.points.length * 0.4f), path.points.length - 2);

        // Add world background renderer to scene
        Scene g = engine.getSceneManager().getActiveScene();
        if (g != null) {
            g.removeGameObjects("world_bg");
            GameObject bgGo = GameObject.create("world_bg");
            bgGo.setCullEnabled(false);
            bgGo.addComponent(new WorldBgRenderer(this));
            g.addGameObject(bgGo);
            println("[configurePath] bgGo active=" + bgGo.isActive() + " layer=" + bgGo.getRenderLayer() + " comps=" + bgGo.getComponents());
        }
    }

    void setEnemyHpMultFromSlider(float slider01) {
        enemyHpMult = 0.65f + slider01 * 1.1f;
    }

    void resetEconomyForNewMatch() {
        LevelData ld = TdLevelConfig.getLevel(currentLevel);
        money = ld.initialMoney;
        baseOrbs = ld.initialOrbs;
        lostOrbs = 0;
        matchElapsed = 0;
        betweenWaves = false;
        allWavesSpawned = false;
        interWaveDelay = 0;
        nextTowerId = 1;
        beginWave(1);
        spawnCooldown = 1.2f;
    }

    void setLevel(int level) {
        int maxLevel = TdLevelConfig.getTotalLevels();
        currentLevel = constrain(level, 1, maxLevel);
    }

    void resetTowerNaming() {
        nextTowerId = 1;
    }

    void clearEntities() {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        // Remove all enemy, orb, fx GameObjects (keep towers and camera)
        for (GameObject go : new ArrayList<>(g.getGameObjects())) {
            if (go.getComponent(EnemyController.class) != null
                || go.getComponent(RollingOrbController.class) != null
                || go.getComponent(FxBoltController.class) != null
                || go.getComponent(FxRippleController.class) != null) {
                g.markForDestroy(go);
            }
        }
    }

    void beginWave(int w) {
        currentWave = w;
        LevelData ld = TdLevelConfig.getLevel(currentLevel);
        toSpawnInWave = ld.enemyCountBase + w * ld.enemyCountPerWave;
        spawnCooldown = 1.5f;
        playSfx("data/sounds/percussive-gong.wav");
    }

    void applyEconomyAndWavesFromJson(JSONObject o) {
        int maxLevel = TdLevelConfig.getTotalLevels();
        currentLevel = o.hasKey("level") ? o.getInt("level", 1) : 1;
        currentLevel = constrain(currentLevel, 1, maxLevel);

        LevelData ld = TdLevelConfig.getLevel(currentLevel);
        money = o.getInt("money", ld.initialMoney);
        baseOrbs = o.getInt("baseOrbs", ld.initialOrbs);
        lostOrbs = o.getInt("lostOrbs", 0);
        matchElapsed = o.getFloat("matchElapsed", 0);
        currentWave = max(1, min(ld.totalWaves, o.getInt("wave", 1)));
        if (o.hasKey("toSpawn")) {
            toSpawnInWave = max(0, o.getInt("toSpawn", 0));
            betweenWaves = o.getInt("betweenWaves", 0) != 0;
            interWaveDelay = o.getFloat("interWaveDelay", 0f);
            allWavesSpawned = o.getInt("allWavesSpawned", 0) != 0;
            spawnCooldown = o.getFloat("spawnCooldown", 1f);
        } else {
            betweenWaves = false;
            allWavesSpawned = false;
            interWaveDelay = 0f;
            beginWave(currentWave);
            spawnCooldown = 1.2f;
        }
    }

    void fillSaveJson(JSONObject o) {
        o.setInt("level", currentLevel);
        o.setInt("money", money);
        o.setInt("baseOrbs", baseOrbs);
        o.setInt("lostOrbs", lostOrbs);
        o.setInt("wave", currentWave);
        o.setInt("toSpawn", toSpawnInWave);
        o.setInt("betweenWaves", betweenWaves ? 1 : 0);
        o.setFloat("interWaveDelay", interWaveDelay);
        o.setInt("allWavesSpawned", allWavesSpawned ? 1 : 0);
        o.setFloat("spawnCooldown", spawnCooldown);
        o.setFloat("matchElapsed", matchElapsed);
    }

    void loadTowersFromJson(JSONArray ta) {
        if (ta == null) return;
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        for (int i = 0; i < ta.size(); i++) {
            JSONObject t = ta.getJSONObject(i);
            String ks = t.hasKey("kind") ? t.getString("kind") : "MG";
            TowerKind k = TowerKind.MG;
            try {
                k = TowerKind.valueOf(ks);
            } catch (IllegalArgumentException ex) {
                k = TowerKind.MG;
            }
            float px = t.getFloat("x");
            float py = t.getFloat("y");
            spawnTowerObject(g, k, px, py, true);
        }
    }

    void spawnTowerObject(Scene scene, TowerKind k, float px, float py, boolean fullyBuilt) {
        TowerDef d = TowerDef.forKind(k);
        if (d == null) return;

        GameObject go = GameObject.create("Tower_" + (nextTowerId++));
        go.setCullEnabled(false);
        go.getTransform().setPosition(px, py);
        TowerController tc = go.addComponent(TowerController.class);
        tc.kind = k;
        tc.buildAccum = fullyBuilt ? d.buildTime : 0f;
        scene.addGameObject(go);

        go.getTransform().setScale(0.01f, 0.01f);
        engine.getTweenManager()
            .toScale(go, new Vector2(1f, 1f), 0.3f)
            .ease(shenyf.p5engine.tween.Ease::outBack)
            .start();
        playSfx(d.sfxPlace);
    }

    // ── Spawning ──

    void spawnEnemy(int wave, int level, float hpMult) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        GameObject go = GameObject.create("Enemy_" + System.nanoTime());
        go.setCullEnabled(false);
        EnemyController ec = new EnemyController(wave, level, hpMult);
        go.addComponent(ec);
        ec.setPathData(path, vertexDist[baseVertexIndex], pathTotal);
        g.addGameObject(go);
    }

    void spawnRollingOrb(float s0) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        GameObject go = GameObject.create("Orb_" + System.nanoTime());
        go.setCullEnabled(false);
        RollingOrbController roc = new RollingOrbController(s0);
        go.addComponent(roc);
        roc.setPathData(path, vertexDist[baseVertexIndex]);
        g.addGameObject(go);
    }

    void addBoltFx(TowerKind k, float sx, float sy, float ex, float ey) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        GameObject go = GameObject.create("Bolt_" + System.nanoTime());
        go.setCullEnabled(false);
        go.getTransform().setPosition(sx, sy);
        go.addComponent(new FxBoltController(k, sx, sy, ex, ey));
        g.addGameObject(go);
    }

    void addSlowRipple(float x, float y) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        GameObject go = GameObject.create("Ripple_" + System.nanoTime());
        go.setCullEnabled(false);
        go.getTransform().setPosition(x, y);
        TowerDef d = TowerDef.forKind(TowerKind.SLOW);
        float maxR = (d != null) ? d.aoeRadius * 0.9f : 130f * 0.9f;
        go.addComponent(new FxRippleController(maxR));
        g.addGameObject(go);
    }

    // ── Game tick ──

    int tick(float dt, Label lblHudLine) {
        matchElapsed += dt;
        LevelData ld = TdLevelConfig.getLevel(currentLevel);
        if (lostOrbs >= ld.initialOrbs) return 1;

        applyEnemySlows();
        updateSpawns(dt);
        applyEnemyPhaseAndPickups();
        updateRollingOrbs();
        towerCombat(dt);
        cleanupDeadEntities();

        int alive = countAliveEnemies();

        if (lblHudLine != null) {
            String fmt = engine.getI18n().get("hud.format");
            String levelName = engine.getI18n().get(TdLevelConfig.getLevelNameKey(currentLevel));
            lblHudLine.setText(String.format(Locale.US, fmt,
                levelName, matchElapsed, currentWave, ld.totalWaves, alive, baseOrbs, lostOrbs, money));
        }

        if (allWavesSpawned && alive == 0 && lostOrbs < ld.initialOrbs) return 2;
        return 0;
    }

    // ── World drawing (path, base, exit, placement ghost) ──
    // Enemies, towers, FX are drawn by their own Components via Scene.render()

    void drawWorldBackgroundTo(PGraphics g) {
        g.fill(26, 32, 48);
        g.noStroke();
        g.rect(0, 0, WORLD_W, WORLD_H);

        // Path
        if (path != null) {
            g.stroke(60, 90, 130);
            g.strokeWeight(3);
            g.noFill();
            g.beginShape();
            for (Vector2 p : path.points) {
                g.vertex(p.x, p.y);
            }
            g.endShape();
        }

        // Base
        if (path != null && baseVertexIndex < path.points.length) {
            Vector2 baseP = path.points[baseVertexIndex];
            g.fill(40, 200, 120, 90);
            g.ellipse(baseP.x, baseP.y, 52, 52);
            g.fill(200, 230, 255);
            g.textAlign(CENTER, CENTER);
            g.text(engine.getI18n().get("hud.baseOrbs", baseOrbs), baseP.x, baseP.y - 36);
        }

        // Exit
        if (path != null && path.points.length > 0) {
            Vector2 exitP = path.points[path.points.length - 1];
            g.fill(255, 80, 80, 70);
            g.ellipse(exitP.x, exitP.y, 44, 44);
            g.fill(255, 200, 200);
            g.text(engine.getI18n().get("hud.exit"), exitP.x, exitP.y - 34);
        }

        g.textAlign(PGraphics.LEFT, PGraphics.BASELINE);
    }

    void drawPlacementGhost(TowerKind buildSelected, boolean buildArmed) {
        if (!buildArmed || app.appMode != 2) return;
        TowerDef d = TowerDef.forKind(buildSelected);
        if (d == null) return;

        float mx = app.mouseX;
        float my = app.mouseY;
        // Convert screen to world if camera active
        if (app.camera != null) {
            Vector2 designMouse = engine.getDisplayManager().actualToDesign(new Vector2(mx, my));
            Vector2 worldMouse = app.camera.screenToWorld(designMouse);
            mx = worldMouse.x;
            my = worldMouse.y;
        }

        if (mx < 0 || mx > WORLD_W || my < 0 || my > WORLD_H) return;

        int gx = (int) snapGrid(mx);
        int gy = (int) snapGrid(my);
        boolean ok = money >= d.cost && canPlaceTower(gx, gy);
        float planR = d.kind == TowerKind.SLOW ? d.aoeRadius : d.range;

        app.noFill();
        app.strokeWeight(2);
        app.stroke(255, 210, 90, ok ? 175 : 100);
        strokeRangeRing(app.g, gx, gy, planR);
        app.rectMode(CENTER);
        float cr = app.red(d.iconColor);
        float cg = app.green(d.iconColor);
        float cb = app.blue(d.iconColor);
        app.fill(cr, cg, cb, ok ? 110 : 55);
        app.stroke(ok ? 140 : 90, ok ? 220 : 120, 255, ok ? 200 : 90);
        app.strokeWeight(2);
        app.rect(gx, gy, 28, 28, 4);
        app.rectMode(PGraphics.CORNER);
        app.noStroke();
    }

    static float snapGrid(float v) {
        return round(v / TdConfig.GRID) * TdConfig.GRID;
    }

    static void strokeRangeRing(PGraphics g, float cx, float cy, float radius) {
        if (radius <= 2f) return;
        int n = TdConfig.RANGE_RING_SEGMENTS;
        g.beginShape();
        for (int i = 0; i <= n; i++) {
            float t = PConstants.TWO_PI * (i / (float) n);
            g.vertex(cx + PApplet.cos(t) * radius, cy + PApplet.sin(t) * radius);
        }
        g.endShape(PConstants.CLOSE);
    }

    boolean canPlaceTower(float px, float py) {
        if (px < TdConfig.GRID || py < TdConfig.GRID
            || px > WORLD_W - TdConfig.GRID || py > WORLD_H - TdConfig.GRID) return false;
        if (path.minDistanceToPolyline(new Vector2(px, py)) < 26f) return false;
        Scene g = engine.getSceneManager().getActiveScene();
        if (g != null) {
            for (GameObject go : g.getGameObjects()) {
                if (go.getComponent(TowerController.class) == null) continue;
                Vector2 tp = go.getTransform().getPosition();
                float dx = tp.x - px;
                float dy = tp.y - py;
                if (dx * dx + dy * dy < 36f * 36f) return false;
            }
        }
        return true;
    }

    boolean tryBuyAndPlaceTower(TowerKind k, float px, float py) {
        TowerDef d = TowerDef.forKind(k);
        if (d == null || money < d.cost) return false;
        if (!canPlaceTower(px, py)) return false;
        money -= d.cost;
        spawnTowerObject(engine.getSceneManager().getActiveScene(), k, px, py, false);
        return true;
    }

    // ── Internal systems ──

    void applyEnemySlows() {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null || path == null) return;

        // Reset slows
        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec != null) ec.slowMul = 1f;
        }

        // Apply slow towers
        TowerDef slowDef = TowerDef.forKind(TowerKind.SLOW);
        if (slowDef == null) return;
        for (GameObject go : g.getGameObjects()) {
            TowerController tc = go.getComponent(TowerController.class);
            if (tc == null || tc.kind != TowerKind.SLOW || !tc.isOperational()) continue;
            Vector2 p = go.getTransform().getPosition();
            float r = slowDef.aoeRadius;
            for (GameObject ego : g.getGameObjects()) {
                EnemyController ec = ego.getComponent(EnemyController.class);
                if (ec == null || !ec.alive) continue;
                Vector2 ep = path.sample(ec.s);
                if (ep.distanceSq(p) < r * r) {
                    ec.slowMul = min(ec.slowMul, slowDef.slowFactor);
                }
            }
        }
    }

    void updateSpawns(float dt) {
        if (allWavesSpawned) return;
        LevelData ld = TdLevelConfig.getLevel(currentLevel);
        if (betweenWaves) {
            interWaveDelay -= dt;
            if (interWaveDelay <= 0) {
                betweenWaves = false;
                beginWave(currentWave + 1);
                spawnCooldown = 0.5f;
            }
            return;
        }
        if (toSpawnInWave > 0) {
            spawnCooldown -= dt;
            if (spawnCooldown <= 0) {
                spawnEnemy(currentWave, currentLevel, enemyHpMult);
                toSpawnInWave--;
                spawnCooldown = ld.spawnCooldown / enemyHpMult;
                if (toSpawnInWave == 0) {
                    if (currentWave >= ld.totalWaves) {
                        allWavesSpawned = true;
                    } else {
                        betweenWaves = true;
                        interWaveDelay = ld.interWaveDelay;
                    }
                }
            }
        }
    }

    void applyEnemyPhaseAndPickups() {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null || path == null) return;
        float dBase = vertexDist[baseVertexIndex];
        float dEnd = pathTotal;

        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec == null || !ec.alive) continue;

            if (ec.phase == 0) {
                if (!ec.stoleTriggered && ec.s >= dBase) {
                    ec.stoleTriggered = true;
                    if (baseOrbs > 0) {
                        baseOrbs--;
                        ec.carriedOrb = true;
                        playSfx("data/sounds/ambient-glass.wav");
                    }
                    ec.phase = 1;
                }
            } else if (ec.phase == 1) {
                if (ec.s >= dEnd - 0.5f) {
                    if (ec.carriedOrb) {
                        lostOrbs++;
                        ec.carriedOrb = false;
                    }
                    ec.alive = false;
                }
            }

            // Try pickup rolling orb
            if (ec.alive && ec.phase == 1 && !ec.carriedOrb) {
                Vector2 ep = path.sample(ec.s);
                for (GameObject rgo : g.getGameObjects()) {
                    RollingOrbController roc = rgo.getComponent(RollingOrbController.class);
                    if (roc == null) continue;
                    Vector2 rp = path.sample(roc.s);
                    if (ep.distanceSq(rp) < TdConfig.PICKUP_R * TdConfig.PICKUP_R) {
                        ec.carriedOrb = true;
                        rgo.setActive(false);
                        break;
                    }
                }
            }
        }
    }

    void updateRollingOrbs() {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        float dBase = vertexDist[baseVertexIndex];
        for (GameObject go : g.getGameObjects()) {
            RollingOrbController roc = go.getComponent(RollingOrbController.class);
            if (roc == null) continue;
            if (roc.s <= dBase) {
                baseOrbs++;
                playSfx("data/sounds/ambient-splash.wav");
                go.setActive(false);
            }
        }
    }

    void towerCombat(float dt) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        for (GameObject go : g.getGameObjects()) {
            TowerController tc = go.getComponent(TowerController.class);
            if (tc == null) continue;
            tc.tick(this, dt, go.getTransform().getPosition());
        }
    }

    void cleanupDeadEntities() {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        for (GameObject go : new ArrayList<>(g.getGameObjects())) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec != null && !ec.alive) {
                onEnemyKilled(ec);
                g.markForDestroy(go);
                continue;
            }
            if (!go.isActive()) {
                g.markForDestroy(go);
            }
        }
    }

    // ── Combat helpers ──

    int countAliveEnemies() {
        int n = 0;
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return 0;
        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec != null && ec.alive) n++;
        }
        return n;
    }

    TdEnemy findNearestAliveEnemy(Vector2 from, float maxRange) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null || path == null) return null;
        TdEnemy best = null;
        float bestD = 1e12f;
        float maxSq = maxRange * maxRange;
        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec == null || !ec.alive) continue;
            Vector2 ep = path.sample(ec.s);
            float dx = ep.x - from.x;
            float dy = ep.y - from.y;
            float dsq = dx * dx + dy * dy;
            if (dsq <= maxSq && dsq < bestD) {
                bestD = dsq;
                best = new TdEnemy(ec.spawnWave, ec.level, 1f);
                best.s = ec.s;
                best.hp = ec.hp;
                best.hpMax = ec.hpMax;
                best.speed = ec.speed;
                best.alive = ec.alive;
                best.carriedOrb = ec.carriedOrb;
                best.slowMul = ec.slowMul;
            }
        }
        return best;
    }

    void onEnemyKilled(EnemyController ec) {
        if (!ec.alive) return;
        money += TdConfig.killRewardFor(new TdEnemy(ec.spawnWave, ec.level, 1f));
        if (ec.carriedOrb) {
            ec.carriedOrb = false;
            spawnRollingOrb(min(ec.s, pathTotal - 0.1f));
        }
        playSfx("data/sounds/vocal-hah.wav");
    }

    void damageEnemyNearest(Vector2 from, float range, float dmg, float aoe, boolean aoeMode) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null || path == null) return;
        TdEnemy best = null;
        float bestD = 1e9f;
        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec == null || !ec.alive) continue;
            float d = path.sample(ec.s).distance(from);
            if (d < range && d < bestD) {
                bestD = d;
                best = new TdEnemy(ec.spawnWave, ec.level, 1f);
                best.s = ec.s;
                best.hp = ec.hp;
                best.hpMax = ec.hpMax;
            }
        }
        if (best == null) return;
        if (!aoeMode) {
            applyDamageToEnemyAt(best.s, dmg);
            return;
        }
        Vector2 hit = path.sample(best.s);
        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec == null || !ec.alive) continue;
            if (path.sample(ec.s).distance(hit) <= aoe) {
                applyDamageToEnemyAt(ec.s, dmg);
            }
        }
    }

    void applyDamageToEnemyAt(float s, float dmg) {
        Scene g = engine.getSceneManager().getActiveScene();
        if (g == null) return;
        for (GameObject go : g.getGameObjects()) {
            EnemyController ec = go.getComponent(EnemyController.class);
            if (ec == null || !ec.alive || abs(ec.s - s) > 0.1f) continue;
            ec.hp -= dmg;
            if (ec.hp <= 0) ec.alive = false;
        }
    }

    void playSfx(String path) {
        try {
            engine.getAudio().playOneShot(path, "sfx");
        } catch (Exception e) {
            // ignore
        }
    }
}

/** Renders path, base, and exit — placed at renderLayer 0 in the world. */
public static class WorldBgRenderer extends Component implements Renderable {

    final TdGameWorld world;

    WorldBgRenderer(TdGameWorld world) {
        this.world = world;
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(0);
    }

    @Override
    public void render(IRenderer renderer) {
        PGraphics g = renderer.getGraphics();
        // println("[WorldBgRenderer] render called, g=" + g + " size=" + g.width + "x" + g.height);
        world.drawWorldBackgroundTo(g);
    }
}
