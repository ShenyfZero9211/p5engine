/**
 * Save/Load system: per-level JSON persistence.
 * Stored in data/save/level_{id}.json
 */
static final class TdSaveLoad {

  // ── Path helpers ──

  static String getSaveDir(PApplet app) {
    return app.sketchPath("data/save");
  }

  static String getSavePath(PApplet app, String levelId) {
    return getSaveDir(app) + "/level_" + levelId + ".json";
  }

  // ── Check save existence ──

  static boolean hasSave(PApplet app, String levelId) {
    return new java.io.File(getSavePath(app, levelId)).exists();
  }

  // ── Save ──

  static boolean saveGame(PApplet app) {
    if (TdGameWorld.level == null) return false;
    JSONObject json = new JSONObject();
    json.setInt("version", 1);
    json.setString("levelId", TdGameWorld.level.id);
    json.setString("difficultyKey", TdGameWorld.currentDifficultyKey);
    json.setInt("money", TdGameWorld.money);
    json.setInt("orbits", TdGameWorld.orbits);
    json.setInt("currentWave", TdGameWorld.currentWave);
    json.setInt("escapedEnemies", TdGameWorld.escapedEnemies);
    json.setBoolean("waveInProgress", TdGameWorld.waveInProgress);
    json.setFloat("waveTimer", TdGameWorld.waveTimer);
    json.setFloat("spawnTimer", TdGameWorld.spawnTimer);
    json.setInt("waveSpawnIndex", TdGameWorld.waveSpawnIndex);
    json.setInt("waveSpawnCount", TdGameWorld.waveSpawnCount);
    json.setBoolean("firstTowerPlaced", TdGameWorld.firstTowerPlaced);
    // Save activeSpawns for parallel wave support
    JSONArray aspArr = new JSONArray();
    for (int i = 0; i < TdGameWorld.activeSpawns.size(); i++) {
      TdGameWorld.ActiveSpawn asp = TdGameWorld.activeSpawns.get(i);
      JSONObject o = new JSONObject();
      o.setInt("idx", i);
      o.setInt("remaining", asp.remaining);
      o.setFloat("timer", asp.timer);
      aspArr.append(o);
    }
    json.setJSONArray("activeSpawns", aspArr);
    json.setFloat("baseIncomeAccumulator", TdGameWorld.baseIncomeAccumulator);
    json.setFloat("levelStartTotalTime", TdGameWorld.levelStartTotalTime);
    json.setFloat("levelPlayTime", TdGameWorld.levelPlayTime);
    json.setJSONArray("towers", serializeTowers());
    json.setJSONArray("enemies", serializeEnemies());
    json.setJSONArray("orbs", serializeOrbs());
    json.setJSONArray("pendingAttaches", serializePendingAttaches());

    try {
      java.io.File dir = new java.io.File(getSaveDir(app));
      if (!dir.exists()) dir.mkdirs();
      app.saveJSONObject(json, getSavePath(app, TdGameWorld.level.id));
      return true;
    }
    catch (Exception e) {
      println("[TdSaveLoad] Save failed: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  // ── Load ──

  static boolean loadGame(TowerDefenseMin2 app, String levelId) {
    try {
      String path = getSavePath(app, levelId);
      java.io.File f = new java.io.File(path);
      if (!f.exists()) return false;
      JSONObject json = app.loadJSONObject(path);
      if (json == null) return false;

      int version = json.getInt("version", 0);
      if (version != 1) {
        System.err.println("[TdSaveLoad] Save version mismatch: expected 1, got " + version);
        return false;
      }

      String diffKey = json.hasKey("difficultyKey") ? json.getString("difficultyKey") : "normal";

      // ── Phase 1: Validate save data BEFORE touching game state ──
      // Pre-load level def to validate route IDs against this level
      LevelDef ld = TdAssets.loadLevel(levelId, diffKey);
      if (ld == null) return false;

      // Validate enemy route IDs
      JSONArray enemiesArr = getJSONArrayOrEmpty(json, "enemies");
      for (int i = 0; i < enemiesArr.size(); i++) {
        JSONObject o = enemiesArr.getJSONObject(i);
        String activeRouteId = o.getString("activeRouteId", "");
        if (!activeRouteId.isEmpty()) {
          boolean found = false;
          if (ld.paths != null) {
            for (PathRoute pr : ld.paths) {
              if (pr.id.equals(activeRouteId)) {
                found = true;
                break;
              }
            }
          }
          if (!found) {
            println("[TdSaveLoad] Validation failed: enemy route '" + activeRouteId + "' not found in level " + levelId);
            return false;
          }
        }
      }
      // Validate orb route IDs
      JSONArray orbsArr = getJSONArrayOrEmpty(json, "orbs");
      for (int i = 0; i < orbsArr.size(); i++) {
        JSONObject o = orbsArr.getJSONObject(i);
        String routeId = o.getString("routeId", "");
        if (!routeId.isEmpty()) {
          boolean found = false;
          if (ld.paths != null) {
            for (PathRoute pr : ld.paths) {
              if (pr.id.equals(routeId)) {
                found = true;
                break;
              }
            }
          }
          if (!found) {
            println("[TdSaveLoad] Validation failed: orb route '" + routeId + "' not found in level " + levelId);
            return false;
          }
        }
      }

      // ── Phase 2: Apply save data (only after validation passed) ──
      boolean ok = TdGameWorld.startLevel(app, levelId, diffKey);
      if (!ok) return false;

      // Override game state
      TdGameWorld.money = json.getInt("money", TdGameWorld.money);
      TdGameWorld.orbits = json.getInt("orbits", TdGameWorld.orbits);
      TdGameWorld.currentWave = json.getInt("currentWave", TdGameWorld.currentWave);
      TdGameWorld.escapedEnemies = json.getInt("escapedEnemies", TdGameWorld.escapedEnemies);
      TdGameWorld.waveInProgress = json.getBoolean("waveInProgress", TdGameWorld.waveInProgress);
      TdGameWorld.waveTimer = json.getFloat("waveTimer", TdGameWorld.waveTimer);
      TdGameWorld.spawnTimer = json.getFloat("spawnTimer", TdGameWorld.spawnTimer);
      TdGameWorld.waveSpawnIndex = json.getInt("waveSpawnIndex", TdGameWorld.waveSpawnIndex);
      TdGameWorld.waveSpawnCount = json.getInt("waveSpawnCount", TdGameWorld.waveSpawnCount);
      TdGameWorld.firstTowerPlaced = json.getBoolean("firstTowerPlaced", TdGameWorld.firstTowerPlaced);
      TdGameWorld.baseIncomeAccumulator = json.getFloat("baseIncomeAccumulator", TdGameWorld.baseIncomeAccumulator);
      TdGameWorld.levelStartTotalTime = json.getFloat("levelStartTotalTime", TdGameWorld.levelStartTotalTime);
      TdGameWorld.levelPlayTime = json.getFloat("levelPlayTime", TdGameWorld.levelPlayTime);

      // Restore activeSpawns for parallel wave support (new format)
      JSONArray aspArr = json.getJSONArray("activeSpawns");
      if (aspArr != null && TdGameWorld.currentWave > 0 && TdGameWorld.level.waves != null) {
        TdGameWorld.activeSpawns.clear();
        WaveDef wave = TdGameWorld.level.waves[TdGameWorld.currentWave - 1];
        for (int i = 0; i < aspArr.size(); i++) {
          JSONObject o = aspArr.getJSONObject(i);
          int idx = o.getInt("idx", 0);
          if (idx >= 0 && idx < wave.spawns.length) {
            TdGameWorld.ActiveSpawn asp = new TdGameWorld.ActiveSpawn(wave.spawns[idx]);
            asp.remaining = o.getInt("remaining", asp.remaining);
            asp.timer = o.getFloat("timer", asp.timer);
            TdGameWorld.activeSpawns.add(asp);
          }
        }
      } else {
        // Legacy fallback: reconstruct activeSpawns from waveSpawnIndex/waveSpawnCount
        TdGameWorld.activeSpawns.clear();
        if (TdGameWorld.currentWave > 0 && TdGameWorld.level.waves != null) {
          WaveDef wave = TdGameWorld.level.waves[TdGameWorld.currentWave - 1];
          int idx = TdGameWorld.waveSpawnIndex;
          if (idx >= 0 && idx < wave.spawns.length) {
            TdGameWorld.ActiveSpawn asp = new TdGameWorld.ActiveSpawn(wave.spawns[idx]);
            asp.remaining = Math.max(0, wave.spawns[idx].count - TdGameWorld.waveSpawnCount);
            asp.timer = TdGameWorld.spawnTimer;
            TdGameWorld.activeSpawns.add(asp);
          }
        }
      }

      // Clear transient entities
      TdGameWorld.bullets.clear();
      TdGameWorld.effects.clear();
      TdGameWorld.pendingLaserHits.clear();

      // Rebuild persistent entities
      rebuildTowers(app, getJSONArrayOrEmpty(json, "towers"));
      rebuildEnemies(app, getJSONArrayOrEmpty(json, "enemies"));
      rebuildOrbs(app, getJSONArrayOrEmpty(json, "orbs"));
      rebuildPendingAttaches(getJSONArrayOrEmpty(json, "pendingAttaches"));

      return true;
    }
    catch (Exception e) {
      println("[TdSaveLoad] Load failed for level " + levelId + ": " + e.getMessage());
      e.printStackTrace();
      // Intentionally do NOT rollback - keep current game state unchanged on load failure
      return false;
    }
  }

  // ── Serialize ──

  static JSONArray serializeTowers() {
    JSONArray arr = new JSONArray();
    for (Tower t : TdGameWorld.towers) {
      if (t.isSelling) continue;
      JSONObject o = new JSONObject();
      o.setString("type", t.def.type.name());
      o.setInt("gridX", t.gridX);
      o.setInt("gridY", t.gridY);
      o.setBoolean("built", t.built);
      o.setFloat("buildProgress", t.buildProgress);
      o.setInt("upgradeLevel", t.upgradeLevel);
      o.setBoolean("isUpgrading", t.isUpgrading);
      o.setFloat("upgradeProgress", t.upgradeProgress);
      o.setFloat("cooldown", t.cooldown);
      arr.setJSONObject(arr.size(), o);
    }
    return arr;
  }

  static JSONArray serializeEnemies() {
    JSONArray arr = new JSONArray();
    for (Enemy e : TdGameWorld.enemies) {
      if (e.hp <= 0 || e.reachedEnd) continue;
      JSONObject o = new JSONObject();
      o.setString("type", e.enemyDef.key);
      o.setFloat("hp", e.hp);
      o.setFloat("maxHp", e.maxHp);
      o.setFloat("speed", e.speed);
      o.setFloat("slowFactor", e.slowFactor);
      o.setFloat("targetSlowFactor", e.targetSlowFactor);
      o.setFloat("slowTimer", e.slowTimer);
      o.setFloat("armor", e.armor);
      o.setFloat("maxArmor", e.maxArmor);
      o.setFloat("routeProgress", e.routeProgress);
      o.setString("state", e.state.name());
      o.setBoolean("hasStolen", e.hasStolen);
      o.setBoolean("backtracking", e.backtracking);
      o.setInt("orbsCarried", e.orbsCarried);
      o.setFloat("hitFlashTimer", e.hitFlashTimer);
      o.setString("activeRouteId", e.activeRoute != null ? e.activeRoute.id : "");
      o.setString("inboundRouteId", e.inboundRoute != null ? e.inboundRoute.id : "");
      // Poison stacks only
      JSONArray poisons = new JSONArray();
      for (EnemyStatusEffect se : e.statusEffects) {
        if (se instanceof PoisonStatusEffect) {
          PoisonStatusEffect p = (PoisonStatusEffect) se;
          JSONObject pobj = new JSONObject();
          pobj.setFloat("dps", p.dps);
          pobj.setFloat("duration", p.timer);
          pobj.setFloat("timer", p.tickTimer);
          pobj.setInt("stackIndex", p.stackIndex);
          poisons.setJSONObject(poisons.size(), pobj);
        }
      }
      o.setJSONArray("poisons", poisons);
      arr.setJSONObject(arr.size(), o);
    }
    return arr;
  }

  static JSONArray serializeOrbs() {
    JSONArray arr = new JSONArray();
    for (Orb orb : TdGameWorld.orbs) {
      JSONObject o = new JSONObject();
      o.setString("routeId", orb.route != null ? orb.route.id : "");
      o.setFloat("pathDistance", orb.pathDistance);
      arr.setJSONObject(arr.size(), o);
    }
    return arr;
  }

  static JSONArray serializePendingAttaches() {
    JSONArray arr = new JSONArray();
    for (PendingAttach pa : TdGameWorld.pendingAttaches) {
      JSONObject o = new JSONObject();
      o.setFloat("timer", pa.timer);
      o.setString("enemyType", pa.enemyType);
      o.setInt("count", pa.count);
      o.setString("route", pa.route);
      o.setFloat("hpMulti", pa.hpMulti);
      arr.setJSONObject(arr.size(), o);
    }
    return arr;
  }

  // ── Deserialize / Rebuild ──

  static void rebuildTowers(TowerDefenseMin2 app, JSONArray arr) {
    TdGameWorld.towers.clear();
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      String typeStr = o.getString("type", "MG");
      TowerType tt;
      try {
        tt = TowerType.valueOf(typeStr);
      }
      catch (Exception ex) {
        continue;
      }
      TowerDef def = TdAssets.loadTowerDef(tt);
      if (def == null) continue;

      Tower t = new Tower(def, o.getInt("gridX"), o.getInt("gridY"));
      t.built = o.getBoolean("built", false);
      t.buildProgress = o.getFloat("buildProgress", 0f);
      t.upgradeLevel = o.getInt("upgradeLevel", 0);
      t.isUpgrading = o.getBoolean("isUpgrading", false);
      t.upgradeProgress = o.getFloat("upgradeProgress", 0f);
      t.cooldown = o.getFloat("cooldown", 0f);

      GameObject go = GameObject.create("Tower");
      go.getTransform().setPosition(t.worldX, t.worldY);
      go.setRenderLayer(5);
      go.addComponent(new TowerRenderer(t));
      app.gameScene.addGameObject(go);
      t.gameObject = go;
      TdGameWorld.towers.add(t);
    }
  }

  static void rebuildEnemies(TowerDefenseMin2 app, JSONArray arr) {
    TdGameWorld.enemies.clear();
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      String typeKey = o.getString("type", "");
      EnemyDef def = TdAssets.loadEnemyDef(typeKey);
      if (def == null) continue;

      Enemy e = new Enemy();
      e.enemyDef = def;
      e.hp = o.getFloat("hp", 1f);
      e.maxHp = o.getFloat("maxHp", 1f);
      e.speed = o.getFloat("speed", 60f);
      e.radius = def.radius;
      e.slowFactor = o.getFloat("slowFactor", 1f);
      e.targetSlowFactor = o.getFloat("targetSlowFactor", 1f);
      e.slowTimer = o.getFloat("slowTimer", 0f);
      e.armor = o.getFloat("armor", def.armor);
      e.maxArmor = o.getFloat("maxArmor", e.armor);
      e.routeProgress = o.getFloat("routeProgress", 0f);
      String stateStr = o.getString("state", "MOVE_TO_BASE");
      try {
        e.state = EnemyState.valueOf(stateStr);
      }
      catch (Exception ex) {
        e.state = EnemyState.MOVE_TO_BASE;
      }
      e.hasStolen = o.getBoolean("hasStolen", false);
      e.backtracking = o.getBoolean("backtracking", false);
      e.orbsCarried = o.getInt("orbsCarried", 0);
      e.hitFlashTimer = o.getFloat("hitFlashTimer", 0f);

      String activeRouteId = o.getString("activeRouteId", "");
      String inboundRouteId = o.getString("inboundRouteId", "");
      e.activeRoute = findRoute(activeRouteId);
      e.inboundRoute = findRoute(inboundRouteId);
      if (e.state == EnemyState.FLEE && !e.backtracking) {
        e.outboundRoute = e.activeRoute;
      }

      if (e.activeRoute != null && e.activeRoute.path != null) {
        e.pos = e.activeRoute.path.sample(PApplet.constrain(e.routeProgress, 0, e.activeRoute.path.getTotalLength()));
        GameObject go = GameObject.create("Enemy");
        go.getTransform().setPosition(e.pos.x, e.pos.y);
        Vector2 dir = e.activeRoute.path.direction(e.routeProgress);
        if (dir != null) go.getTransform().setRotation(PApplet.atan2(dir.y, dir.x));
        go.setRenderLayer(10);
        go.addComponent(new EnemyRenderer(e));
        app.gameScene.addGameObject(go);
        e.gameObject = go;
      }
      if (e.pos == null) {
        println("[TdSaveLoad] Warning: skipping enemy with null pos, routeId=" + activeRouteId + " in level " + TdGameWorld.level.id);
        continue;
      }
      TdGameWorld.enemies.add(e);

      // Restore poison stacks
      JSONArray poisons = o.hasKey("poisons") ? o.getJSONArray("poisons") : null;
      if (poisons != null) {
        for (int j = 0; j < poisons.size(); j++) {
          JSONObject p = poisons.getJSONObject(j);
          float dps = p.getFloat("dps", 0f);
          float duration = p.getFloat("duration", 0f);
          int stackIndex = p.getInt("stackIndex", 0);
          PoisonStatusEffect pse = new PoisonStatusEffect(dps, duration, stackIndex);
          pse.tickTimer = p.getFloat("timer", 0.5f);
          e.statusEffects.add(pse);
        }
      }
    }
  }

  static void rebuildOrbs(TowerDefenseMin2 app, JSONArray arr) {
    TdGameWorld.orbs.clear();
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      String routeId = o.getString("routeId", "");
      PathRoute route = findRoute(routeId);
      if (route == null || route.path == null) continue;

      Orb orb = new Orb();
      orb.route = route;
      orb.pathDistance = o.getFloat("pathDistance", route.baseDistance);
      orb.pos = route.path.sample(orb.pathDistance);
      GameObject go = GameObject.create("Orb");
      go.getTransform().setPosition(orb.pos.x, orb.pos.y);
      go.setRenderLayer(12);
      go.addComponent(new OrbRenderer(orb));
      app.gameScene.addGameObject(go);
      orb.gameObject = go;
      TdGameWorld.orbs.add(orb);
    }
  }

  static void rebuildPendingAttaches(JSONArray arr) {
    TdGameWorld.pendingAttaches.clear();
    if (arr == null) return;
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      float timer = o.getFloat("timer", 0f);
      String enemyType = o.getString("enemyType", "");
      int count = o.getInt("count", 1);
      String route = o.getString("route", null);
      float hpMulti = o.getFloat("hpMulti", 1.0f);
      TdGameWorld.pendingAttaches.add(new PendingAttach(timer, enemyType, count, route, hpMulti, null));
    }
  }

  static JSONArray getJSONArrayOrEmpty(JSONObject json, String key) {
    if (json.hasKey(key)) {
      Object val = json.get(key);
      if (val instanceof JSONArray) return (JSONArray) val;
    }
    return new JSONArray();
  }

  static PathRoute findRoute(String routeId) {
    if (TdGameWorld.level == null || TdGameWorld.level.paths == null || routeId == null || routeId.isEmpty())
      return null;
    for (PathRoute pr : TdGameWorld.level.paths) {
      if (routeId.equals(pr.id)) return pr;
    }
    return null;
  }
}
