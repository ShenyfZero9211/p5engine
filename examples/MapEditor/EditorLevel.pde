// ============================================
// Data Models
// ============================================

enum EditorTool {
  SELECT, SPAWN, BASE, EXIT, PATH, ERASE
}

enum EditorEntityType {
  SPAWN, BASE, EXIT, PATH_POINT
}

enum PathRouteType {
  INBOUND, OUTBOUND, DIRECT
}

enum PathMode {
  PATH_POINTS,   // Simple level: single pathPoints list
  MULTI_PATHS    // Multi-path level: multiple paths with id/type
}

static class EditorLevel {
  int id = 1;
  String nameKey = "level.new.name";
  String subtitleKey = "level.new.subtitle";
  LevelType levelType = LevelType.DEFEND_BASE;
  int initialMoney = 300;
  int baseOrbs = 5;
  int maxEscapeCount = 15;
  int enemyHpBase = 100;
  String allowedTowers = "";
  boolean earnMoneyOnKill = true;
  int worldW = 1600;
  int worldH = 1200;

  PathMode pathMode = PathMode.PATH_POINTS;

  Vector2 basePos;
  Vector2 exitPos;
  Vector2 spawnPos;

  // Simple single path (for backward compatibility)
  ArrayList<Vector2> pathPoints = new ArrayList<>();

  // Multi paths
  ArrayList<EditorPath> paths = new ArrayList<>();

  // Waves
  ArrayList<EditorWave> waves = new ArrayList<>();
}

static class EditorPath {
  String id = "";
  PathRouteType type = PathRouteType.DIRECT;
  ArrayList<Vector2> points = new ArrayList<>();
}

static class EditorWave {
  float delay = 2.0f;
  ArrayList<EditorSpawn> spawns = new ArrayList<>();
}

static class EditorSpawn {
  String type = "level1";
  int count = 5;
  float interval = 1.0f;
  String route = "";
}

static class EditorEntity {
  EditorEntityType type;
  Vector2 position;
  EditorPath pathRef; // for path points that belong to a multi-path

  EditorEntity(EditorEntityType type, Vector2 position) {
    this.type = type;
    this.position = position;
  }
}

// Compatibility with TowerDefenseMin2 YAML types
enum LevelType {
  DEFEND_BASE, SURVIVAL
}
