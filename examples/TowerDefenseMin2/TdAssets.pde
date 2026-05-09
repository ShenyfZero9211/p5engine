/**
 * Asset loading: i18n, YAML configs, audio init.
 */
static final class TdAssets {

    // ── Ruins textures (loaded via engine ImageManager) ──
    static shenyf.p5engine.rendering.Texture[] RUINS_TEXTURES;
    static int RUINS_TEXTURE_COUNT = 0;

    // ── Texture atlas config ──
    public static final class TextureConfig {
        public final String scaleMode;
        public final float scale;
        public final String anchor;
        public final float globalScale;

        public TextureConfig(String scaleMode, float scale, String anchor, float globalScale) {
            this.scaleMode = scaleMode;
            this.scale = scale;
            this.anchor = anchor;
            this.globalScale = globalScale;
        }
    }

    public static final class TextureSetConfig {
        public final TextureConfig defaultConfig;
        public final java.util.Map<String, TextureConfig> entries;

        public TextureSetConfig(TextureConfig defaultConfig, java.util.Map<String, TextureConfig> entries) {
            this.defaultConfig = defaultConfig;
            this.entries = entries;
        }

        public TextureConfig resolve(String fileName) {
            TextureConfig cfg = entries.get(fileName);
            return cfg != null ? cfg : defaultConfig;
        }
    }

    public static java.util.Map<String, TextureSetConfig> TEXTURE_SET_CONFIGS;

    public static TextureConfig getTextureConfig(String setName, String fileName) {
        if (TEXTURE_SET_CONFIGS == null) return null;
        TextureSetConfig set = TEXTURE_SET_CONFIGS.get(setName);
        if (set == null) return null;
        return set.resolve(fileName);
    }

    static void loadRuinsTextures(shenyf.p5engine.rendering.ImageManager images) {
        if (images == null) return;
        java.io.File dir = new java.io.File(
            P5Engine.getInstance().getApplet().sketchPath("textures"));
        java.util.List<shenyf.p5engine.rendering.Texture> list =
            new java.util.ArrayList<>();
        if (dir.exists()) {
            java.io.File[] files = dir.listFiles(new java.io.FilenameFilter() {
                public boolean accept(java.io.File d, String name) {
                    return name.startsWith("ruins_") && name.endsWith(".png");
                }
            });
            if (files != null) {
                java.util.Arrays.sort(files,
                    (a, b) -> a.getName().compareTo(b.getName()));
                for (java.io.File f : files) {
                    shenyf.p5engine.rendering.Texture tex =
                        images.load("textures/" + f.getName());
                    if (tex != null) list.add(tex);
                }
            }
        }
        RUINS_TEXTURES = list.toArray(
            new shenyf.p5engine.rendering.Texture[0]);
        RUINS_TEXTURE_COUNT = RUINS_TEXTURES.length;
    }

    // ── Load all ──

    static void loadAll(PApplet app) {
        loadConfigs(app);
        loadTextureConfigs(app);
        loadI18n(P5Engine.getInstance());
    }

