import processing.core.*;
import processing.data.*;
import processing.event.*;
import processing.opengl.*;
import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.ui.*;
import shenyf.p5engine.math.*;
import shenyf.p5engine.rendering.*;
import shenyf.p5engine.audio.*;
import org.yaml.snakeyaml.*;
import java.util.*;
public class TowerDefenseMin2 extends PApplet {
// ===== Bullet.pde =====
/**
 * Projectile or beam fired by a tower.
 */
static class Bullet {
    Vector2 pos;
    Vector2 vel;
    float damage;
    float aoeRadius;
    float laserBonus;
    float slowFactor;
    float life;
    boolean dead;
    GameObject gameObject;

    void update(float dt) {
        if (dead) return;
        life -= dt;
        if (life <= 0) { dead = true; markDead(); return; }

        pos.add(vel.copy().mult(dt));
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }

        for (Enemy e : TdGameWorld.enemies) {
            if (pos.distance(e.pos) < e.radius + 4) {
                hit(e);
                dead = true;
                markDead();
                return;
            }
        }
    }

    void hit(Enemy e) {
        float dmg = damage;
        if (laserBonus > 0) dmg += laserBonus;
        e.hp -= dmg;
        if (slowFactor > 0) e.slowFactor = Math.min(e.slowFactor, slowFactor);

        if (aoeRadius > 0) {
            for (Enemy ne : TdGameWorld.enemies) {
                if (ne != e && e.pos.distance(ne.pos) <= aoeRadius) {
                    ne.hp -= dmg * 0.5f;
                }
            }
        }
    }

    void markDead() {
        if (gameObject != null) {
            gameObject.markForDestroy();
        }
    }
}

// ===== Enemy.pde =====
/**
 * Enemy instance on the path.
 */

enum EnemyState {
    MOVE_TO_BASE,
    STEAL,
    FLEE,
    DEAD
}

static class Enemy {
    Vector2 pos;
    float hp, maxHp;
    float speed;
    float radius;
    float slowFactor = 1f;
    boolean reachedEnd;

    TdPath path;
    float pathDistance;
    GameObject gameObject;

    EnemyState state = EnemyState.MOVE_TO_BASE;
    boolean hasStolen = false;

    void update(float dt) {
        if (path == null) return;

        switch (state) {
            case MOVE_TO_BASE:
                pathDistance += speed * slowFactor * dt;
                if (pathDistance >= TdGameWorld.basePathDist) {
                    pathDistance = TdGameWorld.basePathDist;
                    state = EnemyState.STEAL;
                }
                break;
            case STEAL:
                hasStolen = true;
                TdGameWorld.orbits--;
                state = EnemyState.FLEE;
                break;
            case FLEE:
                pathDistance += speed * slowFactor * dt;
                if (pathDistance >= path.getTotalLength()) {
                    reachedEnd = true;
                }
                break;
            case DEAD:
                return;
        }

        if (pathDistance >= path.getTotalLength()) {
            pos = path.sample(path.getTotalLength());
        } else {
            pos = path.sample(pathDistance);
        }
        if (gameObject != null) {
            gameObject.getTransform().setPosition(pos.x, pos.y);
        }
    }
}

