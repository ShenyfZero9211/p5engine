/**
 * One match: path, waves, enemies, economy, combat. No UI widgets — sketch passes {@link Label} for HUD text.
 */
static final class TdGameWorld {

  final TowerDefenseMin app;
  final P5Engine engine;

  TdPath path;
  int baseVertexIndex = 4;
  float[] vertexDist;
  float pathTotal;

  final ArrayList<TdEnemy> enemies = new ArrayList<TdEnemy>();
  final ArrayList<TdRollingOrb> rolling = new ArrayList<TdRollingOrb>();
  final ArrayList<TdFxBolt> fxBolts = new ArrayList<TdFxBolt>();
  final ArrayList<TdSlowRipple> fxSlowRipples = new ArrayList<TdSlowRipple>();

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
    // 使用当前关卡的路径配置
    Vector2[] levelWaypoints = TdLevelPath.getPath(currentLevel);
    path = new TdPath(levelWaypoints);
    vertexDist = path.vertexDistances();
    pathTotal = path.totalLength;
    // 基地位置大约在路径的40%处
    baseVertexIndex = min((int)(path.points.length * 0.4f), path.points.length - 2);
  }

  void setEnemyHpMultFromSlider(float slider01) {
    enemyHpMult = 0.65f + slider01 * 1.1f;
  }

  void resetEconomyForNewMatch() {
    money = TdLevelConfig.getInitialMoney(currentLevel);
    baseOrbs = TdLevelConfig.getInitialOrbs(currentLevel);
    lostOrbs = 0;
    matchElapsed = 0;
    betweenWaves = false;
    allWavesSpawned = false;
    interWaveDelay = 0;
    nextTowerId = 1;
    beginWave(1);
    spawnCooldown = 1.2f;
  }

  /** 设置当前关卡 */
  void setLevel(int level) {
    currentLevel = constrain(level, 1, TdLevelConfig.TOTAL_LEVELS);
  }

  void resetTowerNaming() {
    nextTowerId = 1;
  }

  void clearEntities() {
    enemies.clear();
    rolling.clear();
    fxBolts.clear();
    fxSlowRipples.clear();
  }

  void beginWave(int w) {
    currentWave = w;
    toSpawnInWave = TdLevelConfig.getEnemyCountBase(currentLevel) + w * TdLevelConfig.getEnemyCountPerWave(currentLevel);
    spawnCooldown = 1.5f;
    if (app.flow != null) app.flow.playSfx("data/sounds/percussive-gong.wav");
  }

  void applyEconomyAndWavesFromJson(JSONObject o) {
    // 读取关卡信息（如果没有保存过关卡信息，默认使用第一关）
    currentLevel = o.hasKey("level") ? o.getInt("level", 1) : 1;
    currentLevel = constrain(currentLevel, 1, TdLevelConfig.TOTAL_LEVELS);
    
    money = o.getInt("money", TdLevelConfig.getInitialMoney(currentLevel));
    baseOrbs = o.getInt("baseOrbs", TdLevelConfig.getInitialOrbs(currentLevel));
    lostOrbs = o.getInt("lostOrbs", 0);
    matchElapsed = o.getFloat("matchElapsed", 0);
    currentWave = max(1, min(TdLevelConfig.getTotalWaves(currentLevel), o.getInt("wave", 1)));
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
    GameObject go = GameObject.create("Tower_" + (nextTowerId++));
    go.getTransform().setPosition(px, py);
    TowerController tc = go.addComponent(TowerController.class);
    tc.kind = k;
    tc.buildAccum = fullyBuilt ? TdConfig.TOWER_BUILD_SECONDS : 0f;
    scene.addGameObject(go);
    // 建造出生缩放动画
    go.getTransform().setScale(0.01f, 0.01f);
    engine.getTweenManager()
      .toScale(go, new Vector2(1f, 1f), 0.3f)
      .ease(shenyf.p5engine.tween.Ease::outBack)
      .start();
    if (app.flow != null) app.flow.playSfx("data/sounds/synthetic-select.wav");
  }

  /** @return 0 = playing, 1 = lose, 2 = win */
  int tick(float dt, Label lblHudLine) {
    matchElapsed += dt;
    if (lostOrbs >= TdLevelConfig.getInitialOrbs(currentLevel)) {
      return 1;
    }

    applyEnemySlows();
    updateSpawns(dt);
    updateEnemies(dt);
    updateRolling(dt);
    towerCombat(dt);
    updateFx(dt);

    int alive = 0;
    for (TdEnemy e : enemies) if (e.alive) alive++;

    if (lblHudLine != null) {
      String fmt = engine.getI18n().get("hud.format");
      String levelName = engine.getI18n().get(TdLevelConfig.getLevelNameKey(currentLevel));
      lblHudLine.setText(String.format(Locale.US, fmt,
        levelName, matchElapsed, currentWave, TdLevelConfig.getTotalWaves(currentLevel), alive, baseOrbs, lostOrbs, money));
    }

    if (allWavesSpawned && alive == 0 && lostOrbs < TdLevelConfig.getInitialOrbs(currentLevel)) {
      return 2;
    }
    return 0;
  }

  void drawBattlefield(TowerKind buildSelected, int appMode, boolean showAllTowerRanges, boolean buildArmed) {
    if (appMode == 0 || appMode == 1) return;

    app.pushStyle();
    app.pushMatrix();
    int px0 = 0;
    int py0 = TdConfig.TOP_HUD;
    int pw = app.width - TdConfig.RIGHT_W;
    int ph = app.height - TdConfig.TOP_HUD;
    app.clip(px0, py0, pw, ph);
    app.translate(0, TdConfig.TOP_HUD);
    app.fill(26, 32, 48);
    app.noStroke();
    app.rect(0, 0, pw, ph);

    app.stroke(60, 90, 130);
    app.strokeWeight(3);
    app.noFill();
    app.beginShape();
    for (Vector2 p : path.points) {
      app.vertex(p.x, p.y);
    }
    app.endShape();

    Vector2 baseP = path.points[baseVertexIndex];
    app.fill(40, 200, 120, 90);
    app.ellipse(baseP.x, baseP.y, 52, 52);
    app.fill(200, 230, 255);
    app.textAlign(CENTER, CENTER);
    app.text(engine.getI18n().get("hud.baseOrbs", baseOrbs), baseP.x, baseP.y - 36);

    Vector2 exitP = path.points[path.points.length - 1];
    app.fill(255, 80, 80, 70);
    app.ellipse(exitP.x, exitP.y, 44, 44);
    app.fill(255, 200, 200);
    app.text(engine.getI18n().get("hud.exit"), exitP.x, exitP.y - 34);

    for (TdRollingOrb r : rolling) {
      Vector2 p = path.sample(r.s);
      app.fill(255, 220, 60);
      app.ellipse(p.x, p.y, 16, 16);
    }

    for (TdEnemy e : enemies) {
      if (!e.alive) continue;
      Vector2 p = path.sample(e.s);
      app.fill(e.carriedOrb ? app.color(255, 120, 200) : app.color(200, 80, 80));
      app.ellipse(p.x, p.y, 22, 22);
      float t = e.hp / e.hpMax;
      app.noFill();
      app.stroke(40, 40, 60);
      app.rect(p.x - 14, p.y - 22, 28, 4);
      app.fill(80, 220, 120);
      app.noStroke();
      app.rect(p.x - 14, p.y - 22, 28 * t, 4);
    }

    for (TdFxBolt b : fxBolts) {
      b.draw(app);
    }
    for (TdSlowRipple r : fxSlowRipples) {
      r.draw(app);
    }

    Scene g = engine.getSceneManager().getActiveScene();
    if (g != null) {
      if (showAllTowerRanges) {
        app.noFill();
        app.strokeWeight(1);
        app.stroke(120, 180, 255, 120);
        for (GameObject go : g.getGameObjects()) {
          TowerController tc = go.getComponent(TowerController.class);
          if (tc == null || !tc.isOperational()) continue;
          Vector2 p = go.getTransform().getPosition();
          TowerDef def = TowerDef.forKind(tc.kind);
          float rRing = def.kind == TowerKind.SLOW ? def.aoeRadius : def.range;
          strokeRangeRing(app, p.x, p.y, rRing);
        }
        app.noStroke();
      }
      for (GameObject go : g.getGameObjects()) {
        TowerController tc = go.getComponent(TowerController.class);
        if (tc == null) continue;
        Vector2 p = go.getTransform().getPosition();
        TowerDef def = TowerDef.forKind(tc.kind);
        boolean op = tc.isOperational();
        app.noStroke();
        if (!op) {
          float bp = tc.buildProgress01();
          app.fill(app.red(def.iconColor), app.green(def.iconColor), app.blue(def.iconColor), 90);
          app.rectMode(CENTER);
          app.rect(p.x, p.y, 28, 28, 4);
          app.rectMode(CORNER);
          app.noStroke();
          app.fill(40, 55, 75, 220);
          app.rect(p.x - 12, p.y - 21, 24, 5, 2);
          app.fill(100, 200, 255, 240);
          app.rect(p.x - 12, p.y - 21, 24 * bp, 5, 2);
          app.stroke(180, 210, 255, 160);
          app.noFill();
          app.strokeWeight(1);
          app.rectMode(CENTER);
          app.rect(p.x, p.y, 30, 30, 4);
        } else {
          app.fill(def.iconColor);
          app.rectMode(CENTER);
          app.rect(p.x, p.y, 28, 28, 4);
        }
        app.rectMode(CORNER);
        app.noStroke();
      }
    }

    int mx = app.mouseX;
    int my = app.mouseY - TdConfig.TOP_HUD;
    if (buildArmed && appMode == 2 && mx < pw && app.mouseY >= TdConfig.TOP_HUD) {
      TowerDef d = TowerDef.forKind(buildSelected);
      int gx = (int) snapGrid(mx);
      int gy = (int) snapGrid(my);
      boolean ok = money >= d.cost && canPlaceTower(gx, gy);
      float planR = d.kind == TowerKind.SLOW ? d.aoeRadius : d.range;
      app.pushStyle();
      app.noFill();
      app.strokeWeight(2);
      app.stroke(255, 210, 90, ok ? 175 : 100);
      strokeRangeRing(app, gx, gy, planR);
      app.rectMode(CENTER);
      float cr = app.red(d.iconColor);
      float cg = app.green(d.iconColor);
      float cb = app.blue(d.iconColor);
      app.fill(cr, cg, cb, ok ? 110 : 55);
      app.stroke(ok ? 140 : 90, ok ? 220 : 120, 255, ok ? 200 : 90);
      app.strokeWeight(2);
      app.rect(gx, gy, 28, 28, 4);
      app.popStyle();
    }

    app.noClip();
    app.popMatrix();
    app.popStyle();
  }

  static float snapGrid(float v) {
    return round(v / TdConfig.GRID) * TdConfig.GRID;
  }

  /** Stroked polygon ring; much cheaper in P2D than large {@code ellipse()} outlines. */
  static void strokeRangeRing(PApplet app, float cx, float cy, float radius) {
    if (radius <= 2f) return;
    int n = TdConfig.RANGE_RING_SEGMENTS;
    app.beginShape();
    for (int i = 0; i <= n; i++) {
      float t = app.TWO_PI * (i / (float) n);
      app.vertex(cx + app.cos(t) * radius, cy + app.sin(t) * radius);
    }
    app.endShape(app.CLOSE);
  }

  boolean canPlaceTower(float px, float py) {
    if (px < TdConfig.GRID || py < TdConfig.GRID
      || px > app.width - TdConfig.RIGHT_W - TdConfig.GRID
      || py > app.height - TdConfig.TOP_HUD - TdConfig.GRID) return false;
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
    if (money < d.cost) return false;
    if (!canPlaceTower(px, py)) return false;
    money -= d.cost;
    spawnTowerObject(engine.getSceneManager().getActiveScene(), k, px, py, false);
    return true;
  }

  void applyEnemySlows() {
    Scene g = engine.getSceneManager().getActiveScene();
    if (g == null) return;
    for (TdEnemy e : enemies) e.slowMul = 1f;
    for (GameObject go : g.getGameObjects()) {
      TowerController tc = go.getComponent(TowerController.class);
      if (tc == null || tc.kind != TowerKind.SLOW || !tc.isOperational()) continue;
      Vector2 p = go.getTransform().getPosition();
      float r = TowerDef.forKind(TowerKind.SLOW).aoeRadius;
      for (TdEnemy e : enemies) {
        if (!e.alive) continue;
        Vector2 ep = path.sample(e.s);
        if (ep.distanceSq(p) < r * r) {
          e.slowMul = min(e.slowMul, TowerDef.forKind(TowerKind.SLOW).slowFactor);
        }
      }
    }
  }

  void updateSpawns(float dt) {
    if (allWavesSpawned) return;
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
        enemies.add(new TdEnemy(currentWave, currentLevel, enemyHpMult));
        toSpawnInWave--;
        spawnCooldown = TdLevelConfig.getSpawnCooldown(currentLevel) / enemyHpMult;
        if (toSpawnInWave == 0) {
          if (currentWave >= TdLevelConfig.getTotalWaves(currentLevel)) {
            allWavesSpawned = true;
          } else {
            betweenWaves = true;
            interWaveDelay = TdLevelConfig.getInterWaveDelay(currentLevel);
          }
        }
      }
    }
  }

  void updateEnemies(float dt) {
    float dBase = vertexDist[baseVertexIndex];
    float dEnd = pathTotal;
    for (TdEnemy e : enemies) {
      if (!e.alive) continue;
      float v = e.speed * e.slowMul;
      e.s += v * dt;
      if (e.phase == 0) {
        if (!e.stoleTriggered && e.s >= dBase) {
          e.stoleTriggered = true;
          if (baseOrbs > 0) {
            baseOrbs--;
            e.carriedOrb = true;
            if (app.flow != null) app.flow.playSfx("data/sounds/ambient-glass.wav");
          }
          e.phase = 1;
        }
      } else if (e.phase == 1) {
        if (e.s >= dEnd - 0.5f) {
          if (e.carriedOrb) {
            lostOrbs++;
            e.carriedOrb = false;
          }
          e.alive = false;
        }
      }
      tryPickupRolling(e);
    }
  }

  void tryPickupRolling(TdEnemy e) {
    if (!e.alive || e.carriedOrb) return;
    if (e.phase != 1) return;
    Vector2 ep = path.sample(e.s);
    Iterator<TdRollingOrb> it = rolling.iterator();
    while (it.hasNext()) {
      TdRollingOrb r = it.next();
      Vector2 rp = path.sample(r.s);
      if (ep.distanceSq(rp) < TdConfig.PICKUP_R * TdConfig.PICKUP_R) {
        e.carriedOrb = true;
        it.remove();
        return;
      }
    }
  }

  void updateRolling(float dt) {
    float dBase = vertexDist[baseVertexIndex];
    Iterator<TdRollingOrb> it = rolling.iterator();
    while (it.hasNext()) {
      TdRollingOrb r = it.next();
      r.s -= TdConfig.ROLL_SPEED * dt;
      if (r.s <= dBase) {
        baseOrbs++;
        if (app.flow != null) app.flow.playSfx("data/sounds/ambient-splash.wav");
        it.remove();
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

  void updateFx(float dt) {
    Iterator<TdFxBolt> ib = fxBolts.iterator();
    while (ib.hasNext()) {
      if (!ib.next().update(dt)) ib.remove();
    }
    Iterator<TdSlowRipple> ir = fxSlowRipples.iterator();
    while (ir.hasNext()) {
      if (!ir.next().update(dt)) ir.remove();
    }
  }

  TdEnemy findNearestAliveEnemy(Vector2 from, float maxRange) {
    TdEnemy best = null;
    float bestD = 1e12f;
    float maxSq = maxRange * maxRange;
    for (TdEnemy e : enemies) {
      if (!e.alive) continue;
      Vector2 ep = path.sample(e.s);
      float dx = ep.x - from.x;
      float dy = ep.y - from.y;
      float dsq = dx * dx + dy * dy;
      if (dsq <= maxSq && dsq < bestD) {
        bestD = dsq;
        best = e;
      }
    }
    return best;
  }

  void addBoltFx(TowerKind k, float sx, float sy, float ex, float ey) {
    fxBolts.add(new TdFxBolt(k, sx, sy, ex, ey));
  }

  void addSlowRipple(float x, float y) {
    fxSlowRipples.add(new TdSlowRipple(x, y));
  }

  void onEnemyKilled(TdEnemy e) {
    if (!e.alive) return;
    e.alive = false;
    money += TdConfig.killRewardFor(e);
    if (e.carriedOrb) {
      e.carriedOrb = false;
      rolling.add(new TdRollingOrb(min(e.s, pathTotal - 0.1f)));
    }
    if (app.flow != null) app.flow.playSfx("data/sounds/vocal-hah.wav");
  }

  void damageEnemyNearest(Vector2 from, float range, float dmg, float aoe, boolean aoeMode) {
    TdEnemy best = null;
    float bestD = 1e9f;
    for (TdEnemy e : enemies) {
      if (!e.alive) continue;
      float d = path.sample(e.s).distance(from);
      if (d < range && d < bestD) {
        bestD = d;
        best = e;
      }
    }
    if (best == null) return;
    if (!aoeMode) {
      applyDamage(best, dmg);
      return;
    }
    Vector2 hit = path.sample(best.s);
    for (TdEnemy e : enemies) {
      if (!e.alive) continue;
      if (path.sample(e.s).distance(hit) <= aoe) {
        applyDamage(e, dmg);
      }
    }
  }

  void applyDamage(TdEnemy e, float dmg) {
    e.hp -= dmg;
    if (e.hp <= 0) onEnemyKilled(e);
  }
}
