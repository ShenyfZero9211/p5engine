package shenyf.p5engine.collision;

import shenyf.p5engine.scene.GameObject;

/**
 * Interface for Components that want to receive collision events.
 * Implement this on any Component attached to the same GameObject as a Collider.
 */
public interface CollisionListener {

    void onCollision(GameObject other);
}