// ===== TdAssets.pde =====
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

    static void loadConfigs(PApplet app) {
        org.yaml.snakeyaml.Yaml yaml = new org.yaml.snakeyaml.Yaml();

        java.io.InputStream tis = app.createInput("config/towers.yaml");
        if (tis == null) throw new RuntimeException("Cannot load config/towers.yaml");
        towerYamlRoot = (java.util.Map) yaml.load(tis);

        java.io.InputStream lis = app.createInput("config/levels.yaml");
        if (lis == null) throw new RuntimeException("Cannot load config/levels.yaml");
        levelYamlList = (java.util.List) yaml.load(lis);
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
            ((Number) t.get("buildTime")).floatValue(),
            iconColor,
            sfx != null ? (String) sfx.get("fire") : null,
            sfx != null ? (String) sfx.get("place") : null
        );
    }

    static LevelDef loadLevel(int levelId) {
        for (Object obj : levelYamlList) {
            java.util.Map lvl = (java.util.Map) obj;
            int id = ((Number) lvl.get("id")).intValue();
            if (id == levelId) {
                return parseLevel(lvl);
            }
        }
        return null;
    }

    static int getLevelCount() {
        return levelYamlList != null ? levelYamlList.size() : 0;
    }

    private static LevelDef parseLevel(java.util.Map lvl) {
        LevelDef ld = new LevelDef();
        ld.id = ((Number) lvl.get("id")).intValue();
        ld.nameKey = (String) lvl.get("nameKey");
        ld.subtitleKey = (String) lvl.get("subtitleKey");
        ld.initialMoney = ((Number) lvl.get("initialMoney")).intValue();
        ld.initialOrbs = ((Number) lvl.get("initialOrbs")).intValue();
        ld.totalWaves = ((Number) lvl.get("totalWaves")).intValue();
        ld.worldW = ((Number) lvl.get("worldWidth")).intValue();
        ld.worldH = ((Number) lvl.get("worldHeight")).intValue();

        java.util.Map enemy = (java.util.Map) lvl.get("enemy");
        ld.enemyHpBase = ((Number) enemy.get("hpBase")).floatValue();
        ld.enemyHpPerWave = ((Number) enemy.get("hpPerWave")).floatValue();
        ld.enemySpeed = ((Number) enemy.get("speed")).floatValue();
        ld.enemyCountBase = ((Number) enemy.get("countBase")).intValue();
        ld.enemyCountPerWave = ((Number) enemy.get("countPerWave")).intValue();

        ld.spawnCooldown = ((Number) lvl.get("spawnCooldown")).floatValue();
        ld.interWaveDelay = ((Number) lvl.get("interWaveDelay")).floatValue();

        // Positions
        java.util.Map base = (java.util.Map) lvl.get("basePos");
        ld.basePos = new Vector2(((Number)base.get("x")).floatValue(), ((Number)base.get("y")).floatValue());
        java.util.Map exit = (java.util.Map) lvl.get("exitPos");
        ld.exitPos = new Vector2(((Number)exit.get("x")).floatValue(), ((Number)exit.get("y")).floatValue());
        java.util.Map spawn = (java.util.Map) lvl.get("spawnPos");
        ld.spawnPos = new Vector2(((Number)spawn.get("x")).floatValue(), ((Number)spawn.get("y")).floatValue());

        // Path points
        java.util.List pts = (java.util.List) lvl.get("pathPoints");
        ld.pathPoints = new Vector2[pts.size()];
        for (int i = 0; i < pts.size(); i++) {
            java.util.Map p = (java.util.Map) pts.get(i);
            ld.pathPoints[i] = new Vector2(((Number)p.get("x")).floatValue(), ((Number)p.get("y")).floatValue());
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

// ===== TdCamera.pde =====
/**
 * Camera controller: edge-scroll, clamp, mouse-in-viewport check.
 */
static final class TdCamera {

    static void updateEdgeScroll(float dt) {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam == null) return;
        Vector2 dm = TowerDefenseMin2.inst.engine.getDisplayManager().actualToDesign(
            new Vector2(TowerDefenseMin2.inst.mouseX, TowerDefenseMin2.inst.mouseY));

        float scrollSpeed = 400; // design pixels/sec
        float left   = cam.getViewportOffsetX();
        float top    = cam.getViewportOffsetY();
        float right  = left + cam.getViewportWidth();
        float bottom = top + cam.getViewportHeight();
        float margin = 24;

        float dx = 0, dy = 0;
        if (TowerDefenseMin2.inst.keyScrollLeft || dm.x < left + margin)  dx = -scrollSpeed;
        if (TowerDefenseMin2.inst.keyScrollRight || dm.x > right - margin) dx = scrollSpeed;
        if (TowerDefenseMin2.inst.keyScrollUp || dm.y < top + margin)    dy = -scrollSpeed;
        if (TowerDefenseMin2.inst.keyScrollDown || dm.y > bottom - margin) dy = scrollSpeed;

        if (dx != 0 || dy != 0) {
            cam.getTransform().translate(dx * dt / cam.getZoom(), dy * dt / cam.getZoom());
            cam.clampToBounds();
        }
    }

    static boolean isMouseInViewport() {
        Camera2D cam = TowerDefenseMin2.inst.camera;
        if (cam == null) return false;
        Vector2 dm = TowerDefenseMin2.inst.engine.getDisplayManager().actualToDesign(
            new Vector2(TowerDefenseMin2.inst.mouseX, TowerDefenseMin2.inst.mouseY));
        float left   = cam.getViewportOffsetX();
        float top    = cam.getViewportOffsetY();
        float right  = left + cam.getViewportWidth();
        float bottom = top + cam.getViewportHeight();
        return dm.x >= left && dm.x <= right && dm.y >= top && dm.y <= bottom;
    }
}

// ===== TdConfig.pde =====
/**
 * TowerDefenseMin2 — Global constants and configuration.
 */
static final class TdConfig {

    // ── Display ──
    static final int DESIGN_W = 1280;
    static final int DESIGN_H = 720;
    static final int TOP_HUD = 48;
    static final int RIGHT_W = 240;
    static final int WORLD_W = 1280 - RIGHT_W;
    static final int WORLD_H = 720 - TOP_HUD;

    // ── World ──
    static final int GRID = 40;
    static final int WORLD_MAP_W = 2400;
    static final int WORLD_MAP_H = 1600;

    // ── Colors (Sci-Fi dark theme) ──
    static final int C_BG_DARK   = 0xFF0E1222;
    static final int C_BG_PANEL  = 0xFF1A2035;
    static final int C_BORDER    = 0xFF2A3A55;
    static final int C_ACCENT    = 0xFF4A9EFF;
    static final int C_HIGHLIGHT = 0xFFFF8C42;
    static final int C_TEXT      = 0xFFE0E6F0;
    static final int C_TEXT_DIM  = 0xFF8899AA;
    static final int C_PATH      = 0xFF3A5068;
    static final int C_BASE      = 0xFF28C76F;
    static final int C_EXIT      = 0xFFFF5B5B;
    static final int C_ORB       = 0xFFFFD700;
    static final int C_ENEMY     = 0xFFFF6B6B;
    static final int C_GHOST_OK  = 0xFF4A9EFF;
    static final int C_GHOST_BAD = 0xFFFF5B5B;

    // ── Camera ──
    static final float CAM_MIN_ZOOM = 0.4f;
    static final float CAM_MAX_ZOOM = 3.0f;
    static final float CAM_EDGE_SCROLL_SPEED = 480f; // design pixels/sec
    static final int CAM_EDGE_MARGIN = 20; // actual pixels

    // ── Towers ──
    static final float TOWER_BUILD_TIME = 0.8f;
    static final float TOWER_SNAP_RADIUS = 36f;

    // ── Game ──
    static final int INITIAL_MONEY = 420;
    static final int MAX_LEVELS = 7;
    static final float ENEMY_RADIUS = 14;
    static final int KILL_REWARD_BASE = 15;
}

/**
 * Tower type enum. Actual stats loaded from YAML at runtime.
 */
enum TowerType {
    MG,       // Machine Gun — fast, low dmg, single target
    MISSILE,  // Missile — slow, high dmg, AOE
    LASER,    // Laser — continuous beam, armor piercing
    SLOW;     // Slow — no dmg, slows enemies in range

    static TowerType fromBuildMode(TdBuildMode mode) {
        switch (mode) {
            case MG: return MG;
            case MISSILE: return MISSILE;
            case LASER: return LASER;
            case SLOW: return SLOW;
            default: return null;
        }
    }

    static TdBuildMode toBuildMode(TowerType type) {
        switch (type) {
            case MG: return TdBuildMode.MG;
            case MISSILE: return TdBuildMode.MISSILE;
            case LASER: return TdBuildMode.LASER;
            case SLOW: return TdBuildMode.SLOW;
            default: return TdBuildMode.NONE;
        }
    }
}

/**
 * Mutable tower definition loaded from towers.yaml.
 */
static final class TowerDef {
    final TowerType type;
    final String nameKey;
    final String descKey;
    final int cost;
    final float range;
    final float firePeriod;
    final float damage;
    final float aoeRadius;
    final float laserBonus;
    final float slowFactor;
    final float buildTime;
    final int iconColor;
    final String sfxFire;
    final String sfxPlace;

    TowerDef(TowerType type, String nameKey, String descKey, int cost, float range,
             float firePeriod, float damage, float aoeRadius, float laserBonus,
             float slowFactor, float buildTime, int iconColor,
             String sfxFire, String sfxPlace) {
        this.type = type;
        this.nameKey = nameKey;
        this.descKey = descKey;
        this.cost = cost;
        this.range = range;
        this.firePeriod = firePeriod;
        this.damage = damage;
        this.aoeRadius = aoeRadius;
        this.laserBonus = laserBonus;
        this.slowFactor = slowFactor;
        this.buildTime = buildTime;
        this.iconColor = iconColor;
        this.sfxFire = sfxFire;
        this.sfxPlace = sfxPlace;
    }
}

/**
 * Level definition loaded from levels.yaml.
 */
static final class LevelDef {
    int id;
    String nameKey;
    String subtitleKey;
    int initialMoney;
    int initialOrbs;
    int totalWaves;
    float enemyHpBase;
    float enemyHpPerWave;
    float enemySpeed;
    int enemyCountBase;
    int enemyCountPerWave;
    float spawnCooldown;
    float interWaveDelay;
    Vector2[] pathPoints;
    Vector2 basePos;
    Vector2 exitPos;
    Vector2 spawnPos;
    int worldW;
    int worldH;
}

/**
 * Per-wave configuration.
 */
static final class WaveDef {
    int enemyCount;
    float hp;
    float speed;
    float interval;
    float reward;
}

// ===== TdEntities.pde =====
/**
 * Entity Components (Phase 3):
 * - EnemyController: path following, steal/flee state machine
 * - TowerController: targeting, firing cooldown
 * - ProjectileController: flight, collision, AoE
 * - OrbController: base orbs animation
 */

// ===== TdFlow.pde =====
/**
 * Scene flow controller: Menu -> LevelSelect -> Playing -> Win/Lose.
 */
static final class TdFlow {

    static void buildMainMenu(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("menu_win");
        win.setBounds(340, 200, 600, 360);
        win.setTitle(TdAssets.i18n("menu.title"));
        win.setZOrder(10);
        root.add(win);

        Panel panel = new Panel("menu_panel");
        panel.setBounds(0, 0, 600, 360);
        panel.setLayoutManager(new FlowLayout(16, 16, true));
        win.add(panel);

        Label title = new Label("menu_title");
        title.setText(TdAssets.i18n("menu.title"));
        title.setBounds(0, 0, 560, 48);
        panel.add(title);

        Button btnStart = new Button("btn_start");
        btnStart.setLabel(TdAssets.i18n("menu.start"));
        btnStart.setAction(() -> TdFlow.showLevelSelect(app));
        panel.add(btnStart);

        Button btnSettings = new Button("btn_settings");
        btnSettings.setLabel(TdAssets.i18n("menu.settings"));
        btnSettings.setAction(() -> TdFlow.showSettings(app));
        panel.add(btnSettings);

        Button btnQuit = new Button("btn_quit");
        btnQuit.setLabel(TdAssets.i18n("menu.quit"));
        btnQuit.setAction(() -> app.exit());
        panel.add(btnQuit);

        TdSound.playBgmMenu();
    }

    static void showLevelSelect(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("level_win");
        win.setBounds(240, 160, 800, 440);
        win.setTitle(TdAssets.i18n("levelSelect.title"));
        win.setZOrder(10);
        root.add(win);

        Panel panel = new Panel("level_panel");
        panel.setBounds(0, 0, 800, 440);
        panel.setLayoutManager(new GridLayout(2, 4, 12, 12));
        win.add(panel);

        int count = TdAssets.getLevelCount();
        for (int i = 1; i <= Math.max(count, 7); i++) {
            final int lid = i;
            Button btn = new Button("btn_level_" + i);
            btn.setLabel(TdAssets.i18n("levelSelect.level", i));
            btn.setAction(() -> TdFlow.startLevel(app, lid));
            panel.add(btn);
        }

        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("menu.back"));
        btnBack.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnBack);
    }

    static void showSettings(TowerDefenseMin2 app) {
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("settings_win");
        win.setBounds(340, 200, 600, 480);
        win.setTitle(TdAssets.i18n("settings.title"));
        win.setZOrder(10);
        root.add(win);

        Panel panel = new Panel("settings_panel");
        panel.setBounds(0, 0, 600, 480);
        panel.setLayoutManager(new FlowLayout(12, 12, true));
        win.add(panel);

        // Master Volume
        Label lblMaster = new Label("lbl_master");
        lblMaster.setText(TdAssets.i18n("settings.masterVolume"));
        panel.add(lblMaster);

        Slider sldMaster = new Slider("sld_master");
        sldMaster.setSize(200, 24);
        sldMaster.setValue(app.engine.getAudio().getMasterVolume());
        sldMaster.setOnChange(() -> TdAssets.setMasterVolume(sldMaster.getValue()));
        panel.add(sldMaster);

        // BGM Volume
        Label lblBgm = new Label("lbl_bgm");
        lblBgm.setText(TdAssets.i18n("settings.bgmVolume"));
        panel.add(lblBgm);

        Slider sldBgm = new Slider("sld_bgm");
        sldBgm.setSize(200, 24);
        float bgmVol = 1.0f;
        try { bgmVol = app.engine.getAudio().getGroup("bgm").getVolume(); } catch (Exception e) { }
        sldBgm.setValue(bgmVol);
        sldBgm.setOnChange(() -> TdAssets.setBgmVolume(sldBgm.getValue()));
        panel.add(sldBgm);

        // SFX Volume
        Label lblSfx = new Label("lbl_sfx");
        lblSfx.setText(TdAssets.i18n("settings.sfxVolume"));
        panel.add(lblSfx);

        Slider sldSfx = new Slider("sld_sfx");
        sldSfx.setSize(200, 24);
        float sfxVol = 1.0f;
        try { sfxVol = app.engine.getAudio().getGroup("sfx").getVolume(); } catch (Exception e) { }
        sldSfx.setValue(sfxVol);
        sldSfx.setOnChange(() -> TdAssets.setSfxVolume(sldSfx.getValue()));
        panel.add(sldSfx);

        // Resolution
        Label lblRes = new Label("lbl_res");
        lblRes.setText(TdAssets.i18n("settings.resolution"));
        panel.add(lblRes);

        Panel resPanel = new Panel("res_panel");
        resPanel.setLayoutManager(new FlowLayout(8, 8, false));
        int[][] resOptions = { {1280, 720}, {1600, 900}, {1920, 1080} };
        for (int[] res : resOptions) {
            final int rw = res[0];
            final int rh = res[1];
            Button btnRes = new Button("btn_res_" + rw);
            btnRes.setLabel(rw + "x" + rh);
            btnRes.setAction(() -> {
                app.surface.setSize(rw, rh);
                app.engine.getDisplayManager().onWindowResize(rw, rh);
                app.worldWindow.setBounds(0, TdConfig.TOP_HUD, rw - TdConfig.RIGHT_W, rh - TdConfig.TOP_HUD);
                app.worldViewport.setBounds(1, 1, app.worldWindow.getWidth() - 2, app.worldWindow.getHeight() - 2);
                app.camera.setViewportSize(app.worldWindow.getWidth() - 2, app.worldWindow.getHeight() - 2);
            });
            resPanel.add(btnRes);
        }
        panel.add(resPanel);

        // Language
        Label lblLang = new Label("lbl_lang");
        lblLang.setText(TdAssets.i18n("settings.language"));
        panel.add(lblLang);

        Button btnZh = new Button("btn_zh");
        btnZh.setLabel(TdAssets.i18n("settings.lang.zh"));
        btnZh.setAction(() -> app.engine.getI18n().setLocale("zh"));
        panel.add(btnZh);

        Button btnEn = new Button("btn_en");
        btnEn.setLabel(TdAssets.i18n("settings.lang.en"));
        btnEn.setAction(() -> app.engine.getI18n().setLocale("en"));
        panel.add(btnEn);

        Button btnBack = new Button("btn_back");
        btnBack.setLabel(TdAssets.i18n("settings.back"));
        btnBack.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnBack);
    }

    static void startLevel(TowerDefenseMin2 app, int levelId) {
        app.state = TdState.PLAYING;
        TdGameWorld.startLevel(app, levelId);
        app.ui.getRoot().removeAllChildren();
        // HUD is drawn on screen layer, not UI
    }

    static void showWin(TowerDefenseMin2 app) {
        app.state = TdState.WIN;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("win_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.win"));
        win.setZOrder(20);
        root.add(win);

        Panel panel = new Panel("win_panel");
        panel.setBounds(0, 0, 500, 240);
        panel.setLayoutManager(new FlowLayout(16, 16, true));
        win.add(panel);

        Button btnNext = new Button("btn_next");
        btnNext.setLabel(TdAssets.i18n("game.nextLevel"));
        btnNext.setAction(() -> {
            int next = TdGameWorld.level != null ? TdGameWorld.level.id + 1 : 1;
            if (next <= TdAssets.getLevelCount()) startLevel(app, next);
            else buildMainMenu(app);
        });
        panel.add(btnNext);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnMenu);
    }

    static void showLose(TowerDefenseMin2 app) {
        app.state = TdState.LOSE;
        Panel root = app.ui.getRoot();
        root.removeAllChildren();

        Window win = new Window("lose_win");
        win.setBounds(390, 260, 500, 240);
        win.setTitle(TdAssets.i18n("game.lose"));
        win.setZOrder(20);
        root.add(win);

        Panel panel = new Panel("lose_panel");
        panel.setBounds(0, 0, 500, 240);
        panel.setLayoutManager(new FlowLayout(16, 16, true));
        win.add(panel);

        Button btnRetry = new Button("btn_retry");
        btnRetry.setLabel(TdAssets.i18n("game.retry"));
        btnRetry.setAction(() -> {
            int id = TdGameWorld.level != null ? TdGameWorld.level.id : 1;
            startLevel(app, id);
        });
        panel.add(btnRetry);

        Button btnMenu = new Button("btn_menu");
        btnMenu.setLabel(TdAssets.i18n("game.mainMenu"));
        btnMenu.setAction(() -> TdFlow.buildMainMenu(app));
        panel.add(btnMenu);
    }
}

