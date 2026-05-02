/**
 * Asset loading: i18n, YAML configs, audio init.
 */
static final class TdAssets {

    // ── Load all ──

    static void loadAll(PApplet app) {
        loadConfigs(app);
        loadI18n(P5Engine.getInstance());
    }

    // ── i18n ──

    static void loadI18n(P5Engine engine) {
        // I18n auto-loads data/i18n/{locale}.json on setLocale
        engine.getI18n().setLocale("zh");
    }

    static String i18n(String key) {
        return P5Engine.getInstance().getI18n().get(key);
    }

    static String i18n(String key, Object... args) {
        return P5Engine.getInstance().getI18n().get(key, args);
    }

    // ── YAML configs ──

    static java.util.Map towerYamlRoot;
    static java.util.List levelYamlList;
    static java.util.Map enemyYamlRoot;
    static java.util.Map gameSettingsYamlRoot;

    static void loadConfigs(PApplet app) {
        org.yaml.snakeyaml.Yaml yaml = new org.yaml.snakeyaml.Yaml();

        java.io.InputStream tis = app.createInput("config/towers.yaml");
        if (tis == null) throw new RuntimeException("Cannot load config/towers.yaml");
        towerYamlRoot = (java.util.Map) yaml.load(tis);

        java.io.InputStream lis = app.createInput("config/levels/levels.yaml");
        if (lis == null) throw new RuntimeException("Cannot load config/levels/levels.yaml");
        levelYamlList = (java.util.List) yaml.load(lis);

        java.io.InputStream eis = app.createInput("config/enemies.yaml");
        if (eis == null) throw new RuntimeException("Cannot load config/enemies.yaml");
        enemyYamlRoot = (java.util.Map) yaml.load(eis);

        java.io.InputStream gis = app.createInput("config/game_settings.yaml");
        if (gis != null) {
            gameSettingsYamlRoot = (java.util.Map) yaml.load(gis);
        }
    }

    static TowerDef loadTowerDef(TowerType type) {
        String id = type.name().toLowerCase();
        java.util.Map towers = (java.util.Map) towerYamlRoot.get("towers");
        java.util.Map t = (java.util.Map) towers.get(id);
        if (t == null) return null;

        java.util.List c = (java.util.List) t.get("iconColor");
        int iconColor = 0xFF000000 | (((Number)c.get(0)).intValue() << 16)
                                      | (((Number)c.get(1)).intValue() << 8)
                                      | ((Number)c.get(2)).intValue();

        java.util.Map sfx = (java.util.Map) t.get("sfx");

        return new TowerDef(
            type,
            (String) t.get("nameKey"),
            (String) t.get("descKey"),
            ((Number) t.get("cost")).intValue(),
            ((Number) t.get("range")).floatValue(),
            ((Number) t.get("firePeriod")).floatValue(),
            ((Number) t.get("damage")).floatValue(),
            ((Number) t.get("aoeRadius")).floatValue(),
            ((Number) t.get("laserBonus")).floatValue(),
            ((Number) t.get("slowFactor")).floatValue(),
            t.containsKey("slowDuration") ? ((Number) t.get("slowDuration")).floatValue() : 0f,
            t.containsKey("laserDelay") ? ((Number) t.get("laserDelay")).floatValue() : 0f,
            ((Number) t.get("buildTime")).floatValue(),
            iconColor,
            sfx != null ? (String) sfx.get("fire") : null,
            sfx != null ? (String) sfx.get("place") : null,
            sfx != null ? (String) sfx.get("complete") : null
        );
    }

    static LevelDef loadLevel(int levelId) {
        // Verify level exists in index
        boolean found = false;
        for (Object obj : levelYamlList) {
            java.util.Map meta = (java.util.Map) obj;
            int id = ((Number) meta.get("id")).intValue();
            if (id == levelId) {
                found = true;
                break;
            }
        }
        if (!found) return null;

        // Load detailed level data from individual file
        org.yaml.snakeyaml.Yaml yaml = new org.yaml.snakeyaml.Yaml();
        java.io.InputStream levelIs = P5Engine.getInstance().getApplet().createInput("config/levels/level_" + levelId + ".yaml");
        if (levelIs == null) {
            throw new RuntimeException("Cannot load config/levels/level_" + levelId + ".yaml");
        }
        java.util.Map lvl = (java.util.Map) yaml.load(levelIs);
        return parseLevel(lvl);
    }