    static void loadTextureConfigs(PApplet app) {
        org.yaml.snakeyaml.Yaml yaml = new org.yaml.snakeyaml.Yaml();
        java.io.InputStream is = app.createInput("config/textures.yaml");
        if (is == null) return;
        java.util.Map root = (java.util.Map) yaml.load(is);
        java.util.Map sets = (java.util.Map) root.get("textureSets");
        if (sets == null) return;

        TEXTURE_SET_CONFIGS = new java.util.HashMap<>();
        for (Object setKeyObj : sets.keySet()) {
            String setName = (String) setKeyObj;
            java.util.Map setData = (java.util.Map) sets.get(setKeyObj);

            java.util.Map defMap = (java.util.Map) setData.get("default");
            String defMode = defMap != null ? (String) defMap.get("scaleMode") : "fit";
            float defScale = defMap != null ? ((Number) defMap.getOrDefault("scale", 1.0)).floatValue() : 1.0f;
            String defAnchor = defMap != null ? (String) defMap.getOrDefault("anchor", "center") : "center";
            float defGlobal = defMap != null ? ((Number) defMap.getOrDefault("globalScale", 1.0)).floatValue() : 1.0f;
            TextureConfig defaultCfg = new TextureConfig(defMode, defScale, defAnchor, defGlobal);

            java.util.Map<String, TextureConfig> entries = new java.util.HashMap<>();
            java.util.Map entMap = (java.util.Map) setData.get("entries");
            if (entMap != null) {
                for (Object fileKeyObj : entMap.keySet()) {
                    String fileName = (String) fileKeyObj;
                    java.util.Map fileData = (java.util.Map) entMap.get(fileKeyObj);
                    String mode = fileData != null ? (String) fileData.getOrDefault("scaleMode", defMode) : defMode;
                    float scale = fileData != null ? ((Number) fileData.getOrDefault("scale", defScale)).floatValue() : defScale;
                    String anchor = fileData != null ? (String) fileData.getOrDefault("anchor", defAnchor) : defAnchor;
                    float global = fileData != null ? ((Number) fileData.getOrDefault("globalScale", defGlobal)).floatValue() : defGlobal;
                    entries.put(fileName, new TextureConfig(mode, scale, anchor, global));
                }
            }
            TEXTURE_SET_CONFIGS.put(setName, new TextureSetConfig(defaultCfg, entries));
        }
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
    static java.util.Map<String, DifficultyDef> difficulties;

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

        loadDifficulties();
    }

    static void loadDifficulties() {
        if (gameSettingsYamlRoot == null) return;
        java.util.Map diffMap = (java.util.Map) gameSettingsYamlRoot.get("difficulties");
        if (diffMap == null) return;
        difficulties = new java.util.HashMap<>();
        for (Object keyObj : diffMap.keySet()) {
            String key = (String) keyObj;
            java.util.Map d = (java.util.Map) diffMap.get(keyObj);
            String nameKey = (String) d.get("nameKey");
            float hpMulti = d.containsKey("enemyHpMultiplier") ? ((Number) d.get("enemyHpMultiplier")).floatValue() : 1.0f;
            float rewardMulti = d.containsKey("killRewardMultiplier") ? ((Number) d.get("killRewardMultiplier")).floatValue() : 1.0f;
            difficulties.put(key, new DifficultyDef(key, nameKey, hpMulti, rewardMulti));
        }
    }

    static DifficultyDef getDifficulty(String key) {
        if (difficulties == null || key == null) return null;
        return difficulties.get(key);
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
        java.util.Map u = (java.util.Map) t.get("upgrade");
        java.util.Map u2 = (java.util.Map) t.get("upgrade2");
        int baseCost = ((Number) t.get("cost")).intValue();

        return new TowerDef(
            type,
            (String) t.get("nameKey"),
            (String) t.get("descKey"),
            baseCost,
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
            sfx != null ? (String) sfx.get("complete") : null,
            u != null && u.containsKey("cost") ? ((Number) u.get("cost")).intValue() : baseCost / 2,
            u != null && u.containsKey("buildTime") ? ((Number) u.get("buildTime")).floatValue() : ((Number) t.get("buildTime")).floatValue(),
            u != null && u.containsKey("damageMult") ? ((Number) u.get("damageMult")).floatValue() : 1f,
            u != null && u.containsKey("rangeMult") ? ((Number) u.get("rangeMult")).floatValue() : 1f,
            u != null && u.containsKey("speedMult") ? ((Number) u.get("speedMult")).floatValue() : 1f,
            u != null && u.containsKey("slowMult") ? ((Number) u.get("slowMult")).floatValue() : 1f,
            u != null && u.containsKey("poisonMult") ? ((Number) u.get("poisonMult")).floatValue() : 1f,
            u != null && u.containsKey("aoeMult") ? ((Number) u.get("aoeMult")).floatValue() : 1f,
            u != null && u.containsKey("bulletSizeMult") ? ((Number) u.get("bulletSizeMult")).floatValue() : 1f,
            t.containsKey("poisonDamage") ? ((Number) t.get("poisonDamage")).floatValue() : 0f,
            t.containsKey("poisonDuration") ? ((Number) t.get("poisonDuration")).floatValue() : 0f,
            t.containsKey("poisonFanAngle") ? ((Number) t.get("poisonFanAngle")).floatValue() : 90f,
            t.containsKey("commandBonus") ? ((Number) t.get("commandBonus")).floatValue() : 1f,
            u != null && u.containsKey("commandMult") ? ((Number) u.get("commandMult")).floatValue() : 1f,
            u2 != null && u2.containsKey("cost") ? ((Number) u2.get("cost")).intValue() : baseCost,
            u2 != null && u2.containsKey("buildTime") ? ((Number) u2.get("buildTime")).floatValue() : ((Number) t.get("buildTime")).floatValue()
        );
    }