// ===== TdGameWorld.pde =====
/**
 * Game world state: level data, towers, enemies, bullets, base/exit state.
 */
static final class TdGameWorld {

    static LevelDef level;
    static int money, orbits, currentWave, enemiesRemaining;
    static ArrayList<Tower> towers = new ArrayList<>();
    static ArrayList<Enemy> enemies = new ArrayList<>();
    static ArrayList<Bullet> bullets = new ArrayList<>();
    static float waveTimer, spawnTimer;
    static boolean waveInProgress;
    static TdPath path;
    static float basePathDist;

    static void startLevel(TowerDefenseMin2 app, int levelId) {
        // Clean up old entities
        for (Enemy e : enemies) {
            if (e.gameObject != null) e.gameObject.markForDestroy();
        }
        for (Tower t : towers) {
            if (t.gameObject != null) t.gameObject.markForDestroy();
        }
        for (Bullet b : bullets) {
            if (b.gameObject != null) b.gameObject.markForDestroy();
        }
        towers.clear();
        enemies.clear();
        bullets.clear();

        level = TdAssets.loadLevel(levelId);
        money = level.initialMoney;
        orbits = level.initialOrbs;
        currentWave = 0;
        enemiesRemaining = 0;
        waveTimer = 2.0f;
        spawnTimer = 0;
        waveInProgress = false;
        path = new TdPath(level.pathPoints);
        basePathDist = path.closestDistanceTo(level.basePos);

        // Resize world
        TowerDefenseMin2.WORLD_W = level.worldW;
        TowerDefenseMin2.WORLD_H = level.worldH;
        app.camera.setWorldBounds(new Rect(0, 0, level.worldW, level.worldH));
        app.camera.jumpCenterTo(level.worldW * 0.5f, level.worldH * 0.5f);
    }

    static void update(float dt) {
        if (level == null) return;

        // Wave management
        if (!waveInProgress && enemies.isEmpty() && currentWave < level.totalWaves) {
            waveTimer -= dt;
            if (waveTimer <= 0) {
                currentWave++;
                enemiesRemaining = level.enemyCountBase + level.enemyCountPerWave * (currentWave - 1);
                waveInProgress = true;
                spawnTimer = 0;
            }
        }

        // Spawning
        if (waveInProgress && enemiesRemaining > 0) {
            spawnTimer -= dt;
            if (spawnTimer <= 0) {
                spawnEnemy();
                enemiesRemaining--;
                spawnTimer = level.spawnCooldown;
                if (enemiesRemaining == 0) {
                    waveInProgress = false;
                    waveTimer = level.interWaveDelay;
                }
            }
        }

        // Check win/lose
        if (orbits <= 0 && enemies.isEmpty() && !waveInProgress && currentWave >= level.totalWaves) {
            TdFlow.showLose(TowerDefenseMin2.inst);
            return;
        }
        if (currentWave >= level.totalWaves && enemies.isEmpty() && !waveInProgress && orbits > 0) {
            TdFlow.showWin(TowerDefenseMin2.inst);
            return;
        }

        // Update entities
        for (int i = enemies.size() - 1; i >= 0; i--) {
            Enemy e = enemies.get(i);
            e.update(dt);
            if (e.reachedEnd) {
                if (e.gameObject != null) e.gameObject.markForDestroy();
                enemies.remove(i);
            } else if (e.hp <= 0) {
                e.state = EnemyState.DEAD;
                if (!e.hasStolen) {
                    money += TdConfig.KILL_REWARD_BASE;
                }
                if (e.gameObject != null) e.gameObject.markForDestroy();
                enemies.remove(i);
            }
        }

        for (int i = bullets.size() - 1; i >= 0; i--) {
            Bullet b = bullets.get(i);
            b.update(dt);
            if (b.dead) bullets.remove(i);
        }

        // Tower AI
        for (Tower t : towers) {
            t.update(dt);
        }
    }

