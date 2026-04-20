package shenyf.p5engine.collision;

import shenyf.p5engine.scene.GameObject;

import java.util.List;

/**
 * Base interface for collision components.
 * Implementations define shape and collision response.
 */
public interface Collider {

    /**
     * Called by the Scene to check this collider against all other colliders.
     */
    void checkCollisions(List<GameObject> allObjects);

    /**
     * Returns the collision radius for broad-phase checks.
     */
    float getCollisionRadius();

    /**
     * Returns the world-space center position of this collider.
     */
    float getCenterX();

    float getCenterY();
}
