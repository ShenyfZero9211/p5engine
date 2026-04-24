import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;

/** Lightweight enemy data object (DTO) used for combat queries. */
static final class TdEnemy {
    float s;
    float speed;
    float hp;
    float hpMax;
    final int spawnWave;
    final int level;
    boolean alive = true;
    int phase;
    boolean stoleTriggered;
    boolean carriedOrb;
    float slowMul = 1f;

    TdEnemy(int spawnWave, int level, float hpMult) {
        this.spawnWave = spawnWave;
        this.level = level;
        LevelData ld = TdLevelConfig.getLevel(level);
        hpMax = ld.enemyHpBase + spawnWave * ld.enemyHpPerWave;
        hp = hpMax * hpMult;
        speed = ld.enemySpeed;
    }
}

/** Enemy entity — fully Component-based with renderLayer = 15. */
public static class EnemyController extends Component implements Renderable {

    float s;
    float speed;
    float hp;
    float hpMax;
    final int spawnWave;
    final int level;
    boolean alive = true;
    int phase;
    boolean stoleTriggered;
    boolean carriedOrb;
    float slowMul = 1f;

    // Set externally by TdGameWorld after spawn
    TdPath path;
    float dBase;
    float pathTotal;

    EnemyController(int spawnWave, int level, float hpMult) {
        this.spawnWave = spawnWave;
        this.level = level;
        LevelData ld = TdLevelConfig.getLevel(level);
        this.hpMax = ld.enemyHpBase + spawnWave * ld.enemyHpPerWave;
        this.hp = this.hpMax * hpMult;
        this.speed = ld.enemySpeed;
    }

    void setPathData(TdPath path, float dBase, float pathTotal) {
        this.path = path;
        this.dBase = dBase;
        this.pathTotal = pathTotal;
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(15);
    }

    @Override
    public void update(float dt) {
        if (!alive || path == null) return;

        float v = speed * slowMul;
        s += v * dt;
        getTransform().setPosition(path.sample(s));

        if (phase == 0) {
            if (!stoleTriggered && s >= dBase) {
                stoleTriggered = true;
                phase = 1;
            }
        } else if (phase == 1) {
            if (s >= pathTotal - 0.5f) {
                alive = false;
            }
        }
    }

    @Override
    public void render(IRenderer renderer) {
        if (!alive || path == null) return;
        PGraphics g = renderer.getGraphics();
        Vector2 p = path.sample(s);

        g.noStroke();
        g.fill(carriedOrb ? g.color(255, 120, 200) : g.color(200, 80, 80));
        g.ellipse(p.x, p.y, 22, 22);

        float t = hp / hpMax;
        g.noFill();
        g.stroke(40, 40, 60);
        g.rect(p.x - 14, p.y - 22, 28, 4);
        g.fill(80, 220, 120);
        g.noStroke();
        g.rect(p.x - 14, p.y - 22, 28 * t, 4);
    }

    Vector2 getPosition() {
        return path != null ? path.sample(s) : new Vector2(0, 0);
    }
}

/** Rolling orb entity — Component-based, renderLayer = 16. */
public static class RollingOrbController extends Component implements Renderable {

    float s;
    TdPath path;
    float dBase;

    RollingOrbController(float s0) {
        this.s = s0;
    }

    void setPathData(TdPath path, float dBase) {
        this.path = path;
        this.dBase = dBase;
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(16);
    }

    @Override
    public void update(float dt) {
        if (path == null) return;
        s -= TdConfig.ROLL_SPEED * dt;
        getTransform().setPosition(path.sample(s));
        if (s <= dBase) {
            // Reached base — mark for destruction
            getGameObject().setActive(false);
        }
    }

    @Override
    public void render(IRenderer renderer) {
        if (path == null) return;
        PGraphics g = renderer.getGraphics();
        Vector2 p = path.sample(s);
        g.noStroke();
        g.fill(255, 220, 60);
        g.ellipse(p.x, p.y, 16, 16);
    }

    Vector2 getPosition() {
        return path != null ? path.sample(s) : new Vector2(0, 0);
    }
}