    static void spawnEnemy() {
        Enemy e = new Enemy();
        e.path = path;
        e.pathDistance = 0;
        e.pos = path.sample(0);
        e.hp = level.enemyHpBase + level.enemyHpPerWave * (currentWave - 1);
        e.maxHp = e.hp;
        e.speed = level.enemySpeed;
        e.radius = TdConfig.ENEMY_RADIUS;
        e.state = EnemyState.MOVE_TO_BASE;
        e.hasStolen = false;

        GameObject go = GameObject.create("Enemy");
        go.getTransform().setPosition(e.pos.x, e.pos.y);
        go.setRenderLayer(10);
        go.addComponent(new EnemyRenderer(e));
        TowerDefenseMin2.inst.gameScene.addGameObject(go);
        e.gameObject = go;

        enemies.add(e);
    }

    static boolean canPlaceTower(int gx, int gy) {
        if (level == null) return false;
        float wx = (gx + 0.5f) * TdConfig.GRID;
        float wy = (gy + 0.5f) * TdConfig.GRID;
        if (wx < 0 || wy < 0 || wx > level.worldW || wy > level.worldH) return false;
        for (Tower t : towers) {
            if (Math.abs(t.gridX - gx) < 1 && Math.abs(t.gridY - gy) < 1) return false;
        }
        return true;
    }

    static boolean tryPlaceTower(TdBuildMode mode, int gx, int gy) {
        if (!canPlaceTower(gx, gy)) return false;
        TowerDef def = TdAssets.loadTowerDef(TowerType.fromBuildMode(mode));
        if (def == null || money < def.cost) return false;
        money -= def.cost;
        Tower t = new Tower(def, gx, gy);

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
}

// ===== TdGhost.pde =====
/**
 * Ghost tower preview: draws on screen layer using worldToScreen transform.
 */
static final class TdGhost {

    static int gridX, gridY;
    static boolean isValid;
    static float worldX, worldY;

    static void update() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (app.buildMode == TdBuildMode.NONE || app.camera == null) {
            isValid = false;
            return;
        }
        // Coordinate chain: actual mouse → design coords → world coords → snap to grid
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        Vector2 world = app.camera.screenToWorld(dm);
        gridX = Math.round(world.x / TdConfig.GRID - 0.5f);
        gridY = Math.round(world.y / TdConfig.GRID - 0.5f);
        worldX = (gridX + 0.5f) * TdConfig.GRID;
        worldY = (gridY + 0.5f) * TdConfig.GRID;
        isValid = TdGameWorld.canPlaceTower(gridX, gridY);
    }

    static void draw() {
        if (!isValid) return;
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        // Coordinate chain for drawing: world → design (screen) → actual pixels
        Vector2 design = app.camera.worldToScreen(new Vector2(worldX, worldY));
        Vector2 screen = app.engine.getDisplayManager().designToActual(design);
        float r = app.camera.getZoom() * TdConfig.GRID * 0.5f;

        app.pushStyle();
        app.noFill();
        app.stroke(app.buildMode == TdBuildMode.MG ? 0xFF4A9EFF :
                   app.buildMode == TdBuildMode.MISSILE ? 0xFFFF643C :
                   app.buildMode == TdBuildMode.LASER ? 0xFF3CDC78 :
                   0xFFC878DC);
        app.strokeWeight(2);
        app.ellipse(screen.x, screen.y, r * 2, r * 2);

        // Range indicator
        TowerDef def = TdAssets.loadTowerDef(TowerType.fromBuildMode(app.buildMode));
        if (def != null) {
            float rangeR = app.camera.getZoom() * def.range;
            app.strokeWeight(1);
            app.stroke(0x55FFFFFF);
            app.noFill();
            app.ellipse(screen.x, screen.y, rangeR * 2, rangeR * 2);
        }

        app.popStyle();
    }
}

// ===== TdHUD.pde =====
/**
 * HUD elements rendered on screen layer (top bar, right panel, minimap).
 */
static final class TdHUD {

    static void drawTopBar() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(0, 0));
        float x = d.x, y = d.y;
        float w = app.width;
        float h = TdConfig.TOP_HUD;

        app.pushStyle();
        app.noStroke();
        app.fill(TdTheme.BG_TITLE);
        app.rect(x, y, w, h);
        app.stroke(TdTheme.ACCENT);
        app.strokeWeight(1);
        app.noFill();
        app.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);

        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.LEFT, PApplet.CENTER);
        app.textSize(14);
        app.text("$ " + TdGameWorld.money + "  ♦ " + TdGameWorld.orbits + "  波 " + TdGameWorld.currentWave + "/" + (TdGameWorld.level != null ? TdGameWorld.level.totalWaves : 0),
            x + 16, y + h * 0.5f);

        // Pause button
        float btnW = 72;
        float btnH = 28;
        float btnX = x + w - btnW - 12;
        float btnY = y + (h - btnH) * 0.5f;
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        boolean pauseHover = dm.x >= btnX && dm.x <= btnX + btnW && dm.y >= btnY && dm.y <= btnY + btnH;
        int pauseFill = pauseHover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG;
        app.noStroke();
        app.fill(pauseFill);
        app.rect(btnX, btnY, btnW, btnH);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(btnX + 0.5f, btnY + 0.5f, btnW - 1, btnH - 1);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(12);
        app.text(TdAssets.i18n("game.pause"), btnX + btnW * 0.5f, btnY + btnH * 0.5f);

        app.popStyle();
    }

    static void drawBuildPanel() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, 0));
        float x = d.x - TdConfig.RIGHT_W;
        float y = TdConfig.TOP_HUD;
        float w = TdConfig.RIGHT_W;
        float h = d.y + app.height - y;

        app.pushStyle();
        app.noStroke();
        app.fill(TdTheme.BG_PANEL);
        app.rect(x, y, w, h);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);

        // Tower buttons
        float btnH = 56;
        float gap = 8;
        float by = y + 16;
        TowerType[] types = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW };
        String[] initials = { "M", "R", "L", "S" };
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        for (int i = 0; i < types.length; i++) {
            TowerType tt = types[i];
            TowerDef def = TdAssets.loadTowerDef(tt);
            if (def == null) continue;
            boolean selected = app.buildMode == TowerType.toBuildMode(tt);
            boolean hover = dm.x >= x + 8 && dm.x <= x + w - 8 && dm.y >= by && dm.y <= by + btnH;
            int fill = selected ? TdTheme.BTN_PRESS : (hover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG);
            app.noStroke();
            app.fill(fill);
            app.rect(x + 8, by, w - 16, btnH);
            app.stroke(selected ? TdTheme.ACCENT : TdTheme.BORDER);
            app.strokeWeight(selected ? 2 : 1);
            app.noFill();
            app.rect(x + 8.5f, by + 0.5f, w - 17, btnH - 1);

            // Icon
            float iconSize = 32;
            float iconX = x + 16;
            float iconY = by + (btnH - iconSize) * 0.5f;
            app.noStroke();
            app.fill(TdConfig.C_ACCENT);
            app.rect(iconX, iconY, iconSize, iconSize);
            app.fill(TdTheme.BG_DARK);
            app.textAlign(PApplet.CENTER, PApplet.CENTER);
            app.textSize(14);
            app.text(initials[i], iconX + iconSize * 0.5f, iconY + iconSize * 0.5f);

            // Name and cost
            app.fill(TdTheme.TEXT);
            app.textAlign(PApplet.LEFT, PApplet.CENTER);
            app.textSize(13);
            app.text(TdAssets.i18n(def.nameKey), iconX + iconSize + 10, by + btnH * 0.35f);
            app.fill(TdTheme.TEXT_DIM);
            app.textSize(11);
            app.text("$" + def.cost, iconX + iconSize + 10, by + btnH * 0.7f);

            by += btnH + gap;
        }

        // Cancel button
        by += 8;
        float cancelH = 32;
        boolean cancelHover = dm.x >= x + 8 && dm.x <= x + w - 8 && dm.y >= by && dm.y <= by + cancelH;
        int cancelFill = cancelHover ? TdTheme.BTN_HOVER : TdTheme.BTN_BG;
        app.noStroke();
        app.fill(cancelFill);
        app.rect(x + 8, by, w - 16, cancelH);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(x + 8.5f, by + 0.5f, w - 17, cancelH - 1);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(12);
        app.text(TdAssets.i18n("game.build.cancel"), x + w * 0.5f, by + cancelH * 0.5f);

        app.popStyle();
    }

    static void drawMinimap() {
        TdMinimap.draw();
    }

    static void handleMinimapClick() {
        TdMinimap.handleClick();
    }

    static void drawPauseOverlay() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        app.pushStyle();
        app.fill(0xCC000000);
        app.noStroke();
        app.rect(0, 0, app.width, app.height);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(32);
        app.text("PAUSED", app.width * 0.5f, app.height * 0.5f);
        app.popStyle();
    }

    static boolean isPauseButtonHit(float mx, float my) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(0, 0));
        float x = d.x, y = d.y;
        float w = app.width;
        float h = TdConfig.TOP_HUD;
        float btnW = 72;
        float btnH = 28;
        float btnX = x + w - btnW - 12;
        float btnY = y + (h - btnH) * 0.5f;
        return mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH;
    }

    static TdBuildMode getBuildModeAt(float mx, float my) {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, 0));
        float x = d.x - TdConfig.RIGHT_W;
        float y = TdConfig.TOP_HUD;
        float w = TdConfig.RIGHT_W;
        float btnH = 56;
        float gap = 8;
        float by = y + 16;
        TowerType[] types = { TowerType.MG, TowerType.MISSILE, TowerType.LASER, TowerType.SLOW };
        for (int i = 0; i < types.length; i++) {
            TowerDef def = TdAssets.loadTowerDef(types[i]);
            if (def == null) continue;
            if (mx >= x + 8 && mx <= x + w - 8 && my >= by && my <= by + btnH) {
                return TowerType.toBuildMode(types[i]);
            }
            by += btnH + gap;
        }
        // Cancel button
        by += 8;
        float cancelH = 32;
        if (mx >= x + 8 && mx <= x + w - 8 && my >= by && my <= by + cancelH) {
            return TdBuildMode.NONE;
        }
        return null;
    }
}