    static SpawnAttach[] loadAttaches(java.util.Map s) {
        java.util.List attachList = (java.util.List) s.get("attach");
        if (attachList == null || attachList.isEmpty()) return null;
        SpawnAttach[] attaches = new SpawnAttach[attachList.size()];
        for (int i = 0; i < attachList.size(); i++) {
            java.util.Map a = (java.util.Map) attachList.get(i);
            int count = a.containsKey("count") ? ((Number) a.get("count")).intValue() : 1;
            float delay = a.containsKey("delay") ? ((Number) a.get("delay")).floatValue() : 0f;
            attaches[i] = new SpawnAttach(
                (String) a.get("type"),
                count,
                delay,
                (String) a.get("route"),
                loadAttaches(a)
            );
        }
        return attaches;
    }

    static float getBaseIncomeRate() {
        if (gameSettingsYamlRoot == null) return 0.25f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 0.25f;
        Object rate = gs.get("baseIncomeRate");
        if (rate instanceof Number) return ((Number) rate).floatValue();
        return 0.25f;
    }

    static int getLevelCount() {
        return levelYamlList != null ? levelYamlList.size() : 0;
    }

    static EnemyDef loadEnemyDef(String typeKey) {
        if (enemyYamlRoot == null) return null;
        java.util.Map enemies = (java.util.Map) enemyYamlRoot.get("enemies");
        java.util.Map e = (java.util.Map) enemies.get(typeKey);
        if (e == null) return null;
        String sfxDeath = (String) e.get("sfxDeath");
        if (sfxDeath == null) sfxDeath = TdSound.SFX_DEATH;
        int killReward = e.containsKey("killReward") ? ((Number) e.get("killReward")).intValue() : 10;
        return new EnemyDef(
            typeKey,
            (String) e.get("nameKey"),
            ((Number) e.get("speedMultiplier")).floatValue(),
            ((Number) e.get("hpMultiplier")).floatValue(),
            ((Number) e.get("orbCapacity")).intValue(),
            ((Number) e.get("radius")).floatValue(),
            killReward,
            sfxDeath
        );
    }