    static LevelDef loadLevel(int levelId) {
        return loadLevel(levelId, null);
    }

    static LevelDef loadLevel(int levelId, String difficultyKey) {
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
        LevelDef level = parseLevel(lvl);

        // Apply difficulty wave override if present
        if (difficultyKey != null && level.difficultyWaves != null) {
            WaveDef[] override = level.difficultyWaves.get(difficultyKey);
            if (override != null) {
                level.waves = override;
            }
        }

        return level;
    }

    static SpawnAttach[] loadAttaches(java.util.Map s) {
        java.util.List attachList = (java.util.List) s.get("attach");
        if (attachList == null || attachList.isEmpty()) return null;
        SpawnAttach[] attaches = new SpawnAttach[attachList.size()];
        for (int i = 0; i < attachList.size(); i++) {
            java.util.Map a = (java.util.Map) attachList.get(i);
            int count = a.containsKey("count") ? ((Number) a.get("count")).intValue() : 1;
            float delay = a.containsKey("delay") ? ((Number) a.get("delay")).floatValue() : 0f;
            float hpMulti = a.containsKey("hpMulti") ? ((Number) a.get("hpMulti")).floatValue() : 1.0f;
            attaches[i] = new SpawnAttach(
                (String) a.get("type"),
                count,
                delay,
                (String) a.get("route"),
                hpMulti,
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

    static int getCommandKillBonusMin() {
        if (gameSettingsYamlRoot == null) return 1;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 1;
        Object v = gs.get("commandKillBonusMin");
        if (v instanceof Number) return ((Number) v).intValue();
        return 1;
    }

    static int getCommandKillBonusMax() {
        if (gameSettingsYamlRoot == null) return 3;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 3;
        Object v = gs.get("commandKillBonusMax");
        if (v instanceof Number) return ((Number) v).intValue();
        return 3;
    }

    static float getTooltipDelay() {
        if (gameSettingsYamlRoot == null) return 1.0f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 1.0f;
        Object v = gs.get("tooltipDelay");
        if (v instanceof Number) return ((Number) v).floatValue();
        return 1.0f;
    }

    static float getStarBrightness() {
        if (gameSettingsYamlRoot == null) return 1.0f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 1.0f;
        Object v = gs.get("starBrightness");
        if (v instanceof Number) return ((Number) v).floatValue();
        return 1.0f;
    }

    static float getMenuStarBrightness() {
        if (gameSettingsYamlRoot == null) return 1.0f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 1.0f;
        Object v = gs.get("menuStarBrightness");
        if (v instanceof Number) return ((Number) v).floatValue();
        return 1.0f;
    }

    static int getMenuBgR() {
        if (gameSettingsYamlRoot == null) return 8;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 8;
        Object v = gs.get("menuBgR");
        if (v instanceof Number) return ((Number) v).intValue();
        return 8;
    }

    static int getMenuBgG() {
        if (gameSettingsYamlRoot == null) return 12;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 12;
        Object v = gs.get("menuBgG");
        if (v instanceof Number) return ((Number) v).intValue();
        return 12;
    }

    static int getMenuBgB() {
        if (gameSettingsYamlRoot == null) return 28;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 28;
        Object v = gs.get("menuBgB");
        if (v instanceof Number) return ((Number) v).intValue();
        return 28;
    }

    static float getBgLodZoomThreshold() {
        if (gameSettingsYamlRoot == null) return 0.5f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 0.5f;
        Object v = gs.get("bgLodZoomThreshold");
        if (v instanceof Number) return ((Number) v).floatValue();
        return 0.5f;
    }

    static boolean isRandomBackground() {
        if (gameSettingsYamlRoot == null) return true;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return true;
        Object v = gs.get("randomBackground");
        if (v instanceof Boolean) return ((Boolean) v).booleanValue();
        return true;
    }

    static boolean isRenderBlockedZones() {
        if (gameSettingsYamlRoot == null) return true;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return true;
        Object v = gs.get("renderBlockedZones");
        if (v instanceof Boolean) return ((Boolean) v).booleanValue();
        return true;
    }

    static boolean isRenderStars() {
        if (gameSettingsYamlRoot == null) return true;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return true;
        Object v = gs.get("renderStars");
        if (v instanceof Boolean) return ((Boolean) v).booleanValue();
        return true;
    }

    static boolean isRenderNebulas() {
        if (gameSettingsYamlRoot == null) return true;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return true;
        Object v = gs.get("renderNebulas");
        if (v instanceof Boolean) return ((Boolean) v).booleanValue();
        return true;
    }

    static boolean isRenderPlatformLayer() {
        if (gameSettingsYamlRoot == null) return true;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return true;
        Object v = gs.get("renderPlatformLayer");
        if (v instanceof Boolean) return ((Boolean) v).booleanValue();
        return true;
    }

    static float getIntroDelay() {
        if (gameSettingsYamlRoot == null) return 1.0f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 1.0f;
        Object v = gs.get("introDelay");
        if (v instanceof Number) return ((Number) v).floatValue();
        return 1.0f;
    }

    static float getIntroPostDelay() {
        if (gameSettingsYamlRoot == null) return 1.0f;
        java.util.Map gs = (java.util.Map) gameSettingsYamlRoot.get("gameSettings");
        if (gs == null) return 1.0f;
        Object v = gs.get("introPostDelay");
        if (v instanceof Number) return ((Number) v).floatValue();
        return 1.0f;
    }

    static int getLevelCount() {
        return levelYamlList != null ? levelYamlList.size() : 0;
    }

    static String loadBriefingText(int levelId, String locale) {
        String briefPath = "config/levels/brief/level_" + levelId + "_" + locale + ".txt";
        try {
            java.io.InputStream is = P5Engine.getInstance().getApplet().createInput(briefPath);
            if (is == null) return "\u8bfb\u53d6\u5931\u8d25";
            java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(is, "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append('\n');
            }
            reader.close();
            String result = sb.toString().trim();
            return result.isEmpty() ? "\u8bfb\u53d6\u5931\u8d25" : result;
        } catch (Exception e) {
            return "\u8bfb\u53d6\u5931\u8d25";
        }
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

    static WaveDef[] parseWaves(java.util.List waveList) {
        if (waveList == null || waveList.isEmpty()) return null;
        WaveDef[] waves = new WaveDef[waveList.size()];
        for (int i = 0; i < waveList.size(); i++) {
            java.util.Map w = (java.util.Map) waveList.get(i);
            float delay = ((Number) w.get("delay")).floatValue();
            java.util.List spawnList = (java.util.List) w.get("spawns");
            WaveSpawn[] spawns = new WaveSpawn[spawnList != null ? spawnList.size() : 0];
            for (int j = 0; j < spawns.length; j++) {
                java.util.Map s = (java.util.Map) spawnList.get(j);
                float hpMulti = s.containsKey("hpMulti") ? ((Number) s.get("hpMulti")).floatValue() : 1.0f;
                spawns[j] = new WaveSpawn(
                    (String) s.get("type"),
                    ((Number) s.get("count")).intValue(),
                    ((Number) s.get("interval")).floatValue(),
                    (String) s.get("route"),
                    hpMulti,
                    loadAttaches(s)
                );
            }
            waves[i] = new WaveDef(delay, spawns);
        }
        return waves;
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

        // Waves (default)
        java.util.List waveList = (java.util.List) lvl.get("waves");
        ld.waves = parseWaves(waveList);

        // Difficulty wave overrides
        java.util.Map lvlDiffMap = (java.util.Map) lvl.get("difficulties");
        if (lvlDiffMap != null) {
            ld.difficultyWaves = new java.util.HashMap<>();
            for (Object diffKeyObj : lvlDiffMap.keySet()) {
                String diffKey = (String) diffKeyObj;
                java.util.Map diffData = (java.util.Map) lvlDiffMap.get(diffKeyObj);
                java.util.List diffWaveList = (java.util.List) diffData.get("waves");
                WaveDef[] diffWaves = parseWaves(diffWaveList);
                if (diffWaves != null) {
                    ld.difficultyWaves.put(diffKey, diffWaves);
                }
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

        // Allowed upgrades (optional, default all)
        java.util.List upgradeList = (java.util.List) lvl.get("allowedUpgrades");
        if (upgradeList != null) {
            ld.allowedUpgrades = new TowerType[upgradeList.size()];
            for (int i = 0; i < upgradeList.size(); i++) {
                String tt = (String) upgradeList.get(i);
                try {
                    ld.allowedUpgrades[i] = TowerType.valueOf(tt.toUpperCase());
                } catch (Exception ex) {
                    ld.allowedUpgrades[i] = null;
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

        // Dev mode (optional, default false)
        Object devObj = lvl.get("devMode");
        if (devObj != null) {
            ld.devMode = Boolean.parseBoolean(devObj.toString());
        } else {
            ld.devMode = false;
        }

        // Blocked zones (optional)
        java.util.List zoneList = (java.util.List) lvl.get("blockedZones");
        if (zoneList != null && !zoneList.isEmpty()) {
            ld.blockedZones = new BlockedZone[zoneList.size()];
            for (int i = 0; i < zoneList.size(); i++) {
                java.util.Map z = (java.util.Map) zoneList.get(i);
                String ztype = (String) z.get("type");
                String visualStr = (String) z.get("visual");
                BlockedVisualType visual = BlockedVisualType.VOID;
                if (visualStr != null) {
                    try {
                        visual = BlockedVisualType.valueOf(visualStr.toUpperCase());
                    } catch (Exception ex) {
                        visual = BlockedVisualType.VOID;
                    }
                }
                if ("circle".equalsIgnoreCase(ztype)) {
                    float cx = ((Number) z.get("cx")).floatValue();
                    float cy = ((Number) z.get("cy")).floatValue();
                    float r = ((Number) z.get("radius")).floatValue();
                    ld.blockedZones[i] = new BlockedZone(cx, cy, r, visual);
                } else {
                    // default rect
                    float zx = ((Number) z.get("x")).floatValue();
                    float zy = ((Number) z.get("y")).floatValue();
                    float zw = ((Number) z.get("w")).floatValue();
                    float zh = ((Number) z.get("h")).floatValue();
                    ld.blockedZones[i] = new BlockedZone(zx, zy, zw, zh, visual);
                }
            }
        }

        // Platforms (optional)
        java.util.List platList = (java.util.List) lvl.get("platforms");
        if (platList != null && !platList.isEmpty()) {
            ld.platforms = new PlatformZone[platList.size()];
            for (int i = 0; i < platList.size(); i++) {
                java.util.Map p = (java.util.Map) platList.get(i);
                java.util.List platPts = (java.util.List) p.get("points");
                Vector2[] vertices = new Vector2[platPts.size()];
                for (int j = 0; j < platPts.size(); j++) {
                    java.util.Map pm = (java.util.Map) platPts.get(j);
                    vertices[j] = new Vector2(((Number)pm.get("x")).floatValue(), ((Number)pm.get("y")).floatValue());
                }
                int edgeColor = 0xFF4A9EFF; // default blue glow
                int fillColor = 0xFF1A1F2B; // default dark metal
                java.util.List ec = (java.util.List) p.get("edgeColor");
                if (ec != null && ec.size() >= 3) {
                    edgeColor = 0xFF000000 | (((Number)ec.get(0)).intValue() << 16)
                                              | (((Number)ec.get(1)).intValue() << 8)
                                              | ((Number)ec.get(2)).intValue();
                }
                java.util.List fc = (java.util.List) p.get("fillColor");
                if (fc != null && fc.size() >= 3) {
                    fillColor = 0xFF000000 | (((Number)fc.get(0)).intValue() << 16)
                                              | (((Number)fc.get(1)).intValue() << 8)
                                              | ((Number)fc.get(2)).intValue();
                }
                ld.platforms[i] = new PlatformZone(vertices, edgeColor, fillColor);
            }
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