// ===== TdLevelData.pde =====
/**
 * Level data loader placeholder.
 * Actual loading implemented in TdAssets (YAML via snakeyaml).
 */

// ===== TdMap.pde =====
/**
 * Map renderer: draws grid, path, base, spawn point in world space.
 */
static final class TdMap {

    static void render() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        LevelDef lv = TdGameWorld.level;
        if (lv == null) return;

        app.pushStyle();

        // Grid
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        for (int gx = 0; gx <= lv.worldW; gx += TdConfig.GRID) {
            app.line(gx, 0, gx, lv.worldH);
        }
        for (int gy = 0; gy <= lv.worldH; gy += TdConfig.GRID) {
            app.line(0, gy, lv.worldW, gy);
        }

        // Path
        if (lv.pathPoints.length > 1) {
            app.stroke(0xFF4A9EFF);
            app.strokeWeight(12);
            app.strokeCap(PApplet.ROUND);
            for (int i = 1; i < lv.pathPoints.length; i++) {
                app.line(lv.pathPoints[i-1].x, lv.pathPoints[i-1].y, lv.pathPoints[i].x, lv.pathPoints[i].y);
            }
        }

        // Base
        app.noStroke();
        app.fill(0xFF4A9EFF);
        app.ellipse(lv.basePos.x, lv.basePos.y, 24, 24);
        app.fill(TdTheme.TEXT);
        app.textAlign(PApplet.CENTER, PApplet.CENTER);
        app.textSize(10);
        app.text("BASE", lv.basePos.x, lv.basePos.y);

        // Exit
        app.noStroke();
        app.fill(0xFFFF4444);
        app.ellipse(lv.exitPos.x, lv.exitPos.y, 16, 16);

        // Spawn
        app.noStroke();
        app.fill(0xFFFF8C42);
        app.ellipse(lv.spawnPos.x, lv.spawnPos.y, 12, 12);

        app.popStyle();
    }
}

// ===== TdMinimap.pde =====
/**
 * Minimap widget — encapsulates bounds, drawing, and click-to-jump logic.
 */
static final class TdMinimap {
    static final float MW = 180, MH = 120;

    static float getX() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, app.height));
        return d.x - TdConfig.RIGHT_W + 16;
    }

    static float getY() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 d = app.engine.getDisplayManager().actualToDesign(new Vector2(app.width, app.height));
        return d.y - MH - 16;
    }

    static boolean isMouseOver() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        float mx = getX();
        float my = getY();
        return dm.x >= mx && dm.x <= mx + MW && dm.y >= my && dm.y <= my + MH;
    }

    static void handleClick() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        if (TdGameWorld.level == null || app.camera == null) return;
        Vector2 dm = app.engine.getDisplayManager().actualToDesign(new Vector2(app.mouseX, app.mouseY));
        float mx = getX();
        float my = getY();
        float wx = (dm.x - mx) / MW * TdGameWorld.level.worldW;
        float wy = (dm.y - my) / MH * TdGameWorld.level.worldH;
        app.camera.jumpCenterTo(wx, wy);
    }

    static void draw() {
        TowerDefenseMin2 app = TowerDefenseMin2.inst;
        float mx = getX();
        float my = getY();

        app.pushStyle();
        app.noStroke();
        app.fill(TdTheme.BG_DARK);
        app.rect(mx, my, MW, MH);
        app.stroke(TdTheme.BORDER);
        app.strokeWeight(1);
        app.noFill();
        app.rect(mx + 0.5f, my + 0.5f, MW - 1, MH - 1);

        if (TdGameWorld.level != null) {
            float sx = MW / TdGameWorld.level.worldW;
            float sy = MH / TdGameWorld.level.worldH;
            // Base
            app.fill(0xFF4A9EFF);
            app.ellipse(mx + TdGameWorld.level.basePos.x * sx, my + TdGameWorld.level.basePos.y * sy, 6, 6);
            // Exit
            app.fill(0xFFFF4444);
            app.ellipse(mx + TdGameWorld.level.exitPos.x * sx, my + TdGameWorld.level.exitPos.y * sy, 6, 6);
            // Path
            app.stroke(0xFF4A9EFF);
            app.strokeWeight(1);
            Vector2[] pts = TdGameWorld.level.pathPoints;
            for (int i = 1; i < pts.length; i++) {
                app.line(mx + pts[i-1].x * sx, my + pts[i-1].y * sy,
                         mx + pts[i].x * sx, my + pts[i].y * sy);
            }
            // Camera rect
            Camera2D cam = app.camera;
            float cx = cam.getTransform().getPosition().x;
            float cy = cam.getTransform().getPosition().y;
            float cw = cam.getViewportWidth() / cam.getZoom();
            float ch = cam.getViewportHeight() / cam.getZoom();
            app.noFill();
            app.stroke(0xFFFF8C42);
            app.strokeWeight(1);
            app.rect(mx + (cx - cw * 0.5f) * sx, my + (cy - ch * 0.5f) * sy, cw * sx, ch * sy);
        }

        app.popStyle();
    }
}

// ===== TdPath.pde =====
/**
 * Path system: polyline with distance sampling for enemy movement.
 */
static final class TdPath {
    Vector2[] points;
    float[] segmentLengths;
    float totalLength;

    TdPath(Vector2[] points) {
        this.points = points;
        computeLengths();
    }

    private void computeLengths() {
        if (points == null || points.length < 2) {
            segmentLengths = new float[0];
            totalLength = 0;
            return;
        }
        segmentLengths = new float[points.length - 1];
        totalLength = 0;
        for (int i = 0; i < points.length - 1; i++) {
            float len = points[i].distance(points[i + 1]);
            segmentLengths[i] = len;
            totalLength += len;
        }
    }

    /** Sample position at distance along the path. */
    Vector2 sample(float dist) {
        if (points == null || points.length == 0) return new Vector2();
        if (dist <= 0) return points[0].copy();
        if (dist >= totalLength) return points[points.length - 1].copy();
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            if (accumulated + segmentLengths[i] >= dist) {
                float t = (dist - accumulated) / segmentLengths[i];
                return Vector2.lerp(points[i], points[i + 1], t);
            }
            accumulated += segmentLengths[i];
        }
        return points[points.length - 1].copy();
    }

    /** Get direction vector at distance along the path. */
    Vector2 direction(float dist) {
        if (points == null || points.length < 2) return new Vector2(1, 0);
        if (dist <= 0) return points[1].copy().sub(points[0]).normalize();
        if (dist >= totalLength) {
            return points[points.length - 1].copy().sub(points[points.length - 2]).normalize();
        }
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            if (accumulated + segmentLengths[i] >= dist) {
                return points[i + 1].copy().sub(points[i]).normalize();
            }
            accumulated += segmentLengths[i];
        }
        return points[points.length - 1].copy().sub(points[points.length - 2]).normalize();
    }

    /** Find the distance along the path closest to the given point. */
    float closestDistanceTo(Vector2 target) {
        if (points == null || points.length == 0) return 0;
        float bestDist = 0;
        float bestD = Float.MAX_VALUE;
        float accumulated = 0;
        for (int i = 0; i < segmentLengths.length; i++) {
            Vector2 a = points[i];
            Vector2 b = points[i + 1];
            Vector2 ab = b.copy().sub(a);
            Vector2 at = target.copy().sub(a);
            float abLenSq = ab.x * ab.x + ab.y * ab.y;
            float t = abLenSq > 0 ? PApplet.constrain((at.x * ab.x + at.y * ab.y) / abLenSq, 0, 1) : 0;
            Vector2 closest = Vector2.lerp(a, b, t);
            float d = closest.distance(target);
            if (d < bestD) {
                bestD = d;
                bestDist = accumulated + segmentLengths[i] * t;
            }
            accumulated += segmentLengths[i];
        }
        return bestDist;
    }

    float getTotalLength() { return totalLength; }
}

