// ============================================
// YAML Load / Save
// ============================================

import java.util.Map;
import java.util.List;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.DumperOptions;

static EditorLevel loadLevelFromYaml(String yamlPath) {
  try {
    String content = "";
    if (MapEditor.inst != null) {
      content = join(MapEditor.inst.loadStrings(yamlPath), "\n");
    }
    return loadLevelFromYamlString(content);
  } catch (Exception e) {
    println("[ERROR] Failed to load YAML: " + e.getMessage());
    e.printStackTrace();
    return new EditorLevel();
  }
}

static EditorLevel loadLevelFromYamlString(String content) {
  EditorLevel level = new EditorLevel();
  if (content == null || content.isEmpty()) return level;

  try {
    Yaml yaml = new Yaml();
    Map<String, Object> data = (Map<String, Object>) yaml.load(content);
    if (data == null) return level;

    level.id = getInt(data, "id", 1);
    level.nameKey = getString(data, "nameKey", "level.new.name");
    level.subtitleKey = getString(data, "subtitleKey", "level.new.subtitle");
    String lt = getString(data, "levelType", "DEFEND_BASE");
    level.levelType = "SURVIVAL".equals(lt) ? LevelType.SURVIVAL : LevelType.DEFEND_BASE;
    level.initialMoney = getInt(data, "initialMoney", 300);
    level.baseOrbs = getInt(data, "baseOrbs", 5);
    level.maxEscapeCount = getInt(data, "maxEscapeCount", 15);
    level.enemyHpBase = getInt(data, "enemyHpBase", 100);
    level.worldW = getInt(data, "worldWidth", 1600);
    level.worldH = getInt(data, "worldHeight", 1200);

    // Allowed towers
    List<String> towerList = (List<String>) data.get("allowedTowers");
    if (towerList != null) {
      StringBuilder towers = new StringBuilder();
      for (String tt : towerList) {
        if (towers.length() > 0) towers.append(",");
        towers.append(tt);
      }
      level.allowedTowers = towers.toString();
    }

    // Earn money on kill
    Object earnObj = data.get("earnMoneyOnKill");
    if (earnObj != null) {
      level.earnMoneyOnKill = Boolean.parseBoolean(earnObj.toString());
    } else {
      level.earnMoneyOnKill = true;
    }

    Map<String, Number> basePos = (Map<String, Number>) data.get("basePos");
    if (basePos != null) {
      level.basePos = new Vector2(basePos.get("x").floatValue(), basePos.get("y").floatValue());
    }
    Map<String, Number> exitPos = (Map<String, Number>) data.get("exitPos");
    if (exitPos != null) {
      level.exitPos = new Vector2(exitPos.get("x").floatValue(), exitPos.get("y").floatValue());
    }
    Map<String, Number> spawnPos = (Map<String, Number>) data.get("spawnPos");
    if (spawnPos != null) {
      level.spawnPos = new Vector2(spawnPos.get("x").floatValue(), spawnPos.get("y").floatValue());
    }

    // Determine path mode from YAML content
    List<Map<String, Object>> paths = (List<Map<String, Object>>) data.get("paths");
    List<Map<String, Number>> pathPoints = (List<Map<String, Number>>) data.get("pathPoints");
    if (paths != null && !paths.isEmpty()) {
      level.pathMode = PathMode.MULTI_PATHS;
      for (Map<String, Object> p : paths) {
        EditorPath path = new EditorPath();
        path.id = getString(p, "id", "");
        String pt = getString(p, "type", "DIRECT");
        path.type = PathRouteType.valueOf(pt);
        List<Map<String, Number>> pts = (List<Map<String, Number>>) p.get("points");
        if (pts != null) {
          for (Map<String, Number> pt2 : pts) {
            path.points.add(new Vector2(pt2.get("x").floatValue(), pt2.get("y").floatValue()));
          }
        }
        level.paths.add(path);
      }
    } else if (pathPoints != null) {
      level.pathMode = PathMode.PATH_POINTS;
      for (Map<String, Number> pt : pathPoints) {
        level.pathPoints.add(new Vector2(pt.get("x").floatValue(), pt.get("y").floatValue()));
      }
    }

    // Waves
    List<Map<String, Object>> waves = (List<Map<String, Object>>) data.get("waves");
    if (waves != null) {
      for (Map<String, Object> w : waves) {
        EditorWave wave = new EditorWave();
        wave.delay = getFloat(w, "delay", 2.0f);
        List<Map<String, Object>> spawns = (List<Map<String, Object>>) w.get("spawns");
        if (spawns != null) {
          for (Map<String, Object> s : spawns) {
            EditorSpawn spawn = new EditorSpawn();
            spawn.type = getString(s, "type", "level1");
            spawn.count = getInt(s, "count", 5);
            spawn.interval = getFloat(s, "interval", 1.0f);
            spawn.route = getString(s, "route", "");
            wave.spawns.add(spawn);
          }
        }
        level.waves.add(wave);
      }
    }

  } catch (Exception e) {
    println("[ERROR] Failed to load YAML: " + e.getMessage());
    e.printStackTrace();
  }
  return level;
}

