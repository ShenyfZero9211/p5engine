/**
 * Tutorial / Onboarding system.
 *
 * Drives TutorialOverlay with step sequences loaded from data/config/tutorials.json.
 * Completion state is persisted in TowerDefenseMin2.ini via TdSaveData.
 */
static class TdTutorial {

    static TutorialOverlay overlay;
    static TutorialSequence sequence;
    static java.util.Map<String, Object> configRoot;
    static java.util.Map<String, java.util.Map<String, Object>> tutorialMeta;
    static java.util.Map<String, java.util.List<Object>> tutorialSteps;
    static String currentKey;
    static UIManager uiManager;
    static int towersAtStepStart = 0; // for ACTION advance detection (tower placement)
    static int orbsAtStepStart = 0;   // for ACTION advance detection (orb stolen)
    static boolean firstKillTriggered = false; // for first enemy kill hint

    static void init(UIManager ui) {
        uiManager = ui;
        overlay = new TutorialOverlay("tutorial_overlay", ui);
        sequence = new TutorialSequence();
        overlay.setSequence(sequence);
        ui.getRoot().add(overlay);
        overlay.setVisible(false);
        loadConfigs();

        sequence.setOnComplete(() -> {
            ui.setEventInterceptor(null);
            TutorialGridRenderer.enabled = false;
            TutorialGridRenderer.cells.clear();
            if (currentKey != null) {
                markShown(currentKey);
            }
            overlay.setVisible(false);
            currentKey = null;
        });

        overlay.setOnNextButtonClick(() -> {
            TdSound.playClick();
        });

        sequence.setOnStepChanged(() -> {
            overlay.refreshTarget();
            refreshWorldRenderer();
            towersAtStepStart = TdGameWorld.towers.size();
            orbsAtStepStart = TdGameWorld.orbits;
        });
    }

    static void loadConfigs() {
        try {
            String path = TowerDefenseMin2.inst.sketchPath("data/config/tutorials.json");
            java.io.File f = new java.io.File(path);
            if (f.exists()) {
                processing.data.JSONObject json = TowerDefenseMin2.inst.loadJSONObject(f);
                configRoot = jsonToMap(json);
                tutorialMeta = new java.util.HashMap<>();
                tutorialSteps = new java.util.HashMap<>();
                for (Object keyObj : configRoot.keySet()) {
                    String key = (String) keyObj;
                    Object val = configRoot.get(key);
                    if (val instanceof java.util.Map) {
                        java.util.Map<String, Object> meta = (java.util.Map<String, Object>) val;
                        tutorialMeta.put(key, meta);
                        Object stepsObj = meta.get("steps");
                        if (stepsObj instanceof java.util.List) {
                            tutorialSteps.put(key, (java.util.List<Object>) stepsObj);
                        }
                    }
                }
            }
        } catch (Exception e) {
            println("[TdTutorial] failed to load tutorials.json: " + e.getMessage());
            configRoot = null;
        }
    }

    static java.util.Map<String, Object> jsonToMap(processing.data.JSONObject json) {
        java.util.Map<String, Object> map = new java.util.HashMap<>();
        for (Object key : json.keys()) {
            String k = (String) key;
            Object v = json.get(k);
            if (v instanceof processing.data.JSONObject) {
                map.put(k, jsonToMap((processing.data.JSONObject) v));
            } else if (v instanceof processing.data.JSONArray) {
                map.put(k, jsonToList((processing.data.JSONArray) v));
            } else {
                map.put(k, v);
            }
        }
        return map;
    }

    static java.util.List<Object> jsonToList(processing.data.JSONArray arr) {
        java.util.List<Object> list = new java.util.ArrayList<>();
        for (int i = 0; i < arr.size(); i++) {
            Object v = arr.get(i);
            if (v instanceof processing.data.JSONObject) {
                list.add(jsonToMap((processing.data.JSONObject) v));
            } else if (v instanceof processing.data.JSONArray) {
                list.add(jsonToList((processing.data.JSONArray) v));
            } else {
                list.add(v);
            }
        }
        return list;
    }