// ===== TdRenderers.pde =====
/**
 * Render Components for world layer (renderLayer < 100).
 * Drawn inside SceneViewport's off-screen buffer via p5engine renderer.
 */

static class WorldBgRenderer extends RendererComponent {
    protected void renderShape(PGraphics g) {
        LevelDef lv = TdGameWorld.level;
        if (lv == null) return;

        // Grid
        g.stroke(TdTheme.BORDER);
        g.strokeWeight(1);
        g.noFill();
        for (int gx = 0; gx <= lv.worldW; gx += TdConfig.GRID) {
            g.line(gx, 0, gx, lv.worldH);
        }
        for (int gy = 0; gy <= lv.worldH; gy += TdConfig.GRID) {
            g.line(0, gy, lv.worldW, gy);
        }

        // Path
        if (lv.pathPoints != null && lv.pathPoints.length > 1) {
            g.stroke(0xFF4A9EFF);
            g.strokeWeight(12);
            g.strokeCap(PApplet.ROUND);
            for (int i = 1; i < lv.pathPoints.length; i++) {
                g.line(lv.pathPoints[i-1].x, lv.pathPoints[i-1].y,
                       lv.pathPoints[i].x, lv.pathPoints[i].y);
            }
        }

        // Base
        g.noStroke();
        g.fill(0xFF4A9EFF);
        g.ellipse(lv.basePos.x, lv.basePos.y, 24, 24);
        g.fill(TdTheme.TEXT);
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        g.textSize(10);
        g.text("BASE", lv.basePos.x, lv.basePos.y);

        // Exit
        g.noStroke();
        g.fill(0xFFFF4444);
        g.ellipse(lv.exitPos.x, lv.exitPos.y, 16, 16);

        // Spawn
        g.noStroke();
        g.fill(0xFFFF8C42);
        g.ellipse(lv.spawnPos.x, lv.spawnPos.y, 12, 12);
    }
}

static class EnemyRenderer extends RendererComponent {
    Enemy enemy;
    EnemyRenderer(Enemy enemy) { this.enemy = enemy; }

    protected void renderShape(PGraphics g) {
        if (enemy == null || enemy.hp <= 0) return;

        // Body
        g.noStroke();
        if (enemy.state == EnemyState.MOVE_TO_BASE) {
            g.fill(TdConfig.C_ENEMY);
        } else {
            g.fill(TdConfig.C_ORB);
        }
        g.ellipse(enemy.pos.x, enemy.pos.y, enemy.radius * 2, enemy.radius * 2);

        // HP bar
        float barW = enemy.radius * 2;
        float barH = 4;
        float barX = enemy.pos.x - barW * 0.5f;
        float barY = enemy.pos.y - enemy.radius - 8;
        g.noStroke();
        g.fill(0xFF333333);
        g.rect(barX, barY, barW, barH);
        g.fill(0xFFFF4444);
        float hpPct = enemy.maxHp > 0 ? enemy.hp / enemy.maxHp : 0;
        g.rect(barX, barY, barW * hpPct, barH);
    }
}

static class TowerRenderer extends RendererComponent {
    Tower tower;
    TowerRenderer(Tower tower) { this.tower = tower; }

    protected void renderShape(PGraphics g) {
        if (tower == null) return;
        float size = TdConfig.GRID * 0.7f;
        float half = size * 0.5f;

        if (!tower.built) {
            // Building progress
            g.noStroke();
            g.fill(0xFF444444);
            g.rect(tower.worldX - half, tower.worldY - half, size, size);
            g.fill(0xFF4A9EFF);
            float prog = tower.buildProgress / tower.def.buildTime;
            g.rect(tower.worldX - half, tower.worldY - half, size * prog, size);
            return;
        }

        // Tower body
        g.noStroke();
        g.fill(tower.def.iconColor);
        g.rect(tower.worldX - half, tower.worldY - half, size, size);

        // Range indicator (subtle)
        g.noFill();
        g.stroke(tower.def.iconColor);
        g.strokeWeight(1);
        g.ellipse(tower.worldX, tower.worldY, tower.def.range * 2, tower.def.range * 2);
    }
}

static class BulletRenderer extends RendererComponent {
    Bullet bullet;
    BulletRenderer(Bullet bullet) { this.bullet = bullet; }

    protected void renderShape(PGraphics g) {
        if (bullet == null || bullet.dead) return;
        g.noStroke();
        g.fill(0xFFFFFF00);
        g.ellipse(bullet.pos.x, bullet.pos.y, 6, 6);
    }
}

// ===== TdSound.pde =====
/**
 * Sound shortcuts & pre-load declarations.
 */
static final class TdSound {

    static final String SFX_CLICK   = "sounds/ui_click.wav";
    static final String SFX_HOVER   = "sounds/ui_hover.wav";
    static final String SFX_SHOT    = "sounds/shot_single.wav";
    static final String SFX_LASER   = "sounds/laser_charge.wav";
    static final String SFX_BUFF    = "sounds/buff_get.wav";
    static final String SFX_BGM     = "music/TopGun.ogg";

    static void playBgmMenu() {
        try {
            P5Engine.getInstance().getAudio().playOneShot(SFX_BGM, "bgm");
        } catch (Exception e) {}
    }

    static void playClick() {
        TdAssets.playSfx(SFX_CLICK);
    }

    static void playShot() {
        TdAssets.playSfx(SFX_SHOT);
    }
}

// ===== TdTheme.pde =====
/**
 * Sci-Fi dark theme for TowerDefenseMin2.
 * Overrides DefaultTheme with a cyan/orange accent palette.
 */
public class TdTheme implements Theme {

    private float currentAlpha = 1f;

    static final int BG_DARK   = 0xFF0E1222;
    static final int BG_PANEL  = 0xFF1A2035;
    static final int BG_TITLE  = 0xFF151B2E;
    static final int BORDER    = 0xFF2A3A55;
    static final int ACCENT    = 0xFF4A9EFF;
    static final int HIGHLIGHT = 0xFFFF8C42;
    static final int TEXT      = 0xFFE0E6F0;
    static final int TEXT_DIM  = 0xFF8899AA;
    static final int BTN_BG    = 0xFF252F45;
    static final int BTN_HOVER = 0xFF2F3D5A;
    static final int BTN_PRESS = 0xFF1A3A5C;

    // ── Theme interface ──