static String saveLevelToYaml(EditorLevel level) {
  StringBuilder sb = new StringBuilder();
  sb.append("id: ").append(level.id).append("\n");
  sb.append("nameKey: ").append(level.nameKey).append("\n");
  sb.append("subtitleKey: ").append(level.subtitleKey).append("\n");
  sb.append("levelType: ").append(level.levelType.name()).append("\n");
  sb.append("initialMoney: ").append(level.initialMoney).append("\n");
  if (level.levelType == LevelType.DEFEND_BASE) {
    sb.append("baseOrbs: ").append(level.baseOrbs).append("\n");
  } else {
    sb.append("maxEscapeCount: ").append(level.maxEscapeCount).append("\n");
  }
  sb.append("enemyHpBase: ").append(level.enemyHpBase).append("\n");
  sb.append("worldWidth: ").append(level.worldW).append("\n");
  sb.append("worldHeight: ").append(level.worldH).append("\n");

  if (level.basePos != null) {
    sb.append("basePos: { x: ").append((int)level.basePos.x).append(", y: ").append((int)level.basePos.y).append(" }\n");
  }
  if (level.exitPos != null) {
    sb.append("exitPos: { x: ").append((int)level.exitPos.x).append(", y: ").append((int)level.exitPos.y).append(" }\n");
  }
  if (level.spawnPos != null) {
    sb.append("spawnPos: { x: ").append((int)level.spawnPos.x).append(", y: ").append((int)level.spawnPos.y).append(" }\n");
  }

  // Paths based on mode
  if (level.pathMode == PathMode.PATH_POINTS && !level.pathPoints.isEmpty()) {
    sb.append("pathPoints:\n");
    for (Vector2 pt : level.pathPoints) {
      sb.append("  - { x: ").append((int)pt.x).append(", y: ").append((int)pt.y).append(" }\n");
    }
  } else if (level.pathMode == PathMode.MULTI_PATHS && !level.paths.isEmpty()) {
    sb.append("paths:\n");
    for (EditorPath path : level.paths) {
      sb.append("  - id: ").append(path.id).append("\n");
      sb.append("    type: ").append(path.type.name()).append("\n");
      sb.append("    points:\n");
      for (Vector2 pt : path.points) {
        sb.append("      - { x: ").append((int)pt.x).append(", y: ").append((int)pt.y).append(" }\n");
      }
    }
  }

  // Allowed towers
  if (!level.allowedTowers.isEmpty()) {
    sb.append("allowedTowers: [");
    String[] towers = level.allowedTowers.split(",");
    for (int i = 0; i < towers.length; i++) {
      if (i > 0) sb.append(", ");
      sb.append(towers[i].trim());
    }
    sb.append("]\n");
  }

  // Earn money on kill
  sb.append("earnMoneyOnKill: ").append(level.earnMoneyOnKill).append("\n");

  // Waves
  if (!level.waves.isEmpty()) {
    sb.append("waves:\n");
    for (EditorWave wave : level.waves) {
      sb.append("  - delay: ").append(wave.delay).append("\n");
      sb.append("    spawns:\n");
      for (EditorSpawn spawn : wave.spawns) {
        sb.append("      - type: ").append(spawn.type).append("\n");
        sb.append("        count: ").append(spawn.count).append("\n");
        sb.append("        interval: ").append(spawn.interval).append("\n");
        if (!spawn.route.isEmpty()) {
          sb.append("        route: ").append(spawn.route).append("\n");
        }
      }
    }
  }

  return sb.toString();
}

// Helper methods
static int getInt(Map<String, Object> map, String key, int def) {
  Object v = map.get(key);
  if (v instanceof Number) return ((Number) v).intValue();
  return def;
}

static float getFloat(Map<String, Object> map, String key, float def) {
  Object v = map.get(key);
  if (v instanceof Number) return ((Number) v).floatValue();
  return def;
}

static String getString(Map<String, Object> map, String key, String def) {
  Object v = map.get(key);
  if (v instanceof String) return (String) v;
  return def;
}
