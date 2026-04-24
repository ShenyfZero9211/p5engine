import shenyf.p5engine.scene.*;
import shenyf.p5engine.rendering.*;

/** Projectile / bolt VFX — short-lived Component on its own GameObject, renderLayer = 25. */
public static class FxBoltController extends Component implements Renderable {

    final TowerKind kind;
    final float sx, sy, ex, ey;
    float age;
    final float flyDur;
    float impactAge;

    FxBoltController(TowerKind k, float sx, float sy, float ex, float ey) {
        this.kind = k;
        this.sx = sx;
        this.sy = sy;
        this.ex = ex;
        this.ey = ey;
        this.age = 0;
        if (k == TowerKind.MISSILE) {
            flyDur = 0.2f;
        } else if (k == TowerKind.LASER) {
            flyDur = 0.07f;
        } else {
            flyDur = 0.085f;
        }
        this.impactAge = -1f;
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(25);
    }

    @Override
    public void update(float dt) {
        age += dt;
        if (kind == TowerKind.MISSILE) {
            if (age >= flyDur) {
                if (impactAge < 0f) impactAge = 0f;
                impactAge += dt;
                if (impactAge >= 0.16f) {
                    getGameObject().setActive(false);
                }
            }
        } else if (age >= flyDur) {
            getGameObject().setActive(false);
        }
    }

    @Override
    public void render(IRenderer renderer) {
        PGraphics g = renderer.getGraphics();

        if (kind == TowerKind.MISSILE && impactAge >= 0f) {
            float k = impactAge / 0.16f;
            float alpha = PApplet.lerp(220, 0, k);
            g.noFill();
            g.stroke(255, 200, 80, alpha);
            g.strokeWeight(3);
            float r0 = PApplet.lerp(10f, 48f, k);
            g.ellipse(ex, ey, r0 * 2, r0 * 2);
            g.stroke(255, 120, 40, alpha * 0.55f);
            g.strokeWeight(2);
            g.ellipse(ex, ey, r0 * 2.6f, r0 * 2.6f);
            g.noStroke();
            return;
        }

        float t = min(1f, age / flyDur);
        float x = PApplet.lerp(sx, ex, t);
        float y = PApplet.lerp(sy, ey, t);

        if (kind == TowerKind.LASER) {
            g.stroke(255, 90, 240, PApplet.lerp(40, 220, min(1f, t * 4f)));
            g.strokeWeight(5);
            g.line(sx, sy, ex, ey);
            g.strokeWeight(2);
            g.stroke(255, 220, 255, 200);
            g.line(sx, sy, ex, ey);
            g.noStroke();
        } else if (kind == TowerKind.MISSILE) {
            g.stroke(255, 170, 70, 200);
            g.strokeWeight(4);
            g.line(sx, sy, x, y);
            g.noStroke();
            g.fill(255, 230, 160);
            g.ellipse(x, y, 10, 10);
        } else {
            g.stroke(255, 240, 120, 210);
            g.strokeWeight(2);
            g.line(sx, sy, x, y);
            g.noStroke();
            g.fill(255, 255, 200);
            g.ellipse(x, y, 6, 6);
        }
    }
}

/** Slow-tower ripple VFX — short-lived Component, renderLayer = 25. */
public static class FxRippleController extends Component implements Renderable {

    final float maxR;
    float age;
    final float dur = 0.4f;

    FxRippleController(float maxR) {
        this.maxR = maxR;
        this.age = 0;
    }

    @Override
    public void start() {
        getGameObject().setRenderLayer(25);
    }

    @Override
    public void update(float dt) {
        age += dt;
        if (age >= dur) {
            getGameObject().setActive(false);
        }
    }

    @Override
    public void render(IRenderer renderer) {
        PGraphics g = renderer.getGraphics();
        Vector2 pos = getGameObject().getTransform().getPosition();
        float p = min(1f, age / dur);
        float r = maxR * p;
        float alpha = PApplet.lerp(160, 0, p);
        g.noFill();
        g.stroke(120, 255, 200, alpha);
        g.strokeWeight(2);
        g.ellipse(pos.x, pos.y, r * 2, r * 2);
        g.stroke(180, 255, 220, alpha * 0.45f);
        g.strokeWeight(1);
        g.ellipse(pos.x, pos.y, r * 2 * 0.55f, r * 2 * 0.55f);
        g.noStroke();
    }
}