    @Override
    public void drawPanel(PApplet g, float x, float y, float w, float h, boolean focused) {
        g.noStroke();
        g.fill(a(BG_PANEL));
        g.rect(x, y, w, h);
        g.stroke(a(focused ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    }

    @Override
    public void drawFrame(PApplet g, float x, float y, float w, float h) {
        g.noStroke();
        g.fill(a(BG_PANEL));
        g.rect(x, y, w, h);
        g.stroke(a(ACCENT));
        g.strokeWeight(2);
        g.noFill();
        g.rect(x + 1, y + 1, w - 2, h - 2);
    }

    @Override
    public void drawWindowChrome(PApplet g, float x, float y, float w, float h, float titleH, String title, boolean focused) {
        // Title bar
        g.noStroke();
        g.fill(a(BG_TITLE));
        g.rect(x, y, w, titleH);
        // Content
        g.fill(a(BG_PANEL));
        g.rect(x, y + titleH, w, h - titleH);
        // Border
        g.stroke(a(focused ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
        // Title text
        g.fill(a(TEXT));
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, titleH * 0.55f));
        g.text(title != null ? title : "", x + 10, y + titleH * 0.5f);

        // Control buttons (close/max/min) — simplified as small rects
        float btnW = 20, btnH = 14, btnGap = 4;
        float btnY = y + (titleH - btnH) * 0.5f;
        float btnRight = x + w - btnGap;
        // Close
        btnRight -= btnW;
        drawWinButton(g, btnRight, btnY, btnW, btnH, "×");
        // Max
        btnRight -= btnW + btnGap;
        drawWinButton(g, btnRight, btnY, btnW, btnH, "□");
        // Min
        btnRight -= btnW + btnGap;
        drawWinButton(g, btnRight, btnY, btnW, btnH, "−");
    }

    private void drawWinButton(PApplet g, float x, float y, float w, float h, String label) {
        g.noStroke();
        g.fill(a(0xFF333333));
        g.rect(x, y, w, h);
        g.stroke(a(BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
        g.fill(a(TEXT));
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        g.textSize(9);
        g.text(label, x + w * 0.5f, y + h * 0.5f);
    }

    @Override
    public void drawButton(PApplet g, float x, float y, float w, float h, String label, boolean hover, boolean pressed, boolean disabled) {
        int fill = disabled ? 0xFF333333 : (pressed ? BTN_PRESS : (hover ? BTN_HOVER : BTN_BG));
        g.noStroke();
        g.fill(a(fill));
        g.rect(x, y, w, h);
        g.stroke(a(disabled ? BORDER : (hover ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.textAlign(PApplet.CENTER, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", x + w * 0.5f, y + h * 0.5f);
    }

    @Override
    public void drawCheckbox(PApplet g, float x, float y, float w, float h, String label, boolean checked, boolean hover, boolean disabled) {
        float box = Math.min(h - 6, 16);
        float bx = x + 4;
        float by = y + (h - box) * 0.5f;
        g.stroke(a(disabled ? BORDER : (hover ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF333333 : BG_DARK));
        g.rect(bx, by, box, box);
        if (checked) {
            g.stroke(a(ACCENT));
            g.line(bx + 3, by + box * 0.5f, bx + box * 0.35f, by + box - 3);
            g.line(bx + box * 0.35f, by + box - 3, bx + box - 2, by + 2);
        }
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", bx + box + 8, y + h * 0.5f);
    }

    @Override
    public void drawRadio(PApplet g, float x, float y, float w, float h, String label, boolean selected, boolean hover, boolean disabled) {
        float r = Math.min(h - 6, 14) * 0.5f;
        float cx = x + 4 + r;
        float cy = y + h * 0.5f;
        g.stroke(a(disabled ? BORDER : (hover ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF333333 : BG_DARK));
        g.ellipse(cx, cy, r * 2, r * 2);
        if (selected) {
            g.noStroke();
            g.fill(a(ACCENT));
            g.ellipse(cx, cy, r * 1.1f, r * 1.1f);
        }
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.45f));
        g.text(label != null ? label : "", x + 4 + r * 2 + 10, y + h * 0.5f);
    }

    @Override
    public void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled, int textAlign) {
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.noStroke();
        g.textAlign(textAlign, PApplet.CENTER);
        g.textSize(Math.min(14, h * 0.5f));
        g.text(text != null ? text : "", x, y, w, h);
    }

    @Override
    public void drawTextField(PApplet g, float x, float y, float w, float h, String text, int caretIndex, boolean focused, boolean disabled) {
        g.stroke(a(disabled ? BORDER : (focused ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF333333 : BG_DARK));
        g.rect(x, y, w, h);
        g.fill(a(disabled ? TEXT_DIM : TEXT));
        g.noStroke();
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        float textSize = Math.min(14, h * 0.45f);
        g.textSize(textSize);
        String t = text != null ? text : "";
        g.text(t, x + 6, y + h * 0.5f);
        if (focused && !disabled) {
            int ci = caretIndex < 0 ? t.length() : Math.min(caretIndex, t.length());
            String prefix = t.substring(0, ci);
            float tw = g.textWidth(prefix);
            g.stroke(a(ACCENT));
            g.line(x + 6 + tw, y + 6, x + 6 + tw, y + h - 6);
        }
    }

    @Override
    public void drawSliderTrack(PApplet g, float x, float y, float w, float h, float value01, boolean hover, boolean disabled) {
        float v = Math.max(0, Math.min(1, value01));
        g.noStroke();
        g.fill(a(disabled ? 0xFF333333 : 0xFF252525));
        g.rect(x, y + h * 0.35f, w, h * 0.3f);
        g.fill(a(disabled ? BORDER : ACCENT));
        g.rect(x, y + h * 0.35f, w * v, h * 0.3f);
        float knobX = x + w * v;
        g.stroke(a(hover && !disabled ? ACCENT : BORDER));
        g.strokeWeight(1);
        g.fill(a(disabled ? 0xFF555555 : 0xFFCCCCCC));
        g.ellipse(knobX, y + h * 0.5f, h * 0.55f, h * 0.55f);
    }

    @Override
    public void drawScrollBar(PApplet g, float x, float y, float w, float h, float thumbStart, float thumbLen, boolean vertical, boolean hover, boolean disabled) {
        g.noStroke();
        g.fill(a(0xFF222222));
        g.rect(x, y, w, h);
        g.fill(a(disabled ? 0xFF555555 : (hover ? 0xFF777777 : 0xFF666666)));
        if (vertical) {
            g.rect(x + 1, y + thumbStart, w - 2, Math.max(8, thumbLen));
        } else {
            g.rect(x + thumbStart, y + 1, Math.max(8, thumbLen), h - 2);
        }
    }

    @Override
    public void drawProgressBar(PApplet g, float x, float y, float w, float h, float value01, boolean disabled) {
        float v = Math.max(0, Math.min(1, value01));
        g.noStroke();
        g.fill(a(disabled ? 0xFF333333 : 0xFF252525));
        g.rect(x, y, w, h);
        g.fill(a(disabled ? BORDER : ACCENT));
        g.rect(x, y, w * v, h);
        g.stroke(a(BORDER));
        g.strokeWeight(1);
        g.noFill();
        g.rect(x + 0.5f, y + 0.5f, w - 1, h - 1);
    }

    @Override
    public void drawList(PApplet g, float x, float y, float w, float h, java.util.List<String> items, int firstIndex, int selectedIndex, boolean focused, boolean disabled) {
        g.stroke(a(disabled ? BORDER : (focused ? ACCENT : BORDER)));
        g.strokeWeight(1);
        g.fill(a(BG_DARK));
        g.rect(x, y, w, h);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(13);
        float rowH = 26;
        int idx = 0;
        for (int i = firstIndex; i < items.size(); i++) {
            float ry = y + idx * rowH;
            if (ry + rowH > y + h) break;
            if (i == selectedIndex) {
                g.noStroke();
                g.fill(a(0xFF2A4A6A));
                g.rect(x + 1, ry, w - 2, rowH);
            }
            g.fill(a(disabled ? TEXT_DIM : TEXT));
            g.noStroke();
            g.text(items.get(i), x + 6, ry + rowH * 0.5f);
            idx++;
        }
    }

    @Override
    public void drawTabHeader(PApplet g, float x, float y, float w, float h, String[] titles, int selected, boolean focused) {
        if (titles == null || titles.length == 0) return;
        float tw = w / titles.length;
        for (int i = 0; i < titles.length; i++) {
            float tx = x + i * tw;
            boolean sel = i == selected;
            g.noStroke();
            g.fill(a(sel ? BG_PANEL : 0xFF2A2A2A));
            g.rect(tx, y, tw, h);
            g.stroke(a(focused && sel ? ACCENT : BORDER));
            g.strokeWeight(1);
            g.noFill();
            g.rect(tx + 0.5f, y + 0.5f, tw - 1, h - 1);
            g.fill(a(TEXT));
            g.textAlign(PApplet.CENTER, PApplet.CENTER);
            g.textSize(Math.min(13, h * 0.45f));
            g.text(titles[i], tx + tw * 0.5f, y + h * 0.5f);
        }
    }

    @Override
    public void drawImage(PApplet g, float x, float y, float w, float h, processing.core.PImage img, boolean disabled) {
        if (img == null) {
            g.noStroke();
            g.fill(a(0xFF333333));
            g.rect(x, y, w, h);
            return;
        }
        g.pushStyle();
        int baseAlpha = Math.round(255 * currentAlpha);
        if (disabled) {
            g.tint(255, Math.round(baseAlpha * 120f / 255f));
        } else if (currentAlpha < 1f) {
            g.tint(255, baseAlpha);
        }
        g.image(img, x, y, w, h);
        g.popStyle();
    }

    @Override
    public void setCurrentAlpha(float alpha) {
        this.currentAlpha = Math.max(0f, Math.min(1f, alpha));
    }

    private int a(int color) {
        if (currentAlpha >= 1f) return color;
        int origA = (color >>> 24) & 0xFF;
        int newA = Math.round(origA * currentAlpha);
        return (newA << 24) | (color & 0x00FFFFFF);
    }
}

// ===== TdWave.pde =====
/**
 * Wave data & timing — handled inside TdGameWorld.
 * This file reserved for future wave composition logic (mixed enemy types, etc.)
 */
static final class TdWave {
    int waveNumber;
    int enemyCount;
    float hpMultiplier;
    float speedMultiplier;
    String[] enemyTypes;
}

// ===== Tower.pde =====
/**
 * Active tower instance in the game world.
 */
static class Tower {
    TowerDef def;
    int gridX, gridY;
    float worldX, worldY;
    float cooldown;
    float buildProgress;
    boolean built;
    GameObject gameObject;

    Tower(TowerDef def, int gx, int gy) {
        this.def = def;
        this.gridX = gx;
        this.gridY = gy;
        this.worldX = (gx + 0.5f) * TdConfig.GRID;
        this.worldY = (gy + 0.5f) * TdConfig.GRID;
        this.cooldown = 0;
        this.buildProgress = 0;
        this.built = false;
    }

    void update(float dt) {
        if (!built) {
            buildProgress += dt;
            if (buildProgress >= def.buildTime) built = true;
            return;
        }
        cooldown -= dt;
        if (cooldown <= 0) {
            Enemy target = findTarget();
            if (target != null) {
                fireAt(target);
                cooldown = def.firePeriod;
            }
        }
    }

    Enemy findTarget() {
        Enemy best = null;
        float bestDist = def.range;
        for (Enemy e : TdGameWorld.enemies) {
            float d = e.pos.distance(new Vector2(worldX, worldY));
            if (d <= bestDist) {
                bestDist = d;
                best = e;
            }
        }
        return best;
    }

    void fireAt(Enemy target) {
        Bullet b = new Bullet();
        b.pos = new Vector2(worldX, worldY);
        b.vel = target.pos.copy().sub(b.pos).normalize().mult(400);
        b.damage = def.damage;
        b.aoeRadius = def.aoeRadius;
        b.laserBonus = def.laserBonus;
        b.slowFactor = def.slowFactor;
        b.life = 3.0f;
        TdGameWorld.bullets.add(b);
        TdAssets.playSfx(def.sfxFire);

        GameObject bGo = GameObject.create("Bullet");
        bGo.getTransform().setPosition(b.pos.x, b.pos.y);
        bGo.setRenderLayer(15);
        bGo.addComponent(new BulletRenderer(b));
        TowerDefenseMin2.inst.gameScene.addGameObject(bGo);
        b.gameObject = bGo;
    }
}

// ===== TowerDefenseMin2.pde =====

static TowerDefenseMin2 inst;

P5Engine engine;
UIManager ui;
SketchUiCoordinator sketchUi;
Scene gameScene;
Camera2D camera;
SceneViewport worldViewport;
Window worldWindow;

static int WORLD_W = 2400;
static int WORLD_H = 1600;

TdState state = TdState.MENU;
TdBuildMode buildMode = TdBuildMode.NONE;
boolean keyScrollUp, keyScrollDown, keyScrollLeft, keyScrollRight;

public void settings() {
  P5Engine.configureDisplay(this, P5Config.defaults()
    .width(1280).height(720)
    .renderer(P5Config.RenderMode.P2D)
    .displayConfig(DisplayConfig.defaults()
      .designWidth(1280).designHeight(720).scaleMode(ScaleMode.FIT).resizable(true)));
}

public void setup() {
  inst = this;
  engine = P5Engine.create(this, P5Config.defaults().logToFile(true));
  engine.setApplicationTitle("TowerDefenseMin2");
  ui = new UIManager(this);
  ui.attach();
  sketchUi = new SketchUiCoordinator(this, ui);
  ui.setTheme(new TdTheme());

  gameScene = engine.getSceneManager().getActiveScene();
  setupCamera();
  setupWorldViewport();

  // World background renderer (grid, path, base, exit) — lives in Scene
  GameObject bgGo = GameObject.create("world_bg");
  bgGo.addComponent(new WorldBgRenderer());
  bgGo.setRenderLayer(0);
  gameScene.addGameObject(bgGo);

  TdAssets.loadAll(this);
  TdFlow.buildMainMenu(this);
}

void setupCamera() {
  GameObject camGo = GameObject.create("camera");
  camera = camGo.addComponent(Camera2D.class);
  camera.setWorldBounds(new Rect(0, 0, WORLD_W, WORLD_H));
  camera.jumpCenterTo(WORLD_W * 0.5f, WORLD_H * 0.5f);
  gameScene.setCamera(camera);
  gameScene.addGameObject(camGo);
}

void setupWorldViewport() {
  worldWindow = new Window("world_win");
  worldWindow.setBounds(0, TdConfig.TOP_HUD, 1280 - TdConfig.RIGHT_W, 720 - TdConfig.TOP_HUD);
  worldWindow.setTitle("World");
  worldWindow.setZOrder(0);
  ui.getRoot().add(worldWindow);

  worldViewport = new SceneViewport("world_vp");
  worldViewport.setBounds(1, 1, worldWindow.getWidth() - 2, worldWindow.getHeight() - 2);
  worldViewport.setScene(gameScene);
  worldViewport.setCamera(camera);
  worldWindow.add(worldViewport);

  int vpW = (int)(worldWindow.getWidth() - 2);
  int vpH = (int)(worldWindow.getHeight() - 2);
  camera.setViewportSize(vpW, vpH);
  camera.setViewportOffset(worldWindow.getAbsoluteX() + 1, worldWindow.getAbsoluteY() + worldWindow.getTitleBarHeight() + 1);
}

public void draw() {
  background(14, 18, 34);
  engine.update();
  float dt = engine.getGameTime().getDeltaTime();
  float dtReal = engine.getGameTime().getRealDeltaTime();

  switch (state) {
    case PLAYING:
      TdGameWorld.update(dt);
      TdCamera.updateEdgeScroll(dt);
      syncCameraToWindow();
      break;
    case PAUSED:
      // freeze game logic
      break;
    default:
      break;
  }

  sketchUi.updateFrame(dtReal);
  sketchUi.renderFrame();

  if (state == TdState.PLAYING) {
    TdHUD.drawTopBar();
    TdHUD.drawBuildPanel();
    TdHUD.drawMinimap();
  }

  if (state == TdState.PLAYING && buildMode != TdBuildMode.NONE) {
    TdGhost.update();
    TdGhost.draw();
  }

  if (state == TdState.PAUSED) {
    TdHUD.drawPauseOverlay();
  }
}

void syncCameraToWindow() {
  if (worldWindow == null || camera == null) return;
  float newX = worldWindow.getAbsoluteX() + 1;
  float newY = worldWindow.getAbsoluteY() + worldWindow.getTitleBarHeight() + 1;
  if (newX != camera.getViewportOffsetX() || newY != camera.getViewportOffsetY()) {
    camera.setViewportOffset(newX, newY);
  }
  float newW = worldWindow.getWidth() - 2;
  float newH = worldWindow.getHeight() - worldWindow.getTitleBarHeight() - 2;
  if (newW != camera.getViewportWidth() || newH != camera.getViewportHeight()) {
    camera.setViewportSize(newW, newH);
  }
}

public void mousePressed() {
  if (state == TdState.PLAYING) {
    Vector2 dm = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));

    // Pause button
    if (mouseButton == LEFT && TdHUD.isPauseButtonHit(dm.x, dm.y)) {
      state = TdState.PAUSED;
      return;
    }

    // Build panel
    if (mouseButton == LEFT) {
      TdBuildMode clicked = TdHUD.getBuildModeAt(dm.x, dm.y);
      if (clicked != null) {
        buildMode = clicked;
        return;
      }
    }

    if (TdMinimap.isMouseOver() && mouseButton == LEFT) {
      TdHUD.handleMinimapClick();
      return;
    }

    // World viewport click
    if (buildMode != TdBuildMode.NONE && mouseButton == LEFT && TdGhost.isValid) {
      TdGameWorld.tryPlaceTower(buildMode, TdGhost.gridX, TdGhost.gridY);
      buildMode = TdBuildMode.NONE;
    } else if (mouseButton == RIGHT) {
      buildMode = TdBuildMode.NONE;
    }
  }
}

public void mouseDragged() {
  if (state == TdState.PLAYING && mouseButton == LEFT && camera != null && TdCamera.isMouseInViewport()) {
    float dx = mouseX - pmouseX;
    float dy = mouseY - pmouseY;
    camera.getTransform().translate(-dx / camera.getZoom(), -dy / camera.getZoom());
    camera.clampToBounds();
  }
}

public void mouseWheel(MouseEvent e) {
  if (state == TdState.PLAYING && camera != null && TdCamera.isMouseInViewport()) {
    float c = -e.getCount();
    Vector2 dm = engine.getDisplayManager().actualToDesign(new Vector2(mouseX, mouseY));
    camera.zoomAt(c, dm);
  }
}

public void keyPressed() {
  if (keyCode == UP) keyScrollUp = true;
  if (keyCode == DOWN) keyScrollDown = true;
  if (keyCode == LEFT) keyScrollLeft = true;
  if (keyCode == RIGHT) keyScrollRight = true;
  if (key == 'p' || key == 'P') {
    if (state == TdState.PLAYING) state = TdState.PAUSED;
    else if (state == TdState.PAUSED) state = TdState.PLAYING;
  }
}

public void keyReleased() {
  if (keyCode == UP) keyScrollUp = false;
  if (keyCode == DOWN) keyScrollDown = false;
  if (keyCode == LEFT) keyScrollLeft = false;
  if (keyCode == RIGHT) keyScrollRight = false;
}

enum TdState { MENU, LEVEL_SELECT, PLAYING, PAUSED, WIN, LOSE }
enum TdBuildMode { NONE, MG, MISSILE, LASER, SLOW }

public static void main(String[] args) { PApplet.main(new String[]{"TowerDefenseMin2"}); }
}