    static boolean start(String key) {
        println("[TdTutorial] start(" + key + ") called, shown=" + hasShown(key));
        firstKillTriggered = false;
        if (hasShown(key)) return false;
        if (configRoot == null) {
            println("[TdTutorial] configRoot is null");
            return false;
        }
        if (!configRoot.containsKey(key)) {
            println("[TdTutorial] key not found: " + key);
            return false;
        }

        java.util.List<Object> rawSteps = tutorialSteps != null ? tutorialSteps.get(key) : null;
        if (rawSteps == null || rawSteps.isEmpty()) return false;

        java.util.List<shenyf.p5engine.ui.tutorial.TutorialStep> steps = new java.util.ArrayList<>();
        for (int i = 0; i < rawSteps.size(); i++) {
            java.util.Map<String, Object> m = (java.util.Map<String, Object>) rawSteps.get(i);
            shenyf.p5engine.ui.tutorial.TutorialStep s = new shenyf.p5engine.ui.tutorial.TutorialStep();
            s.stepIndex = i;
            s.textKey = getString(m, "textKey", "");
            s.allowSkip = getBool(m, "allowSkip", true);

            String tt = getString(m, "targetType", "screen_rect");
            if ("ui".equals(tt)) {
                s.targetType = shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.UI_COMPONENT;
            } else if ("world_rect".equals(tt)) {
                s.targetType = shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.WORLD_RECT;
            } else if ("full_screen_no_mask".equals(tt)) {
                s.targetType = shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.FULL_SCREEN_NO_MASK;
            } else if ("global".equals(tt)) {
                s.targetType = shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.GLOBAL;
            } else {
                s.targetType = shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.SCREEN_RECT;
            }
            s.targetId = getString(m, "targetId", null);
            s.targetX = getFloat(m, "targetX", 0);
            s.targetY = getFloat(m, "targetY", 0);
            s.targetW = getFloat(m, "targetW", 100);
            s.targetH = getFloat(m, "targetH", 100);

            String adv = getString(m, "advance", "click");
            switch (adv) {
                case "action":
                    s.advanceMode = shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.ACTION;
                    break;
                case "auto":
                    s.advanceMode = shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.AUTO;
                    break;
                case "key":
                    s.advanceMode = shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.KEY;
                    break;
                case "button":
                    s.advanceMode = shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.BUTTON;
                    break;
                default:
                    s.advanceMode = shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.CLICK;
            }
            s.delay = getFloat(m, "delay", 0f);
            s.autoDuration = getFloat(m, "autoDuration", 3.0f);
            s.triggerEvent = getString(m, "triggerEvent", null);

            String be = getString(m, "borderEffect", "pulse");
            switch (be) {
                case "flash":
                    s.borderEffect = shenyf.p5engine.ui.tutorial.TutorialStep.BorderEffect.FLASH;
                    break;
                case "none":
                    s.borderEffect = shenyf.p5engine.ui.tutorial.TutorialStep.BorderEffect.NONE;
                    break;
                default:
                    s.borderEffect = shenyf.p5engine.ui.tutorial.TutorialStep.BorderEffect.PULSE;
            }
            s.bubbleAnchor = getString(m, "bubbleAnchor", "center");

            steps.add(s);
        }

        currentKey = key;
        // Populate extra target rectangles for buildable grids (full_screen_no_mask step)
        for (shenyf.p5engine.ui.tutorial.TutorialStep s : steps) {
            if (s.targetType == shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.FULL_SCREEN_NO_MASK) {
                s.targetRects = computeBuildableRects();
                TutorialGridRenderer.cells.clear();
                TutorialGridRenderer.cells.addAll(computeBuildableCells());
                TutorialGridRenderer.borderEffect = s.borderEffect;
                break;
            }
        }
        // Re-add overlay if it was removed by root.removeAllChildren()
        if (overlay.getParent() == null) {
            uiManager.getRoot().add(overlay);
        }
        overlay.setVisible(true);
        uiManager.setEventInterceptor(overlay);
        towersAtStepStart = TdGameWorld.towers.size();
        sequence.start(steps);
        println("[TdTutorial] sequence started, steps=" + steps.size() + " active=" + sequence.isActive() + " parent=" + overlay.getParent());
        return true;
    }

    static void skip() {
        if (sequence != null) sequence.skip();
    }

    /**
     * Stops the tutorial gracefully without marking it as shown.
     * Called when the game ends (win/lose) to clean up state.
     */
    static void triggerEvent(String event) {
        if (sequence != null && sequence.isActive()) {
            sequence.triggerEvent(event);
        }
    }

    static void onEnemyKilled() {
        if (firstKillTriggered) return;
        firstKillTriggered = true;
        triggerEvent("first_enemy_killed");
    }

    static void stop() {
        if (sequence != null) {
            sequence.stop();
        }
        if (overlay != null) {
            overlay.setVisible(false);
        }
        if (uiManager != null) {
            uiManager.setEventInterceptor(null);
        }
        TutorialGridRenderer.enabled = false;
        TutorialGridRenderer.cells.clear();
        currentKey = null;
    }

    static boolean isActive() {
        return sequence != null && sequence.isActive();
    }

    static boolean onKeyPressed(int keyCode) {
        if (overlay != null && overlay.onKeyPressed(keyCode)) {
            return true;
        }
        return false;
    }

