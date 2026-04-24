import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;

/** Tower behaviour + rendering; renderLayer = 10. */
public static class TowerController extends Component implements Renderable {

    TowerKind kind = TowerKind.MG;
    float cooldown;
    float buildAccum;

    boolean isOperational() {
        TowerDef d = TowerDef.forKind(kind);
        float bt = (d != null) ? d.buildTime : 2.25f;
        return buildAccum >= bt;
    }

    float buildProgress01() {
        TowerDef d = TowerDef.forKind(kind);
        float bt = (d != null) ? d.buildTime : 2.25f;
        return min(1f, buildAccum / bt);
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(10);
    }

    void tick(TdGameWorld world, float dt, Vector2 pos) {
        TowerDef d = TowerDef.forKind(kind);
        if (d == null) return;

        if (!isOperational()) {
            buildAccum += dt;
            return;
        }

        if (kind == TowerKind.SLOW) {
            cooldown -= dt;
            if (cooldown > 0) return;
            world.addSlowRipple(pos.x, pos.y);
            cooldown = d.firePeriod > 0.05f ? d.firePeriod : 0.72f;
            world.playSfx(d.sfxFire);
            return;
        }

        cooldown -= dt;
        if (cooldown > 0) return;

        TdEnemy tgt = world.findNearestAliveEnemy(pos, d.range);
        if (tgt == null) {
            cooldown = d.firePeriod;
            return;
        }

        Vector2 ep = world.path.sample(tgt.s);
        world.addBoltFx(kind, pos.x, pos.y, ep.x, ep.y);

        if (kind == TowerKind.MISSILE) {
            world.damageEnemyNearest(pos, d.range, d.damage, d.aoeRadius, true);
            world.playSfx(d.sfxFire);
        } else if (kind == TowerKind.LASER) {
            world.damageEnemyNearest(pos, d.range, d.damage, 0, false);
            world.playSfx(d.sfxFire);
        } else {
            world.damageEnemyNearest(pos, d.range, d.damage, 0, false);
            world.playSfx(d.sfxFire);
        }
        cooldown = d.firePeriod;
    }

    @Override
    public void render(IRenderer renderer) {
        TowerDef d = TowerDef.forKind(kind);
        if (d == null) return;

        PGraphics g = renderer.getGraphics();
        Vector2 pos = getGameObject().getTransform().getPosition();
        boolean op = isOperational();

        g.noStroke();

        if (!op) {
            float bp = buildProgress01();
            g.fill(g.red(d.iconColor), g.green(d.iconColor), g.blue(d.iconColor), 90);
            g.rectMode(PGraphics.CENTER);
            g.rect(pos.x, pos.y, 28, 28, 4);
            g.rectMode(PGraphics.CORNER);
            g.noStroke();
            g.fill(40, 55, 75, 220);
            g.rect(pos.x - 12, pos.y - 21, 24, 5, 2);
            g.fill(100, 200, 255, 240);
            g.rect(pos.x - 12, pos.y - 21, 24 * bp, 5, 2);
            g.stroke(180, 210, 255, 160);
            g.noFill();
            g.strokeWeight(1);
            g.rectMode(PGraphics.CENTER);
            g.rect(pos.x, pos.y, 30, 30, 4);
        } else {
            g.fill(g.red(d.iconColor), g.green(d.iconColor), g.blue(d.iconColor));
            g.rectMode(PGraphics.CENTER);
            g.rect(pos.x, pos.y, 28, 28, 4);
        }
        g.rectMode(PGraphics.CORNER);
        g.noStroke();
    }
}