    private static LevelDef parseLevel(java.util.Map lvl) {
        LevelDef ld = new LevelDef();
        ld.id = ((Number) lvl.get("id")).intValue();
        ld.nameKey = (String) lvl.get("nameKey");
        ld.subtitleKey = (String) lvl.get("subtitleKey");
        String lt = (String) lvl.get("levelType");
        ld.levelType = "SURVIVAL".equals(lt) ? LevelType.SURVIVAL : LevelType.DEFEND_BASE;
        ld.initialMoney = ((Number) lvl.get("initialMoney")).intValue();
        if (ld.levelType == LevelType.DEFEND_BASE) {
            ld.baseOrbs = ((Number) lvl.get("baseOrbs")).intValue();
        } else {
            ld.maxEscapeCount = ((Number) lvl.get("maxEscapeCount")).intValue();
        }
        ld.worldW = ((Number) lvl.get("worldWidth")).intValue();
        ld.worldH = ((Number) lvl.get("worldHeight")).intValue();
        ld.enemyHpBase = ((Number) lvl.get("enemyHpBase")).floatValue();

        // Positions
        java.util.Map base = (java.util.Map) lvl.get("basePos");
        ld.basePos = new Vector2(((Number)base.get("x")).floatValue(), ((Number)base.get("y")).floatValue());
        java.util.Map exit = (java.util.Map) lvl.get("exitPos");
        ld.exitPos = new Vector2(((Number)exit.get("x")).floatValue(), ((Number)exit.get("y")).floatValue());
        java.util.Map spawn = (java.util.Map) lvl.get("spawnPos");
        ld.spawnPos = new Vector2(((Number)spawn.get("x")).floatValue(), ((Number)spawn.get("y")).floatValue());

        // Paths — new multi-path format
        java.util.List pathList = (java.util.List) lvl.get("paths");
        if (pathList != null) {
            ld.paths = new PathRoute[pathList.size()];
            for (int i = 0; i < pathList.size(); i++) {
                java.util.Map p = (java.util.Map) pathList.get(i);
                String pid = (String) p.get("id");
                String ptype = (String) p.get("type");
                RouteType rt = RouteType.INBOUND;
                if ("OUTBOUND".equalsIgnoreCase(ptype)) rt = RouteType.OUTBOUND;
                else if ("DIRECT".equalsIgnoreCase(ptype)) rt = RouteType.DIRECT;
                java.util.List ppts = (java.util.List) p.get("points");
                Vector2[] points = new Vector2[ppts.size()];
                for (int j = 0; j < ppts.size(); j++) {
                    java.util.Map pm = (java.util.Map) ppts.get(j);
                    points[j] = new Vector2(((Number)pm.get("x")).floatValue(), ((Number)pm.get("y")).floatValue());
                }
                ld.paths[i] = new PathRoute(pid, rt, points, ld.basePos);
            }
        }

        // Legacy pathPoints — auto-convert to PathRoute(s)
        java.util.List pts = (java.util.List) lvl.get("pathPoints");
        if (pts != null) {
            ld.pathPoints = new Vector2[pts.size()];
            for (int i = 0; i < pts.size(); i++) {
                java.util.Map p = (java.util.Map) pts.get(i);
                ld.pathPoints[i] = new Vector2(((Number)p.get("x")).floatValue(), ((Number)p.get("y")).floatValue());
            }
            // Auto-build PathRoutes from legacy pathPoints if paths not provided
            if (ld.paths == null && ld.pathPoints.length > 1) {
                // Find point closest to basePos
                int baseIdx = 0;
                float bestD = Float.MAX_VALUE;
                for (int i = 0; i < ld.pathPoints.length; i++) {
                    float d = ld.pathPoints[i].distance(ld.basePos);
                    if (d < bestD) {
                        bestD = d;
                        baseIdx = i;
                    }
                }
                if (ld.levelType == LevelType.DEFEND_BASE) {
                    ld.paths = new PathRoute[2];
                    // INBOUND: spawn -> base
                    Vector2[] inbound = new Vector2[baseIdx + 1];
                    System.arraycopy(ld.pathPoints, 0, inbound, 0, baseIdx + 1);
                    ld.paths[0] = new PathRoute("legacy_inbound", RouteType.INBOUND, inbound, ld.basePos);
                    // OUTBOUND: base -> exit
                    Vector2[] outbound = new Vector2[ld.pathPoints.length - baseIdx];
                    System.arraycopy(ld.pathPoints, baseIdx, outbound, 0, ld.pathPoints.length - baseIdx);
                    ld.paths[1] = new PathRoute("legacy_outbound", RouteType.OUTBOUND, outbound, ld.basePos);
                } else {
                    // SURVIVAL: single DIRECT path
                    ld.paths = new PathRoute[1];
                    ld.paths[0] = new PathRoute("legacy_direct", RouteType.DIRECT, ld.pathPoints, null);
                }
            }
        }

        // Waves
        java.util.List waveList = (java.util.List) lvl.get("waves");
        if (waveList != null) {
            ld.waves = new WaveDef[waveList.size()];
            for (int i = 0; i < waveList.size(); i++) {
                java.util.Map w = (java.util.Map) waveList.get(i);
                float delay = ((Number) w.get("delay")).floatValue();
                java.util.List spawnList = (java.util.List) w.get("spawns");
                WaveSpawn[] spawns = new WaveSpawn[spawnList != null ? spawnList.size() : 0];
                for (int j = 0; j < spawns.length; j++) {
                    java.util.Map s = (java.util.Map) spawnList.get(j);
                    spawns[j] = new WaveSpawn(
                        (String) s.get("type"),
                        ((Number) s.get("count")).intValue(),
                        ((Number) s.get("interval")).floatValue(),
                        (String) s.get("route"),
                        loadAttaches(s)
                    );
                }
                ld.waves[i] = new WaveDef(delay, spawns);
            }
        }

        // Allowed towers (optional, default all)
        java.util.List towerList = (java.util.List) lvl.get("allowedTowers");
        if (towerList != null) {
            ld.allowedTowers = new TowerType[towerList.size()];
            for (int i = 0; i < towerList.size(); i++) {
                String tt = (String) towerList.get(i);
                try {
                    ld.allowedTowers[i] = TowerType.valueOf(tt.toUpperCase());
                } catch (Exception ex) {
                    ld.allowedTowers[i] = null;
                }
            }
        }

        // Earn money on kill (optional, default true)
        Object earnObj = lvl.get("earnMoneyOnKill");
        if (earnObj != null) {
            ld.earnMoneyOnKill = Boolean.parseBoolean(earnObj.toString());
        } else {
            ld.earnMoneyOnKill = true;
        }

        return ld;
    }

    // ── Audio helpers ──

    static void playSfx(String path) {
        try {
            P5Engine.getInstance().getAudio().playOneShot(path, "sfx");
        } catch (Exception e) {
            // ignore audio errors during development
        }
    }

    static void setMasterVolume(float v) {
        P5Engine.getInstance().getAudio().setMasterVolume(v);
    }

    static void setBgmVolume(float v) {
        P5Engine.getInstance().getAudio().setGroupVolume("bgm", v);
    }

    static void setSfxVolume(float v) {
        P5Engine.getInstance().getAudio().setGroupVolume("sfx", v);
    }
}