    static void update(float dt) {
        // Note: sequence.update(dt) is already called by TutorialOverlay.update()
        // through the UI system's per-frame update loop.
        if (sequence != null && sequence.isActive()) {
            shenyf.p5engine.ui.tutorial.TutorialStep step = sequence.getCurrentStep();
            if (step == null) return;

            // Detect ACTION advance triggers
            if (step.advanceMode == shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.ACTION) {
                if (TdGameWorld.towers.size() > towersAtStepStart) {
                    sequence.nextStep();
                }
            }

            // Trigger events for AUTO steps with triggerEvent (forced ready)
            if (step.advanceMode == shenyf.p5engine.ui.tutorial.TutorialStep.AdvanceMode.AUTO
                    && step.triggerEvent != null && !sequence.isStepReady()) {
                if (step.triggerEvent.contains("orb_stolen")) {
                    if (TdGameWorld.orbits < orbsAtStepStart) {
                        sequence.triggerEvent("orb_stolen");
                    } else {
                        for (Enemy e : TdGameWorld.enemies) {
                            if (e.hasStolen) {
                                sequence.triggerEvent("orb_stolen");
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    static java.util.List<float[]> computeBuildableRects() {
        java.util.List<float[]> rects = new java.util.ArrayList<>();
        if (TdGameWorld.level == null) return rects;
        // Ensure blockedGrids is fresh before reading
        TdGameWorld.computeBlockedGrids();
        int maxGX = (int)(TdGameWorld.level.worldW / TdConfig.GRID) + 1;
        int maxGY = (int)(TdGameWorld.level.worldH / TdConfig.GRID) + 1;
        for (int gx = 0; gx <= maxGX; gx++) {
            for (int gy = 0; gy <= maxGY; gy++) {
                if (!TdGameWorld.canPlaceTower(gx, gy)) continue;
                float wx = (gx + 0.5f) * TdConfig.GRID;
                float wy = (gy + 0.5f) * TdConfig.GRID;
                rects.add(new float[]{wx, wy, TdConfig.GRID, TdConfig.GRID});
            }
        }
        return rects;
    }

    static java.util.List<int[]> computeBuildableCells() {
        java.util.List<int[]> cells = new java.util.ArrayList<>();
        if (TdGameWorld.level == null) return cells;
        TdGameWorld.computeBlockedGrids();
        int maxGX = (int)(TdGameWorld.level.worldW / TdConfig.GRID) + 1;
        int maxGY = (int)(TdGameWorld.level.worldH / TdConfig.GRID) + 1;
        for (int gx = 0; gx <= maxGX; gx++) {
            for (int gy = 0; gy <= maxGY; gy++) {
                if (!TdGameWorld.canPlaceTower(gx, gy)) continue;
                cells.add(new int[]{gx, gy});
            }
        }
        return cells;
    }

    static void refreshWorldRenderer() {
        TutorialGridRenderer.enabled = false;
        TutorialGridRenderer.cells.clear();
        if (sequence == null || !sequence.isActive()) return;
        shenyf.p5engine.ui.tutorial.TutorialStep step = sequence.getCurrentStep();
        if (step == null) return;
        TutorialGridRenderer.borderEffect = step.borderEffect;
        if (step.targetType == shenyf.p5engine.ui.tutorial.TutorialStep.TargetType.FULL_SCREEN_NO_MASK) {
            if (step.targetRects != null && !step.targetRects.isEmpty()) {
                TutorialGridRenderer.enabled = true;
                for (float[] r : step.targetRects) {
                    if (r == null || r.length < 4) continue;
                    int gx = (int)(r[0] / TdConfig.GRID);
                    int gy = (int)(r[1] / TdConfig.GRID);
                    TutorialGridRenderer.cells.add(new int[]{gx, gy});
                }
            }
        }
    }

    // ---- Persistence ----

    static String getTutorialKeyForLevel(String levelId) {
        if (tutorialMeta == null) return null;
        for (java.util.Map.Entry<String, java.util.Map<String, Object>> entry : tutorialMeta.entrySet()) {
            java.util.Map<String, Object> meta = entry.getValue();
            Object lidObj = meta.get("levelId");
            if (lidObj != null) {
                String lid = lidObj.toString();
                if (lid.equals(levelId)) return entry.getKey();
            }
        }
        return null;
    }

    static boolean hasShown(String key) {
        // game_settings.yaml enableTutorial is the master switch:
        // false = tutorial system disabled (skip all)
        // true  = check per-key completion in TowerDefenseMin2.ini
        if (!TdAssets.isTutorialEnabled()) {
            return true; // master switch off -> treat as already shown
        }
        // Debug: force tutorial to always show regardless of save data
        if (TdAssets.isDebugTutorialAlwaysOn()) {
            return false;
        }
        if (TdSaveData.cfg == null || key == null) return false;
        return TdSaveData.cfg.getBoolean("tutorial", key, false);
    }

    static void markShown(String key) {
        if (TdSaveData.cfg == null || key == null) return;
        TdSaveData.cfg.set("tutorial", key, true);
        TdSaveData.save();
    }

    // ---- Helpers ----

    static String getString(java.util.Map<String, Object> m, String k, String def) {
        Object v = m.get(k);
        return v != null ? v.toString() : def;
    }

    static boolean getBool(java.util.Map<String, Object> m, String k, boolean def) {
        Object v = m.get(k);
        if (v instanceof Boolean) return (Boolean) v;
        if (v != null) return Boolean.parseBoolean(v.toString());
        return def;
    }

    static float getFloat(java.util.Map<String, Object> m, String k, float def) {
        Object v = m.get(k);
        if (v instanceof Number) return ((Number) v).floatValue();
        if (v != null) {
            try { return Float.parseFloat(v.toString()); } catch (Exception ignored) {}
        }
        return def;
    }
}
