package shenyf.p5engine.collision;

import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.GameObject;

import java.util.List;

/**
 * Generic circular collision component.
 * Attach to any GameObject to give it a circular hit region.
 */
public class CircleCollider extends Component implements Collider {

    private float radius = 10;
    private float offsetX = 0;
    private float offsetY = 0;

    public CircleCollider() {
    }

    public CircleCollider(float radius) {
        this.radius = radius;
    }

    public CircleCollider(float radius, float offsetX, float offsetY) {
        this.radius = radius;
        this.offsetX = offsetX;
        this.offsetY = offsetY;
    }

    @Override
    public void checkCollisions(List<GameObject> allObjects) {
        if (getGameObject() == null || !isEnabled()) return;

        float ax = getCenterX();
        float ay = getCenterY();
        float ar = getCollisionRadius();
        shenyf.p5engine.scene.Scene scene = getGameObject().getScene();

        for (GameObject other : allObjects) {
            if (other == getGameObject() || !other.isActive()) continue;

            for (Component c : other.getComponents()) {
                if (c instanceof Collider && c != this && c.isEnabled()) {
                    Collider otherCollider = (Collider) c;
                    float bx = otherCollider.getCenterX();
                    float by = otherCollider.getCenterY();
                    float br = otherCollider.getCollisionRadius();

                    float dx = ax - bx;
                    float dy = ay - by;
                    float distSq = dx * dx + dy * dy;
                    float minDist = ar + br;

                    if (scene != null) {
                        scene.incrementCollisionCheckCount();
                    }

                    if (distSq < minDist * minDist) {
                        onCollision(other);
                    }
                }
            }
        }
    }

    @Override
    public float getCollisionRadius() {
        return radius;
    }

    @Override
    public float getCenterX() {
        return getTransform().getWorldPosition().x + offsetX;
    }

    @Override
    public float getCenterY() {
        return getTransform().getWorldPosition().y + offsetY;
    }

    /**
     * Notifies all sibling Components that implement CollisionListener.
     */
    protected void onCollision(GameObject other) {
        for (Component c : getGameObject().getComponents()) {
            if (c instanceof CollisionListener && c.isEnabled()) {
                ((CollisionListener) c).onCollision(other);
            }
        }
    }

    public float getRadius() {
        return radius;
    }

    public void setRadius(float radius) {
        this.radius = radius;
    }

    public float getOffsetX() {
        return offsetX;
    }

    public void setOffsetX(float offsetX) {
        this.offsetX = offsetX;
    }

    public float getOffsetY() {
        return offsetY;
    }

    public void setOffsetY(float offsetY) {
        this.offsetY = offsetY;
    }
}
